import "./application"
import "./generator"
import "./processor"
import "./writer"

echo "Start"

let
  g = Generator.new()
  p = Processor.new()
  w = Writer.new()
  app = Application.new(g, p, w)

g.init()
p.init()
w.init()

app.run()
