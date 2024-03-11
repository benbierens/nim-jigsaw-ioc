import "./lifestyles"

type
  Looper* = ref object of RootObj
    nothing: int
  Looper2* = ref object of RootObj
    nothing: int
  Processor* = ref object of RootObj
    isInitialized: bool
  Output* = object
    data*: string

method init*(self: Processor) =
  self.isInitialized = true

method process*(self: Processor, input: string): Output = 
  if not self.isInitialized:
    raiseAssert("Not initialized!")
  return Output(data: input)

proc new*(T: type Processor, looper: Looper): Processor {.transient.} =
  Processor(
    isInitialized: false
  )

proc new*(T: type Looper, l2: Looper2): Looper {.transient.} =
  Looper(
    nothing: 17
  )

proc new*(T: type Looper2, processor: Processor): Looper2 {.transient.} =
  Looper2(
    nothing: 17
  )
