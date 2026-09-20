import Base

# Pure accumulator probe used to verify the headless engine boundary.
def transition(state: Nat, delta: Nat) -> Nat:
  Nat.add(state, delta)
