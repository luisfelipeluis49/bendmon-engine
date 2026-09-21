import Base
import ../../engine/battle/model.bend as Model
import ../../engine/battle/rng.bend as Rng
import ../../engine/battle/sources.bend as Sources
import ../../engine/battle/combat_math.bend as Math
import ../../engine/battle/runtime.bend as Runtime

def reservation() -> Runtime.SourceReservation:
  Runtime.SourceReservation{Model.ActorId{0n}, Math.MoveId{7n}, Model.ActorId{1n}}

def profile() -> Runtime.CombatProfile:
  Runtime.CombatProfile{Math.AlwaysHit{}, Math.StageNeutral{}, Math.StageNeutral{},
    100, 50, 100, 100, 1875}

def action_code(result: Runtime.ActionResult) -> Nat:
  match result:
    case Runtime.ActionCommitted{rng,
        Runtime.RuntimeHit{Model.ActorId{0n}, Model.ActorId{1n}, 100, True{}}}:
      1n
    case _:
      0n

def escape_code(result: Runtime.EscapeResult) -> Nat:
  match result:
    case Runtime.EscapeSucceeded{rng}:
      1n
    case _:
      0n

def fizzle_code(result: Runtime.ActionResult) -> Nat:
  match result:
    case Runtime.ActionFizzled{Rng.RngState{1, 2, 3, 4},
        Runtime.RuntimeFizzle{Model.ActorId{0n}, Model.ActorId{1n}}}:
      1n
    case _:
      0n

def cancel_code(result: Runtime.ActionResult) -> Nat:
  match result:
    case Runtime.ActionFault{Rng.RngState{0, 0, 0, 0},
        Rng.RngInvalidState{Rng.RngState{0, 0, 0, 0}}}:
      1n
    case _:
      0n

def unavailable_code(result: Runtime.EscapeResult) -> Nat:
  match result:
    case Runtime.EscapeUnavailable{Rng.RngState{1, 2, 3, 4}, 0}:
      1n
    case _:
      0n

def actor(id: Nat, side: Model.Side, phase: Model.Phase) -> Model.Actor:
  Model.Actor{Model.ActorId{id}, side, 10n, 100n, phase, 0}

def runtime_submit_code(result: Runtime.RuntimeBattle) -> Nat:
  match result:
    case Runtime.RuntimeAdvanced{Model.BattleState{60, 60, actors, Nil{}, 2n,
        Model.AwaitingCommands{}}, emitted}:
      1n
    case _:
      0n

def runtime_submit_test() -> Runtime.RuntimeBattle:
  Runtime.submit(8n,
    Model.BattleState{0, 60,
      [actor(0n, Model.Player{}, Model.Ready{}),
       actor(1n, Model.Enemy{}, Model.Ready{})], Nil{}, 0n,
      Model.AwaitingCommands{}},
    [Model.BattleWait{Model.ActorId{0n}}, Model.BattleWait{Model.ActorId{1n}}])

def runtime_state() -> Runtime.RuntimeState:
  Runtime.RuntimeState{
    Model.BattleState{0, 60,
      [actor(0n, Model.Player{}, Model.Ready{}),
       actor(1n, Model.Enemy{}, Model.Ready{})], Nil{}, 0n,
      Model.AwaitingCommands{}},
    Rng.RngState{1, 2, 3, 4}, Runtime.WildEncounter{}, 0,
    [Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{7n}, 0, False{}}],
    Nil{}, Nil{},
    [Runtime.DefenderSnapshot{Model.ActorId{1n}, profile()}]}

def runtime_reject_code(result: Runtime.RuntimeSubmitResult) -> Nat:
  match result:
    case Runtime.RuntimeSubmitRejected{Runtime.RuntimeState{
        Model.BattleState{0, 60, actors, Nil{}, 0n,
          Model.AwaitingCommands{}}, Rng.RngState{1, 2, 3, 4},
        Runtime.WildEncounter{}, 0,
        Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{7n}, 0, False{}}
          <> Nil{}, Nil{}, Nil{}, defenders},
        Model.SourceReserved{Model.ActorId{0n}} <> Nil{}}:
      1n
    case _:
      0n

