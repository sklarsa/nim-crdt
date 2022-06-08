import std/deques
import std/times

type
  LwwCrdtRegister*[T] = ref object
    ops: Deque[(T, float)]

proc value*[T](r: LwwCrdtRegister[T]) =
  return r.ops.peekLast()

proc write*[T](r: LwwCrdtRegister[T], o: T) =
  r.ops.addLast((o, epochTime()))

proc syncLww*[T](r, r1: LwwCrdtRegister[T]): T =

  var val: (T, float)
  # Sync algorithm assumes that operations are time-ordered
  while r.ops.len > 0 or r1.ops.len > 0:
    # If r1 is empty, pop from r
    if r1.ops.len == 0:
      val = r.ops.popFirst()
    # If r is empty, pop from r1
    elif r.ops.len == 0:
      val = r1.ops.popFirst()
    # If r occurred before r1, pop s
    elif r.ops[0][1] <= r1.ops[0][1]:
      val = r.ops.popFirst()
    # Otherwise pop r1
    else:
      val = r1.ops.popFirst()

  return val[0]


if isMainModule:
  # Test basic writes
  var a = LwwCrdtRegister[int]()
  var b = LwwCrdtRegister[int]()

  a.write(1)
  assert syncLww(a, b) == 1
  b.write(2)
  assert syncLww(a, b) == 2
