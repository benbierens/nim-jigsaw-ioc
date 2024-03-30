import macros, strutils
import types

proc findCtorOfType*(ctors: seq[CtorInfo], tName: string): CtorInfo =
  for ctor in ctors:
    if ctor.typeName == tName:
      return ctor
    if tName in ctor.abstracts:
      return ctor
  raiseAssert("Unable to find component by name: '" & tName & "'. Has it been registered?")

proc getLifestyleForSym(typeName: string, lifestyleSym: NimNode): Lifestyle = 
  let str = lifestyleSym.strVal

  if str == "Transient":
    return Lifestyle.Transient
  if str == "Singleton":
    return Lifestyle.Singleton
  if str == "Instance":
    return Lifestyle.Instance

  raiseAssert("Invalid lifestyle specification for '" & typeName & "'.")

proc getAbstractsFromSym(abstractsSym: NimNode): seq[string] = 
  var abstracts = newSeq[string]()

  if abstractsSym.kind == nnkSym:
    abstracts.add(abstractsSym.strVal)
  if abstractsSym.kind == nnkTupleConstr:
    for child in abstractsSym:
      abstracts.add(child.strVal)

  return abstracts

proc getInstanceCtorInfo(typeName: string, lifestyle: Lifestyle, abstractsSym: NimNode): CtorInfo =
  return CtorInfo(
    typeName: typeName,
    foreignArgs: @[],
    lifestyle: lifestyle,
    orderNumber: -1,
    instanceParamSym: genSym(NimSymKind.nskParam, typeName.toLowerAscii),
    abstracts: getAbstractsFromSym(abstractsSym)
  )

proc areCtorParameters(formalParams: NimNode, typeName: string): bool =
  if formalParams[1].kind == nnkIdentDefs:
      let identDefs = formalParams[1]
      if identDefs[1].kind == nnkCommand:
        let command = identDefs[1]
        if command[1].kind == nnkIdent and $(command[1].strVal) == typeName:
          return true
  return false

proc getForeignArgs(formalParams: NimNode): seq[string] =
  var args: seq[string] = @[]
  for fparam in formalParams:
    if fparam.kind == nnkIdentDefs:
      if fparam[1].kind == nnkSym and
        fparam[2].kind == nnkEmpty:
        args.add($fparam[1].strVal)
  return args

proc getCtorInfoForTypeForSingleCtorProc(
  typeName: string,
  lifestyle: Lifestyle,
  ctor: NimNode,
  abstractsSym: NimNode
): CtorInfo =
  let ctorImpl = ctor.getImpl
  assert ctorImpl.kind == nnkProcDef, "(Jigsaw-IoC internal error) getCtorInfoForTypeForSingleCtorProc: Symbol not a procedure"
  let formalParams = ctorImpl.findChild(it.kind == nnkFormalParams)
  
  if areCtorParameters(formalParams, typeName):
    var args = getForeignArgs(formalParams)
    return CtorInfo(
      typeName: typeName,
      foreignArgs: args,
      lifestyle: lifestyle,
      orderNumber: -1,
      abstracts: getAbstractsFromSym(abstractsSym),
      ctor: ctor
    )
  return CtorInfo()

proc getCtorInfoForTypeForMultipleCtorProcs(
  typeName: string,
  lifestyle: Lifestyle,
  ctor: NimNode,
  abstractsSym: NimNode
): CtorInfo =
  for ctorProc in ctor:
    let info = getCtorInfoForTypeForSingleCtorProc(typeName, lifestyle, ctorProc, abstractsSym)
    if info.isValid:
      return info
  return CtorInfo()

proc getCtorInfoForType(
  componentSym: NimNode,
  abstractsSym: NimNode,
  lifestyleSym: NimNode,
  ctor: NimNode): CtorInfo = 
  let
    typeName = componentSym.strVal
    lifestyle = getLifestyleForSym(typeName, lifestyleSym)

  # instance-lifestyle components don't require a newProc,
  # and their arguments don't need to be inspected.
  if lifestyle == Lifestyle.Instance:
    return getInstanceCtorInfo(typeName, lifestyle, abstractsSym)

  # for transient and singleton components, we need to find their ctor procs,
  # and find their non-defaulted arguments.

  # Multiple procs 
  if ctor.kind == nnkClosedSymChoice:
    let ctorInfo = getCtorInfoForTypeForMultipleCtorProcs(typeName, lifestyle, ctor, abstractsSym)
    if ctorInfo.isValid:
      return ctorInfo

  # Single proc
  if ctor.kind == nnkSym:
    let ctorInfo = getCtorInfoForTypeForSingleCtorProc(typeName, lifestyle, ctor, abstractsSym)
    if ctorInfo.isValid:
      return ctorInfo

  raiseAssert("(Jigsaw-IoC) Failed to find ctor '" &
    ctor.treeRepr & 
    "' for type '" &
    typeName &
    "'.")

proc getCtorInfoFromRegistration(objConst: NimNode, ctor: NimNode): CtorInfo =
  assert objConst[0].kind == nnkBracketExpr
  assert objConst[1].kind == nnkExprColonExpr

  var useCtor = ctor
  if objConst.len == 3 and objConst[2].kind == nnkExprColonExpr:
    # If a component-level ctor is specified, we use it.
    echo "using component-level ctor override!"
    useCtor = objConst[2][1]

  let info = getCtorInfoForType(
    objConst[0][1],
    objConst[0][2],
    objConst[1][1],
    useCtor
  )

  return info

template getCtorInfosFromInstaller*(installer: typed, ctor: typed): seq[CtorInfo] =
  var ctors = newSeq[CtorInfo]()

  if installer[1].kind == nnkObjConstr:
    # Single registration in installer
    echo "single"
    let info = getCtorInfoFromRegistration(installer[1], ctor)
    if info.isValid:
        ctors.add(info)

  # TODO: single registration with installer-level ctor
  
  elif installer[1].kind == nnkTupleConstr:
    # Multiple registrations in installer
    echo "multi"
    for registrationType in installer[1]:
      let info = getCtorInfoFromRegistration(registrationType, ctor)
      if info.isValid:
        ctors.add(info)

  elif installer.kind == nnkObjConstr and
    installer[1].kind == nnkExprColonExpr and
    installer[1][0].kind == nnkSym and
    installer[1][0].strVal == "ctor":
      echo "multie with ctor"
      # Multiple registrations with installer-level ctor
      let installerLevelCtor = installer[1][1]
      for registrationType in installer[0][1]:
        let info = getCtorInfoFromRegistration(registrationType, installerLevelCtor)
        if info.isValid:
          ctors.add(info)

  else:
    raiseAssert("(Jigsaw-IoC internal error) Unknown registration node-kind. Obj or Tuple supported.")

  ctors
