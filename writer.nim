import "./processor"

type
  Writer* = ref object of RootObj
    isInitialized: bool

method init*(self: Writer) =
  self.isInitialized = true

method write*(self: Writer, output: Output): void = 
  if not self.isInitialized:
    raiseAssert("Not initialized!")
  echo "Write: " & output.data

proc new*(T: type Writer): Writer =
  Writer(
    isInitialized: false
  )
