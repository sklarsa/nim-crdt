import std/deques
import std/times

type
  LwwCrdtRegister*[T] = ref object
    value*: T
    timestamp: float

proc write*[T](r: LwwCrdtRegister[T], o: T) =
  var t = epochTime()
  if t >= r.timestamp:
    r.value = o
    r.timestamp = t

proc syncLww*[T](r, r1: LwwCrdtRegister[T]): LwwCrdtRegister[T] =
  var ret = LwwCrdtRegister[T]()
  if r.timestamp >= r1.timestamp:
    ret.value = r.value
    ret.timestamp = r.timestamp
  else:
    ret.value = r1.value
    ret.timestamp = r1.timestamp

  return ret

if isMainModule:
  # Test basic writes
  var a = LwwCrdtRegister[int]()
  var b = LwwCrdtRegister[int]()

  a.write(1)
  assert syncLww(a, b).value == 1
  b.write(2)
  assert syncLww(a, b).value == 2
  a.write(3)
  assert syncLww(a, b).value == 3
