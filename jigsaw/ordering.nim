import algorithm
import inspection
import types

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

proc orderCtors*(ctors: var seq[CtorInfo]) = 
  for ctor in ctors.mitems:
    assignOrderNumber(ctors, ctor)
    if ctor.orderNumber == -1:
      raiseAssert("(Jigsaw-IoC internal error) Unable to find order number for type " & ctor.typeName)

  proc byOrderNumber(a, b: CtorInfo): int = 
    a.orderNumber - b.orderNumber

  sort(ctors, byOrderNumber)
