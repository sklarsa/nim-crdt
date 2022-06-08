import std/algorithm
import std/deques
import std/sets
import std/sequtils
import std/tables
import std/times

type
  CrdtSet*[T] = ref object of RootObj
    data: HashSet[T]

proc add*[T](s: CrdtSet[T], o: T) =
  s.data.incl(o)

proc rm*[T](s: CrdtSet[T], o: T) =
  s.data.excl(o)

proc len*[T](s: CrdtSet[T]): int =
  return s.data.len

proc value*[T](s: CrdtSet[T]): HashSet[T] =
  return s.data

proc syncAddWins*[T](s, s1: CrdtSet[T]): CrdtSet[T] =
  return CrdtSet[T](data: s.data.union(s1.data))

proc syncRmWins*[T](s, s1: CrdtSet[T]): CrdtSet[T] =
  return CrdtSet[T](data: s.data.intersection(s1.data))

type
  SetOpType {.pure.} = enum
    sAdd, sRm

type
  SetOp = object
    timestamp: float
    op: SetOpType

proc setOpCmp(x, y: SetOp): int =
  cmp(x.timestamp, y.timestamp)

type
  LwwCrdtSet*[T] = ref object of CrdtSet[T]
    ops: TableRef[T, seq[SetOp]]

proc add*[T](s: LwwCrdtSet[T], o: T) =
  let op = SetOp(timestamp: epochTime(), op: sAdd)
  if o notin s.ops:
    s.ops[o] = @[]
  doAssert o in s.ops
  s.ops[o].add(op)

proc rm*[T](s: LwwCrdtSet[T], o: T) =
  let op = SetOp(timestamp: epochTime(), op: sRm)
  if o notin s.ops:
    s.ops[o] = @[]
  doAssert o in s.ops
  s.ops[o].add(op)


proc syncLww*[T](s, s1: LwwCrdtSet[T]): LwwCrdtSet[T] =
  var d = HashSet[T]()
  let allKeys = toHashSet[T](concat(toSeq(s.ops.keys()), toSeq(s1.ops.keys())))
  for k in allKeys:
    # Sync algorithm assumes that operations are time-ordered, so we need to sort both
    var sData = s.ops.getOrDefault(k, @[]).sorted(setOpCmp).toDeque()
    var s1Data = s1.ops.getOrDefault(k, @[]).sorted(setOpCmp).toDeque()

    while sData.len > 0 or s1Data.len > 0:
      var reg: SetOp
      # If s1Data is empty, pop from sData
      if s1Data.len == 0:
        reg = sData.popFirst()
      # If sData is empty, pop from s1Data
      elif sData.len == 0:
        reg = s1Data.popFirst()
      # If sData occurred before S1Data, pop sData
      elif sData[0].timestamp <= sData[0].timestamp:
        reg = sData.popFirst()
      # Otherwise pop s1Data
      else:
        reg = s1Data.popFirst()
      case reg.op:
        of sAdd:
          d.incl(k)
        of sRm:
          d.excl(k)

  return LwwCrdtSet[T](data: d)


if isMainModule:
  # Test basic add/rm mechanics
  var s = CrdtSet[int]()
  s.add(1)
  s.add(1)
  s.add(2)
  s.rm(2)

  assert s.len() == 1
  assert s.value() == toHashSet([1])

  # Test addWins/rmWins sync
  var a = CrdtSet[int]()
  var b = CrdtSet[int]()

  a.add(1)
  a.rm(1)
  a.add(1)

  b.add(1)
  b.rm(1)

  let addWins = syncAddWins(a, b)
  assert addWins.len() == 1
  assert addWins.value() == toHashSet([1])

  let rmWins = syncRmWins(a, b)
  assert rmWins.len() == 0
  assert rmWins.value() == HashSet[int]()

  # Test lww sync
  var e = LwwCrdtSet[int](ops: newTable[int, seq[SetOp]]())
  var f = LwwCrdtSet[int](ops: newTable[int, seq[SetOp]]())

  e.add(1)
  f.rm(1)
  assert syncLww(e, f).len() == 0

  f.add(1)
  e.add(1)
  assert syncLww(e, f).len() == 1
