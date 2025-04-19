# Logger

Logger is a simple and extensible logging library for OpenComputers,
inspired by Serilog.

It comes with two built-in sinks (console and file output), and provides
an easy way to create custom sinks. The goal is to simplify logging
in your OC programs and offer a flexible system that can grow with your
needs.

---

## Terminology

**Sink** - A destination for log messages. This could be the computer's
console, a file on a disk or any other output.

---

## Why?

When writing OpenComputers programs, it's common to sprinkle in `print`
statements for quick debugging. But `print` lacks structure,
consistency, and visibility - especially for more important messages.

This library aims to provide:
 - Easy and consistent logging with structured output,
 - Multiple output targets (sinks), each with their own configuration,
 - Readable and color-highlighted console logs,
 - The ability to filter logs per sink (e.g., only warnings in console,
 full debug in file)

---

## Features

### Per-Sink Log Levels

Unlike some logging systems that define a global logging level,
this logger applies filtering **per sink**. Each sink can have a
different `minLevel`, giving more fine-grained control over what
gets logged where.

---

## Example usage

```lua
local createLogger = require("logger")
local logger = createLogger()

-- Add sink to output to console
logger.addSink(logger.SinkFactory.createConsoleSink(logger.LoggerLevel.DEBUG))

-- Add sink to output to file
logger.addSink(logger.SinkFactory.createFileSink("/home/log.txt", logger.LoggerLevel.WARNING))

logger.info("Shown in the console")
logger.error("Shown in both console and the file")
```

## API

### createLogger(): Logger

Calling `require("logger")` returns a factory function.
Use this function to create an isolated logger instance with its own
sinks and settings.

# Logger

This table is used as a wrapper around instance of a logger.

## Logger.LoggerLevel

Simple enum like table to give names and values for different log levels
| Name       | Value |
|------------|-------|
| EVERYTHING | -999  |
| DEBUG      | -1    |
| INFO       | 0     |
| WARNING    | 1     |
| ERROR      | 2     |
| CRITICAL   | 3     |
| NONE       | 999   |

## Logger.SinkFactory

This is a basic helper factory to create some basic sinks.

### Logger.SinkFactory.createConsoleSink([minLevel: Logger.LoggerLevel]): Sink

Creates simple Sink to output to console. By default if minLevel is
not specified it will default to Logger.LoggerLevel.INFO.

By default the log messages will be coloured depending on the severity
of the log as follows
| Log Level | Background       | Foreground        |
|-----------|------------------|-------------------|
| CRITICAL  | 0xFF0000 - Red   | 0xFFFFFF - White  |
| ERROR     | 0x000000 - Black | 0xFF0000 - Red    |
| WARNING   | 0x000000 - Black | 0xFFFF00 - Yellow |
| INFO      | 0x000000 - Black | 0xFFFFFF - White  |
| DEBUG     | 0x000000 - Black | 0xAAAAAA - Gray   |
| [invalid] | 0x000000 - Black | 0xFF55FF - Pink   |


### Logger.SinkFactory.createFileSink(filepath: string, [minLevel: Logger.LoggerLevel]): Sink

Creates simple Sink to output to a file, specified by filepath.
By default if minLevel is not specified, it will default to
Logger.LoggerLevel.INFO.

### Logger.addSink(sink: Sink)

Adds a new sink to be used by the logger.

### Logger.setFormatter(format: string)

Sets new format of the string being logged.
The default formatter is `[%t] [%l] %m`
The replaced tokens are 
- `%t` - replaced with time in `%H:%M:%S` format
- `%l` - replaced with verbose name of the log level, e.g. "critical" or "warning"
- `%m` - replaced with the actual message being logged

### Logger.critical(message: string)

Creates a critical log with specified message

### Logger.error(message: string)

Creates a error log with specified message

### Logger.warning(message: string)

Creates a warning log with specified message

### Logger.info(message: string)

Creates a info log with specified message

### Logger.debug(message: string)

Creates a debug log with specified message

# Sink

Sink is a simple table with function to write information. To implement
custom sink you need it to implement the following

## Sink.write(logLevel: Logger.LoggerLevel, message: string)

This function should do whatever you want to do with the message.

## Sink.minLevel: Logger.LoggerLevel

This specifies the minimum level of log to be sent to your Sink.
If `minLevel` is not defined on a sink, it defaults to
`Logger.LoggerLevel.INFO`.