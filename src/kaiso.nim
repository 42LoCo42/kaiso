import std/[asyncnet, asyncdispatch, os, nativesockets, strutils]
import utils
import SocketWithInfo
import AsyncTcpServer

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
      for entry in walkDirRec(dir = serviceDir, relative = true, yieldFilter = {pcFile, pcLinkToFile}, followFilter = {pcDir, pcLinkToDir}):
        if not entry.lastPathPart.isHidden:
          await client.socket.sendLine entry
    # client tries to connect
    else:
      try:
        # LFI guard
        let file = serviceDir / line
        assert file.isRelativeTo serviceDir,
          "Requested file $1 = $2 not relative to service directory $3" % [line, file, serviceDir]

        service.socket = newAsyncUnixSocket(buffered = false)
        await service.socket.connectUnix serviceDir / line

        # start bidirectional data transfer
        asyncCheck client.transferTo service
        asyncCheck service.transferTo client
      except:
        echo getCurrentExceptionMsg()
        client.close
        service.close
        return

asyncTcpServer "0.0.0.0", 37812.Port, handle
