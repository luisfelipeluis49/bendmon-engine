import Base
import ./catalog.bend as Catalog
import ./commands.bend as Commands
import ./geometry.bend as Geometry
import ./events.bend as Events
import ./world_session.bend as Session

# Replay inputs are the deterministic world boundary. Host I/O and battle
# choices stay outside this fold; battle replay is owned by M7.
type Input is Data:
  ReplayCommand{value: Commands.Command}
  ReplayMove{value: Geometry.Input}
  ReplayEvent{value: Events.Input}

type ReplayResult is Data:
  ReplayComplete{session: Session.WorldSession, steps: Nat}
  ReplayRejected{session: Session.WorldSession, index: Nat}

def apply(input: Input, catalog: Catalog.Catalog,
  +session: Session.WorldSession) -> Session.SessionResult:
  match input:
    case ReplayCommand{value}: Session.command(catalog, session, value)
    case ReplayMove{value}: Session.move(catalog, session, value)
    case ReplayEvent{value}: Session.event_step(session, value)

def result_session(result: Session.SessionResult) -> Session.WorldSession:
  match result:
    case Session.Advanced{state}: state
    case Session.Rejected{state}: state
    case Session.EncounterReady{state, species, level}: state
    case Session.EncounterPending{state, encounter_id}: state
    case Session.EventAborted{state, diagnostic}: state
    case Session.BattleAdvanced{state, status, events}: state
    case Session.BattleReturned{state, status, events, captures}: state
    case Session.BattleChoice{state}: state

def fold(inputs: List<&2, Input>, result: Session.SessionResult,
  index: Nat, +catalog: Catalog.Catalog) -> ReplayResult:
  match inputs result:
    case Nil{} Session.Rejected{state}:
      ReplayRejected{state, Nat.sub(index, 1n)}
    case Nil{} Session.EventAborted{state, diagnostic}:
      ReplayRejected{state, Nat.sub(index, 1n)}
    case Nil{} value: ReplayComplete{result_session(value), index}
    case input <> rest Session.Rejected{state}:
      ReplayRejected{state, Nat.sub(index, 1n)}
    case input <> rest Session.EventAborted{state, diagnostic}:
      ReplayRejected{state, Nat.sub(index, 1n)}
    case input <> rest value:
      fold(rest, apply(input, catalog, result_session(value)),
        (index + 1n : Nat), catalog)

def replay(inputs: List<&2, Input>, catalog: Catalog.Catalog,
  +initial: Session.WorldSession) -> ReplayResult:
  fold(inputs, Session.Advanced{initial}, 0n, catalog)
