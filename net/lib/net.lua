local event = require("event")
local computer = require("computer")
local component = require("component")

local net = {}
net.routes = {}
net.modems = {}
net.ports = {}

local MATCH_UUID = "(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)"

-- register all modems, and listen for changes to them
event.listen("component_removed", function(_, uuid, type)
  if type ~= "modem" then return end
  table.remove(net.modems, uuid)
end)

event.listen("component_added", function(_, uuid, type)
  if type ~= "modem" then return end
  net.modems[uuid] = component.proxy(uuid)
  for port,_ in pairs(net.ports) do
    net.modems[uuid].open(port)
  end
end)

for uuid,_ in component.list("modem") do
  net.modems[uuid] = component.proxy(uuid)
end

-- load /etc/hosts file
local hostsFile = io.open("/etc/hosts", "r")
if hostsFile then
  for line in hostsFile:lines() do
    local uuid, hostname = line:match("^" .. MATCH_UUID .. "%s+(.+)")
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

function net.isAddress(hostname)
  return hostname:match("^" .. MATCH_UUID .. "$") ~= nil
end

function net.isHostname(hostname)
  return not net.isAddress(hostname)
end

function net.lookupAddress(hostname)
  if net.isAddress(hostname) then return hostname end
  if net.routes[hostname] ~= nil then return net.routes[hostname] end
  return nil
end

function net.findAddress(hostname, timeout, nocache)
  timeout = timeout or 3
  nocache = nocache or false

  if net.isAddress(hostname) then return hostname end
  if not nocache then
    local lockupAddress = net.lookupAddress(hostname)
    if lockupAddress ~= nil then return lockupAddress end
  end

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

function net.isOpen(port)
  return net.ports[port] == true
end

function net.open(port)
  if net.isOpen(port) then return false, "port is already open" end
  net.ports[port] = true
  for uuid,modem in pairs(net.modems) do
    modem.open(port)
  end
  return true, ""
end

function net.close(port)
  if not net.isOpen(port) then return false, "port is already closed" end
  table.remove(net.ports, port)
  for uuid,modem in pairs(net.modems) do
    modem.close(port)
  end
  return true, ""
end

function net.send(target, port, ...)
  local address = net.findAddress(target)
  if not address then return false, "Hostname not found" end

  for uuid,modem in pairs(net.modems) do
    modem.send(address, port, ...)
  end
  return true, ""
end
--------------

event.listen("modem_message",
  function(_, deviceUUID, from, port, _, protocol, operation, arg)
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

-- open ports via net itself to keep internal port state correct.
net.open(1)

return net