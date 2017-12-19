# onyx-log

onyx-log: the simple, fast, multithreading logging library for D.


## Key features:
 - Create loggers in "logger pool" from configuration data packed to Bundle (onyx-config lib).
 - Get logger by his name.
 - Write message to logger.
 - Any work with loggers in multi-threaded environment is safety.
 - Working together with vibe.d

 
 
### For use logger with vibe.d, add to your project:
in dub.sdl
```
subConfiguration "onyx-log" "library-vibedlog"
```
 or in dub.json
```
"subConfigurations": {
        "onyx-log": "library-vibedlog"
    }
```


## Examples:

Configuration text file ("./test/test.conf"):

    # Logger's name. Any string value
    [DebugLogger]

    # Message level accepted by logger
    # Values by priority from low to high: debug, info, warning, error, critical, fatal
    level = debug

    # Appender is logger's message writer
    # Values: NullAppender, ConsoleAppender, FileAppender
    appender = FileAppender

    # Rolling type
    # Values: SizeBasedRollover
    rolling = SizeBasedRollover

    # Log file max size
    # Values: number, number with suffix: K, M, G, T, P
    maxSize = 2M

    # Max number of log files
    # Values: number
    maxHistory = 4

    # For FileAppender need path to log file and base of file name
    fileName = ./log/MainDebug.log



    [ErrorLogger]
    level = error
    appender = ConsoleAppender


Source code example:

```D
    import onyx.log;
    import onyx.bundle;

    void main()
    {
        /* Build ConfBundle from config file */
        auto bundle = new immutable Bundle("./test/test.conf");

        /* Add loggers to "logger pool" */
        createLoggers(bundle);

        /* Get logger from "logger pool" */
        auto log = getLogger("ErrorLogger");

        /* send message to logger */
        log.error("error msg");

        auto logDebug = getLogger("DebugLogger");
        logDebug.debug_("debug msg");
        logDebug.info("info msg");
        logDebug.error("error!!!!!! msg");
    }
```
