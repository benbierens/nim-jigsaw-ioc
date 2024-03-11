import macros, strutils, sequtils
import "./ioc"
import "./application"
import "./generator"
import "./processor"
import "./writer"
import "./config"

type
  CtorInfo = object
    typeName: string
    foreignArgs: seq[string]

  Installer[TComponents] = object
    components: TComponents
    # instances: todo

# <Ctor inspection>

proc findCtorOfType(ctors: seq[CtorInfo], tName: string): CtorInfo =
  for ctor in ctors:
    if ctor.typeName == tName:
      return ctor
  raiseAssert("Unable to find CtorInfo by name: " & tName)

proc `$`*(info: CtorInfo): string =
  "CtorInfo[Name: " & info.typeName & " - ForeignArgs: " & info.foreignArgs.join(",") & "]"

template getCtorInfoForType(compType: typed, newProcTypes: typed): CtorInfo = 
  let typeName = compType.strVal

  var 
    name = ""
    args:seq[string] = @[]

  for newProcType in newProcTypes:
    let procDef = newProcType.getImpl
    assert procDef.kind == nnkProcDef, "Symbol not a procedure!"

    let formalParams = procDef.findChild(it.kind == nnkFormalParams)

    if formalParams[0].kind == nnkSym and $(formalParams[0].strVal) == typeName:
      name = typeName
      for fparam in formalParams:
        if fparam.kind == nnkIdentDefs:
          if fparam[1].kind == nnkSym and
            fparam[2].kind == nnkEmpty:
            args.add($fparam[1].strVal)

  CtorInfo(
    typeName: name,
    foreignArgs: args
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

macro ListTypes(installers: typed, newProcTypes: typed): untyped =
  var ctorInfos = newSeq[CtorInfo]()

  # Inspect installers to create ctorInfo objects.
  for installer in installers:
    let infos = getCtorInfosFromInstaller(installer, newProcTypes)
    for i in infos:
      ctorInfos.add(i)

  echo "ctor infos:"
  echo $ctorInfos.len
  for info in ctorInfos:
    echo "Name: " & info.typeName
    echo "Foreign args:"
    for arg in info.foreignArgs:
      echo " - " & arg
    echo ""

  # Ensure no loops
  ensureNoLoops(ctorInfos)

  # emit a proc:
  result = quote do:
    proc yeah() =
      echo "yeah!"

echo "actual running:"

ListTypes([
  Installer[(Application, Generator)],
  Installer[(Processor, Writer, Config, Looper, Looper2)]
], new)

yeah()
