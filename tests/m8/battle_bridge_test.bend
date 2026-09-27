import Base
import ../m7/session_learning_test.bend as LearningFixture
import ../m7/session_test.bend as BattleFixture
import ../../engine/world/battle_bridge.bend as Bridge
import ../../engine/world/exploration.bend as Exploration
import ../../engine/world/encounters.bend as Encounters
import ../../engine/world/geometry.bend as Geometry
import ../../engine/m7/playable.bend as Playable
import ../../engine/battle/rng.bend as Rng
import ../../engine/battle/runtime.bend as Runtime
import ../../engine/battle/model.bend as Battle

def world() -> Exploration.State:
  Exploration.State{0n,
    Geometry.Point{Geometry.Coord{False{}, 100},
      Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 100}},
    Encounters.Meter{Some{0n}, 0n, 100n, 0n,
      Rng.RngState{1, 2, 3, 4}},
    Some{Exploration.PendingEncounter{0n, 7n}}, 123n}

def opened() -> Maybe<Playable.PlayableSession>:
  Playable.open(LearningFixture.full_state(),
    Playable.ContentCatalog{LearningFixture.catalog(), [], 7n, 123n},
    7n, 123n)

def was_started(result: Bridge.StartResult) -> Bool:
  match result:
    case Bridge.Started{state}: True{}
    case _: False{}

def was_rejected(result: Bridge.StartResult) -> Bool:
  match result:
    case Bridge.StartRejected{}: True{}
    case _: False{}

def start_valid(result: Maybe<Playable.PlayableSession>) -> Bool:
  match result:
    case None{}: False{}
    case Some{session}:
      was_started(Bridge.start(world(), session))

def wrong_identity(result: Maybe<Playable.PlayableSession>) -> Bool:
  match result:
    case None{}: False{}
    case Some{session}:
      was_rejected(Bridge.start(Exploration.State{0n,
          Geometry.Point{Geometry.Coord{False{}, 100},
            Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 100}},
          Encounters.Meter{Some{0n}, 0n, 100n, 0n,
            Rng.RngState{1, 2, 3, 4}},
          Some{Exploration.PendingEncounter{0n, 7n}}, 124n}, session))

def step_rejected(result: Bridge.StepResult) -> Bool:
  match result:
    case Bridge.StepRejected{state}: True{}
    case _: False{}

def returned_world_ok(+state: Bridge.State) -> Bool:
  match state:
    case Bridge.State{+world, +battle, True{}}:
      step_rejected(Bridge.step(state))
    case _: False{}

def returned_once(result: Bridge.StepResult) -> Bool:
  match result:
    case Bridge.Returned{state, status, events, captures}:
      returned_world_ok(state)
    case _: False{}

def after_offer(result: Bridge.StepResult) -> Bool:
  match result:
    case Bridge.MoveOffered{state, 77n, 2, 7}:
      returned_once(Bridge.choose_move(state, 77n, 7, False{}, None{}))
    case _: False{}

def after_submit(result: Bridge.SubmitResult) -> Bool:
  match result:
    case Bridge.Submitted{state, events}:
      after_offer(Bridge.step(state))
    case _: False{}

def after_start(result: Bridge.StartResult) -> Bool:
  match result:
    case Bridge.Started{state}:
      after_submit(Bridge.submit(state, 10n,
        [BattleFixture.lethal_move(),
          Runtime.RuntimeWait{Battle.ActorId{1n}}]))
    case _: False{}

def full_round_trip(result: Maybe<Playable.PlayableSession>) -> Bool:
  match result:
    case None{}: False{}
    case Some{session}: after_start(Bridge.start(world(), session))

def main() -> List<&2, Bool>:
  [start_valid(opened()), wrong_identity(opened()), full_round_trip(opened())]
