import "./config"

type
  Generator* = ref object of RootObj
    isInitialized: bool

method init*(self: Generator) =
  self.isInitialized = true

method generate*(self: Generator): string = 
  if not self.isInitialized:
    raiseAssert("Not initialized!")
  return "A"

proc new*(T: type Generator, config: Config): Generator =
  Generator(
    isInitialized: false
  )
