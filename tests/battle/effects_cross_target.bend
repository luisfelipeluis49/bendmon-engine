import Base
import ../../engine/battle/effects.bend as Effects
import ./effects_test.bend as Golden

def main() -> Nat:
  Golden.ordered_code(Effects.run(Golden.ordered_program(), Golden.world(),
    Golden.snapshot(), Golden.test_rng()))

#| 1
