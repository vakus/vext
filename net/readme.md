# Net

Net is easy network protocol based on real life [Address Resolution
Protocol (ARP)](https://en.wikipedia.org/wiki/Address_Resolution_Protocol)
with few small differences to make it more human friendly.

# Planned Features

- [x] Register into network by broadcasting own hostname
- [x] Save known network for future reference
- [ ] Send and Receive messages using hostname
- [ ] Supporting program: ping
- [ ] Relay messages between two networks

# Why?

I wanted to create a network within OpenComputers, and created a 
"network" floppy, however just as I was trying to install it I realised
that I may have more fun implementing my own network protocol.

# How?

OpenComputers on the network are always accessible on modem networks and
can be only addressed by their UUID, akin to real life MAC address.
The UUID however is not very user-friendly way to access specific
computers, so I want to take advantage of the computers hostnames.

I want this protocol to work as a simple translation layer between human
friendly names and the network UUID addresses used by OpenComputers.
as result I decided to create a protocol based on ARP protocol, however
instead of knowing IP addresses, we know the hostname of the computer,
and instead of retrieving a MAC address, we get the computer's UUID.

The computer will be keeping own routing table, which will be
effectively hostname to UUID lookup table.
When a computer turns on a register packet will be broadcasted to
announce the computer joining the network. Computers which receive
this packet will then add the hostname and the UUID the message came
from to their internal routing table. 

For simplicity the requests will be sent on port 1.

Whenever a new computer is added to the network, the routing lookup
table is also saved in `/etc/hosts`.

# Clarifications

**IMPORTANT:** Within this document I refer to Universally Unique Identifier (UUID)
number of times. I also used it as data type, which doesn't exist within
OpenComputers. While the *actual* backing data type is string I have
done this to allow to quickly distinguish between Human friendly
identifier, and the UUID address of a computer.

# Messages

The messages in my network protocol use OpenComputers message
segmentation. To prevent UUID spoofing, I always use the UUID from
"senderAddress" that is provided by 
[`modem_message` event](https://ocdoc.cil.li/component:signals).

The following messages are sent on port 1.

| Protocol | Command  | Payload      | Explanation                                                         |
|----------|----------|--------------|---------------------------------------------------------------------|
| ARP      | FIND     | \<hostname\> | Message used to broadcast finding a computer with pecific hostname. |
| ARP      | REGISTER | \<hostname\> | Message used to announce own hostname. This can be as  broadcast or as response to FIND command. |

# Events

This is the list of events that my network layer raises.

- `arp_register(hostname: string, address: uuid)` - raised when a new
hostname is added to the internal routing table.
  - `hostname` - the hostname of computer that was registered
  - `address` - the network uuid of computer that was registered

# Functions

- `net.broadcast(port: number, ...)`
 
  Simplified method to broadcast message through all available network
  modems
  - `port` - the port on which the message is broadcasted
  - `...` - data. This is essentially passed forward to each modem and
  has the same limitations as data in 
  [`send` or `broadcast` commands](https://ocdoc.cil.li/component:modem)

- `net.findAddress(hostname: string, [timeout: number]): uuid` 

  Attempt finding computer's address by the computers hostname.
  When a hostname is successfully retrieved it is cached for future use
  to reduce network traffic.
  If a searched hostname is either already known, or another computer
  responds to the ARP/FIND command within timeout time, this command
  will return the UUID of the computer with specified hostname. If the
  name is not known, and no computer's respond within the timeout, this
  method will return `nil`.

  - `hostname` - the hostname of the computer your trying to find
  - `timeout` - the maximum time in seconds you wish to wait. The
  default is 3 seconds.

# Security considerations

The current implementation is simple and has some issues which can be
abused.

### Hostname collision

Currently there is no system to detect or prevent hostname collision.
If two computers have the same name then the last one to send REGISTER
packet, will be one which will be prioritised.

Additionally, when two or more computers respond to FIND packet, there
is no guaranteed order of operations which leads to the following
behaviour:
 - `net.findAddress` function will return the FIRST response to the FIND
  packet
 - after this the lookup table will be overwritten to whatever response
 is processed last.
 - re-running `net.findAddress` after the above will return the LAST
 response to the FIND packet.

This can be improved by preventing overwriting existing hostname lookups
and using this to generate collision event.

The problem with this approach is a decision on what should be done in
the following example:
- computer `C-01` knows `C-02`
- computer `C-02` has empty routing table
- malicious computer tries to claim `C-01`
- computer `C-01` can detect conflict with itself and report collision
- computer `C-02` can not detect collision on its own as it has no prior
knowledge of `C-01`. 

Introducing a collision detected packet sent by real `C-01` could inform
`C-02` of the collision, however this then can be then abused to prevent
registering any new computers within network.
For example a malicious computer could respond to all `FIND` requests
with a collision detected packet. This would also have to be somehow
accounted within `net.findAddress`.

### Hostname changes

Currently if a computer changes its hostname, the change is not
reflected to the rest of the network. The new name would be announced
when searched or when the computer boots, but the old name would still
be registered.

This could be partially solved by introducing a `RENAME` command into
ARP protocol. which contains two arguments old name and new name.
The incoming UUID can be used to validate if the old name was belonging
to this computer before, and if so it could be cleanly updated in the
routing table. This however would not work for computers which are
offline at the time of sending `RENAME` command, which would leave them
in dirty state.