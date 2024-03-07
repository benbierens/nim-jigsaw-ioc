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

macro ShowType(procName: typed): untyped =
  result = quote do:
    seq[CtorInfo](@[])

  template addSignature(x: untyped) =
    let impl = x.getImpl
    assert impl.kind == nnkProcDef, "Symbol not a procedure!"
    var
      ttypeName: string = "unknown"
      targs: seq[string] = @[]

    for child in impl:
      if child.kind == nnkFormalParams:
        for fparam in child:
          if fparam.kind == nnkSym:
            ttypeName = $(fparam.strVal)
          elif fparam.kind == nnkIdentDefs:
            if fparam[1].kind == nnkSym and
              fparam[2].kind == nnkEmpty:
              targs.add($fparam[1].strVal)

    var isStrA = newStrLitNode(ttypeName)
    if not (ttypeName == "unknown") and not (ttypeName == "auto"):
      # objctor:
      #   sym CtorInfo
      #   exprcolonExpr
      #     Ident "typeName"
      #     StrLit "name"
      #   exprColonexpr
      #     Ident "foreignArgs"
      #     Prefix
      #       OpenSymChoice 2 "@"
      #       Bracket
      #         StrLit "argsnames"

      let typenameExpr = newNimNode(nnkExprColonExpr)
      typenameExpr.add(newIdentNode("typeName"))
      typenameExpr.add(newStrLitNode(ttypeName))

      let argsExpr = newNimNode(nnkExprColonExpr)
      argsExpr.add(newIdentNode("foreignArgs"))
      let argsPrefix = newNimNode(nnkPrefix)
      argsExpr.add(argsPrefix)
      let openSym = bindSym("@", brForceOpen)
      let bracket = newTree(nnkBracket)
      for farg in targs:
        bracket.add(newStrLitNode(farg))      
      argsPrefix.add(openSym)
      argsPrefix.add(bracket)

      let ctorinfoSym = bindSym("CtorInfo")
      let objCtor = newNimNode(nnkObjConstr)
      objCtor.add(ctorinfoSym)
      objCtor.add(typenameExpr)
      objCtor.add(argsExpr)
      result[1][1].add objCtor

  if procName.kind == nnkSym:
    addSignature(procName)
  else:
    for y in procName:
      addSignature(y)
      
  # echo result.treeRepr

echo "actual running:"
echo "showing 'new' symbols:"

let infos: seq[CtorInfo] = ShowType(new)
for info in infos:
    echo ""
    echo "Name: " & info.typeName
    echo "Foreign args:"
    for arg in info.foreignArgs:
        echo " - " & arg
