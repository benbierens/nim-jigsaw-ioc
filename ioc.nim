# import std/os
# import std/terminal
# import std/options
# import std/strutils
import std/typetraits

type
  Lifestyle* = enum
    Transient
    Singleton
  Component = object
    typeName*: string # name of the type
    depencenyTypeNames*: seq[string] # name of the types in ctor args
    lifestyle*: Lifestyle # transient or singleton
    #singletonInstance*: any # if singleton, store instance here
  IoC* = ref object of RootObj
    components: seq[Component]
  
proc register*[T](self: IoC, c: typedesc[T], lifestyle: Lifestyle = Lifestyle.Transient): void =
  echo "register this component type: " & c.name
  let typeName = c.name


proc init*(self: IoC): void =
  echo "create all singletons (recurse resolve dependencies)"
  echo "then init each singleton that has one"

proc resolve*[T](self: IoC, c: typedesc[T]): T =
  echo "if T is transient, create (recurse resolve dependencies), init, then return"
  echo "otherwise, return singleton instance"
  raiseAssert("A!")
