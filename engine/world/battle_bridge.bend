import Base
import ../battle/model.bend as Battle
import ../battle/rng.bend as Rng
import ../battle/runtime.bend as Runtime
import ../m7/playable.bend as Playable
import ../m7/session.bend as Session
import ../m7/battle.bend as M7
import ../m7/reward_bridge.bend as RewardBridge
import ./encounters.bend as Encounters
import ./exploration.bend as Exploration

# This state is the single-use handoff token. `returned` prevents a terminal
# playable snapshot from drawing a second overworld threshold.
type State is Data:
  State{world: Exploration.State, battle: Playable.PlayableSession,
    returned: Bool}

type StartResult is Data:
  Started{state: State}
  StartRejected{}

type StepResult is Data:
  Advanced{state: State, status: Session.StepStatus,
    events: List<&2, Battle.TransitionEvent>,
    captures: List<&2, M7.CaptureEvent>}
  Returned{state: State, status: Session.StepStatus,
    events: List<&2, Battle.TransitionEvent>,
    captures: List<&2, M7.CaptureEvent>}
  MoveOffered{state: State, individual: Nat, level: U32, move: U32}
  EvolutionOffered{state: State, individual: Nat, rule_id: Nat,
    target: Nat}
  AwaitingChoice{state: State}
  StepRejected{state: State}

type SubmitResult is Data:
  Submitted{state: State, events: List<&2, Battle.BattleEvent>}
  SubmitRejected{state: State}

def runtime_rng(battle: M7.State) -> Rng.RngState:
  match battle:
    case M7.State{Runtime.RuntimeState{battle, rng, encounter,
        failed_escapes, sources, reservations, trapped, defenders, effects},
        economy, roster, captured, catalog}: rng

def rng_equal(left: Rng.RngState, right: Rng.RngState) -> Bool:
  match left right:
    case Rng.RngState{la, lb, lc, ld}
         Rng.RngState{ra, rb, rc, rd}:
      Bool.and(U32.is_eq(la, ra), Bool.and(U32.is_eq(lb, rb),
        Bool.and(U32.is_eq(lc, rc), U32.is_eq(ld, rd))))

def meter_rng(meter: Encounters.Meter) -> Rng.RngState:
  match meter:
    case Encounters.Meter{region, weighted, threshold, safe, rng}: rng

def meter_with_rng(meter: Encounters.Meter,
  rng: Rng.RngState) -> Encounters.Meter:
  match meter:
    case Encounters.Meter{region, weighted, threshold, safe, prior_rng}:
      Encounters.Meter{region, weighted, threshold, safe, rng}

def playable_rng(playable: Playable.PlayableSession) -> Rng.RngState:
  match playable:
    case Playable.PlayableSession{Session.State{battle, rewards,
        enemies, owners}, learning, evolution, choices,
        evolution_choices, pending, ruleset, identity}:
      runtime_rng(battle)

def session_rng(session: Session.State) -> Rng.RngState:
  match session:
    case Session.State{battle, rewards, enemies, owners}:
      runtime_rng(battle)

def reward_encounter_matches(context: RewardBridge.Context,
  encounter_id: Nat) -> Bool:
  match context:
    case RewardBridge.Context{context_encounter, defeated, owned,
        items, economy, ledger}:
      Nat.is_eq(encounter_id, context_encounter)

def session_matches(+session: Session.State, encounter_id: Nat) -> Bool:
  match session:
    case Session.State{m7, rewards, +enemies, +owners}:
      Bool.and(reward_encounter_matches(rewards, encounter_id),
        Bool.and(Session.session_valid(session),
          Rng.valid_state(runtime_rng(m7))))

def match_region(meter: Encounters.Meter) -> Nat:
  match meter:
    case Encounters.Meter{Some{region}, weighted, threshold, safe, rng}:
      region
    case _: 0n

def battle_identity_valid(world: Exploration.State,
  battle: Playable.PlayableSession) -> Bool:
  match world battle:
    case Exploration.State{map_id, point, +meter,
        Some{Exploration.PendingEncounter{region_id, encounter_id}}, identity}
         Playable.PlayableSession{+session,
           learning, evolution, choices, evolution_choices, pending, 7n,
           battle_identity}:
      Bool.and(session_matches(session, encounter_id),
      Bool.and(Nat.is_eq(region_id, match_region(meter)),
      Bool.and(Nat.is_eq(identity, battle_identity),
        rng_equal(meter_rng(meter), session_rng(session)))))
    case _ _: False{}

def start_valid(valid: Bool, world: Exploration.State,
  battle: Playable.PlayableSession) -> StartResult:
  match valid:
    case True{}: Started{State{world, battle, False{}}}
    case False{}: StartRejected{}

# Battle entry consumes only a pending encounter whose numeric ID and exact
# loaded content identity are also bound into a valid production M7 session.
def start(+world: Exploration.State,
  +battle: Playable.PlayableSession) -> StartResult:
  start_valid(battle_identity_valid(world, battle), world, battle)

def completed(events: List<&2, Battle.TransitionEvent>) -> Bool:
  match events:
    case Nil{}: False{}
    case Battle.BattleCompleted{status, tick} <> rest: True{}
    case _ <> rest: completed(rest)

