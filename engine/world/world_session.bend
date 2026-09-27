import Base
import ./event_bridge.bend as EventBridge
import ./commands.bend as Commands
import ./exploration.bend as Exploration
import ./catalog.bend as Catalog
import ./geometry.bend as Geometry
import ./encounter_handoff.bend as Handoff
import ./battle_bridge.bend as BattleBridge
import ./events.bend as Events
import ./presentation_cues.bend as Presentation
import ../m7/playable.bend as Playable
import ../battle/runtime.bend as Runtime
import ../battle/model.bend as Battle
import ../m7/battle.bend as M7
import ../m7/session.bend as Session

# WorldSession is the public exploration-boundary constructor retained for
# callers. Battling stores only the persistent event world and battle token;
# the battle bridge already owns its exploration snapshot.
type WorldSession is Data:
  WorldSession{world: EventBridge.State, battle: Maybe<&2, Unit>}
  Battling{persistent: Events.World, battle: BattleBridge.State}

type SessionResult is Data:
  Advanced{state: WorldSession}
  Rejected{state: WorldSession}
  EncounterReady{state: WorldSession, species: Nat, level: Nat}
  EncounterPending{state: WorldSession, encounter_id: Nat}
  EventAborted{state: WorldSession, diagnostic: Events.Diagnostic}
  BattleAdvanced{state: WorldSession, status: Session.StepStatus,
    events: List<&2, Battle.TransitionEvent>}
  BattleReturned{state: WorldSession,
    status: Session.StepStatus, events: List<&2, Battle.TransitionEvent>,
    captures: List<&2, M7.CaptureEvent>}
  BattleChoice{state: WorldSession}

type PresentedResult is Data:
  PresentedResult{result: SessionResult, cues: List<&2, Presentation.Cue>}

type PreparedSession is Data:
  PreparedSession{world: EventBridge.State, encounter: Handoff.Prepared}

type PrepareResult is Data:
  Prepared{value: PreparedSession, species: Nat, level: Nat}
  PrepareRejected{state: WorldSession}

def has_event(world: EventBridge.State) -> Bool:
  match world:
    case EventBridge.State{exploration, persistent, active}:
      match active:
        case None{}: False{}
        case Some{machine}: True{}

def command_event(result: EventBridge.EventBridgeResult,
  ordinal: Nat) -> PresentedResult:
  match result:
    case EventBridge.EventRejected{state}:
      PresentedResult{Rejected{WorldSession{state, None{}}}, []}
    case EventBridge.EventCommitted{state, events}:
      PresentedResult{Advanced{WorldSession{state, None{}}},
        Presentation.ordered_outputs(events, ordinal)}
    case EventBridge.EventProgress{state}:
      PresentedResult{Advanced{WorldSession{state, None{}}}, []}
    case EventBridge.EventYielded{state, kind}:
      PresentedResult{Advanced{WorldSession{state, None{}}},
        Presentation.yield_cues(kind, ordinal, 0n)}
    case EventBridge.EventAborted{state, diagnostic}:
      PresentedResult{EventAborted{WorldSession{state, None{}}, diagnostic}, []}

def command_route(result: Commands.CommandResult, ordinal: Nat) -> PresentedResult:
  match result:
    case Commands.Applied{state}:
      PresentedResult{Advanced{WorldSession{state, None{}}}, []}
    case Commands.EventStarted{result}: command_event(result, ordinal)
    case Commands.Rejected{state}:
      PresentedResult{Rejected{WorldSession{state, None{}}}, []}

def command_ready(ready: Bool, catalog: Catalog.Catalog, +old: WorldSession,
  command: Commands.Command, ordinal: Nat) -> PresentedResult:
  match ready:
    case False{}: PresentedResult{Rejected{old}, []}
    case True{}:
      match old:
        case WorldSession{world, None{}}:
          command_route(Commands.run(command, catalog, world), ordinal)
        case _: PresentedResult{Rejected{old}, []}

def command_presented(catalog: Catalog.Catalog, +old: WorldSession,
  command: Commands.Command, ordinal: Nat) -> PresentedResult:
  match old:
    case WorldSession{world, None{}}:
      command_ready(Bool.not(has_event(world)), catalog, old, command, ordinal)
    case _: PresentedResult{Rejected{old}, []}

