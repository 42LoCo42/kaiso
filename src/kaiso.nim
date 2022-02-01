import std/[asyncnet, asyncdispatch, bitops, os, nativesockets, strutils, posix, posix_utils]
import utils
import SocketWithInfo
import AsyncTcpServer

let args = commandLineParams()
if args.len != 1:
  quit "Usage: $1 <address:port>" % [getAppFilename().lastPathPart]

let (listenIP, listenPort, _) = args[0].parseAddr

proc handle(client: SocketWithInfo) {.async.} =
  while true:
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
      var service = SocketWithInfo()
      var file: File = nil
      try:
        # LFI guard
        let filename = serviceDir / line
        assert filename.isRelativeTo serviceDir,
          "Requested file $1 = $2 not relative to service directory $3" % [line, filename, serviceDir]

        # backends
        case cast[cint](filename.stat.st_mode).bitand S_IFMT:
          of S_IFSOCK: # unix socket
            service.socket = newAsyncUnixSocket(buffered = false)
            await service.socket.connectUnix serviceDir / line
          of S_IFREG: # regular file, should contains IP:port
            file = filename.open
            let (svcAddr, svcPort, svcPath) = file.readLine.parseAddr
            service.socket = await dial(svcAddr, svcPort, buffered = false)
            if svcPath.len > 0:
              await service.socket.sendLine svcPath
          else:
            raise newException(Exception, "Unsupported file type!")

        # start bidirectional data transfer
        asyncCheck client.transferTo service
        asyncCheck service.transferTo client
        return
      except:
        echo "Could not establish a service connection: ", getCurrentExceptionMsg()
        client.close
        service.close
        return
      finally:
        file.close

asyncTcpServer listenIP, listenPort, handle
