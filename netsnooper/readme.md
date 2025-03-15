# netsnooper

simple support application for tracking any incoming messages from
[`modem_message` event](https://ocdoc.cil.li/component:signals)

It will simply output all information on the event which has been in
following format:
`Message received by {localAddress} from {remoteAddress} on port {port}
with distance {distance}`
followed by the data from the message.

The program will also beep when a message is received (useful for
tablets), but this behaviour can be disabled by running the program with
`--silent` flag