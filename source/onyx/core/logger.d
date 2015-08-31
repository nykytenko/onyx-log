/**
 * onyx-log: the generic, fast, multithreading logging library.
 *
 * Logger core implementation.
 *
 * Copyright: © 2015 onyx-itdevelopment
 *
 * License: MIT license. License terms written in "LICENSE.txt" file
 *
 * Authors: Oleg Nykytenko (onyx), onyx.itdevelopment@gmail.com
 *
 * Version: 0.xx
 *
 * Date: 20.03.2015
 */
module onyx.core.logger;


import onyx.log;
import onyx.config.bundle;


@safe:
public:

/**
 * Create loggers
 *
 * Throws: ConfException, LogCreateException, Exception
 */
@trusted
void create(immutable ConfBundle bundle)
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
Log get(immutable string loggerName)
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
 * Set file for save loggers exception information
 *
 * Throws: Exception
 */
@trusted
void setErrorFile(immutable string file)
{
	synchronized (lock) 
	{
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
@system:
private:

import core.sync.mutex;

import std.stdio;

import onyx.core.appender;
/*
 * Mutex use for block work with loggers pool
 */
__gshared Mutex lock;


/*
 * Save loggers by names in pool
 */
__gshared Logger[immutable string] ids;


/*
 * Save loggers errors in file
 */
__gshared File errorFile;



shared static this()
{
	lock = new Mutex();
}


/*
 * Logger implementation
 */
class Logger: Log
{
	/*
 	 * Configuration data
   	 */ 
	mixin(addVal!(immutable ConfBundle, "config", "public"));


	/*
 	 * Name
   	 */ 
	mixin(addVal!(immutable string, "name", "public"));
	
	
	/*
 	 * Level getter in string type
   	 */ 
	public immutable (string) level()
	{
		return mlevel.levelToString();
	}
	

	/*
 	 * Level
   	 */ 
	Level mlevel;

	
	/*
 	 * Appender
   	 */
	Appender appender;
	

	/*
 	 * Encoder
   	 */
	Encoder encoder;
	
	
	/*
	 * Create logger impl
	 *
	 * Throws: LogCreateException, ConfException
	 */
	this(immutable ConfBundle bundle)
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
	 * Throws: ConfException, LogCreateException
	 */
	@trusted /* Object.factory is system */
	Appender createAppender(immutable ConfBundle bundle)
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
		catch (ConfException e)
		{
			throw new ConfException("Error in Config bundle. [" ~ name ~ "]:" ~ e.msg);
		}
		catch (Exception e)
		{
			throw new LogCreateException("Error in creating appender for logger: " ~ name ~ ": " ~ e.msg);
		}
	}
	

	/*
	 * Write message with level "debug" to logger
	 */
	void debug_(lazy const string msg) nothrow
	{
		putMsg(msg, Level.debug_);
	}


	/*
	 * Write message with level "info" to logger
	 */
	void info(lazy const string msg) nothrow
	{
		putMsg(msg, Level.info);
	}
	

	/*
	 * Write message with level "warning" to logger
	 */
	void warning(lazy const string msg) nothrow
	{
		putMsg(msg, Level.warning);
	}
	

	/*
	 * Write message with level "error" to logger
	 */
	void error(lazy const string msg) nothrow
	{
		putMsg(msg, Level.error);
	}
	

	/*
	 * Write message with level "critical" to logger
	 */
	void critical(lazy const string msg) nothrow
	{
		putMsg(msg, Level.critical);
	}
	

	/*
	 * Write message with level "fatal" to logger
	 */
	void fatal(lazy const string msg) nothrow
	{
		putMsg(msg, Level.fatal);
	}
	

	/*
	 * Encode message and put to appender
	 */
	@trusted
	void putMsg(lazy string msg, Level level) nothrow
	{
		string fmsg;
		if (level >= mlevel)
		{
			try
			{
				fmsg = encoder.encode(msg, level);
			}
			catch (Exception e)
			{
				try
				{
					fmsg = encoder.encode("Error in encode log message: " ~ e.msg, Level.error);
				}
				catch (Exception ee)
				{
					fixException(ee);
				}
			}
			try
			{
				appender.append(fmsg);
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


class Encoder
{
	import std.datetime;
	
	/*
 	 * Name
   	 */ 
	mixin(addVal!(immutable string, "name", "private"));
	
	
	/*
 	 * Build encoder
   	 */ 
	this(immutable ConfBundle bundle) pure nothrow
	{
		_name = bundle.glKeys[0];
	}
	
	
	/**
 	 * Do make message finish string
 	 *
 	 * Throws: Exception
   	 */ 
	immutable (string) encode (immutable string message, immutable Level level)
	{
		return std.string.format("%-27s [%s] %s- %s", Clock.currTime.toISOExtString(), levelToString(level), name, message);
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


