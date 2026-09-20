import Base

# Balanced, independent branches exercise the native CPU fork-join runtime.
def balanced(+n: Nat) -> U32:
  match n:
    case 0n:
      1
    case 1n+p:
      left right = balanced(p) balanced(p)
      U32.add(left, right)

def main() -> IO(Unit):
  IO.print(U32.show(balanced(18n)))
