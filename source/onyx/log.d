/**
 * onyx-log: the generic, fast, multithreading logging library.
 *
 * User interface to work with logging.
 *
 * Copyright: © 2015- Oleg Nykytenko
 * License: MIT license. License terms written in "LICENSE.txt" file
 * Authors: Oleg Nykytenko, oleg.nykytenko@gmail.com
 */

module onyx.log;


import onyx.bundle;
public import onyx.core.logger;


deprecated("Use onyx.log.Logger")
alias Log = Logger;

@safe:

/**
 * Create loggers from config bundle
 *
 * Throws: BundleException, LogCreateException
 */
void createLoggers(immutable Bundle bundle)
{
    create(bundle);
}

/**
 * Get created logger interface to work with it
 *
 * Throws: LogException
 */
Logger getLogger(immutable string loggerName)
{
    return get(loggerName);
}

/**
 * Delete logger
 *
 * Throws: Exception
 */
void deleteLogger(immutable string loggerName)
{
    delete_([loggerName]);
}

/**
 * Delete loggers
 *
 * Throws: Exception
 */
void deleteLoggers(immutable string[] loggerNames)
{
    delete_(loggerNames);
}

/**
 * Check is Logger present
 */
bool isLogger(immutable string loggerName) nothrow
{
    return isCreated(loggerName);
}

/**
 * Set path to file for save loggers exception information
 *
 * Throws: Exception
 */
void setErrFile(immutable string file)
{
    setErrorFile(file);
}



/**
 * Logger exception
 */
class LogException:Exception
{
    @safe pure nothrow this(string exString)
    {
        super(exString);
    }
}

/**
 * Log creation exception
 */
class LogCreateException:LogException
{
    @safe pure nothrow this(string exString)
    {
        super(exString);
    }
}



unittest
{
    auto bundle = new immutable Bundle("./test/test.conf");
    createLoggers(bundle);
    setErrorFile("./log/error.log");

    version(vTestFile)
    {
        auto log2 = getLogger("DebugLogger");
        log2.debug_("debug msg");
        log2.info("info msg %d", 2);
        log2.error("error test %d %s", 3, "msg");
	}
    else
    {
        Logger log = getLogger("ErrorLogger");
    	log.info("info test msg %d", 2);
    	log.error("error test %s", "msg");
        log.critical("critical test msg %#x", 125);
    }
}
