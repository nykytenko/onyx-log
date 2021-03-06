/**
 * onyx-log: the generic, fast, multithreading logging library.
 *
 * Logger core implementation.
 *
 * Copyright: © 2015- Oleg Nykytenko
 * License: MIT license. License terms written in "LICENSE.txt" file
 * Authors: Oleg Nykytenko, oleg.nykytenko@gmail.com
 */

module onyx.core.logger;


import onyx.log;
import onyx.bundle;


@safe:
public:

/**
 * Create loggers
 *
 * Throws: ConfException, LogCreateException, Exception
 */
@trusted
void create(immutable Bundle bundle)
{
    synchronized (lock)
    {
        foreach(loggerName; bundle.glKeys())
        {
            if (loggerName in ids)
            {
                throw new LogCreateException("Creating logger error. Logger with name: " ~ loggerName ~ " already created");
            }
            auto log = new Logger(bundle.subBundle(loggerName));
            ids[loggerName] = log;
        }
    }
}

/**
 * Delete loggers
 *
 * Throws: Exception
 */
@trusted
void delete_(immutable GlKey[] loggerNames)
{
    synchronized (lock)
    {
        foreach(loggerName; loggerNames)
        {
            if (loggerName in ids)
            {
            	ids.remove(loggerName);
            }
        }
    }
}

/**
 * Get created logger
 *
 * Throws: LogException
 */
@trusted
Logger get(immutable string loggerName)
{
    if (loggerName in ids)
    {
        return ids[loggerName];
    }
    else
    {
        throw new LogException("Getting logger error. Logger with name: " ~ loggerName ~ " not created");
    }
}

/**
 * Check Logger
 */
@trusted
bool isCreated(immutable string loggerName) nothrow
{
    return (loggerName in ids) ? true : false;
}

/**
 * Set file for save loggers exception information
 *
 * Throws: Exception
 */
@trusted
void setErrorFile(immutable string file)
{
    synchronized (lock)
    {
        static import onyx.core.controller;
        onyx.core.controller.createPath(file);
        errorFile = File(file, "a");
    }
}

/*
 * Make class member with getter
 */
template addVal(T, string name, string specificator)
{
    const char[] member = "private " ~ T.stringof ~ " _" ~ name ~"; ";
    const char[] getter = "@property nothrow pure " ~ specificator ~ " " ~ T.stringof ~ " " ~ name ~ "() { return _" ~ name ~ "; }";
    const char[] addVal = member ~ getter;
}

/**
 * Make class member with getter and setter
 *
 */
template addVar(T, string name, string getterSpecificator, string setterSpecificator)
{
    const char[] setter = "@property nothrow pure " ~ setterSpecificator ~ " void " ~ name ~ "(" ~ T.stringof ~ " var" ~ ") { _" ~ name ~ " = var; }";
    const char[] addVar = addVal!(T, name, getterSpecificator) ~ setter;
}

/*
 **************************************************************************************
 */

/*
 * Logger implementation
 */
class Logger
{

public:
    /*
     * Write message with level "debug" to logger
     */
    void debug_(M...)(lazy const M msg) nothrow
    {
        putMsg(Level.debug_, msg);
    }

    /*
     * Write message with level "info" to logger
     */
    void info(M...)(lazy const M msg) nothrow
    {
        putMsg(Level.info, msg);
    }

    /*
     * Write message with level "warning" to logger
     */
    void warning(M...)(lazy const M msg) nothrow
    {
        putMsg(Level.warning, msg);
    }

    /*
     * Write message with level "error" to logger
     */
    void error(M...)(lazy const M msg) nothrow
    {
        putMsg(Level.error, msg);
    }

    /*
     * Write message with level "critical" to logger
     */
    void critical(M...)(lazy const M msg) nothrow
    {
        putMsg(Level.critical, msg);
    }

    /*
     * Write message with level "fatal" to logger
     */
    void fatal(M...)(lazy const M msg) nothrow
    {
        putMsg(Level.fatal, msg);
    }

@system:
private:
    /* Configuration data */
    mixin(addVal!(immutable Bundle, "config", "public"));
    /* Name */
    mixin(addVal!(immutable string, "name", "public"));

    /*
     * Level getter in string type
     */
    public immutable (string) level()
    {
        return mlevel.levelToString();
    }

    /* Level */
    Level mlevel;
    /* Appender */
    Appender appender;
    /* Encoder */
    Encoder encoder;

