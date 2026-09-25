import Base
import ../battle/model.bend as Battle
import ../battle/runtime.bend as Runtime
import ./battle.bend as M7Battle
import ./session.bend as Session
import ./reward_bridge.bend as Bridge
import ./rewards.bend as Rewards

# The playable M7 entry owns its immutable, validated content snapshot and
# content identity for every retry. Host callers construct it once from the
# bound m7-1 catalog and use these functions for battle commands and choices.
type ContentCatalog is Data:
  ContentCatalog{learning: List<&2, Rewards.SpeciesLearning>,
    evolution: List<&2, Bridge.EvolutionInput>,
    ruleset: Nat, content_identity: Nat}

type Pending is Data:
  NoPending{}
  PendingMove{individual: Nat, level: U32, move: U32}
  PendingEvolution{individual: Nat, rule_id: Nat, target_species: Nat}

type PlayableSession is Data:
  PlayableSession{state: Session.State,
    learning: List<&2, Rewards.SpeciesLearning>,
    evolution: List<&2, Bridge.EvolutionInput>,
    learning_choices: List<&2, Rewards.LearningChoice>,
    evolution_choices: List<&2, Bridge.EvolutionChoice>,
    pending: Pending, ruleset: Nat, content_identity: Nat}

type PlayableStep is Data:
  PlayableAdvanced{session: PlayableSession,
    status: Session.StepStatus,
    emitted: List<&2, Battle.TransitionEvent>,
    captures: List<&2, M7Battle.CaptureEvent>}
  PlayableMoveOffer{individual: Nat, level: U32, move: U32,
    session: PlayableSession}
  PlayableEvolutionOffer{individual: Nat, rule_id: Nat,
    target_species: Nat, session: PlayableSession}
  PlayableAwaitingChoice{session: PlayableSession}
  PlayableRejected{session: PlayableSession}

type PlayableSubmit is Data:
  PlayableAccepted{session: PlayableSession,
    emitted: List<&2, Battle.BattleEvent>}
  PlayableSubmitRejected{session: PlayableSession}

def open_valid(valid: Bool, state: Session.State,
  learning: List<&2, Rewards.SpeciesLearning>,
  evolution: List<&2, Bridge.EvolutionInput>,
  identity: Nat) -> Maybe<PlayableSession>:
  match valid:
    case False{}: None{}
    case True{}:
      Some{PlayableSession{state, learning, evolution, [], [], NoPending{},
        7n, identity}}

def open(+state: Session.State, catalog: ContentCatalog,
  expected_ruleset: Nat, expected_content_identity: Nat) ->
  Maybe<PlayableSession>:
  match catalog:
    case ContentCatalog{learning, evolution, +ruleset, +content_identity}:
      open_valid(Bool.and(Nat.is_eq(ruleset, 7n),
        Bool.and(Nat.is_eq(ruleset, expected_ruleset),
          Bool.and(Nat.is_eq(content_identity, expected_content_identity),
            Session.session_valid(state)))),
        state, learning, evolution, content_identity)

def with_state(old: PlayableSession, state: Session.State,
  pending: Pending,
  learning_choices: List<&2, Rewards.LearningChoice>,
  evolution_choices: List<&2, Bridge.EvolutionChoice>) -> PlayableSession:
  match old:
    case PlayableSession{prior, learning, evolution, old_learning_choices,
        old_evolution_choices, old_pending, ruleset, identity}:
      PlayableSession{state, learning, evolution, learning_choices,
        evolution_choices, pending, ruleset, identity}

def clear_choices(old: PlayableSession, state: Session.State) ->
  PlayableSession:
  with_state(old, state, NoPending{}, [], [])

def step_result(result: Session.InteractiveStepResult,
  +old: PlayableSession) -> PlayableStep:
  match result:
    case Session.InteractiveStepped{
        Session.SessionStep{status, state, emitted, captures}}:
      PlayableAdvanced{clear_choices(old, state), status, emitted, captures}
    case Session.InteractiveMoveChoice{+individual, +level, +move, state}:
      match old:
        case PlayableSession{prior, learning, evolution, learning_choices,
            evolution_choices, pending, ruleset, identity}:
          PlayableMoveOffer{individual, level, move,
            with_state(old, state, PendingMove{individual, level, move},
              learning_choices, evolution_choices)}
    case Session.InteractiveEvolutionChoice{+individual, +rule_id,
        +target_species, state}:
      match old:
        case PlayableSession{prior, learning, evolution, learning_choices,
            evolution_choices, pending, ruleset, identity}:
          PlayableEvolutionOffer{individual, rule_id, target_species,
            with_state(old, state,
              PendingEvolution{individual, rule_id, target_species},
              learning_choices, evolution_choices)}

