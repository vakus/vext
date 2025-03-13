local computer = require("computer")
local component = require("component")
local event = require("event")

local function tableContains(table, value)
  for i = 1, #table do
    if table[i] == value then
      return true
    end
  end
  return false
end

local args = {...}
local beepEnabled = not tableContains(args, "--silent")
local tunnel = component.getPrimary("tunnel")

if tunnel == nil then
  print("[FATAL] Tunnel not found...")
  return
end

local function filter(name, ...)
  return name == "interrupted" or name == "modem_message"
end

print("[INFO] beep is: " .. (beepEnabled and "enabled" or "disabled"))
print("[INFO] Listening for packets")

while true do
  local eventType, localAddress, remoteAddress, port, distance, message = event.pullFiltered(filter)
  if eventType == "interrupted" then
    print("[INFO] Ctrl+c detected. Exiting...")
    return
  end
  print("Message received by {" .. localAddress .. "} from {" .. remoteAddress .. "} on port {" .. port .. "} with distance {" .. distance .. "}")
  print("\t" .. message)
  if beepEnabled then computer.beep() end
end