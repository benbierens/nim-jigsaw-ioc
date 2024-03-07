import "./lifestyles"

type
  Config* = ref object of RootObj
    interestingConfigOption: string

proc new*(T: type Config): Config {.singleton.} =
  Config(
    interestingConfigOption: "Hmm, yes"
  )
