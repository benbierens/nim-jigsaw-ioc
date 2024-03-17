import std/unittest

import "../jigsaw"

proc abstract() =
  raiseAssert("Abstract method called.")

type
  Readable = ref object of RootObj
  Writeable = ref object of Readable
  File = ref object of Writeable

const
  FileReadData = "Data-from-file!"
  BytesWritten = 42

method doRead(readable: Readable): string {.base.} = abstract()
method doWrite(writeable: Writeable): int {.base.} = abstract()

method doRead(file: File): string = FileReadData
method doWrite(file: File): int = BytesWritten

proc new*(T: type File): T =
  File()

suite "Abstraction (Multiple)":
  setup:
    let
      container = CreateContainer([
        Installer[(
          Registration[File, (Readable, Writeable)](lifestyle: Transient)
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
