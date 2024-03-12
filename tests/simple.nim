import std/unittest

suite "Simple tests":
  setup:
    echo "run before each test"
  
  teardown:
    echo "run after each test"
  
  test "runs":
    echo "Test runs!"
