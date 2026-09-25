import Base
import ../../engine/m7/ownership.bend as Ownership
import ../../engine/progression/core.bend as Progression

def base_stats() -> Progression.StatBlock:
  Progression.StatBlock{50, 50, 50, 50, 50, 50}

def ivs() -> Progression.StatBlock:
  Progression.StatBlock{10, 10, 10, 10, 10, 10}

def snapshot() -> Progression.Individual:
  Progression.Individual{100n, 7n, 5, 1900, 5, 20, ivs(), [11, 12],
    [Progression.MoveLearnedRecord{11}], [3n], [4n], [2]}

def captured_ok(result: Ownership.CaptureResult) -> Bool:
  match result:
    case Ownership.CaptureOwned{Progression.Individual{101n, 7n, 5, 1900,
        13, 20, Progression.StatBlock{10, 10, 10, 10, 10, 10}, [11, 12],
        [Progression.MoveLearnedRecord{11}], [3n], [4n], [2]}}:
      True{}
    case _: False{}

def rejected_same(result: Ownership.CaptureResult) -> Bool:
  match result:
    case Ownership.CaptureRejected{Progression.Individual{100n, 7n, 5, 1900,
        5, 20, Progression.StatBlock{10, 10, 10, 10, 10, 10}, [11, 12],
        [Progression.MoveLearnedRecord{11}], [3n], [4n], [2]}}:
      True{}
    case _: False{}

def valid_transfer() -> Bool:
  captured_ok(Ownership.capture(101n, 7n, 13, snapshot(), base_stats()))

def wrong_species() -> Bool:
  rejected_same(Ownership.capture(101n, 8n, 13, snapshot(), base_stats()))

def same_owner_id() -> Bool:
  rejected_same(Ownership.capture(100n, 7n, 13, snapshot(), base_stats()))

def rejected_xp_snapshot(result: Ownership.CaptureResult) -> Bool:
  match result:
    case Ownership.CaptureRejected{Progression.Individual{100n, 7n, 5, 1899,
        5, 20, Progression.StatBlock{10, 10, 10, 10, 10, 10}, [11, 12],
        [Progression.MoveLearnedRecord{11}], [3n], [4n], [2]}}: True{}
    case _: False{}

def rejected_max_hp_snapshot(result: Ownership.CaptureResult) -> Bool:
  match result:
    case Ownership.CaptureRejected{Progression.Individual{100n, 7n, 5, 1900,
        5, 21, Progression.StatBlock{10, 10, 10, 10, 10, 10}, [11, 12],
        [Progression.MoveLearnedRecord{11}], [3n], [4n], [2]}}: True{}
    case _: False{}

def rejected_iv_snapshot(result: Ownership.CaptureResult) -> Bool:
  match result:
    case Ownership.CaptureRejected{Progression.Individual{100n, 7n, 5, 1900,
        5, 20, Progression.StatBlock{32, 10, 10, 10, 10, 10}, [11, 12],
        [Progression.MoveLearnedRecord{11}], [3n], [4n], [2]}}: True{}
    case _: False{}

def inconsistent_xp_level() -> Bool:
  rejected_xp_snapshot(Ownership.capture(101n, 7n, 13,
    Progression.Individual{100n, 7n, 5, 1899, 5, 20, ivs(), [11, 12],
      [Progression.MoveLearnedRecord{11}], [3n], [4n], [2]}, base_stats()))

def incorrect_max_hp() -> Bool:
  rejected_max_hp_snapshot(Ownership.capture(101n, 7n, 13,
    Progression.Individual{100n, 7n, 5, 1900, 5, 21, ivs(), [11, 12],
      [Progression.MoveLearnedRecord{11}], [3n], [4n], [2]}, base_stats()))

def incorrect_iv() -> Bool:
  rejected_iv_snapshot(Ownership.capture(101n, 7n, 13,
    Progression.Individual{100n, 7n, 5, 1900, 5, 20,
      Progression.StatBlock{32, 10, 10, 10, 10, 10}, [11, 12],
      [Progression.MoveLearnedRecord{11}], [3n], [4n], [2]}, base_stats()))

def invalid_execution_hp() -> Bool:
  Bool.and(rejected_same(Ownership.capture(101n, 7n, 0, snapshot(),
      base_stats())),
    rejected_same(Ownership.capture(101n, 7n, 21, snapshot(), base_stats())))

def captured_stats_result(stats: Maybe<&2, Progression.StatBlock>) -> Bool:
  match stats:
    case Some{Progression.StatBlock{20, 10, 10, 10, 10, 10}}: True{}
    case _: False{}

def captured_stats() -> Bool:
  captured_stats_result(Progression.calculate_stats(base_stats(), ivs(), 5))

def main() -> List<&2, Bool>:
  [U32.is_eq(Progression.level_for_xp(1900), 5),
   captured_stats(), valid_transfer(), wrong_species(), same_owner_id(),
   inconsistent_xp_level(), incorrect_max_hp(), incorrect_iv(),
   invalid_execution_hp()]

#| [True{}, True{}, True{}, True{}, True{}, True{}, True{}]
