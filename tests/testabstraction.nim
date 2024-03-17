import std/unittest

import "../jigsaw"

type
  Item = ref object of RootObj
  LaserBlaster = ref object of Item

const LaserBlasterName = "Blaster!"

proc new*(T: type LaserBlaster): T =
  LaserBlaster()

method getName(item: Item): string {.base.} =
  raiseAssert("Abstract method called.")

method getName(laserBlaster: LaserBlaster): string =
  LaserBlasterName

suite "Abstraction":
  setup:
    let
      container = CreateContainer([
        Installer[(
          Registration[LaserBlaster, (Item)](lifestyle: Transient)
        )]
      ], new)

    container.initialize()

  test "Can resolve implementation":
    let b = container.get(LaserBlaster)

    check:
      b.getName() == LaserBlasterName

  test "Can resolve abstraction":
    let i = container.get(Item)

    check:
      i.getName() == LaserBlasterName
