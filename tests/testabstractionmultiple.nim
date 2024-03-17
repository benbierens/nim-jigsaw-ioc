import std/unittest

import "../jigsaw"

proc abstract() =
  raiseAssert("Abstract method called.")

type
  Readable = ref object of RootObj
  Writeable = ref object of Readable
  File = ref object of Writeable
  ReadUser = ref object
    readable: Readable
  WriteUser = ref object
    writeable: Writeable
  Application = ref object
    reader: ReadUser
    writer: WriteUser

const
  FileReadData = "Data-from-file!"
  BytesWritten = 42

method doRead(readable: Readable): string {.base.} = abstract()
method doWrite(writeable: Writeable): int {.base.} = abstract()

method doRead(file: File): string = FileReadData
method doWrite(file: File): int = BytesWritten

proc new*(T: type File): T =
  File()

proc new*(T: type ReadUser, readable: Readable): T =
  ReadUser(
    readable: readable
  )

proc new*(T: type WriteUser, writeable: Writeable): T =
  WriteUser(
    writeable: writeable
  )

proc new*(T: type Application, readUser: ReadUser, writeUser: WriteUser): T =
  Application(
    reader: readUser,
    writer: writeUser
  )

suite "Abstraction (Multiple)":
  setup:
    let
      container = CreateContainer([
        Installer[(
          Registration[File, (Readable, Writeable)](lifestyle: Transient),
          Registration[ReadUser, ()](lifestyle: Transient),
          Registration[WriteUser, ()](lifestyle: Transient),
          Registration[Application, ()](lifestyle: Transient)
        )]
      ], new)

    container.initialize()

  test "Can resolve implementation":
    let f = container.get(File)

    check:
      f.doRead() == FileReadData
      f.doWrite() == BytesWritten

  test "Can resolve first abstraction":
    let r = container.get(Readable)

    check:
      r.doRead() == FileReadData

  test "Can resolve second abstraction":
    let w = container.get(Writeable)

    check:
      w.doWrite() == BytesWritten

  test "Can resolve abstractions as dependencies":
    let app = container.get(Application)

    check:
      app.reader.readable.doRead() == FileReadData
      app.writer.writeable.doWrite() == BytesWritten