def world_after(result: Encounters.MeterResult,
  old: Exploration.State) -> Maybe<Exploration.State>:
  match result:
    case Encounters.MeterRejected{meter}: None{}
    case Encounters.MeterReady{meter}:
      match old:
        case Exploration.State{map_id, point, prior, pending, identity}:
          Some{Exploration.State{map_id, point, meter, None{}, identity}}
    case Encounters.MeterTriggered{region, meter}: None{}

def world_meter(world: Exploration.State) -> Encounters.Meter:
  match world:
    case Exploration.State{map_id, point, meter, pending, identity}: meter

def returned_state(updated: Maybe<Exploration.State>, state: State,
  status: Session.StepStatus,
  events: List<&2, Battle.TransitionEvent>,
  captures: List<&2, M7.CaptureEvent>) -> StepResult:
  match updated:
    case None{}: StepRejected{state}
    case Some{world}:
      match state:
        case State{prior_world, battle, returned}:
          Returned{State{world, battle, True{}}, status, events, captures}

def return_to_world(+state: State,
  status: Session.StepStatus,
  events: List<&2, Battle.TransitionEvent>,
  captures: List<&2, M7.CaptureEvent>) -> StepResult:
  match state:
    case State{+world, +battle, +returned}:
      returned_state(world_after(Encounters.after_battle(
        meter_with_rng(world_meter(world), playable_rng(battle))), world),
        state, status, events, captures)

def finish_if_terminal(done: Bool, state: State,
  status: Session.StepStatus,
  events: List<&2, Battle.TransitionEvent>,
  captures: List<&2, M7.CaptureEvent>) -> StepResult:
  match done:
    case False{}: Advanced{state, status, events, captures}
    case True{}: return_to_world(state, status, events, captures)

def route_step(result: Playable.PlayableStep, state: State) -> StepResult:
  match result state:
    case Playable.PlayableAdvanced{session, status, +emitted, captures}
         State{world, prior, returned}:
      finish_if_terminal(completed(emitted), State{world, session, False{}},
        status, emitted, captures)
    case Playable.PlayableMoveOffer{individual, level, move, session}
         State{world, prior, returned}:
      MoveOffered{State{world, session, False{}}, individual, level, move}
    case Playable.PlayableEvolutionOffer{individual, rule_id, target, session}
         State{world, prior, returned}:
      EvolutionOffered{State{world, session, False{}}, individual,
        rule_id, target}
    case Playable.PlayableAwaitingChoice{session}
         State{world, prior, returned}:
      AwaitingChoice{State{world, session, False{}}}
    case Playable.PlayableRejected{session} _:
      StepRejected{state}

def step_ready(returned: Bool, +state: State) -> StepResult:
  match returned:
    case True{}: StepRejected{state}
    case False{}:
      match state:
        case State{+world, +battle, False{}}:
          route_step(Playable.step(battle), state)
        case State{world, battle, True{}}: StepRejected{state}

def step(+state: State) -> StepResult:
  match state:
    case State{+world, +battle, returned}:
      step_ready(returned, state)

def choose_move_ready(returned: Bool, +state: State, individual: Nat,
  move: U32, accept: Bool, replacement: Maybe<&2, U32>) -> StepResult:
  match returned:
    case True{}: StepRejected{state}
    case False{}:
      match state:
        case State{+world, +battle, False{}}:
          route_step(Playable.choose_move(battle, individual, move, accept,
            replacement), state)
        case State{world, battle, True{}}: StepRejected{state}

def choose_move(+state: State, individual: Nat, move: U32, accept: Bool,
  replacement: Maybe<&2, U32>) -> StepResult:
  match state:
    case State{+world, +battle, returned}:
      choose_move_ready(returned, state, individual, move, accept,
        replacement)

def choose_evolution_ready(returned: Bool, +state: State, individual: Nat,
  rule_id: Nat, accept: Bool) -> StepResult:
  match returned:
    case True{}: StepRejected{state}
    case False{}:
      match state:
        case State{+world, +battle, False{}}:
          route_step(Playable.choose_evolution(battle, individual, rule_id,
            accept), state)
        case State{world, battle, True{}}: StepRejected{state}

def choose_evolution(+state: State, individual: Nat, rule_id: Nat,
  accept: Bool) -> StepResult:
  match state:
    case State{+world, +battle, returned}:
      choose_evolution_ready(returned, state, individual, rule_id, accept)

def route_submit(result: Playable.PlayableSubmit, state: State) -> SubmitResult:
  match result state:
    case Playable.PlayableAccepted{session, emitted}
         State{world, battle, returned}:
      Submitted{State{world, session, False{}}, emitted}
    case Playable.PlayableSubmitRejected{session} _:
      SubmitRejected{state}

def submit_ready(returned: Bool, +state: State, fuel: Nat,
  commands: List<&2, Runtime.RuntimeCommand>) -> SubmitResult:
  match returned:
    case True{}: SubmitRejected{state}
    case False{}:
      match state:
        case State{+world, +battle, False{}}:
          route_submit(Playable.submit(fuel, battle, commands), state)
        case State{world, battle, True{}}: SubmitRejected{state}

def submit(+state: State, fuel: Nat,
  commands: List<&2, Runtime.RuntimeCommand>) -> SubmitResult:
  match state:
    case State{+world, +battle, returned}:
      submit_ready(returned, state, fuel, commands)
