/**
 * onyx-log: the generic, fast, multithreading logging library.
 *
 * Appenders implementation.
 *
 * Copyright: © 2015- Oleg Nykytenko
 * License: MIT license. License terms written in "LICENSE.txt" file
 * Authors: Oleg Nykytenko, oleg.nykytenko@gmail.com
 */

module onyx.core.appender;


@system:
package:


import onyx.bundle;

/**
 * Appender Creating interface
 *
 * Use by Logger for create new Appender
 *
 * ====================================================================================
 */
interface AppenderFactory
{
    Appender factory(immutable Bundle bundle);
}


/**
 * Accept messages and publicate it in target
 */
abstract class Appender
{
    /**
     * Append new message
     */
    void append(string message);

    /**
     * Stop appender and release its resources
     *
     * Messages appended after stop are lost
     */
    void stop() nothrow {}
}


/**
 * Factory for NullAppender
 *
 * ====================================================================================
 */
class NullAppenderFactory:AppenderFactory
{
    override Appender factory(immutable Bundle bundle)
    {
        return new NullAppender();
    }
}


/**
 * Only Accept messages
 */
class NullAppender:Appender
{
    /**
     * Append new message and do nothing
     */
    override void append(string message) nothrow pure {}
}


/**
 * Factory for ConsoleAppender
 *
 * ====================================================================================
 */
class ConsoleAppenderFactory:AppenderFactory
{
    override Appender factory(immutable Bundle bundle)
    {
        return new ConsoleAppender();
    }
}


/**
 * Accept messages and publicate it on console
 */
class ConsoleAppender:Appender
{
    /**
     * Append new message and print it to console
     */
    @trusted /* writefln is system */
    override void append(string message)
    {
        import std.stdio;
        writeln(message);
    }
}


/**
 * Factory for FileAppender
 *
 * ====================================================================================
 */
class FileAppenderFactory:AppenderFactory
{
    override Appender factory(immutable Bundle bundle)
    {
        return new FileAppender(bundle);
    }
}


/**
 * Accept messages and publicate it in file
 */
class FileAppender:Appender
{
    import std.concurrency;

    /* Tid for appender activity */
    Tid activity;

    /**
     * Create Appender
     */
    @trusted
    this(immutable Bundle bundle)
    {
        version (vibedlog)
        {
            import vibe.core.core;
            activity = runTask({fileAppenderActivityStart(bundle);}).tid;
        }
        else
        {
            activity = spawn(&fileAppenderActivityStart, bundle);
        }
    }

    /**
     * Append new message and send it to file
     */
    @trusted
    override void append(string message)
    {
        activity.send(message);
    }

    /**
     * Stop appender activity: it writes received messages, closes file and exits
     *
     * Activity has no owner in vibedlog version (runTask), so without stop
     * it works and keeps file opened forever
     */
    @trusted
    override void stop() nothrow
    {
        try
        {
            activity.send(AppenderStopMsg());
        }
        catch (Exception e) {}
    }
}


/**
 * Command for appender activity to stop
 */
struct AppenderStopMsg {}


/**
 * Start new thread for file log activity
 */
@system
void fileAppenderActivityStart(immutable Bundle bundle) nothrow
{
    try
    {
        new FileAppenderActivity(bundle).run();
    }
    catch (Exception e)
    {
        try
        {
            import std.stdio;
            writeln("FileAppenderActivity exception: " ~ e.msg);
        }
        catch (Exception ioe){}
    }
}


/**
 * Logger FileAppender activity
 *
 * Write log message to file from one thread
 */
class FileAppenderActivity
{
    import onyx.core.controller;
    import std.concurrency;
    import std.datetime;


    /* Max flush period to write to file */
    enum logFileWriteFlushPeriod = 100; // ms

    /* Activity working status */
    enum AppenderWorkStatus {WORKING, STOPPING}
    private auto workStatus = AppenderWorkStatus.WORKING;

    long startFlushTime;

    /* Max flush period to write to file */
    Controller controller;

    /**
     * Primary constructor
     *
     * Save config path and name
     */
    this(immutable Bundle bundle)
    {
        controller = Controller(bundle);
        startFlushTime = Clock.currStdTime();
    }

    /**
     * Entry point for start module work
     */
    @system
    void run()
    {
        /**
         * Main activity cycle
         */
        while (workStatus == AppenderWorkStatus.WORKING)
        {
            try
            {
                workCycle();
            }
            catch (Exception e)
            {
                import std.stdio;
                writeln("FileAppenderActivity workcycle exception: " ~ e.msg);
            }
        }
        try
        {
            controller.close();
        }
        catch (Exception e)
        {
            import std.stdio;
            writeln("FileAppenderActivity close exception: " ~ e.msg);
        }
    }

    /**
     * Activity main cycle
     */
    @trusted
    private void workCycle()
    {
        receiveTimeout(
            100.msecs,
            (string msg)
            {
                controller.saveMsg(msg);
            },
            (AppenderStopMsg m){workStatus = AppenderWorkStatus.STOPPING;},
            (OwnerTerminated e){workStatus = AppenderWorkStatus.STOPPING;},
            (Variant any){}
        );

        if (logFileWriteFlushPeriod <= (Clock.currStdTime() - startFlushTime)/(1000*10))
        {
            controller.flush;
            startFlushTime = Clock.currStdTime();
        }
    }
}