def runtime_reject_test() -> Nat:
  runtime_reject_code(Runtime.runtime_submit(8n, runtime_state(),
    [Runtime.RuntimeWait{Model.ActorId{0n}},
     Runtime.RuntimeWait{Model.ActorId{0n}}]))

def runtime_move_code(result: Runtime.RuntimeSubmitResult) -> Nat:
  match result:
    case Runtime.RuntimeAccepted{Runtime.RuntimeState{
        Model.BattleState{0, 60, actors, events, 2n, Model.Advancing{}}, rng,
        Runtime.WildEncounter{}, 0, sources,
        Runtime.QueuedMove{0n,
          Runtime.SourceReservation{Model.ActorId{0n}, Math.MoveId{7n},
            Model.ActorId{1n}}, attacker} <> Nil{}, trapped, defenders}, emitted}:
      1n
    case _:
      0n

def runtime_move_test() -> Nat:
  runtime_move_code(Runtime.runtime_submit(8n, runtime_state(),
    [Runtime.RuntimeMove{Model.ActorId{0n}, Model.ActorId{1n}, Math.MoveId{7n},
      0, 30, 60, 0n, 0n, profile()},
     Runtime.RuntimeWait{Model.ActorId{1n}}]))

def runtime_move_run_code(result: Runtime.RuntimeRunResult) -> Nat:
  match result:
    case Runtime.RuntimeRunTerminal{Runtime.RuntimeState{
        Model.BattleState{0, 60, actors, Nil{}, sequence, Model.Victory{}}, rng,
        encounter, failed,
        Sources.MoveSource{owner, move, 60, False{}} <> Nil{}, Nil{}, trapped,
        defenders}, emitted,
        Runtime.RuntimeHit{Model.ActorId{0n}, Model.ActorId{1n}, 100, True{}}
          <> Nil{}}:
      1n
    case _:
      0n

def accepted_state(result: Runtime.RuntimeSubmitResult) -> Runtime.RuntimeState:
  match result:
    case Runtime.RuntimeAccepted{state, emitted}:
      state
    case Runtime.RuntimeSubmitRejected{state, diagnostics}:
      state

def runtime_move_run_test() -> Nat:
  runtime_move_run_code(Runtime.runtime_run(16n,
    accepted_state(Runtime.runtime_submit(8n, runtime_state(),
      [Runtime.RuntimeMove{Model.ActorId{0n}, Model.ActorId{1n},
        Math.MoveId{7n}, 0, 30, 60, 0n, 0n, profile()},
       Runtime.RuntimeWait{Model.ActorId{1n}}]))))

def switch_state() -> Runtime.RuntimeState:
  Runtime.RuntimeState{
    Model.BattleState{0, 60,
      [actor(0n, Model.Player{}, Model.Ready{}),
       actor(2n, Model.Player{}, Model.Benched{}),
       actor(1n, Model.Enemy{}, Model.Ready{})], Nil{}, 0n,
      Model.AwaitingCommands{}},
    Rng.RngState{1, 2, 3, 4}, Runtime.WildEncounter{}, 0, Nil{}, Nil{}, Nil{},
    [Runtime.DefenderSnapshot{Model.ActorId{1n}, profile()}]}

def switch_run_code(result: Runtime.RuntimeRunResult) -> Nat:
  match result:
    case Runtime.RuntimeRunBoundary{Runtime.RuntimeState{
        Model.BattleState{30, 60,
          Model.Actor{Model.ActorId{0n}, side0, hp0, speed0, Model.Benched{}, cd0}
            <> Model.Actor{Model.ActorId{2n}, side2, hp2, speed2,
              Model.Ready{}, cd2} <> rest,
          events, sequence, Model.AwaitingCommands{}}, rng, encounter, failed,
        sources, Nil{}, trapped, defenders}, emitted, combat}:
      1n
    case _:
      0n

def switch_run_test() -> Nat:
  switch_run_code(Runtime.runtime_run(16n,
    accepted_state(Runtime.runtime_submit(8n, switch_state(),
      [Runtime.RuntimeSwitch{Model.ActorId{0n}, Model.ActorId{2n}},
       Runtime.RuntimeWait{Model.ActorId{1n}}]))))

