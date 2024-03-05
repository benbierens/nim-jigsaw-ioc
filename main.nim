import "./ioc"
import "./application"
import "./generator"
import "./processor"
import "./writer"

echo "Start"

let container = IoC()

container.register(Generator, Lifestyle.Transient)
container.register(Processor, Lifestyle.Transient)
container.register(Writer, Lifestyle.Singleton)
container.register(Application, Lifestyle.Singleton)

container.init()

let app = container.resolve(Application)
app.run()