def step_ready(+old: PlayableSession) -> PlayableStep:
  match old:
    case PlayableSession{state, learning, evolution, learning_choices,
        evolution_choices, pending, ruleset, identity}:
      step_result(Session.step_with_progression(state, learning,
        learning_choices, evolution, evolution_choices), old)

def step(old: PlayableSession) -> PlayableStep:
  match old:
    case PlayableSession{state, learning, evolution, learning_choices,
        evolution_choices, NoPending{}, ruleset, identity}: step_ready(old)
    case _: PlayableAwaitingChoice{old}

def choose_move_valid(valid: Bool, +old: PlayableSession,
  individual: Nat, level: U32, move: U32, accept: Bool,
  replacement: Maybe<&2, U32>,
  learning_choices: List<&2, Rewards.LearningChoice>,
  evolution_choices: List<&2, Bridge.EvolutionChoice>) -> PlayableStep:
  match valid old:
    case False{} _: PlayableRejected{old}
    case True{} PlayableSession{state, learning, evolution, old_choices,
        old_evolution_choices, pending, ruleset, identity}:
      step_ready(with_state(old, state, NoPending{},
        List.append(&2, Rewards.LearningChoice, learning_choices,
          [Rewards.LearningChoice{individual, level, move, accept,
            replacement}]),
        evolution_choices))

def choose_move(+old: PlayableSession, +individual: Nat, +move: U32,
  accept: Bool, replacement: Maybe<&2, U32>) -> PlayableStep:
  match old:
    case PlayableSession{state, learning, evolution, learning_choices,
        evolution_choices, PendingMove{offered_individual, offered_level,
          offered_move},
        ruleset, identity}:
      choose_move_valid(Bool.and(Nat.is_eq(individual, offered_individual),
        U32.is_eq(move, offered_move)), old, individual, offered_level, move,
        accept, replacement, learning_choices, evolution_choices)
    case _: PlayableRejected{old}

def choose_evolution_valid(valid: Bool, +old: PlayableSession,
  individual: Nat, rule_id: Nat, accept: Bool,
  learning_choices: List<&2, Rewards.LearningChoice>,
  evolution_choices: List<&2, Bridge.EvolutionChoice>) -> PlayableStep:
  match valid old:
    case False{} _: PlayableRejected{old}
    case True{} PlayableSession{state, learning, evolution, old_choices,
        old_evolution_choices, pending, ruleset, identity}:
      step_ready(with_state(old, state, NoPending{}, learning_choices,
        List.append(&2, Bridge.EvolutionChoice, evolution_choices,
          [Bridge.EvolutionChoice{individual, rule_id, accept}])))

def choose_evolution(+old: PlayableSession, +individual: Nat,
  +rule_id: Nat, accept: Bool) -> PlayableStep:
  match old:
    case PlayableSession{state, learning, evolution, learning_choices,
        evolution_choices, PendingEvolution{offered_individual,
          offered_rule, target}, ruleset, identity}:
      choose_evolution_valid(Bool.and(Nat.is_eq(individual,
        offered_individual), Nat.is_eq(rule_id, offered_rule)), old,
        individual, rule_id, accept, learning_choices, evolution_choices)
    case _: PlayableRejected{old}

def submit_result(result: Session.SubmitResult,
  +old: PlayableSession) -> PlayableSubmit:
  match result:
    case Session.SessionRejected{state}: PlayableSubmitRejected{old}
    case Session.SessionAccepted{state, emitted}:
      match old:
        case PlayableSession{prior, learning, evolution, learning_choices,
            evolution_choices, pending, ruleset, identity}:
          PlayableAccepted{clear_choices(old, state), emitted}

def submit(fuel: Nat, +old: PlayableSession,
  commands: List<&2, Runtime.RuntimeCommand>) -> PlayableSubmit:
  match old:
    case PlayableSession{state, learning, evolution, learning_choices,
        evolution_choices, NoPending{}, ruleset, identity}:
      submit_result(Session.submit(fuel, state, commands), old)
    case _: PlayableSubmitRejected{old}
