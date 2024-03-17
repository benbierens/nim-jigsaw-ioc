import std/unittest

import "../jigsaw"

type
  Item = ref object of RootObj
  LaserBlaster = ref object of Item
  Player = ref object
    item: Item

const LaserBlasterName = "Blaster!"

proc abstract() =
  raiseAssert("Abstract method called.")

proc new*(T: type LaserBlaster): T =
  LaserBlaster()

proc new*(T: type Player, item: Item): T =
  Player(
    item: item
  )

method getName(item: Item): string {.base.} = abstract()
method getName(laserBlaster: LaserBlaster): string = LaserBlasterName

suite "Abstraction (Single)":
  setup:
    let
      container = CreateContainer([
        Installer[(
          Registration[LaserBlaster, (Item)](lifestyle: Transient),
          Registration[Player, ()](lifestyle: Transient)
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

  test "Can resolve abstraction as dependency":
    let p = container.get(Player)

    check:
      p.item.getName() == LaserBlasterName
