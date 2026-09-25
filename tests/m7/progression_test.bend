import Base
import ../../engine/progression/core.bend as Progression

def base_stats() -> Progression.StatBlock:
  Progression.StatBlock{100, 100, 100, 100, 100, 100}

def zero_ivs() -> Progression.StatBlock:
  Progression.StatBlock{0, 0, 0, 0, 0, 0}

def match_threshold(value: Maybe<&2, U32>, expected: U32) -> Bool:
  match value:
    case Some{actual}: U32.is_eq(actual, expected)
    case None{}: False{}


def threshold_boundaries() -> Nat:
  +levels = Progression.xp_thresholds()
  +first = Progression.xp_threshold(1)
  +last = Progression.xp_threshold(200)
  +count_ok = Nat.is_eq(List.length(&2, U32, levels), 200n)
  +first_ok = match_threshold(first, 0)
  +last_ok = match_threshold(last, Progression.xp_cap())
  +levels_ok = Bool.and(U32.is_eq(Progression.level_for_xp(0), 1),
    Bool.and(U32.is_eq(Progression.level_for_xp(99), 1),
      Bool.and(U32.is_eq(Progression.level_for_xp(100), 2),
        U32.is_eq(Progression.level_for_xp(4294967295), 200))))
  U32.to_nat(Bool.to_u32(Bool.and(count_ok,
    Bool.and(first_ok, Bool.and(last_ok, levels_ok)))))

def stat_one(result: Maybe<&2, Progression.StatBlock>) -> Bool:
  match result:
    case Some{Progression.StatBlock{13, 7, 7, 7, 7, 7}}: True{}
    case _: False{}

def stat_cap(result: Maybe<&2, Progression.StatBlock>) -> Bool:
  match result:
    case Some{Progression.StatBlock{610, 405, 405, 405, 405, 405}}: True{}
    case _: False{}


def stat_boundaries() -> Nat:
  +at_one = Progression.calculate_stats(base_stats(), zero_ivs(), 1)
  +at_cap = Progression.calculate_stats(base_stats(), zero_ivs(), 200)
  U32.to_nat(Bool.to_u32(Bool.and(stat_one(at_one), stat_cap(at_cap))))

def level_up_check(result: Progression.ProgressResult) -> Nat:
  match result:
    case Progression.ProgressAccepted{
      Progression.ProgressState{2, 100, 11}, 1}: 1n
    case _: 0n

def declined_is_recorded(result: Progression.MoveLearning) -> Bool:
  match result:
    case Progression.MoveDeclined{[1, 2], [Progression.MoveLearnedRecord{1}, Progression.MoveDeclinedRecord{3}]}: True{}
    case _: False{}

def replacement_is_atomic(result: Progression.MoveLearning) -> Bool:
  match result:
    case Progression.MoveReplaced{[1, 3], [Progression.MoveLearnedRecord{1}, Progression.MoveReplacedRecord{3, 2}]}: True{}
    case _: False{}


def level_up_hp_delta() -> Nat:
  level_up_check(Progression.apply_xp(base_stats(), zero_ivs(),
    Progression.ProgressState{1, 0, 8}, 100))


def invalid_replacement_is_rejected(result: Progression.MoveLearning) -> Bool:
  match result:
    case Progression.MoveChoiceRequired{[1, 2], 3, [Progression.MoveLearnedRecord{1}]}: True{}
    case _: False{}


def decline_persisted(individual: Progression.Individual) -> Bool:
  match individual:
    case Progression.Individual{99n, 4n, 1, 0, 10, 10, _, [1, 2],
         [Progression.MoveLearnedRecord{1}, Progression.MoveDeclinedRecord{3}],
         _, _, _}: True{}
    case _: False{}

def move_choice_barrier() -> Nat:
  +choice = Progression.request_move([1, 2], 3, 2, [Progression.MoveLearnedRecord{1}])
  +declined = Progression.resolve_move_choice(choice, False{}, None{})
  +replaced = Progression.resolve_move_choice(choice, True{}, Some{2})
  +invalid = Progression.resolve_move_choice(choice, True{}, Some{99})
  +person = {Progression.Individual{99n, 4n, 1, 0, 10, 10, zero_ivs(),
    [1, 2], [Progression.MoveLearnedRecord{1}], [], [], []} :
    Progression.Individual}
  +committed = Progression.commit_move_learning(person, declined)
  U32.to_nat(Bool.to_u32(Bool.and(declined_is_recorded(declined),
    Bool.and(replacement_is_atomic(replaced),
      Bool.and(invalid_replacement_is_rejected(invalid),
        decline_persisted(committed))))))

def cap_result_ok(result: Progression.ProgressResult) -> Nat:
  match result:
    case Progression.ProgressAccepted{
      Progression.ProgressState{200, 197029900, 610}, 0}: 1n
    case _: 0n

def xp_cap_application() -> Nat:
  cap_result_ok(Progression.apply_xp(base_stats(), zero_ivs(),
    Progression.ProgressState{200, 197029900, 610}, 4294967295))

def rejected_unchanged(result: Progression.ProgressResult,
  state: Progression.ProgressState) -> Bool:
  match result state:
    case Progression.ProgressRejected{Progression.ProgressState{level, xp,
        current_hp}} Progression.ProgressState{expected_level, expected_xp,
        expected_hp}:
      Bool.and(U32.is_eq(level, expected_level),
        Bool.and(U32.is_eq(xp, expected_xp), U32.is_eq(current_hp, expected_hp)))
    case _ _: False{}

