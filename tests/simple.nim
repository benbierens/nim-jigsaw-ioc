import std/unittest

import "../jigsaw"

type
  Application = ref object
    state: int

  Database = ref object
    state: int

proc new*(T: type Application, db: Database): Application {.transient.} =
  Application()

proc new*(T: type Database): Database {.singleton.} =
  Database()

suite "Simple resolution":

  test "Can resolve database":
    let
      container = CreateContainer([
        Installer[(Application, Database)]
      ], new)

    let db = container.get(Database)

    check:
      db.state == 0

