import Base
import ../../engine/core/bootstrap.bend as Boot

# The command count is capped so the exact Nat total stays below Bend's
# representable Nat limit even when every token is the largest U32.
def sum_args(args: List<String>, remaining: Nat, state: Nat) -> Maybe<&2, Nat>:
  match args remaining:
    case Nil{} _:
      Some{state}
    case h <> t 0n:
      None{}
    case h <> t 1n+r:
      do Maybe<&2, Nat>:
        delta : U32 <- U32.read(h)
        sum_args(t, r, Boot.transition(state, U32.to_nat(delta)))

def finish(total: Maybe<&2, Nat>) -> IO(Unit):
  match total:
    case None{}:
      IO.die(Unit, 2, "usage: headless [--] <unsigned decimal U32>... (each value must fit U32; at most 1024 arguments)")
    case Some{value}:
      IO.print(Nat.show(value))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    finish(sum_args(args, 1024n, 0n))
