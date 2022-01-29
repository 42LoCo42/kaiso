import std/asyncnet
import utils

type SocketWithInfo* = ref object
  socket*: AsyncSocket
  readClosed: bool
  writeClosed: bool

proc close*(s: SocketWithInfo) =
  s.socket.close
  s.readClosed = true
  s.writeClosed = true

proc closeRead*(s: SocketWithInfo): cint =
  if s.readClosed: return
  if s.writeClosed:
    s.close
  else:
    result = s.socket.getFd.shutdown SHUT_RD
    s.readClosed = true

proc closeWrite*(s: SocketWithInfo): cint =
  if s.writeClosed: return
  if s.readClosed:
    s.close
  else:
    result = s.socket.getFd.shutdown SHUT_WR
    s.writeClosed = true
