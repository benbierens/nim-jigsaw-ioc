import macros, strutils, algorithm
import "./lifestyles"

export lifestyles

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

  Installer*[TComponents] = object
    components: TComponents

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

proc fieldName(info: CtorInfo): string =
  "instance" & info.typeName

proc hasInstanceLifestyle(info: CtorInfo): bool =
  info.lifestyle == Lifestyle.Singleton or info.lifestyle == Lifestyle.Instance

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

  proc byOrderNumber(a, b: CtorInfo): int = 
    a.orderNumber - b.orderNumber

  sort(ctors, byOrderNumber)

# </Ordering>

# <Emission>

proc createContainerTypeDef(mainList: NimNode, containerType: NimNode, ctors: seq[CtorInfo]) = 
  let containerBody = quote do:
    type
      `containerType` = ref object

  let recList = newNimNode(NimNodeKind.nnkRecList, containerBody)
  let objTy = containerBody[0].findChild(it.kind == nnkRefTy)[0]
  objTy[2] = recList

  for ctor in ctors:
    if ctor.hasInstanceLifestyle:
      recList.add(
        newIdentDefs(ident(ctor.fieldName), ident(ctor.typeName))
      )

  mainList.add(containerBody)

proc createFieldGetter(mainList: NimNode, containerType: NimNode, ctor: CtorInfo) =
  let
    typeSym = ident(ctor.typeName)
    fieldName = ident(ctor.fieldName)
    getter = quote do:
      proc get(container: `containerType`, _: type `typeSym`): auto = 
        return container.`fieldName`
  mainList.add(getter)

proc addDependencyGetCalls(returnCall: NimNode, containerSym: NimNode, ctor: CtorInfo) =
  for fa in ctor.foreignArgs:
    let faIdent = ident(fa)
    returnCall.add(quote do:
      `containerSym`.get(`faIdent`)
    )

proc createTransientGetter(mainList: NimNode, containerType: NimNode, newProcTypes: NimNode, ctor: CtorInfo) =
  let
    typeSym = ident(ctor.typeName)
    containerSym = genSym(NimSymKind.nskParam, "container")

  let
    getter = quote do:
      proc get(`containerSym`: `containerType`, _: type `typeSym`): auto = 
        return `typeSym`.`newProcTypes`()

  let returnCall = getter.findChild(it.kind == nnkStmtList)[0][0]
  returnCall.addDependencyGetCalls(containerSym, ctor)

  mainList.add(getter)

proc createGetters(mainList: NimNode, containerType: NimNode, newProcTypes: NimNode, ctors: seq[CtorInfo]) = 
  for ctor in ctors:
    if ctor.hasInstanceLifestyle:
      createFieldGetter(mainList, containerType, ctor)
    else:
      createTransientGetter(mainList, containerType, newProcTypes, ctor)

proc createContainerCall(mainList: NimNode, containerType: NimNode) =
  mainList.add(
    quote do:
      `containerType`()
  )

# </Emission>

# <Initialization>

proc createInitializeAssignment(assignments: NimNode, containerSym: NimNode, newProcTypes: NimNode, ctor: CtorInfo) =
  let 
    typeSym = ident(ctor.typeName)
    fieldIdent = ident(ctor.fieldName)

  let assignment = quote do:
    `containerSym`.`fieldIdent` = `typeSym`.`newProcTypes`()

  let assignCall = assignment.findChild(it.kind == nnkCall)
  assignCall.addDependencyGetCalls(containerSym, ctor)

  assignments.add(assignment)

proc createInitializer(mainList: NimNode, containerType: NimNode, newProcTypes: NimNode, ctors: seq[CtorInfo]) =
  let
    containerSym = genSym(NimSymKind.nskParam, "container")
    containerInit = quote do:
      proc initialize(`containerSym`: `containerType`)# =
        # `containerSym`.field = "value"

  var assignments = newStmtList()
  for ctor in ctors:
    if ctor.hasInstanceLifestyle:
      createInitializeAssignment(assignments, containerSym, newProcTypes, ctor)

  containerInit[6] = assignments

  mainList.add(containerInit)

# </Initialization>

macro CreateContainer*(installers: typed, newProcTypes: typed): untyped =
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

  # Emit the container

  var mainList = newStmtList()
  let containerType = genSym(NimSymKind.nskType, "Container")

  createContainerTypeDef(mainList, containerType, ctorInfos)

  # createGetters(mainList, containerType, newProcTypes, ctorInfos)

  createInitializer(mainList, containerType, newProcTypes, ctorInfos)

  createContainerCall(mainList, containerType)

  echo ""
  echo mainList.treeRepr
  echo ""
  

  mainList