def malformed_progress_rejections() -> Nat:
  +over_cap = {Progression.ProgressState{200, 197029901, 610} :
    Progression.ProgressState}
  +over_hp = {Progression.ProgressState{1, 0, 14} :
    Progression.ProgressState}
  +a = Progression.apply_xp(base_stats(), zero_ivs(), over_cap, 1)
  +b = Progression.apply_xp(base_stats(), zero_ivs(), over_hp, 1)
  U32.to_nat(Bool.to_u32(Bool.and(rejected_unchanged(a, over_cap),
    rejected_unchanged(b, over_hp))))



def sample_context() -> Progression.EvolutionContext:
  Progression.EvolutionContext{10, [99], [99n], 0n, [99], [99n], 0}

def evolution_offer_ordered(offer: Progression.EvolutionOffer) -> Nat:
  match offer:
    case Progression.EvolutionOffer{True{}, 3n, 40n, True{}}: 1n
    case _: 0n

def evolution_order_and_identity() -> Nat:
  +rules = {[Progression.EvolutionRule{8n, 30n, True{},
      [Progression.MinimumLevel{2}]},
    Progression.EvolutionRule{2n, 20n, False{},
      [Progression.RequiredItem{7}]},
    Progression.EvolutionRule{3n, 40n, True{},
      [Progression.MinimumLevel{2}, Progression.RequiredItem{99},
       Progression.RequiredFlag{99n}, Progression.TimeProfile{0n}]},
    Progression.EvolutionRule{1n, 10n, False{},
      [Progression.MinimumLevel{1}, Progression.MinimumLevel{1},
       Progression.MinimumLevel{1}, Progression.MinimumLevel{1},
       Progression.MinimumLevel{1}]}] : List<&2, Progression.EvolutionRule>}
  +context = sample_context()
  +offer = Progression.first_evolution(context, rules)
  evolution_offer_ordered(offer)

def checked_evolution_result_ok(result: Progression.EvolutionResult) -> Bool:
  match result:
    case Progression.EvolutionAccepted{
      Progression.Individual{99n, 40n, 10, 18900, 50, 60, _, [],
        [Progression.MoveLearnedRecord{1}], [3n], [5n], [6]}}: True{}
    case _: False{}

def wrong_evolution_target_rejected(result: Progression.EvolutionResult) -> Bool:
  match result:
    case Progression.EvolutionRejected{unchanged}:
      match unchanged:
        case Progression.Individual{99n, 4n, 10, 18900, 30, 40, _, _, _, _, _, _}:
          True{}
        case _: False{}
    case _: False{}

def checked_evolution() -> Nat:
  +rules = {[Progression.EvolutionRule{8n, 30n, True{},
      [Progression.MinimumLevel{2}]},
    Progression.EvolutionRule{3n, 40n, True{},
      [Progression.MinimumLevel{2}, Progression.RequiredItem{99}]}] :
    List<&2, Progression.EvolutionRule>}
  +context = sample_context()
  +individual = {Progression.Individual{99n, 4n, 10, 18900, 30, 40,
    zero_ivs(), [], [Progression.MoveLearnedRecord{1}], [3n], [5n], [6]} :
    Progression.Individual}
  +target = {Progression.EvolutionTarget{40n,
    Progression.StatBlock{200, 100, 100, 100, 100, 100}} :
    Progression.EvolutionTarget}
  +success = Progression.evolve_checked(individual, context, rules, target)
  +wrong_target = Progression.evolve_checked(individual, context, rules,
    Progression.EvolutionTarget{41n,
      Progression.StatBlock{200, 100, 100, 100, 100, 100}})
  U32.to_nat(Bool.to_u32(Bool.and(checked_evolution_result_ok(success),
    wrong_evolution_target_rejected(wrong_target))))

def reward_plan_check(result: Progression.RewardPreparation) -> Nat:
  match result:
    case Progression.RewardsPrepared{
      Progression.RewardLedger{[7n]},
      Progression.RewardPlan{
        [Progression.ParticipantXp{1n, 500},
         Progression.ParticipantXp{2n, 500},
         Progression.ParticipantXp{3n, 0}], 50}}: 1n
    case _: 0n

def duplicate_reward_rejected(result: Progression.RewardPreparation) -> Bool:
  match result:
    case Progression.RewardsRejected{Progression.RewardLedger{[7n]}}: True{}
    case _: False{}

def no_payout_on_loss(result: Progression.RewardPreparation) -> Bool:
  match result:
    case Progression.RewardsSkipped{Progression.RewardLedger{[]}}: True{}
    case _: False{}

def reward_preparation() -> Nat:
  +rewards = {[Progression.DefeatedReward{10, 100, 50}] :
    List<&2, Progression.DefeatedReward>}
  +participants = {[Progression.RewardParticipant{1n, True{}, False{}},
    Progression.RewardParticipant{2n, False{}, True{}},
    Progression.RewardParticipant{3n, False{}, False{}}] :
    List<&2, Progression.RewardParticipant>}
  +first = Progression.prepare_rewards(Progression.RewardVictory{}, 7n,
    rewards, participants, Progression.RewardLedger{[]})
  +duplicate = Progression.prepare_rewards(Progression.RewardVictory{}, 7n,
    rewards, participants, Progression.RewardLedger{[7n]})
  +loss = Progression.prepare_rewards(Progression.RewardDefeat{}, 7n,
    rewards, participants, Progression.RewardLedger{[]})
  U32.to_nat(Bool.to_u32(Bool.and(
    Nat.is_eq(reward_plan_check(first), 1n),
    Bool.and(duplicate_reward_rejected(duplicate), no_payout_on_loss(loss)))))

def main() -> List<&2, Nat>:
  [threshold_boundaries(), stat_boundaries(), level_up_hp_delta(),
   xp_cap_application(), malformed_progress_rejections(), move_choice_barrier(),
   evolution_order_and_identity(), checked_evolution(), reward_preparation()]

#| [1, 1, 1, 1, 1, 1, 1, 1, 1]
