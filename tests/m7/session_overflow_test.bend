import Base
import ./session_test.bend as Fixture

def main() -> List<Bool>:
  [Fixture.late_reward_overflow_rolls_back()]
