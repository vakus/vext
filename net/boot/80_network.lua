local net = require("net")
local event = require("event")

event.listen("init", function()
  net.broadcast(1, "ARP", "REGISTER", os.getenv("HOSTNAME"))
end)
