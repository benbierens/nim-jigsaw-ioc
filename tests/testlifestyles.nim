import std/unittest

import "../jigsaw"

type
  Application = ref object
    state: int

  Database = ref object
    state: int

  Config = ref object
    state: int

proc new*(T: type Application, db: Database, c: Config): Application =
  Application(state: 1)

proc new*(T: type Database, c: Config): T =
  Database(state: 1)

suite "Lifestyles":
  setup:
    let
      config = Config(state: 2) 
      container = CreateContainer([
        Installer[(
          Registration[Application, ()](lifestyle: Transient),
          Registration[Database, ()](lifestyle: Singleton),
          Registration[Config, ()](lifestyle: Instance)
        )]
      ], new)

    container.initialize(config)

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

  test "Can resolve Config":
    let c = container.get(Config)

    check:
      c.state == 2

  test "Config lifestyle is instance-singleton":
    let
      value = 12
      c = container.get(Config)

    c.state = value

    let newConfig = container.get(Config)

    check:
      newConfig.state == value
