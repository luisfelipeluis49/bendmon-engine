import Base
import ../../engine/battle/model.bend as Model
import ../../engine/battle/rng.bend as Rng
import ../../engine/battle/sources.bend as Sources
import ../../engine/battle/combat_math.bend as Math
import ../../engine/battle/effects.bend as Effects
import ../../engine/battle/runtime.bend as Runtime
import ../../engine/replay/runtime_fold.bend as Replay

def stages() -> Effects.StatStages:
  Effects.StatStages{Math.StageNeutral{}, Math.StageNeutral{},
    Math.StageNeutral{}, Math.StageNeutral{}, Math.StageNeutral{},
    Math.StageNeutral{}, Math.StageNeutral{}}

def effect_actor(hp: U32) -> Effects.EffectActor:
  Effects.EffectActor{hp, 100, 10, 10, stages(), Nil{}, False{}, Nil{}}

def world() -> Effects.EffectWorld:
  Effects.EffectWorld{effect_actor(100), effect_actor(50)}

def profile() -> Runtime.CombatProfile:
  Runtime.CombatProfile{Math.AlwaysHit{}, Math.StageNeutral{}, Math.StageNeutral{},
    100, 50, 100, 10, 0}

def snapshot() -> Effects.ActionSnapshot:
  Effects.ActionSnapshot{50, 100, 100, Math.StageNeutral{}, Math.AlwaysHit{},
    Effects.NormalPhysical{}, 0}

def invalid_program() -> Effects.EffectProgram:
  Effects.EffectProgram{Effects.Leaf{Effects.Heal{Effects.Target{}, 0}} <> Nil{}}

def state() -> Runtime.RuntimeState:
  Runtime.RuntimeState{
    Model.BattleState{0, 60,
      [Model.Actor{Model.ActorId{0n}, Model.Player{}, 100n, 100n,
        Model.Ready{}, 0},
       Model.Actor{Model.ActorId{1n}, Model.Enemy{}, 50n, 90n,
        Model.Ready{}, 0}], Nil{}, 0n, Model.AwaitingCommands{}},
    Rng.RngState{1, 2, 3, 4}, Runtime.WildEncounter{}, 0,
    [Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{7n}, 0, False{}}],
    Nil{}, Nil{}, [Runtime.DefenderSnapshot{Model.ActorId{1n}, profile()}],
    Some{Runtime.RuntimeEffectState{Model.ActorId{0n}, Model.ActorId{1n}, world()}}}

def command() -> List<&2, Runtime.RuntimeCommand>:
  [Runtime.RuntimeEffectMove{Model.ActorId{0n}, Model.ActorId{1n},
    Math.MoveId{7n}, 0, 30, 60, 0n, 0n, profile(), invalid_program(), snapshot()},
   Runtime.RuntimeWait{Model.ActorId{1n}}]

def result_code(result: Replay.RuntimeReplay) -> Nat:
  match result:
    case Replay.RuntimeReplayEffectRejected{state,
        Effects.InvalidAmount{0} <> Nil{}}:
      1n
    case _:
      0n

def main() -> List<&2, Nat>:
  [result_code(Replay.run(16n, state(), [command()]))]

#| [1]
