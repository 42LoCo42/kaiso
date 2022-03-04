import std/[asyncnet, asyncdispatch, bitops, os, nativesockets, strutils, posix, posix_utils]
import utils
import SocketWithInfo
import AsyncTcpServer

let args = commandLineParams()
if args.len != 1:
  quit "Usage: $1 <address:port>" % [getAppFilename().lastPathPart]

let (listenIP, listenPort) = args[0].parseAddr

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
      await client.socket.sendLine "" # mark end of service list
    # client tries to connect
    else:
      var service = SocketWithInfo()
      var file: File = nil
      try:
        # Don't allow connections to invisible services
        assert not line.startsWith '.', "Requested file $1 is hidden!" % [line]

        # LFI guard
        let filename = serviceDir / line
        assert filename.isRelativeTo serviceDir,
          "Requested file $1 = $2 not relative to service directory $3" % [line, filename, serviceDir]

        # backends
        case cast[cint](filename.stat.st_mode).bitand S_IFMT:
          of S_IFSOCK: # unix socket
            service.socket = newAsyncUnixSocket(buffered = false)
            await service.socket.connectUnix filename
          of S_IFREG: # regular file = service description
            file = filename.open
            let (svcAddr, svcPort, svcOption) = file.readLine.parseService

            if svcPort == 0.Port:
              # connect to unix socket
              service.socket = newAsyncUnixSocket(buffered = false)
              await service.socket.connectUnix serviceDir / svcAddr

              if svcOption.startsWith "passfd":
                let fields = svcOption.split ':'
                if fields.len == 2:
                  let knock = await asyncnet.dial("localhost", fields[1].parseUInt.Port)
                  knock.close
                service.socket.passSocket client.socket
                client.close
                service.close
                return
            else:
              # connect to TCP
              service.socket = await dial(svcAddr, svcPort, buffered = false)

              if svcOption.len > 0:
                # inject service path
                await service.socket.sendLine svcOption
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
