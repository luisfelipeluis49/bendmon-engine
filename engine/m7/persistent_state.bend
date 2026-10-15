import Base
import ../battle/model.bend as Battle
import ../battle/runtime.bend as Runtime
import ../economy/core.bend as Economy
import ../economy/roster.bend as Roster
import ../progression/core.bend as Progression
import ./battle.bend as M7Battle
import ./playable.bend as Playable
import ./session.bend as Session
import ./reward_bridge.bend as Bridge
import ./rewards.bend as Rewards

# Stable M7 state retained after a completed encounter. Content identity keeps
# the ruleset/content binding explicit while battle queues and choices are dropped.
type PersistentState is Data:
  PersistentState{economy: Economy.State, roster: Roster.Roster,
    owned_inputs: List<&2, Rewards.OwnedRewardInput>,
    ledger: Progression.RewardLedger, ruleset: Nat, content_identity: Nat}

def terminal(status: Battle.BattleStatus) -> Bool:
  match status:
    case Battle.Victory{}: True{}
    case Battle.Defeat{}: True{}
    case Battle.Draw{}: True{}
    case Battle.Timeout{}: True{}
    case Battle.Escaped{}: True{}
    case _: False{}

def session_status(state: Session.State) -> Battle.BattleStatus:
  match state:
    case Session.State{battle, rewards, enemies, owners}:
      match battle:
        case M7Battle.State{runtime, economy, roster, captured, catalog}:
          Runtime.runtime_status(runtime)

def has_no_choice_history(learning: List<&2, Rewards.LearningChoice>,
  evolution: List<&2, Bridge.EvolutionChoice>) -> Bool:
  Bool.and(Nat.is_eq(List.length(&2, Rewards.LearningChoice, learning), 0n),
    Nat.is_eq(List.length(&2, Bridge.EvolutionChoice, evolution), 0n))

def owned_individual_valid(individual: Progression.Individual,
  +base: Progression.StatBlock, +ivs: Progression.StatBlock) -> Bool:
  match individual:
    case Progression.Individual{id, species, +level, xp, current_hp,
        +max_hp, stored_ivs, moves, history, observations, unlocks, harmony}:
      Bool.and(Progression.stats_valid(base, ivs, level),
      Bool.and(U32.is_eq(level, Progression.level_for_xp(xp)),
      Bool.and(Rewards.calculated_max_matches(
        Progression.calculate_stats(base, ivs, level), max_hp),
        U32.is_le(current_hp, max_hp))))

def owned_row_valid(+input: Rewards.OwnedRewardInput) -> Bool:
  match input:
    case Rewards.OwnedRewardInput{individual, base, ivs, alive,
        previously_active}:
      Bool.and(Rewards.reward_input_valid(input),
        owned_individual_valid(individual, base, ivs))

def owned_rows_valid(rows: List<&2, Rewards.OwnedRewardInput>) -> Bool:
  match rows:
    case Nil{}: True{}
    case input <> rest:
      Bool.and(owned_row_valid(input), owned_rows_valid(rest))

def ledger_ids_ordered(ids: List<&2, Nat>, previous: Nat) -> Bool:
  match ids:
    case Nil{}: True{}
    case +current <> rest:
      Bool.and(Nat.is_gt(current, previous),
        ledger_ids_ordered(rest, current))

def ledger_valid(ledger: Progression.RewardLedger) -> Bool:
  match ledger:
    case Progression.RewardLedger{completed}:
      ledger_ids_ordered(completed, 0n)

def persistent_fields_valid(+economy: Economy.State, +roster: Roster.Roster,
  +owned: List<&2, Rewards.OwnedRewardInput>,
  +ledger: Progression.RewardLedger) -> Bool:
  Bool.and(Economy.state_valid(economy),
  Bool.and(M7Battle.state_roster_valid(economy, roster),
  Bool.and(Session.owned_roster_valid(owned, roster),
  Bool.and(owned_rows_valid(owned), ledger_valid(ledger)))))

def state_valid(state: PersistentState) -> Bool:
  match state:
    case PersistentState{economy, roster, owned, ledger, ruleset, identity}:
      Bool.and(persistent_fields_valid(economy, roster, owned, ledger),
        Bool.and(Nat.is_eq(ruleset, 7n),
          Nat.is_le(identity, 4294967295n)))

def persistent_fields_result(valid: Bool, +economy: Economy.State,
  +roster: Roster.Roster, +owned: List<&2, Rewards.OwnedRewardInput>,
  +ledger: Progression.RewardLedger, ruleset: Nat, identity: Nat) ->
  Maybe<&2, PersistentState>:
  match valid:
    case False{}: None{}
    case True{}:
      Some{PersistentState{economy, roster, owned, ledger, ruleset, identity}}

def persistent_session(valid: Bool, state: Session.State,
  ruleset: Nat, identity: Nat) -> Maybe<&2, PersistentState>:
  match valid:
    case False{}: None{}
    case True{}:
      match state:
        case Session.State{battle, rewards, enemies, owners}:
          match battle:
            case M7Battle.State{runtime, economy, +roster, captured, catalog}:
              match rewards:
                case Bridge.Context{encounter, defeated, +owned, items,
                    +reward_economy, +ledger}:
                  persistent_fields_result(persistent_fields_valid(
                    reward_economy, roster, owned, ledger), reward_economy,
                    roster, owned, ledger, ruleset, identity)

# Projection is allowed only at a settled encounter boundary. This prevents
# saves from dropping battle queues or an unresolved progression decision.
def project(old: Playable.PlayableSession) -> Maybe<&2, PersistentState>:
  match old:
    case Playable.PlayableSession{+state, learning, evolution,
        learning_choices, evolution_choices, Playable.NoPending{}, +ruleset,
        +identity}:
      persistent_session(Bool.and(Nat.is_eq(ruleset, 7n),
        Bool.and(Nat.is_le(identity, 4294967295n),
        Bool.and(terminal(session_status(state)),
          Bool.and(Session.session_valid(state),
            has_no_choice_history(learning_choices, evolution_choices))))),
        state, ruleset, identity)
    case _: None{}
