import Base
import ../../engine/battle/model.bend as Model
import ../../engine/battle/rng.bend as Rng
import ../../engine/battle/sources.bend as Sources
import ../../engine/battle/combat_math.bend as Math
import ../../engine/battle/runtime.bend as Runtime
import ../../engine/replay/runtime_fold.bend as Replay

def actor(id: Nat, side: Model.Side, phase: Model.Phase) -> Model.Actor:
  Model.Actor{Model.ActorId{id}, side, 10n, 100n, phase, 0}

def profile() -> Runtime.CombatProfile:
  Runtime.CombatProfile{Math.AlwaysHit{}, Math.StageNeutral{},
    Math.StageNeutral{}, 100, 50, 100, 100, 1875}

def state() -> Runtime.RuntimeState:
  Runtime.RuntimeState{Model.BattleState{0, 60,
    [actor(0n, Model.Player{}, Model.Ready{}),
     actor(1n, Model.Enemy{}, Model.Ready{})], Nil{}, 0n,
    Model.AwaitingCommands{}}, Rng.RngState{1, 2, 3, 4},
    Runtime.WildEncounter{}, 0,
    [Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{7n}, 0, False{}}],
    Nil{}, Nil{}, [Runtime.DefenderSnapshot{Model.ActorId{1n}, profile()}]}

def finished_code(result: Replay.RuntimeReplay) -> Nat:
  match result:
    case Replay.RuntimeReplayFinished{Runtime.RuntimeState{
        Model.BattleState{0, 60, actors, Nil{}, sequence, Model.Victory{}}, rng,
        encounter, failed, sources, Nil{}, trapped, defenders}, emitted,
        Runtime.RuntimeHit{Model.ActorId{0n}, Model.ActorId{1n}, 100, True{}}
          <> Nil{}}:
      1n
    case _:
      0n

def rejected_code(result: Replay.RuntimeReplay) -> Nat:
  match result:
    case Replay.RuntimeReplayRejected{state,
        Model.IncompleteBarrier{} <> Nil{}}:
      1n
    case _:
      0n

def fault_code(result: Replay.RuntimeReplay) -> Nat:
  match result:
    case Replay.RuntimeReplayFault{runtime,
        Some{Rng.RngSamplingExhausted{Rng.RngState{1, 2, 3, 4}, 64n}}}:
      1n
    case _:
      0n

def main() -> List<&2, Nat>:
  +terminal_batches = {[[Runtime.RuntimeMove{Model.ActorId{0n},
      Model.ActorId{1n}, Math.MoveId{7n}, 0, 30, 60, 0n, 0n, profile()},
    Runtime.RuntimeWait{Model.ActorId{1n}}],
    [Runtime.RuntimeWait{Model.ActorId{0n}}]]
    : List<&2, List<&2, Runtime.RuntimeCommand>>}
  [finished_code(Replay.run(16n, state(), terminal_batches)),
   rejected_code(Replay.run(16n, state(),
     [[Runtime.RuntimeWait{Model.ActorId{0n}}]])),
   fault_code(Replay.fold_result(Replay.RuntimeFoldFault{state(),
     Some{Rng.RngSamplingExhausted{Rng.RngState{1, 2, 3, 4}, 64n}}}))]

#| [1, 1, 1]
