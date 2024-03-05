type
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

proc new*(T: type Processor): Processor =
  Processor(
    isInitialized: false
  )
