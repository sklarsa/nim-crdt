import std/sets

type
  CrdtSet*[T] = ref object
    data: HashSet[T]

proc add*[T](s: CrdtSet[T], o: T) =
  s.data.incl(o)

proc rm*[T](s: CrdtSet[T], o: T) =
  s.data.excl(o)

proc len*(s: CrdtSet): int =
  return s.data.len

proc syncAddWins[T](s: CrdtSet[T], s1: CrdtSet[T]): CrdtSet[T] =
  return CrdtSet[T](data: s.data.union(s1.data))

proc syncRmWins[T](s: CrdtSet[T], s1: CrdtSet[T]): CrdtSet[T] =
  return CrdtSet[T](data: s.data.intersection(s1.data))

# todo: implement lastWriterWins


if isMainModule:
  # Test basic add/rm mechanics
  var s = CrdtSet[int]()
  s.add(1)
  s.add(1)
  s.add(2)
  s.rm(2)

  assert s.len() == 1

  # Test addWins/rmWins sync
  var a = CrdtSet[int]()
  var b = CrdtSet[int]()

  a.add(1)
  b.add(1)
  a.rm(1)
  b.rm(1)
  a.add(1)

  assert syncAddWins(a, b).len() == 1
  assert syncRmWins(a, b).len() == 0
