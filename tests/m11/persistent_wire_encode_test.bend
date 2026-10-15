import Base
import ../../engine/m7/persistent_wire_encode.bend as Wire
import ../../engine/m7/persistent_state.bend as Persistent
import ../../engine/m7/rewards.bend as Rewards
import ../../engine/economy/core.bend as Economy
import ../../engine/economy/roster.bend as Roster
import ../../engine/progression/core.bend as Progression

def equal_tokens(left: List<&2, Nat>, right: List<&2, Nat>) -> Bool:
  match left right:
    case Nil{} Nil{}: True{}
    case a <> as_ b <> bs:
      Bool.and(Nat.is_eq(a, b), equal_tokens(as_, bs))
    case _ _: False{}

def progressed() -> Persistent.PersistentState:
  base: Progression.StatBlock = Progression.StatBlock{(50 : U32), (100 : U32), (100 : U32), (100 : U32), (100 : U32), (100 : U32)}
  +ivs: Progression.StatBlock = Progression.StatBlock{(0 : U32), (0 : U32), (0 : U32), (0 : U32), (0 : U32), (0 : U32)}
  individual: Progression.Individual = Progression.Individual{77n, 4n, (2 : U32), (100 : U32), (9 : U32), (14 : U32), ivs,
    [(3 : U32), (4 : U32), (5 : U32), (6 : U32)], [Progression.MoveLearnedRecord{(7 : U32)},
      Progression.MoveReplacedRecord{(8 : U32), (9 : U32)}, Progression.MoveDeclinedRecord{(10 : U32)}],
    [11n, 12n], [13n], [(1 : U32), (2 : U32)]}
  +caps: Economy.Capacity = Economy.Capacity{6n, 4n, 1000n, 999n, 512n, 9999999n}
  economy: Economy.State = Economy.State{caps, 0n, 1n, 0n, 4n, 5n,
    [Economy.ItemStack{Economy.ItemId{9n}, 2n}]}
  roster: Roster.Roster = Roster.Roster{caps, [Roster.IndividualId{77n}], []}
  owned: List<&2, Rewards.OwnedRewardInput> = [Rewards.OwnedRewardInput{individual, base, ivs, True{}, True{}}]
  Persistent.PersistentState{economy, roster, owned,
    Progression.RewardLedger{[7n, 8n]}, 7n, 123n}

def expected() -> List<&2, Nat>:
  [1n, 77n,
    6n, 4n, 1000n, 999n, 512n, 9999999n, 0n, 1n, 0n, 4n, 5n,
    1n, 9n, 2n,
    6n, 4n, 1000n, 999n, 512n, 9999999n, 1n, 77n, 0n,
    1n, 47n, 77n, 4n, 2n, 100n, 9n, 14n,
    0n, 0n, 0n, 0n, 0n, 0n,
    4n, 3n, 4n, 5n, 6n,
    3n, 0n, 7n, 1n, 8n, 9n, 2n, 10n,
    2n, 11n, 12n, 1n, 13n, 2n, 1n, 2n,
    50n, 100n, 100n, 100n, 100n, 100n,
    0n, 0n, 0n, 0n, 0n, 0n, 1n, 1n,
    2n, 7n, 8n, 7n, 123n]

def encoded_matches(result: Wire.EncodeResult) -> Bool:
  match result:
    case Wire.EncodeAccepted{tokens}:
      equal_tokens(tokens, expected())
    case _: False{}

def rejected_invalid(result: Wire.EncodeResult) -> Bool:
  match result:
    case Wire.EncodeRejected{}: True{}
    case _: False{}

def main() -> List<Bool>:
  [encoded_matches(Wire.encode(progressed())),
    rejected_invalid(Wire.encode(Persistent.PersistentState{
      Economy.State{Economy.Capacity{6n, 4n, 1000n, 999n, 512n, 9999999n},
        0n, 1n, 0n, 4n, 5n, []},
      Roster.Roster{Economy.Capacity{6n, 4n, 1000n, 999n, 512n, 9999999n},
        [], []}, [], Progression.RewardLedger{[]}, 6n, 0n}))]
