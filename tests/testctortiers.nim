# import std/unittest

# import "../jigsaw"

# type
#   ComponentA = ref object
#   ComponentB = ref object
#   ComponentC = ref object

# proc componentLevelCtor*(T: type ComponentA): T =
#   ComponentA()

# proc installerLevelCtor*(T: type ComponentB): T =
#   ComponentB()

# proc globalCtor*(T: type ComponentC): T =
#   ComponentC()

# suite "Constructor Tiers":
#   setup:
#     let
#       container = CreateContainer([
#         Installer[(
#           Registration[ComponentA, ()](lifestyle: Transient),
#           Registration[ComponentB, ()](lifestyle: Transient)
#         )](ctor: installerLevelCtor)#,
#         # Installer[(
#         #   Registration[ComponentC, ()](lifestyle: Transient)
#         # )]
#       ], globalCtor)

#     container.initialize()

#   test "Can resolve with component level constructor":
#     let c = container.get(ComponentA)

#     check:
#       c != nil

#   test "Can resolve with installer level constructor":
#     let c = container.get(ComponentB)

#     check:
#       c != nil

#   test "Can resolve with global constructor":
#     let c = container.get(ComponentC)

#     check:
#       c != nil