def presented_session(result: PresentedResult) -> SessionResult:
  match result:
    case PresentedResult{result, cues}: result

def command(catalog: Catalog.Catalog, +old: WorldSession,
  command: Commands.Command) -> SessionResult:
  presented_session(command_presented(catalog, old, command, 0n))

def replace_world_exploration(old: EventBridge.State,
  next: Exploration.State) -> EventBridge.State:
  match old:
    case EventBridge.State{prior, persistent, active}:
      EventBridge.State{next, persistent, None{}}

def move_route(result: Exploration.StepResult, old: WorldSession) -> SessionResult:
  match result old:
    case Exploration.Moved{state} WorldSession{world, None{}}:
      Advanced{WorldSession{replace_world_exploration(world, state), None{}}}
    case Exploration.EncounterReached{state, encounter_id}
         WorldSession{world, None{}}:
      EncounterPending{WorldSession{replace_world_exploration(world, state),
        None{}}, encounter_id}
    case _ _: Rejected{old}

def move_ready(ready: Bool, catalog: Catalog.Catalog, +old: WorldSession,
  input: Geometry.Input) -> SessionResult:
  match ready:
    case False{}: Rejected{old}
    case True{}:
      match old:
        case WorldSession{EventBridge.State{exploration, persistent, None{}}, None{}}:
          move_route(Exploration.move(catalog, exploration, input), old)
        case _: Rejected{old}

def move(catalog: Catalog.Catalog, +old: WorldSession,
  input: Geometry.Input) -> SessionResult:
  match old:
    case WorldSession{world, None{}}:
      move_ready(Bool.not(has_event(world)), catalog, old, input)
    case _: Rejected{old}

def event_step_route(result: EventBridge.EventBridgeResult,
  ordinal: Nat) -> PresentedResult:
  command_event(result, ordinal)

def event_step_presented(+old: WorldSession, input: Events.Input,
  ordinal: Nat) -> PresentedResult:
  match old:
    case WorldSession{world, None{}}:
      event_step_route(EventBridge.step(world, input), ordinal)
    case _: PresentedResult{Rejected{old}, []}

def event_step(+old: WorldSession, input: Events.Input) -> SessionResult:
  presented_session(event_step_presented(old, input, 0n))

def persistent_world(old: EventBridge.State) -> Events.World:
  match old:
    case EventBridge.State{exploration, persistent, active}: persistent

def handoff_result(result: Handoff.HandoffResult,
  old: EventBridge.State) -> SessionResult:
  match result:
    case Handoff.HandoffRejected{}: Rejected{WorldSession{old, None{}}}
    case Handoff.HandoffStarted{state, species_id, level}:
      EncounterReady{Battling{persistent_world(old), state}, species_id, level}

def prepare_handoff(result: Handoff.PrepareResult,
  playable: Playable.PlayableSession, world: EventBridge.State) -> SessionResult:
  match result:
    case Handoff.PrepareRejected{}: Rejected{WorldSession{world, None{}}}
    case Handoff.EncounterPrepared{value}:
      handoff_result(Handoff.start(value, playable), world)

def encounter_world(tables: List<&2, Handoff.EncounterTable>,
  +world: EventBridge.State, playable: Playable.PlayableSession) -> SessionResult:
  match world:
    case EventBridge.State{exploration, persistent, None{}}:
      prepare_handoff(Handoff.prepare(exploration, tables), playable, world)
    case _: Rejected{WorldSession{world, None{}}}

def encounter(tables: List<&2, Handoff.EncounterTable>,
  +old: WorldSession, battle: Maybe<Playable.PlayableSession>) -> SessionResult:
  match old battle:
    case WorldSession{world, None{}} Some{playable}:
      encounter_world(tables, world, playable)
    case _ _: Rejected{old}

def prepared(result: Handoff.PrepareResult,
  world: EventBridge.State) -> PrepareResult:
  match result:
    case Handoff.PrepareRejected{}: PrepareRejected{WorldSession{world, None{}}}
    case Handoff.EncounterPrepared{+value}:
      match value:
        case Handoff.Prepared{selected_world, encounter_id,
            species_id, level, source_rng}:
          Prepared{PreparedSession{world, value}, species_id, level}

