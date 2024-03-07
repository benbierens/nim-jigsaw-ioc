import "./config"
import "./lifestyles"

type
  GeneratorMode = enum
    Yes
    No
    Maybe
  Generator* = ref object of RootObj
    isInitialized: bool

method init*(self: Generator) =
  self.isInitialized = true

method generate*(self: Generator): string = 
  if not self.isInitialized:
    raiseAssert("Not initialized!")
  return "A"

proc new*(T: type Generator,
  config: Config,
  defIntOption: int = 123,
  defStrOption: string = "value",
  defEnumOption: GeneratorMode = GeneratorMode.Maybe): Generator {.transient.} =
  Generator(
    isInitialized: false
  )
