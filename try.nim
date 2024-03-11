import macros, strutils, sequtils
import "./ioc"
import "./application"
import "./generator"
import "./processor"
import "./writer"
import "./config"

type
  Lifestyle = enum
    Transient
    Singleton
    Instance

  CtorInfo = object
    typeName: string
    foreignArgs: seq[string]
    lifestyle: Lifestyle
    orderNumber: int

  Installer[TComponents] = object
    components: TComponents
    # instances: todo

# <Ctor inspection>

proc findCtorOfType(ctors: seq[CtorInfo], tName: string): CtorInfo =
  for ctor in ctors:
    if ctor.typeName == tName:
      return ctor
  raiseAssert("(Jigsaw-IoC internal error) Unable to find CtorInfo by name: " & tName)

proc `$`*(info: CtorInfo): string =
  let ls = case info.lifestyle:
    of Lifestyle.Transient:
      "(t)"
    of Lifestyle.Singleton:
      "(s)"
    of Lifestyle.Instance:
      "(i)"
    else:
      raiseAssert("Unknown lifestyle type: " & $info.lifestyle)

  "CtorInfo" & ls & "(" & $info.orderNumber & ")[Name: " & info.typeName & " - ForeignArgs: " & info.foreignArgs.join(",") & "]"

template getLifestyleForPragmas(typeName: string, pragmas: typed): Lifestyle = 
  let
    isTransient = pragmas.findChild(it.kind == nnkSym and $(it.strVal) == "transient") != nil
    isSingleton = pragmas.findChild(it.kind == nnkSym and $(it.strVal) == "singleton") != nil
    isInstance = pragmas.findChild(it.kind == nnkSym and $(it.strVal) == "instance") != nil

  if isTransient and not isSingleton and not isInstance:
    Lifestyle.Transient
  elif not isTransient and isSingleton and not isInstance:
    Lifestyle.Singleton
  elif not isTransient and not isSingleton and isInstance:
    Lifestyle.Instance
  else:
    raiseAssert("Invalid lifestyle specification for '" & typeName & "'. Please specify one of {.transient.} OR {.singleton.} OR {.instance.}")

template getCtorInfoForType(compType: typed, newProcTypes: typed): CtorInfo = 
  let typeName = compType.strVal

  var
    name = ""
    args:seq[string] = @[]
    lifestyle: Lifestyle

  for newProcType in newProcTypes:
    let procDef = newProcType.getImpl
    assert procDef.kind == nnkProcDef, "(Jigsaw-IoC internal error) getCtorInfoForType: Symbol not a procedure"

    let
      formalParams = procDef.findChild(it.kind == nnkFormalParams)
      pragmas = procDef.findChild(it.kind == nnkPragma)
    
    if formalParams[0].kind == nnkSym and $(formalParams[0].strVal) == typeName:
      name = typeName
      lifestyle = getLifestyleForPragmas(name, pragmas)

      for fparam in formalParams:
        if fparam.kind == nnkIdentDefs:
          if fparam[1].kind == nnkSym and
            fparam[2].kind == nnkEmpty:
            args.add($fparam[1].strVal)

  CtorInfo(
    typeName: name,
    foreignArgs: args,
    lifestyle: lifestyle,
    orderNumber: -1
  )

template getCtorInfosFromInstaller(installer: typed, newProcTypes: typed): seq[CtorInfo] =
  var ctors = newSeq[CtorInfo]()

  assert installer[1].kind == nnkTupleConstr
  for compType in installer[1]:
    let info = getCtorInfoForType(compType, newProcTypes)
    if info.typeName.len > 0:
      ctors.add(info)

  ctors

# </Ctor inspector>

# <Loop detection>

proc ensureNoLoop(path: string, ctors: seq[CtorInfo], here: CtorInfo, visited: seq[string]) = 
  if here.typeName in visited:
    raiseAssert("Dependency loop detected: " & path & " -> " & here.typeName)
  
  var newVisited = newSeq[string]()
  for v in visited:
    newVisited.add(v)
  newVisited.add(here.typeName)

  for fa in here.foreignArgs:
    ensureNoLoop(path & "/" & here.typeName, ctors, ctors.findCtorOfType(fa), newVisited)

proc ensureNoLoops(ctors: seq[CtorInfo]) = 
  for ctor in ctors:
    ensureNoLoop("", ctors, ctor, newSeq[string]())

# </Loop detection>

# <Ordering>

proc assignOrderNumber(ctors: var seq[CtorInfo], ctor: var CtorInfo) = 
  if ctor.orderNumber != -1:
    return

  var n = 0
  for fa in ctor.foreignArgs:
    var depCtor = ctors.findCtorOfType(fa)
    assignOrderNumber(ctors, depCtor)
    if n < (depCtor.orderNumber + 1):
      n = depCtor.orderNumber + 1

  ctor.orderNumber = n

proc orderCtors(ctors: var seq[CtorInfo]) = 
  for ctor in ctors.mitems:
    assignOrderNumber(ctors, ctor)
    if ctor.orderNumber == -1:
      raiseAssert("(Jigsaw-IoC internal error) Unable to find order number for type " & ctor.typeName)

# </Ordering>

macro ListTypes(installers: typed, newProcTypes: typed): untyped =
  var ctorInfos = newSeq[CtorInfo]()

  # Inspect installers to create ctorInfo objects.
  for installer in installers:
    let infos = getCtorInfosFromInstaller(installer, newProcTypes)
    for i in infos:
      ctorInfos.add(i)

  # Ensure no loops
  ensureNoLoops(ctorInfos)

  # Figure out dependency order
  orderCtors(ctorInfos)

  echo "ctor infos:"
  echo $ctorInfos.len
  for info in ctorInfos:
    echo $info

  # emit a proc:
  result = quote do:
    proc yeah() =
      echo "yeah!"

echo "actual running:"

ListTypes([
  Installer[(Application, Generator)],
  Installer[(Processor, Writer, Config)]
], new)

yeah()