def escape_run_code(result: Runtime.RuntimeRunResult) -> Nat:
  match result:
    case Runtime.RuntimeRunTerminal{Runtime.RuntimeState{
        Model.BattleState{0, 60, actors, Nil{}, sequence, Model.Escaped{}}, rng,
        encounter, failed, sources, Nil{}, trapped, defenders}, emitted, combat}:
      1n
    case _:
      0n

def escape_run_test() -> Nat:
  escape_run_code(Runtime.runtime_run(16n,
    accepted_state(Runtime.runtime_submit(8n, runtime_state(),
      [Runtime.RuntimeEscape{Model.ActorId{0n}},
       Runtime.RuntimeWait{Model.ActorId{1n}}]))))

def escape_failure_state() -> Runtime.RuntimeState:
  Runtime.RuntimeState{
    Model.BattleState{0, 60,
      [Model.Actor{Model.ActorId{0n}, Model.Player{}, 10n, 1n,
         Model.Ready{}, 0},
       Model.Actor{Model.ActorId{1n}, Model.Enemy{}, 10n, 9999n,
         Model.Ready{}, 0}], Nil{}, 0n, Model.AwaitingCommands{}},
    Rng.RngState{1, 2, 3, 4}, Runtime.WildEncounter{}, 0, Nil{}, Nil{}, Nil{},
    [Runtime.DefenderSnapshot{Model.ActorId{1n}, profile()}]}

def escape_failure_code(result: Runtime.RuntimeRunResult) -> Nat:
  match result:
    case Runtime.RuntimeRunBoundary{Runtime.RuntimeState{
        Model.BattleState{30, 60, actors, events, sequence,
          Model.AwaitingCommands{}}, Rng.RngState{7, 0, 1026, 12288},
        Runtime.WildEncounter{}, 1, sources, Nil{}, trapped, defenders},
        emitted, Nil{}}:
      1n
    case _:
      0n

def escape_failure_test() -> Nat:
  escape_failure_code(Runtime.runtime_run(16n,
    accepted_state(Runtime.runtime_submit(8n, escape_failure_state(),
      [Runtime.RuntimeEscape{Model.ActorId{0n}},
       Runtime.RuntimeWait{Model.ActorId{1n}}]))))

def with_defender(
  state: Runtime.RuntimeState, defender: Runtime.CombatProfile
) -> Runtime.RuntimeState:
  match state:
    case Runtime.RuntimeState{battle, rng, encounter, failed, sources,
        reservations, trapped, old_defenders}:
      Runtime.RuntimeState{battle, rng, encounter, failed, sources,
        reservations, trapped,
        [Runtime.DefenderSnapshot{Model.ActorId{1n}, defender}]}

def no_damage_run_code(result: Runtime.RuntimeRunResult) -> Nat:
  match result:
    case Runtime.RuntimeRunBoundary{state, emitted,
        Runtime.RuntimeNoDamage{Model.ActorId{0n}, Model.ActorId{1n}, True{}}
          <> Nil{}}:
      1n
    case _:
      0n

def current_defender_test() -> Nat:
  +accepted = accepted_state(Runtime.runtime_submit(8n, runtime_state(),
    [Runtime.RuntimeMove{Model.ActorId{0n}, Model.ActorId{1n}, Math.MoveId{7n},
      0, 30, 60, 0n, 0n, profile()},
     Runtime.RuntimeWait{Model.ActorId{1n}}]))
  +tough = {Runtime.CombatProfile{Math.AlwaysHit{}, Math.StageNeutral{},
    Math.StageNeutral{}, 100, 50, 100, 9999, 1875} : Runtime.CombatProfile}
  no_damage_run_code(Runtime.runtime_run(16n, with_defender(accepted, tough)))

def trapped_state() -> Runtime.RuntimeState:
  Runtime.RuntimeState{
    Model.BattleState{0, 60,
      [actor(0n, Model.Player{}, Model.Ready{}),
       actor(2n, Model.Player{}, Model.Benched{}),
       actor(1n, Model.Enemy{}, Model.Ready{})], Nil{}, 0n,
      Model.AwaitingCommands{}},
    Rng.RngState{1, 2, 3, 4}, Runtime.WildEncounter{}, 0, Nil{}, Nil{},
    [Model.ActorId{0n}],
    [Runtime.DefenderSnapshot{Model.ActorId{1n}, profile()}]}

