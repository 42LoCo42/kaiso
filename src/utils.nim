import std/[asyncnet, asyncdispatch, nativesockets, os, net, strutils]

let serviceDir* = "services".absolutePath

# C imports

var errno {.importc, header: "<errno.h>".}: cint

{.push importc, header: "<sys/socket.h>".}
proc shutdown*(socket: SocketHandle, how: cint): cint
let SHUT_RD* {.nodecl.}, SHUT_WR* {.nodecl.}: cint
{.pop.}

{.compile: "send_fd.c".}
proc send_fd(socket, fd: cint): cint {.importc.}
proc passSocket*(over, toPass: AsyncSocket) =
  if cast[cint](over.getFd).send_fd(cast[cint](toPass.getFd)) < 0:
    raise newOSError(osLastError())

# Helper functions

proc newAsyncUnixSocket*(sockType = SOCK_STREAM, buffered = true;
                        inheritable = defined(nimInheritHandles)): owned(AsyncSocket) =
  ## Create a new async Unix domain socket
  newAsyncSocket(domain = AF_UNIX, sockType, protocol = cast[Protocol](0), buffered, inheritable)

proc safeSend*(socket: AsyncSocket, data: string, flags = {SafeDisconn}) {.async.} =
  ## Like send, but an exception is raised on a connection error
  errno = 0
  await send(socket, data, flags)
  assert not flags.isDisconnectionError(osLastError())

proc sendLine*(client: AsyncSocket, line: string, flags = {SafeDisconn}) {.async.} =
  ## Send line followed by CRLF
  await client.safeSend(line & "\r\n", flags)

func parseAddr*(s: string): (string, Port) =
  ## Split address string on : to IP and port
  let fields = s.split ':'
  assert fields.len > 0
  (fields[0], if fields.len == 2: fields[1].parseUInt.Port else: 0.Port)

func parseService*(s: string): (string, Port, string) =
  ## Parse a service string.
  ## It must have one of two formats:
  ## ``<<IP or hostname>:port> [kaiso service name]``
  ## ``<UNIX socket path> [passfd]``
  ## For example:
  ## ``localhost:12345`` = connect to TCP service on localhost port 12345
  ## ``192.168.178.42:37812 ssh`` = connect to kaiso service on 192.168.178.42 port 37812
  ## ``.myUnixSocket passfd`` = connect to UNIX socket .myUnixSocket and use the passfd extension

  let svcFields  = s.split ' '
  assert svcFields.len > 0
  let (address, port) = svcFields[0].parseAddr
  (address, port, if svcFields.len == 2: svcFields[1] else: "")
