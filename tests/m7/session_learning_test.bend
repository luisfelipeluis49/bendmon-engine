import Base
import ./session_test.bend as Fixture
import ../../engine/m7/session.bend as Session
import ../../engine/m7/rewards.bend as Rewards
import ../../engine/m7/reward_bridge.bend as Bridge
import ../../engine/progression/core.bend as Progression
import ../../engine/battle/model.bend as Battle
import ../../engine/battle/runtime.bend as Runtime

def catalog() -> List<&2, Rewards.SpeciesLearning>:
  [Rewards.SpeciesLearning{4n, [Rewards.LevelMove{2, 7}]}]

def queued() -> Maybe<Session.State>:
  Fixture.queued_session(Fixture.submission())

def learned(result: Session.InteractiveStepResult) -> Bool:
  match result:
    case Session.InteractiveStepped{Session.SessionStep{
        Session.Committed{}, Session.State{battle,
          Bridge.Context{7n, defeated,
            [Rewards.OwnedRewardInput{
              Progression.Individual{77n, 4n, 2, 100, hp, max_hp, ivs,
                [3, 7], [Progression.MoveLearnedRecord{3},
                  Progression.MoveLearnedRecord{7}], observations,
                unlocks, harmony}, base, input_ivs, alive, active}],
            items, economy, Progression.RewardLedger{[7n]}},
          enemies, owners}, emitted, captures}}: True{}
    case _: False{}

def automatic_from(result: Maybe<Session.State>) -> Bool:
  match result:
    case None{}: False{}
    case Some{state}:
      learned(Session.step_with_learning(state, catalog(), []))

def automatic_learn() -> Bool:
  automatic_from(queued())

def full_individual() -> Progression.Individual:
  Progression.Individual{77n, 4n, 1, 0, 10, 12,
    Fixture.zero_ivs(), [3, 4, 5, 6], [], [], [], [0]}

def full_context() -> Bridge.Context:
  Bridge.Context{7n, [], [Rewards.OwnedRewardInput{full_individual(),
    Fixture.base_stats(), Fixture.zero_ivs(), True{}, True{}}], [],
    Fixture.economy(), Progression.RewardLedger{[]}}

def full_state() -> Session.State:
  Session.State{Fixture.battle_state(), full_context(),
    [Fixture.enemy_binding()], [Fixture.owner_binding()]}

def full_queued() -> Maybe<Session.State>:
  Fixture.queued_session(Session.submit(10n, full_state(),
    [Fixture.lethal_move(), Runtime.RuntimeWait{Battle.ActorId{1n}}]))

def paused(result: Session.InteractiveStepResult) -> Bool:
  match result:
    case Session.InteractiveMoveChoice{77n, 2, 7,
        Session.State{battle,
          Bridge.Context{7n, [], owned, items, economy,
            Progression.RewardLedger{[]}}, enemies, owners}}: True{}
    case _: False{}

def pause_from(result: Maybe<Session.State>) -> Bool:
  match result:
    case None{}: False{}
    case Some{state}:
      paused(Session.step_with_learning(state, catalog(), []))

def full_slots_pause() -> Bool:
  pause_from(full_queued())

def declined(result: Session.InteractiveStepResult) -> Bool:
  match result:
    case Session.InteractiveStepped{Session.SessionStep{
        Session.Committed{}, Session.State{battle,
          Bridge.Context{7n, defeated,
            [Rewards.OwnedRewardInput{
              Progression.Individual{77n, 4n, 2, 100, hp, max_hp, ivs,
                [3, 4, 5, 6], [Progression.MoveDeclinedRecord{7}],
                observations, unlocks, harmony}, base, input_ivs, alive,
              active}], items, economy,
            Progression.RewardLedger{[7n]}}, enemies, owners},
        emitted, captures}}: True{}
    case _: False{}

def decline_from(result: Maybe<Session.State>) -> Bool:
  match result:
    case None{}: False{}
    case Some{state}:
      declined(Session.step_with_learning(state, catalog(),
        [Rewards.LearningChoice{77n, 2, 7, False{}, None{}}]))

def decline_commits_once() -> Bool:
  decline_from(full_queued())

def main() -> List<&2, Bool>:
  [automatic_learn(), full_slots_pause(), decline_commits_once()]