def trapped_reject_code(result: Runtime.RuntimeSubmitResult) -> Nat:
  match result:
    case Runtime.RuntimeSubmitRejected{state,
        Model.SwitchInvalid{Model.ActorId{0n}, Model.ActorId{2n}} <> Nil{}}:
      1n
    case _:
      0n

def trapped_reject_test() -> Nat:
  trapped_reject_code(Runtime.runtime_submit(8n, trapped_state(),
    [Runtime.RuntimeSwitch{Model.ActorId{0n}, Model.ActorId{2n}},
     Runtime.RuntimeWait{Model.ActorId{1n}}]))

def with_encounter(
  state: Runtime.RuntimeState, encounter: Runtime.EncounterKind
) -> Runtime.RuntimeState:
  match state:
    case Runtime.RuntimeState{battle, rng, old_encounter, failed, sources,
        reservations, trapped, defenders}:
      Runtime.RuntimeState{battle, rng, encounter, failed, sources,
        reservations, trapped, defenders}

def unavailable_submit_code(result: Runtime.RuntimeSubmitResult) -> Nat:
  match result:
    case Runtime.RuntimeSubmitRejected{Runtime.RuntimeState{battle,
        Rng.RngState{1, 2, 3, 4}, encounter, 0, sources, Nil{}, trapped,
        defenders}, Model.EscapeUnavailable{Model.ActorId{0n}} <> Nil{}}:
      1n
    case _:
      0n

def unavailable_submit_test(kind: Runtime.EncounterKind) -> Nat:
  unavailable_submit_code(Runtime.runtime_submit(8n,
    with_encounter(runtime_state(), kind),
    [Runtime.RuntimeEscape{Model.ActorId{0n}},
     Runtime.RuntimeWait{Model.ActorId{1n}}]))

def zero_rng_from(state: Runtime.RuntimeState) -> Runtime.RuntimeState:
  match state:
    case Runtime.RuntimeState{battle, rng, encounter, failed, sources,
        reservations, trapped, defenders}:
      Runtime.RuntimeState{battle, Rng.RngState{0, 0, 0, 0}, encounter,
        failed, sources, reservations, trapped, defenders}

def zero_rng_state() -> Runtime.RuntimeState:
  zero_rng_from(runtime_state())

def rng_fault_code(result: Runtime.RuntimeRunResult) -> Nat:
  match result:
    case Runtime.RuntimeRunFault{Runtime.RuntimeState{
        Model.BattleState{0, 60,
          Model.Actor{Model.ActorId{0n}, Model.Player{}, 10n, 100n,
            Model.Windup{0}, 0} <>
          Model.Actor{Model.ActorId{1n}, Model.Enemy{}, 10n, 100n,
            Model.Recovery{60}, 0} <> Nil{},
          events, 2n, Model.Advancing{}}, Rng.RngState{0, 0, 0, 0},
        Runtime.WildEncounter{}, 0,
        Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{7n}, 0, True{}}
          <> Nil{},
        Runtime.QueuedMove{0n, Runtime.SourceReservation{
          Model.ActorId{0n}, Math.MoveId{7n}, Model.ActorId{1n}}, attacker}
          <> Nil{}, trapped, defenders},
        Some{Rng.RngInvalidState{Rng.RngState{0, 0, 0, 0}}}}:
      1n
    case _:
      0n

def rng_fault_test() -> Nat:
  rng_fault_code(Runtime.runtime_run(8n,
    accepted_state(Runtime.runtime_submit(8n, zero_rng_state(),
      [Runtime.RuntimeMove{Model.ActorId{0n}, Model.ActorId{1n},
        Math.MoveId{7n}, 0, 30, 60, 0n, 0n, profile()},
       Runtime.RuntimeWait{Model.ActorId{1n}}]))))

def dual_source_state() -> Runtime.RuntimeState:
  Runtime.RuntimeState{
    Model.BattleState{0, 60,
      [actor(0n, Model.Player{}, Model.Ready{}),
       actor(1n, Model.Enemy{}, Model.Ready{})], Nil{}, 0n,
      Model.AwaitingCommands{}},
    Rng.RngState{1, 2, 3, 4}, Runtime.WildEncounter{}, 0,
    [Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{7n}, 0, False{}},
     Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{8n}, 0, False{}}],
    Nil{}, Nil{},
    [Runtime.DefenderSnapshot{Model.ActorId{1n},
      Runtime.CombatProfile{Math.AlwaysHit{}, Math.StageNeutral{},
        Math.StageNeutral{}, 100, 50, 100, 9999, 1875}}]}

