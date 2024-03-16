import macros, strutils, algorithm

type
  Lifestyle* = enum
    Unspecified
    Transient
    Singleton
    Instance

  CtorInfo = object
    typeName: string
    foreignArgs: seq[string]
    lifestyle: Lifestyle
    orderNumber: int
    instanceParamSym: NimNode

  Installer*[TRegistrations] = object
    registrations: TRegistrations
  Inst* = Installer

  Registration*[TComponent, TImplements] = object
    component: TComponent
    lifestyle*: Lifestyle
    implements: TImplements
  Reg* = Registration

# <Ctor inspection>

proc findCtorOfType(ctors: seq[CtorInfo], tName: string): CtorInfo =
  for ctor in ctors:
    if ctor.typeName == tName:
      return ctor
  raiseAssert("Unable to find component by name: '" & tName & "'. Has it been registered?")

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

proc getLifestyleForSym(typeName: string, lifestyleSym: NimNode): Lifestyle = 
  let str = lifestyleSym.strVal

  if str == "Transient":
    return Lifestyle.Transient
  if str == "Singleton":
    return Lifestyle.Singleton
  if str == "Instance":
    return Lifestyle.Instance

  raiseAssert("Invalid lifestyle specification for '" & typeName & "'.")

proc getCtorInfoForType(componentSym: NimNode, lifestyleSym: NimNode, newProcTypes: NimNode): CtorInfo = 
  let
    typeName = componentSym.strVal
    lifestyle = getLifestyleForSym(typeName, lifestyleSym)

  # instance-lifestyle components don't require a newProc,
  # and their arguments don't need to be inspected.
  if lifestyle == Lifestyle.Instance:
    return CtorInfo(
      typeName: typeName,
      foreignArgs: @[],
      lifestyle: lifestyle,
      orderNumber: -1,
      instanceParamSym: genSym(NimSymKind.nskParam, typeName.toLowerAscii)
    )

  # for transient and instance components, we need to find their newProc,
  # and find their non-defaulted arguments.
  for newProcType in newProcTypes:
    let procDef = newProcType.getImpl
    assert procDef.kind == nnkProcDef, "(Jigsaw-IoC internal error) getCtorInfoForType: Symbol not a procedure"

    let
      formalParams = procDef.findChild(it.kind == nnkFormalParams)
    
    if formalParams[1].kind == nnkIdentDefs:
      let identDefs = formalParams[1]

      if identDefs[1].kind == nnkCommand:
        let command = identDefs[1]

        if command[1].kind == nnkIdent and $(command[1].strVal) == typeName:
          var args: seq[string] = @[]
          for fparam in formalParams:
            if fparam.kind == nnkIdentDefs:
              if fparam[1].kind == nnkSym and
                fparam[2].kind == nnkEmpty:
                args.add($fparam[1].strVal)

          return CtorInfo(
            typeName: typeName,
            foreignArgs: args,
            lifestyle: lifestyle,
            orderNumber: -1
          )

  CtorInfo(
    typeName: "",
  )

proc getCtorInfoFromRegistration(objConst: NimNode, newProcTypes: NimNode): CtorInfo =
  assert objConst[0].kind == nnkBracketExpr
  assert objConst[1].kind == nnkExprColonExpr

  return getCtorInfoForType(
    objConst[0][1],
    # todo: implement-types
    objConst[1][1],
    newProcTypes
  )

template getCtorInfosFromInstaller(installer: typed, newProcTypes: typed): seq[CtorInfo] =
  var ctors = newSeq[CtorInfo]()

  assert installer[1].kind == nnkTupleConstr
  for registrationType in installer[1]:
    let info = getCtorInfoFromRegistration(registrationType, newProcTypes)
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

proc createSingletonAssignment(containerSym: NimNode, fieldIdent: NimNode, typeSym: NimNode, newProcTypes: NimNode): NimNode =
  return quote do:
    `containerSym`.`fieldIdent` = `typeSym`.`newProcTypes`()

proc createInstanceAssignment(containerSym: NimNode, fieldIdent: NimNode, ctor: CtorInfo): NimNode =
  let instanceParam = ctor.instanceParamSym
  return quote do:
    `containerSym`.`fieldIdent` = `instanceParam`

proc createAssignment(containerSym: NimNode, fieldIdent: NimNode, typeSym: NimNode, newProcTypes: NimNode, ctor: CtorInfo): NimNode =
  if ctor.lifestyle == Lifestyle.Singleton:
    return createSingletonAssignment(containerSym, fieldIdent, typeSym, newProcTypes)
  if ctor.lifestyle == Lifestyle.Instance:
    return createInstanceAssignment(containerSym, fieldIdent, ctor)
  raiseAssert("(Jigsaw-IoC internal error) unknown instance-type lifestyle.")

proc createInitializeAssignment(assignments: NimNode, containerSym: NimNode, newProcTypes: NimNode, ctor: CtorInfo) =
  let 
    typeSym = ident(ctor.typeName)
    fieldIdent = ident(ctor.fieldName)

  let assignment = createAssignment(
    containerSym,
    fieldIdent,
    typeSym,
    newProcTypes,
    ctor
  )

  let assignCall = assignment.findChild(it.kind == nnkCall)
  assignCall.addDependencyGetCalls(containerSym, ctor)

  assignments.add(assignment)

proc addInstanceParams(formalParams: NimNode, ctors: seq[CtorInfo]) =
  for ctor in ctors:
    if ctor.lifestyle == Lifestyle.Instance:
      formalParams.add(
        newIdentDefs(
          ctor.instanceParamSym,
          ident(ctor.typeName)
        )
      )

proc createInitializer(mainList: NimNode, containerType: NimNode, newProcTypes: NimNode, ctors: seq[CtorInfo]) =
  let
    containerSym = genSym(NimSymKind.nskParam, "container")
    containerInit = quote do:
      proc initialize(`containerSym`: `containerType`)

    formalParams = containerInit.findChild(it.kind == nnkFormalParams)

  addInstanceParams(formalParams, ctors)

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

  createGetters(mainList, containerType, newProcTypes, ctorInfos)

  createInitializer(mainList, containerType, newProcTypes, ctorInfos)

  createContainerCall(mainList, containerType)

  mainList
