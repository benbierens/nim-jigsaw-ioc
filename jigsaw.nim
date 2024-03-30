import macros, strutils, algorithm

import jigsaw/types
import jigsaw/inspection
import jigsaw/loopdetection
import jigsaw/ordering
import jigsaw/emission
import jigsaw/initialization
export Installer, Inst, Registration, Reg

proc createContainerCall(mainList: NimNode, containerType: NimNode) =
  mainList.add(
    quote do:
      `containerType`()
  )

macro CreateContainer*(installers: typed, globalCtor: typed): untyped =
  var ctorInfos = newSeq[CtorInfo]()

  # Inspect installers to create ctorInfo objects.
  for installer in installers:
    let infos = getCtorInfosFromInstaller(installer, globalCtor)
    for i in infos:
      ctorInfos.add(i)

  # Ensure no loops
  ensureNoLoops(ctorInfos)

  # Figure out dependency order
  orderCtors(ctorInfos)

  var mainList = newStmtList()
  let containerType = genSym(NimSymKind.nskType, "Container")

  # Emit the container
  emit(mainList, containerType, ctorInfos, globalCtor)

  # Create the initialize method
  createInitializer(mainList, containerType, globalCtor, ctorInfos)

  # Create a container instance
  createContainerCall(mainList, containerType)

  mainList
