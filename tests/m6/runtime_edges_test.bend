import Base
import ../../engine/battle/model.bend as Battle
import ../../engine/battle/combat_math.bend as Math
import ../../engine/battle/rng.bend as Rng
import ../../engine/battle/sources.bend as Sources
import ../../engine/battle/runtime.bend as Runtime

# The production mixed cancellation/fizzle transitions must release or charge
# both sources together without advancing the action RNG stream.

def profile() -> Runtime.CombatProfile:
  Runtime.CombatProfile{Math.AlwaysHit{}, Math.StageNeutral{},
    Math.StageNeutral{}, 100, 50, 100, 10, 0}

def initial() -> Runtime.RuntimeState:
  Runtime.RuntimeState{
    Battle.BattleState{0, 60,
      [Battle.Actor{Battle.ActorId{0n}, Battle.Player{}, 100n, 100n,
          Battle.Ready{}, 0},
       Battle.Actor{Battle.ActorId{1n}, Battle.Enemy{}, 100n, 90n,
          Battle.Ready{}, 0}], Nil{}, 0n, Battle.AwaitingCommands{}},
    Rng.RngState{1, 2, 3, 4}, Runtime.WildEncounter{}, 0,
    [Sources.MoveSource{Battle.ActorId{0n}, Math.MoveId{7n}, 0, True{}},
     Sources.MoveSource{Battle.ActorId{0n}, Math.MoveId{8n}, 0, True{}}],
    [Runtime.QueuedMove{0n,
      Runtime.SourceReservation{Battle.ActorId{0n}, Math.MoveId{7n},
        Battle.ActorId{1n}}, profile()}],
    Nil{}, [Runtime.DefenderSnapshot{Battle.ActorId{1n}, profile()}], None{}}

def cancel_code(result: Runtime.RuntimeAdvanceResult) -> Nat:
  match result:
    case Runtime.RuntimeStep{
        Runtime.RuntimeState{battle, Rng.RngState{1, 2, 3, 4}, encounter,
          failed,
          [Sources.MoveSource{Battle.ActorId{0n}, Math.MoveId{7n}, 0,
             False{}},
           Sources.MoveSource{Battle.ActorId{0n}, Math.MoveId{8n}, 0,
             False{}}], reservations, trapped, defenders, effects}, emitted,
        [Runtime.RuntimeCancel{Battle.ActorId{0n}, Battle.ActorId{1n}}]}:
      1n
    case _: 0n

def fizzle_code(result: Runtime.RuntimeAdvanceResult) -> Nat:
  match result:
    case Runtime.RuntimeStep{
        Runtime.RuntimeState{battle, Rng.RngState{1, 2, 3, 4}, encounter,
          failed,
          [Sources.MoveSource{Battle.ActorId{0n}, Math.MoveId{7n}, 90,
             False{}},
           Sources.MoveSource{Battle.ActorId{0n}, Math.MoveId{8n}, 92,
             False{}}], reservations, trapped, defenders, effects}, emitted,
        [Runtime.RuntimeFizzle{Battle.ActorId{0n}, Battle.ActorId{1n}}]}:
      1n
    case _: 0n

def main() -> List<&2, Nat>:
  [cancel_code(Runtime.cancel_mixed_move(initial(), 0, Battle.ActorId{0n},
      Battle.ActorId{1n}, 0n, Nil{},
      Runtime.SourceReservation{Battle.ActorId{0n}, Math.MoveId{7n},
        Battle.ActorId{1n}}, Math.MoveId{8n})),
   fizzle_code(Runtime.fizzle_mixed_move(initial(), 0, Battle.ActorId{0n},
      Battle.ActorId{1n}, 30, 0n, Nil{}, Math.MoveId{7n}, Math.MoveId{8n},
      60, 61))]

#| [1, 1]
