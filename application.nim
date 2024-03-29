import "./generator"
import "./processor"
import "./writer"
import "./lifestyles"

type
  Application* = ref object of RootObj
    g: Generator
    p: Processor
    w: Writer

method run*(self: Application): void = 
  self.w.write(
    self.p.process(
        self.g.generate()
    )
  )

proc new*(T: type Application,
    g: Generator,
    p: Processor,
    w: Writer): Application {.transient.} =
  Application(
    g: g,
    p: p,
    w: w
  )
