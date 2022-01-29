import std/[asyncnet, asyncdispatch, os, nativesockets]
import utils
import SocketWithInfo

proc transferTo(source: SocketWithInfo, target: SocketWithInfo) {.async.} =
  while true:
    try:
      let buf = await source.socket.recv 4096
      if buf.len == 0:
        discard source.closeRead
        discard target.closeWrite
        break
      await target.socket.send buf
    except:
      echo getCurrentExceptionMsg()
      break

proc handle(client: SocketWithInfo) {.async.} =
  var service = SocketWithInfo()

  while service.socket == nil:
    # while client is not connected: display services on request
    let line = await client.socket.recvLine

    # client has disconnected
    if line.len == 0:
      client.close
      return

    # client has requested the service list
    if line == "\r\n":
      for entry in walkDirRec(dir = "services", relative = true):
        await client.socket.sendLine entry
    else:
      try:
        service.socket = newAsyncUnixSocket(buffered = false)
        await service.socket.connectUnix "services" / line # this can raise OSError
        asyncCheck client.transferTo service
        asyncCheck service.transferTo client
      except:
        echo getCurrentExceptionMsg()
        client.close
        service.close
        return

  
proc serve() {.async.} =
  var server = newAsyncSocket(buffered = false)
  server.setSockOpt OptReuseAddr, true
  server.bindAddr 37812.Port
  server.listen

  while true:
    let clientSocket = await server.accept
    let client = SocketWithInfo(socket: clientSocket)
    asyncCheck client.handle

asyncCheck serve()
runForever()
