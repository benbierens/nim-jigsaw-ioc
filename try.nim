import "./jigsaw"
import "./application"
import "./generator"
import "./processor"
import "./writer"
import "./config"

let container = CreateContainer([
  Installer[(Application, Generator)],
  Installer[(Processor, Writer, Config)]
], new)

container.initialize()

echo "done"


