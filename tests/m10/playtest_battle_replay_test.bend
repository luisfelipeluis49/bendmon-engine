import Base
import ../../engine/world/playtest_battle_replay.bend as Replay
import ../../engine/world/playtest_world_command.bend as Commands
import ../../engine/world/world_session.bend as Session
import ../../engine/world/event_bridge.bend as EventBridge
import ../../engine/world/events.bend as Events
import ../../engine/world/exploration.bend as Exploration
import ../../engine/world/encounters.bend as Encounters
import ../../engine/world/geometry.bend as Geometry
import ../../engine/battle/rng.bend as Rng
import ../../engine/battle/effects.bend as Effects
import ../../engine/world/dynamic_playable_encounter.bend as Encounter
import ../../engine/world/encounter_handoff.bend as Handoff
import ../../engine/m7/dynamic_species.bend as Species
import ../../engine/m7/dynamic_moves.bend as Moves
import ../../engine/m7/rewards.bend as Rewards
import ../../engine/progression/core.bend as Progression

def initial() -> Session.WorldSession:
  Session.WorldSession{EventBridge.State{
    Exploration.State{1n,
      Geometry.Point{Geometry.Coord{False{}, 100},
        Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 100}},
      Encounters.empty(Rng.RngState{1, 2, 3, 4}), None{}, 55n},
    Events.World{[], []}, None{}}, None{}}

def species_row(+id: Nat, hp: U32, speed: U32) -> Species.SpeciesProgressionRecord:
  Species.SpeciesProgressionRecord{id,
    Progression.StatBlock{hp, 50, 40, 35, 45, speed}, 500, 100, 0,
    [0], Rewards.SpeciesLearning{id, [Rewards.LevelMove{1, 1}]}}

def replay_species() -> Species.Catalog:
  Species.Catalog{123, 1, [species_row(4n, 50, 60), species_row(9n, 45, 55)]}

def replay_moves() -> Moves.Catalog:
  Moves.Catalog{123, [Moves.MoveRecord{1, 10, True{}, 0, 0, 30, 60,
    [0], 0, 8, Effects.EffectProgram{[
      Effects.Leaf{Effects.Damage{0n, Effects.Target{},
        Effects.Physical{}, 10}}]}}]}

def battle_world() -> Session.WorldSession:
  Session.WorldSession{EventBridge.State{
    Exploration.State{1n,
      Geometry.Point{Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 0},
        Geometry.Coord{False{}, 0}},
      Encounters.Meter{Some{1n}, 0n, 500000n, 0n,
        Rng.RngState{1, 2, 3, 4}},
      Some{Exploration.PendingEncounter{1n, 77n}}, 123n},
    Events.World{[], []}, None{}}, None{}}

def battling(result: Encounter.EncounterResult) -> Maybe<Session.WorldSession>:
  match result:
    case Encounter.Started{state, species, level}: Some{state}
    case _: None{}

def encounter_battle() -> Maybe<Session.WorldSession>:
  battling(Encounter.start(battle_world(),
    [Handoff.EncounterTable{77n,
      [Encounters.EncounterEntry{9n, 1n, 5n, 5n}]}],
    replay_species(), replay_moves(), 4n, 1, 60))

def rejects_battle_command_outside_battle(result: Replay.ReplayResult) -> Bool:
  match result:
    case Replay.ReplayRejected{Session.WorldSession{world, None{}}, 0n}:
      True{}
    case _: False{}

def advance_was_accepted(replay: Replay.ReplayResult) -> Bool:
  match replay:
    case Replay.Replayed{Session.Battling{persistent, battle}, 1n}: True{}
    case _: False{}

def advance_trace_no_ai_wait(result: Replay.TracedReplay) -> Bool:
  match result:
    case Replay.TracedReplay{Replay.Replayed{session, 1n},
        [Replay.TracePoint{0n, pre_tick, post_tick, False{}}]}: True{}
    case _: False{}

