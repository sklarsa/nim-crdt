import std/deques
import std/times

type
  LwwCrdtRegister*[T] = ref object
    ops: Deque[(T, float)]

proc write*[T](r: LwwCrdtRegister[T], o: T) =
  r.ops.addLast((o, epochTime()))

proc syncLww*[T](s: LwwCrdtRegister[T], s1: LwwCrdtRegister[T]): T =
  # Sync algorithm assumes that operations are naturally time-ordered, which may not always be the case
  var val: (T, float)

  while s.ops.len > 0 or s1.ops.len > 0:
    # If s1 is empty, pop from s
    if s1.ops.len == 0:
      val = s.ops.popFirst()
    # If s is empty, pop from s1
    elif s.ops.len == 0:
      val = s1.ops.popFirst()
    # If s occurred before s1, pop s
    elif s.ops[0][1] <= s1.ops[0][1]:
      val = s.ops.popFirst()
    # Otherwise pop s1
    else:
      val = s1.ops.popFirst()

  return val[0]


if isMainModule:
  # Test basic writes
  var a = LwwCrdtRegister[int]()
  var b = LwwCrdtRegister[int]()

  a.write(1)
  assert syncLww(a, b) == 1
  b.write(2)
  assert syncLww(a, b) == 2
