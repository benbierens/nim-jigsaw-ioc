import macros, strutils
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

macro ListTypes(installers: typed, newProcTypes: typed): untyped =
  var ctorInfos = newSeq[CtorInfo]()

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

  # emit a proc:
  result = quote do:
    proc yeah() =
      echo "yeah!"

# macro ShowType(procName: typed): untyped =
#   result = quote do:
#     seq[CtorInfo](@[])

#   template addSignature(x: untyped) =
#     let impl = x.getImpl
#     assert impl.kind == nnkProcDef, "Symbol not a procedure!"
#     var
#       ttypeName: string = "unknown"
#       targs: seq[string] = @[]

#     echo "procdef:"
#     echo $impl.treeRepr
#     echo ""

#     for child in impl:
#       if child.kind == nnkFormalParams:
#         for fparam in child:
#           if fparam.kind == nnkSym:
#             ttypeName = $(fparam.strVal)
#           elif fparam.kind == nnkIdentDefs:
#             if fparam[1].kind == nnkSym and
#               fparam[2].kind == nnkEmpty:
#               targs.add($fparam[1].strVal)

#     var isStrA = newStrLitNode(ttypeName)
#     if not (ttypeName == "unknown") and not (ttypeName == "auto"):
#       # objctor:
#       #   sym CtorInfo
#       #   exprcolonExpr
#       #     Ident "typeName"
#       #     StrLit "name"
#       #   exprColonexpr
#       #     Ident "foreignArgs"
#       #     Prefix
#       #       OpenSymChoice 2 "@"
#       #       Bracket
#       #         StrLit "argsnames"

#       let typenameExpr = newNimNode(nnkExprColonExpr)
#       typenameExpr.add(newIdentNode("typeName"))
#       typenameExpr.add(newStrLitNode(ttypeName))

#       let argsExpr = newNimNode(nnkExprColonExpr)
#       argsExpr.add(newIdentNode("foreignArgs"))
#       let argsPrefix = newNimNode(nnkPrefix)
#       argsExpr.add(argsPrefix)
#       let openSym = bindSym("@", brForceOpen)
#       let bracket = newTree(nnkBracket)
#       for farg in targs:
#         bracket.add(newStrLitNode(farg))      
#       argsPrefix.add(openSym)
#       argsPrefix.add(bracket)

#       let ctorinfoSym = bindSym("CtorInfo")
#       let objCtor = newNimNode(nnkObjConstr)
#       objCtor.add(ctorinfoSym)
#       objCtor.add(typenameExpr)
#       objCtor.add(argsExpr)
#       result[1][1].add objCtor

#   if procName.kind == nnkSym:
#     addSignature(procName)
#   else:
#     for y in procName:
#       addSignature(y)
      
#   # echo result.treeRepr

echo "actual running:"
# let infos: seq[CtorInfo] = ShowType(new)
# for info in infos:
#     echo ""
#     echo "Name: " & info.typeName
#     echo "Foreign args:"
#     for arg in info.foreignArgs:
#         echo " - " & arg


ListTypes([
  Installer[(Application, Generator)],
  Installer[(Processor, Writer)]
], new)

yeah()
