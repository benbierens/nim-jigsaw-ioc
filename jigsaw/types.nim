import strutils

type
  Lifestyle* = enum
    Unspecified
    Transient
    Singleton
    Instance

  CtorInfo* = object
    typeName*: string
    foreignArgs*: seq[string]
    lifestyle*: Lifestyle
    orderNumber*: int
    instanceParamSym*: NimNode
    abstracts*: seq[string]
    ctor*: NimNode

  Installer*[TRegistrations] = object
    registrations*: TRegistrations
    ctor*: typed
  Inst* = Installer

  Registration*[TComponent, TImplements] = object
    component*: TComponent
    lifestyle*: Lifestyle
    ctor*: typed
    implements*: TImplements
  Reg* = Registration

proc `$`*(info: CtorInfo): string =
  let ls = case info.lifestyle:
    of Lifestyle.Unspecified:
      "(!)"
    of Lifestyle.Transient:
      "(t)"
    of Lifestyle.Singleton:
      "(s)"
    of Lifestyle.Instance:
      "(i)"
    else:
      raiseAssert("Unknown lifestyle type: " & $info.lifestyle)

  "CtorInfo" & ls &
    "(" & $info.orderNumber &
    "){Name: " & info.typeName &
    " - ForeignArgs: [" &
    info.foreignArgs.join(",") &
    "] - Abstracts: [" &
    info.abstracts.join(",") &
    "]}"

proc fieldName*(info: CtorInfo): string =
  "instance" & info.typeName

proc hasInstanceLifestyle*(info: CtorInfo): bool =
  info.lifestyle == Lifestyle.Singleton or info.lifestyle == Lifestyle.Instance
