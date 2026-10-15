import Base
import ../m7/session_test.bend as Fixture
import ../m7/session_learning_test.bend as Learning
import ../../engine/m7/playable.bend as Playable
import ../../engine/m7/persistent_state.bend as Persistent
import ../../engine/m7/session.bend as Session
import ../../engine/m7/rewards.bend as Rewards
import ../../engine/m7/reward_bridge.bend as Bridge
import ../../engine/progression/core.bend as Progression
import ../../engine/economy/core.bend as Economy
import ../../engine/economy/roster.bend as Roster
import ../../engine/battle/model.bend as Battle
import ../../engine/battle/runtime.bend as Runtime

def opened(state: Session.State,
  learning: List<&2, Rewards.SpeciesLearning>) ->
  Maybe<Playable.PlayableSession>:
  Playable.open(state,
    Playable.ContentCatalog{learning, [], 7n, 123n}, 7n, 123n)

def submit_result(result: Playable.PlayableSubmit) ->
  Maybe<Playable.PlayableSession>:
  match result:
    case Playable.PlayableAccepted{session, emitted}: Some{session}
    case _: None{}

def queued(old: Maybe<Playable.PlayableSession>) ->
  Maybe<Playable.PlayableSession>:
  match old:
    case None{}: None{}
    case Some{session}:
      submit_result(Playable.submit(10n, session,
        [Fixture.lethal_move(),
          Runtime.RuntimeWait{Battle.ActorId{1n}}]))

def committed_projection(result: Maybe<&2, Persistent.PersistentState>) -> Bool:
  match result:
    case Some{Persistent.PersistentState{
        Economy.State{capacity, tier, party, storage, equipped, 5n, inventory},
        Roster.Roster{roster_capacity, [Roster.IndividualId{77n}], []},
        [Rewards.OwnedRewardInput{
          Progression.Individual{77n, 4n, 2, 100, hp, max_hp, ivs,
            [3, 4, 5, 6], history, observations, unlocks, harmony},
          base, input_ivs, alive, active}],
        Progression.RewardLedger{[7n]}, 7n, 123n}}: True{}
    case _: False{}

def projection_result(result: Maybe<&2, Persistent.PersistentState>) -> Bool:
  match result:
    case None{}: False{}
    case Some{projection}: committed_projection(Some{projection})

def advanced_result(result: Playable.PlayableStep) -> Bool:
  match result:
        case Playable.PlayableAdvanced{next, status, emitted, captures}:
          projection_result(Persistent.project(next))
        case _: False{}

def resolve_for_projection(result: Playable.PlayableStep) -> Bool:
  match result:
    case Playable.PlayableMoveOffer{77n, level, move, pending}:
      advanced_result(Playable.choose_move(pending, 77n, move, False{}, None{}))
    case _: False{}

def progression_result(old: Maybe<Playable.PlayableSession>) -> Bool:
  match old:
    case None{}: False{}
    case Some{session}: resolve_for_projection(Playable.step(session))

def progression_survives() -> Bool:
  progression_result(queued(opened(Learning.full_state(),
    Learning.catalog())))

def rejected_projection(result: Maybe<&2, Persistent.PersistentState>) -> Bool:
  match result:
    case None{}: True{}
    case _: False{}

def active_result(old: Maybe<Playable.PlayableSession>) -> Bool:
  match old:
    case None{}: False{}
    case Some{session}: rejected_projection(Persistent.project(session))

def active_battle_rejected() -> Bool:
  active_result(opened(Fixture.session_state(), []))

def pending_step(result: Playable.PlayableStep) -> Bool:
  match result:
        case Playable.PlayableMoveOffer{individual, level, move, pending}:
          rejected_projection(Persistent.project(pending))
        case _: False{}

def pending_result(old: Maybe<Playable.PlayableSession>) -> Bool:
  match old:
    case None{}: False{}
    case Some{session}:
      pending_step(Playable.step(session))

def pending_choice_rejected() -> Bool:
  pending_result(queued(opened(Learning.full_state(), Learning.catalog())))

def valid_fields(ledger: Progression.RewardLedger) -> Bool:
  Persistent.persistent_fields_valid(Fixture.economy(),
    Roster.Roster{Fixture.capacity(), [Roster.IndividualId{77n}], []},
    [Fixture.owner_input()], ledger)

def invalid_owned_rejected() -> Bool:
  rejected = Persistent.persistent_fields_valid(Fixture.economy(),
    Roster.Roster{Fixture.capacity(), [Roster.IndividualId{77n}], []},
    [Rewards.OwnedRewardInput{Fixture.owner_individual(),
      Fixture.base_stats(), Progression.StatBlock{1, 0, 0, 0, 0, 0},
      True{}, True{}}], Progression.RewardLedger{[]})
  Bool.not(rejected)

def invalid_roster_rejected() -> Bool:
  rejected = Persistent.persistent_fields_valid(Fixture.economy(),
    Roster.Roster{Fixture.capacity(), [Roster.IndividualId{88n}], []},
    [Fixture.owner_input()], Progression.RewardLedger{[]})
  Bool.not(rejected)

def invalid_economy_rejected() -> Bool:
  rejected = Persistent.persistent_fields_valid(
    Economy.State{Fixture.capacity(), 0n, 1n, 0n, 0n, 10000n, []},
    Roster.Roster{Fixture.capacity(), [Roster.IndividualId{77n}], []},
    [Fixture.owner_input()], Progression.RewardLedger{[]})
  Bool.not(rejected)

def invalid_ledger_rejected() -> Bool:
  Bool.not(valid_fields(Progression.RewardLedger{[7n, 7n]}))

def main() -> List<Bool>:
  [progression_survives(), active_battle_rejected(),
    pending_choice_rejected(), invalid_owned_rejected(),
    invalid_roster_rejected(), invalid_economy_rejected(),
    invalid_ledger_rejected()]
