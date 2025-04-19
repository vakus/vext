local createLogger = require("logger")

local results = {
  passed = 0,
  failed = 0,
  log = {}
}

local function assertEqual(actual, expected, message)
  if actual ~= expected then
    error((message or "Assertion failed") ..
      string.format("\nExpected: %s\nActual: %s", tostring(expected), tostring(actual)))
  end
end

local function runTest(name, fn)
  local ok, err = pcall(fn)

  if ok then
    results.passed = results.passed + 1
    table.insert(results.log, "[PASS] " .. name)
  else
    results.failed = results.failed + 1
    table.insert(results.log, "[FAIL] " .. name .. "\n " .. err)
  end
end

runTest("Basic formatting and dispatch", function()
  local logger = createLogger()
  local mockSink = {
    minLevel = logger.LoggerLevel.DEBUG,
    written = {}
  }

  function mockSink.write(level, msg)
    table.insert(mockSink.written, {level = level, message = msg})
  end

  logger.addSink(mockSink)
  logger.setFormatter("[%l] %m")
  logger.info("Test message")

  assertEqual(#mockSink.written, 1, "Sink should have one message")
  assert(mockSink.written[1].message:match("%[info%] Test message"), "Message formatting incorrect")
end)

runTest("Log level filtering", function()
  local logger = createLogger()
  local mockSink = {
    minLevel = logger.LoggerLevel.WARNING,
    written = {},
  }

  function mockSink.write(level, msg)
    table.insert(mockSink.written, {level = level, message = msg})
  end

  logger.addSink(mockSink)

  logger.debug("Debug msg")
  logger.info("Info msg")

  logger.warning("Warning msg")
  logger.error("Error msg")
  logger.critical("Critical msg")

  assertEqual(#mockSink.written, 3, "Only WARNING and above should be logged")

  local levels = {
    logger.LoggerLevel.WARNING,
    logger.LoggerLevel.ERROR,
    logger.LoggerLevel.CRITICAL
  }

  for i,entry in ipairs(mockSink.written) do
    assertEqual(entry.level, levels[i], "Incorrect log level order or value")
  end
end)

print("\nTest Results:")
for _, line in ipairs(results.log) do
  print(line)
end
print(string.format("\n%d passed, %d failed", results.passed, results.failed))