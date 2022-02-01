import std/[asyncnet, asyncdispatch]
import utils

type SocketWithInfo* = ref object
  ## A wrapper around an AsyncSocket that stores the open state of
  ## the read and write side
  socket*: AsyncSocket
  readClosed: bool
  writeClosed: bool

proc close*(s: SocketWithInfo) =
  ## Close the socket
  if s.socket == nil: return
  s.socket.close
  s.readClosed = true
  s.writeClosed = true

proc closeRead*(s: SocketWithInfo): cint =
  ## Close the read side. This closes the socket when the write side is already closed.
  if s.socket == nil or s.readClosed: return
  if s.writeClosed:
    s.close
  else:
    result = s.socket.getFd.shutdown SHUT_RD
    s.readClosed = true

proc closeWrite*(s: SocketWithInfo): cint =
  ## Close the write side. This closes the socket when the read side is already closed.
  if s.socket == nil or s.writeClosed: return
  if s.readClosed:
    s.close
  else:
    result = s.socket.getFd.shutdown SHUT_WR
    s.writeClosed = true

proc transferTo*(source: SocketWithInfo, target: SocketWithInfo) {.async.} =
  ## Copy data from source to target.
  ## The read side of source and the write side of target will be closed
  ## when a connection error occurs.
  try:
    while true:
      let buf = await source.socket.recv 4096
      assert buf.len > 0, "No more data from this socket"
      await target.socket.safeSend buf
  except:
    echo "Transfer stopped: ", getCurrentExceptionMsg()
    discard source.closeRead
    discard target.closeWrite
    return
