import "./ioc"
import "./application"
import "./generator"
import "./processor"
import "./writer"
import "./config"

echo "Start"

let container = IoC()

container.register(Config, Lifestyle.Singleton)
container.register(Generator, Lifestyle.Transient)
container.register(Processor, Lifestyle.Transient)
container.register(Writer, Lifestyle.Singleton)
container.register(Application, Lifestyle.Singleton)

container.init()

let app = container.resolve(Application)
app.run()