    /*
     * Create logger impl
     *
     * Throws: LogCreateException, ConfException
     */
    this(immutable Bundle bundle)
    {
        _config = bundle;
        _name = bundle.glKeys[0];
        mlevel = bundle.value(name, "level").toLevel;

        appender = createAppender(bundle);
        encoder = new Encoder(bundle);
    }

    /*
     * Extract logger type from bundle
     *
     * Throws: BundleException, LogCreateException
     */
    @trusted /* Object.factory is system */
    Appender createAppender(immutable Bundle bundle)
    {
        try
        {
            string appenderType = bundle.value(name, "appender");
            AppenderFactory f = cast(AppenderFactory)Object.factory("onyx.core.appender." ~ appenderType ~ "Factory");

            if (f is null)
            {
                throw new  LogCreateException("Error create log appender: " ~ appenderType  ~ "  is Illegal appender type from config bundle.");
            }
            Appender a = f.factory(bundle);
            return a;
        }
        catch (BundleException e)
        {
            throw new BundleException("Error in Config bundle. [" ~ name ~ "]:" ~ e.msg);
        }
        catch (Exception e)
        {
            throw new LogCreateException("Error in creating appender for logger: " ~ name ~ ": " ~ e.msg);
        }
    }

    /*
     * Encode message and put to appender
     */
    @trusted
    void putMsg(M...)(Level level, lazy M msg) nothrow
    {
        if (level >= mlevel)
        {
            string emsg;
            try
            {
                import std.format;
                auto fmsg = format(msg);
                emsg = encoder.encode(level, fmsg);
            }
            catch (Exception e)
            {
                try
                {
                    emsg = encoder.encode(Level.error, "Error in encoding log message: " ~ e.msg);
                }
                catch (Exception ee)
                {
                    fixException(ee);
                    return;
                }
            }
            try
            {
                appender.append(emsg);
            }
            catch (Exception e)
            {
                fixException(e);
            }
        }
    }

    /**
     * Logger exeption handler
     */
    @trusted
    void fixException (Exception e) nothrow
    {
        try
        {
            synchronized(lock)
            {
                errorFile.writeln("Error to work with log-> " ~ name ~ " Exception-> "  ~ e.msg);
            }
        }
        catch(Exception e){}
    }
}

@system:
private:


import core.sync.mutex;
import std.stdio;
import onyx.core.appender;

/* Mutex use for block work with loggers pool */
__gshared Mutex lock;
/* Save loggers by names in pool */
__gshared Logger[immutable string] ids;
/* Save loggers errors in file */
__gshared File errorFile;


shared static this()
{
    lock = new Mutex();
}


class Encoder
{
    import std.datetime;

    /* Name */
     mixin(addVal!(immutable string, "name", "private"));

    /*
     * Build encoder
     */
    this(immutable Bundle bundle) pure nothrow
    {
        _name = bundle.glKeys[0];
    }

    /**
     * Do make message finish string
     *
     * Throws: Exception
     */
    string encode (immutable Level level, const string message)
    {
        import std.string;
        string strLevel = "[" ~ levelToString(level) ~ "]";
        return format("%-27s %-10s %-s- %s", Clock.currTime.toISOExtString(), strLevel, name, message);
    }
}


/*
 * Level type
 */
enum Level:int
{
    debug_ = 1,
    info = 2,
    warning = 3,
    error = 4,
    critical = 5,
    fatal = 6
}


/*
 * Convert level from string type to Level
 */
Level toLevel(string str)
{
    Level l;
    switch (str)
    {
        case "debug":
            l = Level.debug_;
            break;
        case "info":
            l = Level.info;
            break;
        case "warning":
            l = Level.warning;
            break;
        case "error":
            l = Level.error;
            break;
        case "critical":
            l = Level.critical;
            break;
        case "fatal":
            l = Level.fatal;
            break;
        default:
            throw new LogCreateException("Error log level value: " ~ str);
    }
    return l;
}

/*
 * Convert level from Level type to string
 */
@safe
string levelToString(Level level)
{
    string l;
    final switch (level)
    {
        case Level.debug_:
            l = "debug";
            break;
        case Level.info:
            l = "info";
            break;
        case Level.warning:
            l = "warning";
            break;
        case Level.error:
            l = "error";
            break;
        case Level.critical:
            l = "critical";
            break;
        case Level.fatal:
            l = "fatal";
            break;
    }
    return l;
}
