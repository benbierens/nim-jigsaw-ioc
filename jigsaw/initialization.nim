import macros
import emission
import types

proc createSingletonAssignment(containerSym: NimNode, fieldIdent: NimNode, typeSym: NimNode, ctor: CtorInfo): NimNode =
  let ctorSym = ctor.ctor
  return quote do:
    `containerSym`.`fieldIdent` = `typeSym`.`ctorSym`()

proc createInstanceAssignment(containerSym: NimNode, fieldIdent: NimNode, ctor: CtorInfo): NimNode =
  let instanceParam = ctor.instanceParamSym
  return quote do:
    `containerSym`.`fieldIdent` = `instanceParam`

proc createAssignment(containerSym: NimNode, fieldIdent: NimNode, typeSym: NimNode, ctor: CtorInfo): NimNode =
  if ctor.lifestyle == Lifestyle.Singleton:
    return createSingletonAssignment(containerSym, fieldIdent, typeSym, ctor)
  if ctor.lifestyle == Lifestyle.Instance:
    return createInstanceAssignment(containerSym, fieldIdent, ctor)
  raiseAssert("(Jigsaw-IoC internal error) unknown instance-type lifestyle.")

proc createInitializeAssignment(assignments: NimNode, containerSym: NimNode, ctor: CtorInfo) =
  let 
    typeSym = ident(ctor.typeName)
    fieldIdent = ident(ctor.fieldName)

  let assignment = createAssignment(
    containerSym,
    fieldIdent,
    typeSym,
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

proc createInitializer*(mainList: NimNode, containerType: NimNode, ctors: seq[CtorInfo]) =
  let
    containerSym = genSym(NimSymKind.nskParam, "container")
    containerInit = quote do:
      proc initialize(`containerSym`: `containerType`)

    formalParams = containerInit.findChild(it.kind == nnkFormalParams)

  addInstanceParams(formalParams, ctors)

  var assignments = newStmtList()
  for ctor in ctors:
    if ctor.hasInstanceLifestyle:
      createInitializeAssignment(assignments, containerSym, ctor)

  containerInit[6] = assignments

  mainList.add(containerInit)
