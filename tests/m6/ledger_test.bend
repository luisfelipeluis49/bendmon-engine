import Base
import ../../engine/mixing/model.bend as MixModel
import ../../engine/mixing/ledger.bend as Ledger
import ../../engine/mixing/observation.bend as Learning
import ../../engine/battle/runtime.bend as Runtime
import ../../engine/battle/combat_math.bend as Math
import ../../engine/battle/model.bend as Battle
import ../../engine/battle/effects.bend as Effects

def move(value: Nat) -> Math.MoveId:
  Math.MoveId{value}

def recipe() -> MixModel.Recipe:
  MixModel.Recipe{MixModel.RecipeId{7n}, move(1n), move(2n),
    MixModel.ResultId{3n}}

def catalog() -> MixModel.Catalog:
  MixModel.Catalog{[recipe()], [], []}

def learned(progress: U32) -> Learning.LearningState:
  Learning.LearningState{MixModel.MonsterId{1n}, [],
    [Learning.LearnedRecipe{MixModel.RecipeId{7n}, progress}]}

def witnesses() -> List<&2, Runtime.RuntimeMixWitness>:
  [Runtime.RuntimeMixWitness{1n, Battle.ActorId{10n}, True{}, True{},
      [move(1n), move(2n)]},
   Runtime.RuntimeMixWitness{2n, Battle.ActorId{20n}, True{}, True{},
      [move(2n), move(1n)]},
   Runtime.RuntimeMixWitness{3n, Battle.ActorId{30n}, True{}, True{},
      [move(1n)]},
   Runtime.RuntimeMixWitness{4n, Battle.ActorId{40n}, False{}, True{},
      [move(1n), move(2n)]},
   Runtime.RuntimeMixWitness{5n, Battle.ActorId{50n}, True{}, False{},
      [move(1n), move(2n)]}]

def successful_event(sequence: Nat) -> Runtime.RuntimeEvent:
  Runtime.RuntimeMixEffectsCommitted{sequence, 7n, 1n, witnesses(),
    [Effects.DamageApplied{0n, Effects.Target{}, Effects.Physical{}, 2,
      False{}}], False{}}

def miss_event(sequence: Nat) -> Runtime.RuntimeEvent:
  Runtime.RuntimeMixEffectsCommitted{sequence, 7n, 1n, witnesses(),
    [Effects.ActionMissed{9000}], False{}}

def ledger(individual: Nat, progress: U32) -> Ledger.IndividualLedger:
  Ledger.IndividualLedger{Learning.LearningState{MixModel.MonsterId{individual},
    [], [Learning.LearnedRecipe{MixModel.RecipeId{7n}, progress}]}, [], []}

def staged_witnesses_match(staged: List<&2, Learning.StagedObservation>) -> Bool:
  match staged:
    case [Learning.StagedObservation{44n, MixModel.RecipeId{7n},
        [MixModel.MonsterId{1n}, MixModel.MonsterId{2n}]}]: True{}
    case _: False{}

def actor_progress(state: Ledger.IndividualLedger, expected: U32) -> Bool:
  match state:
    case Ledger.IndividualLedger{
        Learning.LearningState{MixModel.MonsterId{1n}, observed,
          [Learning.LearnedRecipe{MixModel.RecipeId{7n}, progress}]},
        staged, completed}:
      U32.is_eq(progress, expected)
    case _: False{}

def duplicate_stage_check(second: Ledger.IndividualLedger) -> Bool:
  match second:
    case Ledger.IndividualLedger{learning, staged, completed}:
      staged_witnesses_match(staged)

def duplicate_check(+second: Ledger.IndividualLedger) -> Bool:
  Bool.and(actor_progress(second, 4), duplicate_stage_check(second))

def duplicate_is_idempotent() -> Bool:
  +first = Ledger.apply_event(catalog(), successful_event(44n),
    ledger(1n, 3))
  +second = Ledger.apply_event(catalog(), successful_event(44n), first)
  duplicate_check(second)

def actor_only_check(ally: Ledger.IndividualLedger) -> Bool:
  match ally:
    case Ledger.IndividualLedger{learning, staged, completed}:
      match learning:
        case Learning.LearningState{MixModel.MonsterId{2n}, observed,
            [Learning.LearnedRecipe{MixModel.RecipeId{7n}, progress}]}:
          Bool.and(U32.is_eq(progress, 3), staged_witnesses_match(staged))
        case _: False{}

def actor_only_award() -> Bool:
  +ally = Ledger.apply_event(catalog(), successful_event(44n),
    ledger(2n, 3))
  actor_only_check(ally)

def miss_stage_matches(staged: List<&2, Learning.StagedObservation>) -> Bool:
  match staged:
    case [Learning.StagedObservation{45n, MixModel.RecipeId{7n},
        [MixModel.MonsterId{1n}, MixModel.MonsterId{2n}]}]: True{}
    case _: False{}

def miss_check(+after: Ledger.IndividualLedger) -> Bool:
  match after:
    case Ledger.IndividualLedger{learning, staged, completed}:
      Bool.and(actor_progress(after, 3),
        miss_stage_matches(staged))

def miss_stages_without_award() -> Bool:
  +after = Ledger.apply_event(catalog(), miss_event(45n),
    ledger(1n, 3))
  miss_check(after)

def terminal_check(ongoing: Ledger.IndividualLedger,
  terminal: Ledger.IndividualLedger) -> Bool:
  match ongoing terminal:
    case Ledger.IndividualLedger{Learning.LearningState{_, [], _},
         [Learning.StagedObservation{45n, _, _}], _}
         Ledger.IndividualLedger{Learning.LearningState{_,
           [MixModel.RecipeId{7n}], _}, [], _}: True{}
    case _ _: False{}

def terminal_merge_and_ongoing() -> Bool:
  +staged = Ledger.apply_event(catalog(), miss_event(45n),
    ledger(2n, 0))
  +ongoing = Ledger.merge_terminal(Learning.Ongoing{}, staged)
  +terminal = Ledger.merge_terminal(Learning.Victory{}, ongoing)
  terminal_check(ongoing, terminal)

def no_op_does_not_award() -> Bool:
  +after = Ledger.apply_event(catalog(),
    Runtime.RuntimeMixEffectsCommitted{46n, 7n, 1n, witnesses(), [], False{}},
    ledger(1n, 3))
  actor_progress(after, 3)

def unchanged_status_refresh_does_not_award() -> Bool:
  +after = Ledger.apply_event(catalog(),
    Runtime.RuntimeMixEffectsCommitted{47n, 7n, 1n, witnesses(),
      [Effects.StatusApplied{Effects.Target{}, Effects.Burn{}, True{}}],
      False{}}, ledger(1n, 3))
  actor_progress(after, 3)

def changed_status_awards() -> Bool:
  +after = Ledger.apply_event(catalog(),
    Runtime.RuntimeMixEffectsCommitted{48n, 7n, 1n, witnesses(),
      [Effects.StatusApplied{Effects.Target{}, Effects.Burn{}, True{}}],
      True{}}, ledger(1n, 3))
  actor_progress(after, 4)

def main() -> Bool:
  Bool.and(duplicate_is_idempotent(),
  Bool.and(actor_only_award(),
  Bool.and(miss_stages_without_award(),
  Bool.and(terminal_merge_and_ongoing(), Bool.and(no_op_does_not_award(),
    Bool.and(unchanged_status_refresh_does_not_award(),
      changed_status_awards()))))))
