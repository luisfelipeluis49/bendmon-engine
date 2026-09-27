import Base
import ./replay_test.bend as Cases
import ../../engine/world/replay.bend as Replay

def main() -> List<&2, Bool>:
  [Cases.rejected_at(Replay.replay(Cases.invalid_script(),
    Cases.catalog(), Cases.initial()))]
