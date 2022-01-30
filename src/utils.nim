import std/[asyncnet, asyncdispatch, nativesockets, os, net, strutils]

let serviceDir* = "services".absolutePath

{.push importc, header: "<sys/socket.h>".}
proc shutdown*(socket: SocketHandle, how: cint): cint
let SHUT_RD* {.nodecl.}, SHUT_WR* {.nodecl.}: cint
{.pop.}

var errno {.importc, header: "<errno.h>".}: cint

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
  let fields = s.split(':')
  (fields[0], fields[1].parseUInt.Port)
