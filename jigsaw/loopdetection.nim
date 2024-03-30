import inspection
import types

proc ensureNoLoop(path: string, ctors: seq[CtorInfo], here: CtorInfo, hereByName: string, visited: seq[string]) = 
  if here.typeName in visited:
    raiseAssert("Dependency loop detected: " & path & " -> " & hereByName)
  
  var newVisited = newSeq[string]()
  for v in visited:
    newVisited.add(v)
  newVisited.add(here.typeName)
  for abs in here.abstracts:
    newVisited.add(abs)

  for fa in here.foreignArgs:
    ensureNoLoop(path & "/" & hereByName, ctors, ctors.findCtorOfType(fa), fa, newVisited)

proc ensureNoLoops*(ctors: seq[CtorInfo]) = 
  for ctor in ctors:
    ensureNoLoop("", ctors, ctor, ctor.typeName, newSeq[string]())
