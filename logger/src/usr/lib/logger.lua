local term = require("term")

local LoggerLevel = {
  EVERYTHING = -999,
  DEBUG = -1,
  INFO = 0,
  WARNING = 1,
  ERROR = 2,
  CRITICAL = 3,
  NONE = 999,
}

local SinkFactory = {}

function SinkFactory.createConsoleSink(minLevel)
  local sink = {minLevel = minLevel or LoggerLevel.INFO}
  local gpu = term.gpu()

  local levelStyles = {
    [LoggerLevel.CRITICAL] = {bg = 0xFF0000, fg = 0xFFFFFF},
    [LoggerLevel.ERROR]    = {bg = 0x000000, fg = 0xFF0000},
    [LoggerLevel.WARNING]  = {bg = 0x000000, fg = 0xFFFF00},
    [LoggerLevel.INFO]     = {bg = 0x000000, fg = 0xFFFFFF},
    [LoggerLevel.DEBUG]    = {bg = 0x000000, fg = 0xAAAAAA},
  }

  function sink.write(logLevel, message)
    local oldForeground = gpu.getForeground()
    local oldBackground = gpu.getBackground()

    local style = levelStyles[logLevel]
    if style then
      gpu.setBackground(style.bg)
      gpu.setForeground(style.fg)
    else
      gpu.setBackground(0x000000)
      gpu.setForeground(0xFF55FF)
    end

    term.write(message .. "\n")

    gpu.setBackground(oldBackground)
    gpu.setForeground(oldForeground)
  end

  return sink
end

function SinkFactory.createFileSink(filepath, minLevel)
  local file, err = io.open(filepath, "a")
  if not file then
    error("Failed to open log file: " .. tostring(err))
  end

  local sink = {minLevel = minLevel or LoggerLevel.INFO}

  function sink.write(logLevel, message)
    file:write(message .. "\n")
    file:flush()
  end

  return sink
end

local function createLogger()
  local self = {
    __formatter = "[%t] [%l] %m",
    __sinks = {},
    LoggerLevel = LoggerLevel,
    SinkFactory = SinkFactory,
  }

  function self.addSink(sink)
    if sink and sink.write then
      table.insert(self.__sinks, sink)
    end
  end

  function self.setFormatter(format)
    self.__formatter = format
  end

  function self.__internalLog(logLevel, logLevelString, message)
    local timeStr = os.date("%H:%M:%S")
    local outputMessage = self.__formatter
      :gsub("%%t",timeStr)
      :gsub("%%l", logLevelString)
      :gsub("%%m", message)
    for i,sink in pairs(self.__sinks) do
      if logLevel >= (sink.minLevel or LoggerLevel.INFO) then
        sink.write(logLevel, outputMessage)
      end
    end
  end

  function self.critical(msg) self.__internalLog(LoggerLevel.CRITICAL, "critical", msg) end
  function self.error(msg)    self.__internalLog(LoggerLevel.ERROR, "error", msg) end
  function self.warning(msg)  self.__internalLog(LoggerLevel.WARNING, "warning", msg) end
  function self.info(msg)     self.__internalLog(LoggerLevel.INFO, "info", msg) end
  function self.debug(msg)    self.__internalLog(LoggerLevel.DEBUG, "debug", msg) end

  function self.safeCall(fn)
    xpcall(fn, function(err)
      local trace = debug.traceback(err, 2)
      self.critical(trace)
      return err
    end)
  end

  return self
end

return createLogger