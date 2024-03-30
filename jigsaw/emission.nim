import macros
import types

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

proc addDependencyGetCalls*(returnCall: NimNode, containerSym: NimNode, ctor: CtorInfo) =
  for fa in ctor.foreignArgs:
    let faIdent = ident(fa)
    returnCall.add(quote do:
      `containerSym`.get(`faIdent`)
    )

proc createTransientGetter(mainList: NimNode, containerType: NimNode, globalCtor: NimNode, ctor: CtorInfo) =
  let
    typeSym = ident(ctor.typeName)
    containerSym = genSym(NimSymKind.nskParam, "container")

  let
    getter = quote do:
      proc get(`containerSym`: `containerType`, _: type `typeSym`): auto = 
        return `typeSym`.`globalCtor`()

  let returnCall = getter.findChild(it.kind == nnkStmtList)[0][0]
  returnCall.addDependencyGetCalls(containerSym, ctor)

  mainList.add(getter)

proc createAbstractGetter(mainList: NimNode, containerType: NimNode, ctor: CtorInfo, abstract: string) =
  let
    typeSym = ident(abstract)
    typeName = ident(ctor.typeName)
    getter = quote do:
      proc get(container: `containerType`, _: type `typeSym`): auto = 
        return container.get(`typeName`)


  mainList.add(getter)

proc createAbstractGetters(mainList: NimNode, containerType: NimNode, ctor: CtorInfo) =
  for abstract in ctor.abstracts:
    createAbstractGetter(mainList, containerType, ctor, abstract)

proc createGetters(mainList: NimNode, containerType: NimNode, globalCtor: NimNode, ctors: seq[CtorInfo]) = 
  for ctor in ctors:
    if ctor.hasInstanceLifestyle:
      createFieldGetter(mainList, containerType, ctor)
    else:
      createTransientGetter(mainList, containerType, globalCtor, ctor)
    createAbstractGetters(mainList, containerType, ctor)

proc emit*(mainList: NimNode, containerType: NimNode, ctorInfos: seq[CtorInfo], globalCtor: NimNode) = 
  createContainerTypeDef(mainList, containerType, ctorInfos)
  createGetters(mainList, containerType, globalCtor, ctorInfos)
