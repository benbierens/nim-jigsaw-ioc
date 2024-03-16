import std/unittest

import "../jigsaw"

type
  ComponentA = ref object
    state: int

  ComponentB = ref object
    state: int

  ComponentC = ref object
    state: int

  FirstLoop1 = ref object
  FirstLoop2 = ref object

  SecondLoop1 = ref object
  SecondLoop2 = ref object
  SecondLoop3 = ref object

proc new*(T: type ComponentA): T {.transient.} =
  ComponentA(state: 1)

proc new*(T: type ComponentB, a: ComponentA): T {.transient.} =
  ComponentB(state: a.state + 1)

proc new*(T: type ComponentC, b: ComponentB): T {.transient.} =
  ComponentC(state: b.state + 1)

proc new*(T: type FirstLoop1, l: FirstLoop2): T {.transient.} =
  FirstLoop1()

proc new*(T: type FirstLoop2, l: FirstLoop1): T {.transient.} =
  FirstLoop2()

proc new*(T: type SecondLoop1, l: SecondLoop2): T {.transient.} =
  SecondLoop1()
  
proc new*(T: type SecondLoop2, l: SecondLoop3): T {.transient.} =
  SecondLoop2()
  
proc new*(T: type SecondLoop3, l: SecondLoop1): T {.transient.} =
  SecondLoop3()

suite "Resolution":
  setup:
    let container = CreateContainer([
      Installer[(ComponentA, ComponentB, ComponentC)]
    ], new)

    container.initialize()

  test "Can resolve components":
    let
      a = container.get(ComponentA)
      b = container.get(ComponentB)
      c = container.get(ComponentC)

    check:
      a.state == 1
      b.state == 2
      c.state == 3

# How to test:
#   test "Can detect first-order dependency loops":
#     expect AssertionDefect:
#       let container = CreateContainer([
#         Installer[(FirstLoop1, FirstLoop2)]
#       ], new)

#   test "Can detect second-order dependency loops":
#     expect AssertionDefect:
#       let container = CreateContainer([
#         Installer[(SecondLoop1, SecondLoop2, SecondLoop3)]
#       ], new)