def independent_source_code(result: Runtime.RuntimeSubmitResult) -> Nat:
  match result:
    case Runtime.RuntimeAccepted{Runtime.RuntimeState{
        Model.BattleState{30, 60, actors, events, 4n, Model.Advancing{}}, rng,
        Runtime.WildEncounter{}, 0,
        Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{7n}, 60, False{}} <>
        Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{8n}, 0, True{}}
          <> Nil{}, reservations, trapped, defenders}, emitted}:
      1n
    case _:
      0n

def boundary_state(result: Runtime.RuntimeRunResult) -> Runtime.RuntimeState:
  match result:
    case Runtime.RuntimeRunBoundary{state, emitted, combat}:
      state
    case Runtime.RuntimeRunTerminal{state, emitted, combat}:
      state
    case Runtime.RuntimeRunStalled{state, emitted, combat}:
      state
    case Runtime.RuntimeRunYielded{state, emitted, combat}:
      state
    case Runtime.RuntimeRunFault{state, reason}:
      state

def typed_exhaustion_code(result: Runtime.RuntimeRunResult) -> Nat:
  match result:
    case Runtime.RuntimeRunFault{state,
        Some{Rng.RngSamplingExhausted{Rng.RngState{1, 2, 3, 4}, 64n}}}:
      1n
    case _:
      0n

def typed_exhaustion_test() -> Nat:
  typed_exhaustion_code(Runtime.runtime_run_result(
    Runtime.RuntimeCursorFault{runtime_state(),
      Some{Rng.RngSamplingExhausted{Rng.RngState{1, 2, 3, 4}, 64n}}}))

def independent_source_test() -> Nat:
  +after_first = boundary_state(Runtime.runtime_run(16n,
    accepted_state(Runtime.runtime_submit(8n, dual_source_state(),
      [Runtime.RuntimeMove{Model.ActorId{0n}, Model.ActorId{1n},
        Math.MoveId{7n}, 0, 30, 60, 0n, 0n, profile()},
       Runtime.RuntimeWait{Model.ActorId{1n}}]))))
  independent_source_code(Runtime.runtime_submit(8n, after_first,
    [Runtime.RuntimeMove{Model.ActorId{0n}, Model.ActorId{1n},
      Math.MoveId{8n}, 0, 30, 60, 0n, 0n, profile()}]))

def main() -> List<&2, Nat>:
  +seed = {Rng.RngState{1, 2, 3, 4} : Rng.RngState}
  +bad_profile = {Runtime.CombatProfile{Math.AlwaysHit{}, Math.StageNeutral{},
    Math.StageNeutral{}, 100, 50, 100, 0, 0} : Runtime.CombatProfile}
  [action_code(Runtime.resolve_action(
      Runtime.ActionSnapshot{reservation(), profile(), seed})),
   fizzle_code(Runtime.resolve_action(
      Runtime.ActionSnapshot{reservation(), bad_profile, seed})),
   cancel_code(Runtime.resolve_action(
      Runtime.ActionSnapshot{reservation(), profile(), Rng.RngState{0, 0, 0, 0}})),
   escape_code(Runtime.escape_attempt(Runtime.WildEncounter{}, seed, 0, 9999, 1)),
   unavailable_code(Runtime.escape_attempt(Runtime.TrainerEncounter{}, seed, 0,
      9999, 1)),
   runtime_submit_code(runtime_submit_test()),
   runtime_reject_test(),
   runtime_move_test(), runtime_move_run_test(), switch_run_test(),
   escape_run_test(), escape_failure_test(), current_defender_test(),
   trapped_reject_test(),
   unavailable_submit_test(Runtime.TrainerEncounter{}),
   unavailable_submit_test(Runtime.BossEncounter{}),
   unavailable_submit_test(Runtime.LockedEncounter{}),
   rng_fault_test(), independent_source_test(), typed_exhaustion_test()]

#| [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
