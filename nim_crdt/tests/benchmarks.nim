import nimprof
import std/random
import register


iterator countTo(n: int): int =
  var i = 0
  while i <= n:
    yield i
    inc i


if isMainModule:
    randomize()

    for i in countTo(100):

        var r1 = LwwCrdtRegister[int]()
        var r2 = LwwCrdtRegister[int]()
        var testSize = 1_000_000

        for i in countTo(testSize):
            r1.write(rand(high(int)))
            r2.write(rand(high(int)))

        var val = r1.syncLww(r2)

        if i mod 10 == 0:
            echo(i)