# Selection and M7 construction are separate host phases: prepare returns the
# selected species, and begin validates the host-built playable snapshot.
def prepare_encounter(tables: List<&2, Handoff.EncounterTable>,
  +old: WorldSession) -> PrepareResult:
  match old:
    case WorldSession{EventBridge.State{+exploration, persistent, None{}}, None{}}:
      prepared(Handoff.prepare(exploration, tables),
        EventBridge.State{exploration, persistent, None{}})
    case _: PrepareRejected{old}

def begin_encounter(prepared_session: PreparedSession,
  playable: Playable.PlayableSession) -> SessionResult:
  match prepared_session:
    case PreparedSession{world, encounter}:
      handoff_result(Handoff.start(encounter, playable), world)

def battle_step_route(result: BattleBridge.StepResult,
  persistent: Events.World) -> SessionResult:
  match result:
    case BattleBridge.Advanced{state, status, events, captures}:
      BattleAdvanced{Battling{persistent, state}, status, events}
    case BattleBridge.Returned{state, status, events, captures}:
      BattleReturned{Battling{persistent, state}, status, events, captures}
    case BattleBridge.AwaitingChoice{state}: BattleChoice{Battling{persistent, state}}
    case BattleBridge.MoveOffered{state, individual, level, move}:
      BattleChoice{Battling{persistent, state}}
    case BattleBridge.EvolutionOffered{state, individual, rule_id, target}:
      BattleChoice{Battling{persistent, state}}
    case BattleBridge.StepRejected{state}: Rejected{Battling{persistent, state}}

def advance_battle(+old: WorldSession) -> SessionResult:
  match old:
    case Battling{persistent, battle}:
      battle_step_route(BattleBridge.step(battle), persistent)
    case _: Rejected{old}

def returned_playable(session: WorldSession) -> Maybe<Playable.PlayableSession>:
  match session:
    case Battling{persistent, BattleBridge.State{world, +playable, True{}}}:
      Some{playable}
    case _: None{}

def returned_exploration(battle: BattleBridge.State) -> Exploration.State:
  match battle:
    case BattleBridge.State{world, playable, returned}: world

def battle_returned(battle: BattleBridge.State) -> Bool:
  match battle:
    case BattleBridge.State{world, playable, True{}}: True{}
    case _: False{}

def resume_returned(done: Bool, persistent: Events.World,
  +battle: BattleBridge.State) -> WorldSession:
  match done:
    case False{}: Battling{persistent, battle}
    case True{}:
      WorldSession{EventBridge.State{returned_exploration(battle),
        persistent, None{}}, None{}}

def resume_world(session: WorldSession) -> WorldSession:
  match session:
    case Battling{persistent, +battle}:
      resume_returned(battle_returned(battle), persistent, battle)
    case other: other

def submit_battle_route(result: BattleBridge.SubmitResult,
  persistent: Events.World) -> SessionResult:
  match result:
    case BattleBridge.Submitted{state, events}: Advanced{Battling{persistent, state}}
    case BattleBridge.SubmitRejected{state}: Rejected{Battling{persistent, state}}

def submit_battle(+old: WorldSession, fuel: Nat,
  commands: List<&2, Runtime.RuntimeCommand>) -> SessionResult:
  match old:
    case Battling{persistent, battle}:
      submit_battle_route(BattleBridge.submit(battle, fuel, commands), persistent)
    case _: Rejected{old}

def choose_move_route(result: BattleBridge.StepResult,
  persistent: Events.World) -> SessionResult:
  battle_step_route(result, persistent)

def choose_move(+old: WorldSession, individual: Nat, move: U32, accept: Bool,
  replacement: Maybe<&2, U32>) -> SessionResult:
  match old:
    case Battling{persistent, battle}:
      choose_move_route(BattleBridge.choose_move(battle, individual, move,
        accept, replacement), persistent)
    case _: Rejected{old}

def choose_evolution(+old: WorldSession, individual: Nat, rule_id: Nat,
  accept: Bool) -> SessionResult:
  match old:
    case Battling{persistent, battle}:
      battle_step_route(BattleBridge.choose_evolution(battle, individual,
        rule_id, accept), persistent)
    case _: Rejected{old}
