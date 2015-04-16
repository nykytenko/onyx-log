# onyx-log

onyx-log: the simple, fast, multithreading logging library for D.


## Key features:
 - Create loggers in "logger pool" with configuration data packed to ConfBundle (onyx-config lib).
 - Get logger by his name.
 - Write message to logger.
 - Any work with loggers in multi-threaded environment is safety.

## Examples:

Configuration text file ("./conf/test.conf"):

	# Logger's name. Any string value
	[DebugLogger] 				
	
	# Message level accepted by logger
	# Values by priority from low to high: debug, info, warning, error, critical, fatal
	level = debug			

	# Appender is logger's message writer
	# Values: NullAppender, ConsoleAppender, FileAppender
	appender = FileAppender

	# For FileAppender need path to log file and base of file name
	fileNameBase = ./log/MainDebug.log



	[ErrorLogger]
	level = error
	appender = ConsoleAppender


Source code example:

	import onyx.log;
	import onyx.config.bundle;

	void main()
	{
		/* Build ConfBundle from config file */
		auto bundle = immutable ConfBundle("./test/test.conf");

		/* Add loggers to "logger pool" */
		createLoggers(bundle);

		/* Get logger from "logger pool" */
		auto log = getLogger("ErrorLogger");

		/* send message to logger */
		log.error("error msg");

		auto logDebug = getLogger("DebugLogger");
		logDebug.debug_("debug msg");
		logDebug.info("info msg");
		logDebug.error("error msg");
	}
