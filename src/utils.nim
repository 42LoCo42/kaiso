import std/[asyncnet, asyncdispatch, nativesockets]

{.push header: "<sys/socket.h>", importc.}
proc shutdown*(socket: SocketHandle, how: cint): cint
let SHUT_RD* {.nodecl.}, SHUT_WR* {.nodecl.}: cint
{.pop.}

proc newAsyncUnixSocket*(sockType = SOCK_STREAM, buffered = true;
                        inheritable = defined(nimInheritHandles)): owned(AsyncSocket) =
    newAsyncSocket(domain = AF_UNIX, sockType, protocol = cast[Protocol](0), buffered, inheritable)

proc sendLine*(client: AsyncSocket, line: string, flags: set[SocketFlag] = {}): Future[void] =
  client.send line & "\r\n", flags
