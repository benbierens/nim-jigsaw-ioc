type
  Config* = ref object of RootObj
    interestingConfigOption: string

proc new*(T: type Config): Config =
  Config(
    interestingConfigOption: "Hmm, yes"
  )
