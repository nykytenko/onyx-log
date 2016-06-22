/**
 * onyx-log: the generic, fast, multithreading logging library.
 *
 * Appenders implementation.
 *
 * Copyright: © 2015 onyx-itdevelopment
 *
 * License: MIT license. License terms written in "LICENSE.txt" file
 *
 * Authors: Oleg Nykytenko (onyx), onyx.itdevelopment@gmail.com
 *
 * Version: 0.xx
 *
 * Date: 13.05.2015
 */

module onyx.core.appender;


@system:
package:


import onyx.bundle;

/*
 * Appender Create interface
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
	void append(immutable string message);
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
	override void append(immutable string message) nothrow pure {}
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
	override void append(immutable string message)
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
	
	/**
	 * Tid for appender activity
	 */
	Tid activity;
	
	
	/**
	 * Create Appender
	 */
	@trusted
	this(immutable Bundle bundle)
	{
		activity = spawn(&fileAppenderActivityStart, bundle);
	}
	

	/**
 	 * Append new message and send it to file
   	 */
	@trusted
	override void append(immutable string message)
	{
		activity.send(message);
	}
}


/**
 * Start new thread for file log activity
 */
@system
void fileAppenderActivityStart(immutable Bundle bundle)
{
	new FileAppenderActivity(bundle).run();
}



/**
 * Logger FileAppender activity
 *
 * Write log message to file from one thread
 */
class FileAppenderActivity
{
	import  onyx.core.controller;
	import std.concurrency;
	import std.datetime;
	
	
	/**
	 * Max flush period to write to file
	 */
	enum logFileWriteFlushPeriod = 100; // ms
	
	
	/**
     * Activity working status
     */
    enum AppenderWorkStatus {WORKING, STOPPING}
    private auto workStatus = AppenderWorkStatus.WORKING;


    long startFlushTime;
    
    
    /**
	 * Max flush period to write to file
	 */
	Controller controller;
    
    
	/**
	 * Primary constructor
	 *
	 * Save config path and name
	 */
    this(immutable Bundle bundle)
    {
    	try
    	{
	    	controller = Controller(bundle);
		}
		catch (Exception e)
		{
			import std.stdio;
			writeln("FileAppenderActivity exception: " ~ e.msg);
		}	

		startFlushTime = Clock.currStdTime();
    }

    import std.stdio;
    import std.conv;
    
    
    /**
	 * Entry point for start module work
	 */
	@system
	void run()
	{
		/**
		 * Timer cycle for flush log file
		 */

		
		while (workStatus == AppenderWorkStatus.WORKING)
		{
			workCycle();
		}
	}



	
	
	/**
	 * Activity main cycle
	 */
	@trusted
	private void workCycle()
	{
		receiveTimeout(
			dur!("msecs")(10),
			(string msg)
			{
				controller.saveMsg(msg);
			},
			(OwnerTerminated e){workStatus = AppenderWorkStatus.STOPPING;},
			(Variant any){}
		);

		if (logFileWriteFlushPeriod > (Clock.currStdTime() - startFlushTime)/(1000*10))
		{
			controller.flush;
			startFlushTime = Clock.currStdTime();
		}
	}
	
	
	

}
