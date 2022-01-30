import std/[asyncnet, asyncdispatch]
import SocketWithInfo

type
  Handler = proc (client: SocketWithInfo) {.async.}
  AsyncTcpServer = ref object
    socket: SocketWithInfo
    handler: Handler

proc serve(s: AsyncTcpServer) {.async.} =
  while true:
    let client = SocketWithInfo(socket: await s.socket.socket.accept)
    asyncCheck s.handler client

proc asyncTcpServer*(address: string, port: Port, handler: Handler) =
  ## Setup a TCP server on the given address and port.
  ## Connecting clients will be passed to the handler.
  let server = AsyncTcpServer(handler: handler)
  server.socket = SocketWithInfo(socket: newAsyncSocket(buffered = false))
  server.socket.socket.setSockOpt OptReuseAddr, true
  server.socket.socket.bindAddr port, address
  server.socket.socket.listen

  asyncCheck server.serve
  runForever()
