import Base
import ./session_test.bend as Fixture
import ./session_learning_test.bend as LearningFixture
import ../../engine/m7/playable.bend as Playable
import ../../engine/m7/session.bend as Session
import ../../engine/m7/reward_bridge.bend as Bridge
import ../../engine/m7/rewards.bend as Rewards
import ../../engine/battle/model.bend as Battle
import ../../engine/battle/runtime.bend as Runtime
import ../../engine/progression/core.bend as Progression

def opened() -> Maybe<Playable.PlayableSession>:
  Playable.open(LearningFixture.full_state(),
    Playable.ContentCatalog{LearningFixture.catalog(), [], 7n, 123n},
    7n, 123n)

def queued(result: Playable.PlayableSubmit) ->
  Maybe<Playable.PlayableSession>:
  match result:
    case Playable.PlayableAccepted{session, emitted}: Some{session}
    case _: None{}

def submit_open(result: Maybe<Playable.PlayableSession>) ->
  Maybe<Playable.PlayableSession>:
  match result:
    case None{}: None{}
    case Some{session}:
      queued(Playable.submit(10n, session,
        [Fixture.lethal_move(),
          Runtime.RuntimeWait{Battle.ActorId{1n}}]))

def ready() -> Maybe<Playable.PlayableSession>:
  submit_open(opened())

def offered(result: Playable.PlayableStep) -> Bool:
  match result:
    case Playable.PlayableMoveOffer{77n, 2, 7,
        Playable.PlayableSession{state, learning, evolution, choices,
          evolution_choices, Playable.PendingMove{77n, 2, 7}, 7n, 123n}}:
      True{}
    case _: False{}

def anchored_choice(result: Maybe<Playable.PlayableSession>) -> Bool:
  match result:
    case None{}: False{}
    case Some{session}: offered(Playable.step(session))

def pending_session(result: Playable.PlayableStep) ->
  Maybe<Playable.PlayableSession>:
  match result:
    case Playable.PlayableMoveOffer{77n, 2, 7, session}: Some{session}
    case _: None{}

def pending_from_ready(result: Maybe<Playable.PlayableSession>) ->
  Maybe<Playable.PlayableSession>:
  match result:
    case None{}: None{}
    case Some{session}: pending_session(Playable.step(session))

def pending() -> Maybe<Playable.PlayableSession>:
  pending_from_ready(ready())

def declined(result: Playable.PlayableStep) -> Bool:
  match result:
    case Playable.PlayableAdvanced{
        Playable.PlayableSession{
          Session.State{battle,
            Bridge.Context{7n, defeated,
              [Rewards.OwnedRewardInput{
                Progression.Individual{77n, 4n, 2, 100, hp, max_hp, ivs,
                  [3, 4, 5, 6], [Progression.MoveDeclinedRecord{7}],
                  observations, unlocks, harmony}, base, input_ivs,
                alive, active}], items, economy,
              Progression.RewardLedger{[7n]}}, enemies, owners},
          learning, evolution, [], [], Playable.NoPending{}, 7n, 123n},
        Session.Committed{}, emitted, captures}: True{}
    case _: False{}

def choose_from_pending(result: Maybe<Playable.PlayableSession>) -> Bool:
  match result:
    case None{}: False{}
    case Some{session}:
      declined(Playable.choose_move(session, 77n, 7, False{}, None{}))

def rejected_choice(result: Playable.PlayableStep) -> Bool:
  match result:
    case Playable.PlayableRejected{same}: True{}
    case _: False{}

def bad_choice_rejected(result: Maybe<Playable.PlayableSession>) -> Bool:
  match result:
    case None{}: False{}
    case Some{session}:
      rejected_choice(Playable.choose_move(session, 77n, 8, False{}, None{}))

def invalid_version(result: Maybe<Playable.PlayableSession>) -> Bool:
  match result:
    case None{}: True{}
    case _: False{}

def main() -> List<&2, Bool>:
  [anchored_choice(ready()), choose_from_pending(pending()),
    bad_choice_rejected(pending()),
    invalid_version(Playable.open(LearningFixture.full_state(),
      Playable.ContentCatalog{LearningFixture.catalog(), [], 6n, 123n},
      7n, 123n)),
    invalid_version(Playable.open(LearningFixture.full_state(),
      Playable.ContentCatalog{LearningFixture.catalog(), [], 7n, 123n},
      7n, 124n))]
