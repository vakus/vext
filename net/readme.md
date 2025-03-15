# Net

Net is easy network protocol based on real life [Address Resolution
Protocol (ARP)](https://en.wikipedia.org/wiki/Address_Resolution_Protocol)
with few small differences to make it more human friendly.

# Planned Features

- [x] Register into network by broadcasting own hostname
- [x] Save known network for future reference
- [x] Send messages using hostname or addresses
- [ ] Supporting program: ping
- [ ] Relay messages between two networks
- [ ] Support for networking with tunnels

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

- `arp_register(hostname: string, address: string)` - raised when a new
hostname is added to the internal routing table.
  - `hostname` - the hostname of computer that was registered
  - `address` - the network uuid of computer that was registered

# Functions

There will be fairly few functions that will reasemble OpenComputer's
modem API. The functions in here work in similar matter but allow to
automatically perform hostname lookups, and abstract concept of multiple
network adapters, instead treating them as if they all were one network.

- `net.broadcast(port: number, ...)`
 
  Simplified method to broadcast message through all available network
  modems.
  - `port` - the port on which the message is broadcasted
  - `...` - data. This is essentially passed forward to each modem and
  has the same limitations as data in 
  [`send` or `broadcast` commands](https://ocdoc.cil.li/component:modem)

- `net.isAddress(target: string): isAddress: boolean`

  Checks if the passed `target` is considered an UUID address.
  - `target` - the string to check

  Returns:
  - `isAddress` - true if string is a UUID address, false otherwise.

- `net.isHostname(target: string): isHostname: boolean`

  Checks if the passed `target` is considered as hostname.
  Opposite to `net.isAddress` function.
  - `target` - the string to check

  Returns:
  - `isHostname` - true if string is not an UUID address, false
  otherwise.

- `net.lookupAddress(hostname: string): address: string`

  Attempt finding computer's address by the computer hostname.
  This will only lookup local cache and will not actively search the
  network if a computer is not known.
  If the hostname is already an address as decided by `net.isAddress`
  then the hostname is simply returned.

  Returns:
  - `address` - the UUID address of the machine with the specified
  hostname, or `nil` if the machine was not found.

- `net.findAddress(hostname: string, [timeout: number], [nocache: boolean]): address: string` 

  Attempt finding computer's address by the computers hostname.
  When a hostname is successfully retrieved it is cached for future use
  to reduce network traffic.
  If the hostname is already an address as decided by `net.isAddress`
  then the hostname is simply returned.
  If a searched hostname is either already known (and nocache is set to
  false), or another computer responds to the ARP/FIND command within
  timeout time, this command will return the UUID address of the
  computer with specified hostname. If the name is not known, and no
  computer's respond within the timeout, this method will return `nil`.

  - `hostname` - the hostname of the computer your trying to find
  - `timeout` - the maximum time in seconds you wish to wait. The
  default is 3 seconds.
  - `nocache` - default false, if set to true it will always actively
  search for computer with given hostname even if the hostname exists
  in the cache. Successfully finding computer will still save it to
  cache and emit `arp_register` event.

  Returns:
  - `address` - the UUID address of the machine with the specified
  hostname, or `nil` if the machine was not found.

- `net.isOpen(port: number): opened: boolean`

  Checks if port is opened on the network. Ports managed by net are
  stored in `net.ports` table. This allows to automatically open ports
  for any newly inserted hardware while the program is running.

  - `port` - the port to be checked

- `net.open(port: number): success: boolean, errorMessage: string`

  Opens the port on the network.
  - `port` - the port to be opened

  Returns:
  - `success` - true if port was opened successfully, false otherwise,
  - `errorMessage` - the reason why operation has failed, empty if
  success is true.

- `net.close(port: number): success: boolean, errorMessage: string`

  Closes the port on the network
  - `port` - the port to be closed

  Returns:
  - `success` - true if port was closed successfully, false otherwise,
  - `errorMessage` - the reason why operation has failed, empty if
  success is true.

- `net.send(target: string, port: number, ...): success: boolean, errorMessage: string`

  Sends network message to specific target. If target is provided in
  UUID format then it will be used up directly. Otherwise a lookup is
  done before sending the message.

  - `target` - target where the message should be sent. If the target
  matches UUID format
  `^(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)$`
  then it will be used as address of machine. Otherwise it will attempt
  to be translated to address using `net.findAddress`.
  - `port` - the target port to send the message on
  - `...` - the data section of the message.

  Returns:
  - `success` - true if the message was sent successfully. This does not
  guarantee delivery of the message.
  - `errorMessage` - reason why the message sending failed, empty
  otherwise.


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