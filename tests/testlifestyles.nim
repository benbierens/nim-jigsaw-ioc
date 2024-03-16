import std/unittest

import "../jigsaw"

type
  Application = ref object
    state: int

  Database = ref object
    state: int

proc new*(T: type Application, db: Database): Application {.transient.} =
  Application(state: 1)

proc new*(T: type Database): T {.singleton.} =
  Database(state: 1)

suite "Lifestyles":
  setup:
    let container = CreateContainer([
        Installer[(Application, Database)]
      ], new)

    container.initialize()

  test "Can resolve database":
    let db = container.get(Database)

    check:
      db.state == 1

  test "Database lifestyle is singleton":
    let
      value = 12
      db = container.get(Database)

    db.state = value

    let newDb = container.get(Database)

    check:
      newDb.state == value

  test "Can resolve application":
    let app = container.get(Application)

    check:
      app.state == 1

  test "Application lifestyle is transient":
    let
      value = 12
      app = container.get(Application)

    app.state = value

    let newApp = container.get(Application)

    check:
      newApp.state == 1
