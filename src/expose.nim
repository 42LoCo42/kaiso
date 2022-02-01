import std/[asyncnet, asyncdispatch, os, strutils]
import utils
import SocketWithInfo
import AsyncTcpServer

let args = commandLineParams()
if args.len != 3:
  quit "Usage: $1 <kaiso address:port> <service to expose> <address:port>" % [getAppFilename().lastPathPart]

let (kaisoIP, kaisoPort, _) = args[0].parseAddr
let servicePath = args[1]
let (exposeIP, exposePort, _) = args[2].parseAddr

proc handle(client: SocketWithInfo) {.async.} =
  let service = SocketWithInfo()
  try:
    service.socket = await dial(kaisoIP, kaisoPort, buffered = false)
    await service.socket.sendLine servicePath
    asyncCheck client.transferTo service
    asyncCheck service.transferTo client
  except:
    echo "Could not establish a service connection: ", getCurrentExceptionMsg()
    client.close
    service.close

asyncTcpServer exposeIP, exposePort, handle