def accepted_advance(result: Maybe<Session.WorldSession>) -> Bool:
  match result:
    case Some{Session.Battling{persistent, battle}}:
      advance_trace_no_ai_wait(Replay.run_traced([Commands.PlayAdvanceBattle{}],
        Session.Battling{persistent, battle}, replay_species(), replay_moves()))
    case _: False{}

def battle_command_count(result: Replay.ReplayResult, expected: Nat) -> Bool:
  match result:
    case Replay.Replayed{Session.Battling{persistent, battle}, accepted}:
      Nat.is_eq(accepted, expected)
    case _: False{}

def accepted_wait_after_advance(result: Maybe<Session.WorldSession>) -> Bool:
  match result:
    case Some{Session.Battling{persistent, battle}}:
      battle_command_count(Replay.run([Commands.PlayAdvanceBattle{},
        Commands.PlayBattleWait{0n}],
        Session.Battling{persistent, battle}, replay_species(),
        replay_moves()), 2n)
    case _: False{}

def accepted_second_escape(result: Maybe<Session.WorldSession>) -> Bool:
  match result:
    case Some{Session.Battling{persistent, battle}}:
      battle_command_count(Replay.run([Commands.PlayBattleEscape{0n},
        Commands.PlayAdvanceBattle{}, Commands.PlayAdvanceBattle{},
        Commands.PlayBattleEscape{0n}],
        Session.Battling{persistent, battle}, replay_species(),
        replay_moves()), 4n)
    case _: False{}

def accepted_escape(result: Maybe<Session.WorldSession>) -> Bool:
  match result:
    case Some{Session.Battling{persistent, battle}}:
      battle_command_count(Replay.run([Commands.PlayBattleEscape{0n}],
        Session.Battling{persistent, battle}, replay_species(), replay_moves()), 1n)
    case _: False{}

def authored_move_trace(result: Replay.TracedReplay) -> Bool:
  match result:
    case Replay.TracedReplay{Replay.Replayed{session, 1n},
        [Replay.TracePoint{0n, pre_tick, post_tick, True{}}]}: True{}
    case _: False{}

def accepted_authored_move(result: Maybe<Session.WorldSession>) -> Bool:
  match result:
    case Some{Session.Battling{persistent, battle}}:
      authored_move_trace(Replay.run_traced(
        [Commands.PlayBattleMove{0n, 1n, 1n}],
        Session.Battling{persistent, battle}, replay_species(), replay_moves()))
    case _: False{}

def nonzero_was_rejected(result: Replay.ReplayResult) -> Bool:
  match result:
    case Replay.ReplayRejected{Session.Battling{persistent, battle}, 0n}:
      True{}
    case _: False{}

def rejects_nonzero_battle_actor(result: Maybe<Session.WorldSession>) -> Bool:
  match result:
    case Some{Session.Battling{persistent, battle}}:
      nonzero_was_rejected(Replay.run([Commands.PlayBattleWait{1n}],
        Session.Battling{persistent, battle}, replay_species(), replay_moves()))
    case _: False{}

def stops_with_world_command(result: Replay.ReplayResult) -> Bool:
  match result:
    case Replay.ReplayStopped{session, 0n,
        [Commands.PlayMove{input}]}: True{}
    case _: False{}

def main() -> Bool:
  Bool.and(stops_with_world_command(Replay.run(
    [Commands.PlayMove{Geometry.Input{Geometry.Coord{False{}, 0},
      Geometry.Coord{False{}, 0}, False{}, False{}}}], initial(),
      replay_species(), replay_moves())),
    Bool.and(rejects_battle_command_outside_battle(Replay.run(
      [Commands.PlayBattleWait{0n}], initial(), replay_species(),
      replay_moves())),
      Bool.and(accepted_advance(encounter_battle()),
        Bool.and(accepted_wait_after_advance(encounter_battle()),
          Bool.and(accepted_escape(encounter_battle()),
            Bool.and(accepted_authored_move(encounter_battle()),
            Bool.and(accepted_second_escape(encounter_battle()),
              rejects_nonzero_battle_actor(encounter_battle()))))))))
