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

import onyx.config.bundle;
import onyx.log;

import std.concurrency;
import std.datetime;
import std.file;
import std.stdio;
import std.string;

import core.sync.mutex;
import core.thread;


/**
 * Create loggers
 *
 * Throws: ConfException, LogCreateException, Exception
 */
@trusted
void create(immutable ConfBundle bundle)
{
	auto names = bundle.glKeys();
	synchronized (lock) 
	{
		foreach(loggerName; names)
		{
			if (loggerName in ids)
			{
				throw new LogCreateException("Creating logger error. Logger with name: " ~ loggerName ~ " already created");
			}
			auto log = new Logger(bundle.subBundle(loggerName), loggerName);
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
		auto errorFile = File(file, "a");
	}
}





private:


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
 * Make class member with getter
 */
template addVal(T, string name, string specificator)
{
	const char[] member = "private " ~ T.stringof ~ " _" ~ name ~"; ";
	const char[] getter = "@property nothrow pure " ~ specificator ~ " " ~ T.stringof ~ " " ~ name ~ "() { return _" ~ name ~ "; }";
	const char[] addVal = member ~ getter;
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
	this(immutable ConfBundle bundle, immutable GlKey loggerName)
	{
		if (!bundle.isGlKeyPresent(loggerName))
		{
			throw new LogCreateException("Creating logger error. Not found in config bundle logger with name: " ~ loggerName);
		}
		_config = bundle;
		_name = loggerName;
		mlevel = bundle.value(loggerName, "level").toLevel;
		
		appender = createAppender(bundle, loggerName);
		encoder = new Encoder(bundle, this);
	}
	
	
	/*
	 * Extract logger type from bundle
	 *
	 * Throws: ConfException, LogCreateException
	 */
	@trusted /* Object.factory is system */
	Appender createAppender(immutable ConfBundle bundle, immutable GlKey loggerName)
	{
		try
		{
			string appenderType = bundle.value(loggerName, "appender");
			AppenderFactory f = cast(AppenderFactory)Object.factory("onyx.core.logger." ~ appenderType ~ "Factory");
			
			if (f is null)
			{
				throw new  LogCreateException("Error create log appender: " ~ appenderType  ~ "  is Illegal appender type from config bundle.");
			}
			
			Appender a = f.factory(bundle, this);
			return a;
		}
		catch (ConfException e)
		{
			throw new ConfException("Error in Config bundle. [" ~ loggerName ~ "]:" ~ e.msg);
		}
		catch (Exception e)
		{
			throw new LogCreateException("Error in creating appender for logger: " ~ loggerName ~ ": " ~ e.msg);
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


/*
 * Appender Create interface
 *
 * Use by Logger for create new Appender
 *
 * ====================================================================================
 */ 
interface AppenderFactory
{
	Appender factory(immutable ConfBundle bundle, Logger logger);
}



/**
 * Accept messages and publicate it in target
 */ 
abstract class Appender
{
	/**
 	 * Save Logger
   	 */ 
	Logger logger;
	
	
	/**
 	 * Create Appender
   	 */ 
	this(Logger logger) nothrow pure
	{
		this.logger = logger;
	}
	
	
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
	override Appender factory(immutable ConfBundle bundle, Logger logger)
	{
		return new NullAppender(logger);
	}
}

/**
 * Only Accept messages
 */ 
class NullAppender:Appender
{
	/**
	 * Create Appender
	 */ 
	this(Logger logger)
	{
		super(logger);
	}
	

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
	override Appender factory(immutable ConfBundle bundle, Logger logger)
	{
		return new ConsoleAppender(logger);
	}
}


/**
 * Accept messages and publicate it on console
 */
class ConsoleAppender:Appender
{
	/**
	 * Create Appender
	 */ 
	this(Logger logger)
	{
		super(logger);
	}
	

	/**
 	 * Append new message and print it to console
   	 */
	@trusted /* writefln is system */
	override void append(immutable string message)
	{
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
	override Appender factory(immutable ConfBundle bundle, Logger logger)
	{
		return new FileAppender(bundle, logger);
	}
}


/**
 * Accept messages and publicate it in file
 */
class FileAppender:Appender
{
	/**
	 * Tid for appender activity
	 */
	Tid activity;
	
	
	/**
	 * Create Appender
	 */
	@trusted
	this(immutable ConfBundle bundle, Logger logger)
	{
		super(logger);
		auto filePath = bundle.value(logger.name, "fileNameBase");
		activity = spawn(&fileAppenderActivityStart, filePath);
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
void fileAppenderActivityStart(string filePath)
{
	new FileAppenderActivity(filePath).run();
}



/**
 * Logger FileAppender activity
 *
 * Write log message to file from one thread
 */
class FileAppenderActivity
{
	/**
	 * Max flush period to write to file
	 */
	enum logFileWriteFlushPeriod = 100; // ms


	/**
     * Activity working status
     */
    enum AppenderWorkStatus {WORKING, STOPPING}
    auto workStatus = AppenderWorkStatus.WORKING;


    /**
     * Path to logger file
     */
    mixin(addVal!(immutable string, "filePath", "private"));


	/**
	 * Logging file
	 */
	File file;


	/**
	 * Primary constructor
	 *
	 * Save path to log file
	 */
    this(string filePath) nothrow pure
    {
    	_filePath = filePath;
    }
    

    /**
     * Check Parent directory creation requrired
     */
    private bool isParentDirectoryCreationRequired(string filePath)
    {
    	string dir = getParentDir(filePath);
    	
    	if ((dir.length != 0) && (!exists(dir))) 
    	{
    		return true;
    	}
    	else return false;
    }
    

    /**
     * Create full path to log file
     */
    @system
    private void createMissingParentDirectories(string filePath)
    {
    	mkdirRecurse(getParentDir(filePath)); 
    }
    
    
    /**
     * get parent directory from full file path
     */
    private string getParentDir(string filePath)
    {
    	version(Windows) 
    		string dir = filePath[0..filePath.lastIndexOf("\\")];
    	else 
    		string dir = filePath[0..filePath.lastIndexOf("/")];
    	return dir;
    }
    
    
    /**
     * open log file to work
     */
    @system
    private void openFile(string filePath)
    {
    	if (isParentDirectoryCreationRequired(filePath))
    		createMissingParentDirectories(filePath);
    	file = File(filePath.strip, "a");
    }


	/**
	 * Entry point for start module work
	 */
	@system
	void run()
	{
		openFile(filePath);
		
		auto fileTid = thisTid;
		
		/**
		 * Timer cycle for flush log file
		 */
		void flushTimerCycle()
		{
			while (workStatus == AppenderWorkStatus.WORKING)
			{
				Thread.sleep( dur!("msecs")( logFileWriteFlushPeriod ) );
				send(fileTid, "log_file_flush");
			}
		}
		new Thread(&flushTimerCycle).start;
		
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
		receive(
			(string msg)
			{
				if (msg == "log_file_flush") 
					file.flush;
				else	
					saveToFile(msg);
			},
			(OwnerTerminated e){workStatus = AppenderWorkStatus.STOPPING;},
			(Variant any){}
		);
	}
	
	
	/**
	 * Save message to log file
	 */
	@trusted
	void saveToFile(string msg)
	{
		if (!file.isOpen()) file.open(filePath, "a");
		file.writeln(msg);
	}

}



class Encoder
{
	/*
 	 * Logger
   	 */ 
	Logger logger;
	
	
	/*
 	 * Build encoder
   	 */ 
	this(immutable ConfBundle bundle, Logger logger) pure nothrow
	{
		this.logger = logger;
	}
	
	
	/**
 	 * Do make message finish string
 	 *
 	 * Throws: Exception
   	 */ 
	immutable (string) encode (immutable string message, immutable Level level)
	{
		return std.string.format("%-27s [%s] %s- %s", Clock.currTime.toISOExtString(), levelToString(level), logger.name, message);
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
