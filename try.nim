import macros, strutils
import "./ioc"
import "./application"
import "./generator"
import "./processor"
import "./writer"

macro ShowType(x: typed): untyped =
  result = quote do:
    seq[string](@[])
    
  template addSignature(x: untyped) =
    let impl = x.getImpl
    assert impl.kind == nnkProcDef, "Symbol not a procedure!"
    result[1][1].add newLit(impl.repr)
    
  if x.kind == nnkSym:
    addSignature(x)
  else:
    for y in x:
      addSignature(y)
      
  echo result.treeRepr

echo "showing 'new' symbols:"

let seqstr: seq[string] = ShowType(new)
for ln in seqstr:
    echo ln
