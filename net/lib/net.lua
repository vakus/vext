local event = require("event")
local computer = require("computer")
local component = require("component")

local net = {}
net.routes = {}
net.modems = {}

-- register all modems, and listen for changes to them
event.listen("component_removed", function(_, uuid, type)
  if type ~= "modem" then return end
  table.remove(net.modems, uuid)
end)

event.listen("component_added", function(_, uuid, type)
  if type ~= "modem" then return end
  net.modems[uuid] = component.proxy(uuid)
end)

for uuid,_ in component.list("modem") do
  net.modems[uuid] = component.proxy(uuid)
  -- allow input through port 1
  net.modems[uuid].open(1)
end

-- load /etc/hosts file
local hostsFile = io.open("/etc/hosts", "r")
if hostsFile then
  for line in hostsFile:lines() do
    local uuid, hostname = line:match("^(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)%s+(.+)")
    if uuid and hostname then
      net.routes[hostname] = uuid
    end
  end
  hostsFile:close()
end

-- support functions
function net.broadcast(port, ...)
  for uuid,modem in pairs(net.modems) do
    modem.broadcast(port, ...)
  end
end

function net.findAddress(hostname, timeout)
  timeout = timeout or 3

  if net.routes[hostname] ~= nil then return net.routes[hostname] end

  -- filter to find only arp_register events with expected hostname
  local function filter(name, ...)
    if name ~= "arp_register" then return false end
    local args = {...}
    return args[1] == hostname
  end

  net.broadcast(1, "ARP", "FIND", hostname)
  local _, _, address = event.pullFiltered(timeout, filter)

  return address
end

--------------

event.listen("modem_message", function(_, deviceUUID, from, port, _, protocol, operation, arg)
  if port ~= 1 then return end
  if protocol ~= "ARP" then return end
  if operation == "FIND" and arg == os.getenv("HOSTNAME") then
    local modem = net.modems[deviceUUID]
    modem.send(from, 1, "ARP", "REGISTER", os.getenv("HOSTNAME"))
  end

  if operation == "REGISTER" then
    net.routes[arg] = from
    computer.pushSignal("arp_register", arg, from)
    
    local file = io.open("/etc/hosts", "w")
    if file then
      for hostname, uuid in pairs(net.routes) do
        file:write(uuid .. " " .. hostname)
      end
      file:close()
    end
  end
end)


return net