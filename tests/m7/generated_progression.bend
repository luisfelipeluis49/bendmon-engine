import Base
import ../../engine/progression/core.bend as Progression

def stats_as_list(result: Maybe<&2, Progression.StatBlock>) -> List<&2, U32>:
  match result:
    case Some{Progression.StatBlock{hp, attack, defense, special_attack,
        special_defense, speed}}:
      [hp, attack, defense, special_attack, special_defense, speed]
    case None{}: []

def stat_vectors() -> List<&2, U32>:
  +first = stats_as_list(Progression.calculate_stats(
      Progression.StatBlock{1, 1, 1, 1, 1, 1},
      Progression.StatBlock{0, 0, 0, 0, 0, 0}, 1))
  +fractional = stats_as_list(Progression.calculate_stats(
      Progression.StatBlock{37, 38, 39, 40, 41, 42},
      Progression.StatBlock{29, 28, 27, 26, 25, 24}, 3))
  +maximum = stats_as_list(Progression.calculate_stats(
      Progression.StatBlock{500, 500, 500, 500, 500, 500},
      Progression.StatBlock{31, 31, 31, 31, 31, 31}, 200))
  +invalid = stats_as_list(Progression.calculate_stats(
      Progression.StatBlock{500, 500, 500, 500, 500, 500},
      Progression.StatBlock{31, 31, 31, 31, 31, 31}, 0))
  List.append(&2, U32, List.append(&2, U32, first, fractional),
    List.append(&2, U32, maximum, invalid))

def predicate_vector(+context: Progression.EvolutionContext) -> List<&2, U32>:
  [Bool.to_u32(Progression.predicate_holds(
      Progression.MinimumLevel{10}, context)),
   Bool.to_u32(Progression.predicate_holds(
      Progression.RequiredItem{7}, context)),
   Bool.to_u32(Progression.predicate_holds(
      Progression.RequiredFlag{8n}, context)),
   Bool.to_u32(Progression.predicate_holds(
      Progression.TimeProfile{2n}, context)),
   Bool.to_u32(Progression.predicate_holds(
      Progression.KnownMove{9}, context)),
   Bool.to_u32(Progression.predicate_holds(
      Progression.LearnedRecipe{11n}, context)),
   Bool.to_u32(Progression.predicate_holds(
      Progression.MinimumHarmony{4}, context))]

def selected_candidate_is_expected(offer: Progression.EvolutionOffer) -> U32:
  match offer:
    case Progression.EvolutionOffer{True{}, 2n, 202n, False{}}: 1
    case _: 0

def invalid_rule_skipped() -> U32:
  +context = {Progression.EvolutionContext{20, [7], [8n], 2n, [9],
    [11n], 4} : Progression.EvolutionContext}
  +rules = {[Progression.EvolutionRule{3n, 303n, True{},
      [Progression.MinimumLevel{20}, Progression.RequiredItem{7},
       Progression.RequiredFlag{8n}, Progression.MinimumHarmony{4}]},
    Progression.EvolutionRule{1n, 101n, True{},
      [Progression.MinimumHarmony{6}]},
    Progression.EvolutionRule{4n, 404n, True{},
      [Progression.MinimumLevel{20}, Progression.RequiredItem{7},
       Progression.RequiredFlag{8n}, Progression.MinimumHarmony{4},
       Progression.TimeProfile{2n}]},
    Progression.EvolutionRule{2n, 202n, False{},
      [Progression.MinimumLevel{20}]}] :
    List<&2, Progression.EvolutionRule>}
  selected_candidate_is_expected(Progression.first_evolution(context, rules))

def victory_plan_ok(result: Progression.RewardPreparation) -> U32:
  match result:
    case Progression.RewardsPrepared{Progression.RewardLedger{[9n]},
      Progression.RewardPlan{[Progression.ParticipantXp{1n, 158},
        Progression.ParticipantXp{2n, 158}, Progression.ParticipantXp{3n, 0}], 100}}: 1
    case _: 0

def capture_plan_ok(result: Progression.RewardPreparation) -> U32:
  match result:
    case Progression.RewardsPrepared{_, Progression.RewardPlan{_, 100}}: 1
    case _: 0

def loss_plan_ok(result: Progression.RewardPreparation) -> U32:
  match result:
    case Progression.RewardsSkipped{Progression.RewardLedger{[]}}: 1
    case _: 0

def replay_plan_ok(result: Progression.RewardPreparation) -> U32:
  match result:
    case Progression.RewardsRejected{Progression.RewardLedger{[9n]}}: 1
    case _: 0

def reward_vectors() -> List<&2, U32>:
  +rewards = {[Progression.DefeatedReward{3, 101, 70},
    Progression.DefeatedReward{2, 7, 30}] :
    List<&2, Progression.DefeatedReward>}
  +participants = {[Progression.RewardParticipant{1n, True{}, False{}},
    Progression.RewardParticipant{2n, False{}, True{}},
    Progression.RewardParticipant{3n, False{}, False{}}] :
    List<&2, Progression.RewardParticipant>}
  +paid = Progression.prepare_rewards(Progression.RewardVictory{}, 9n,
    rewards, participants, Progression.RewardLedger{[]})
  +capture = Progression.prepare_rewards(Progression.RewardCapture{}, 10n,
    rewards, participants, Progression.RewardLedger{[]})
  +loss = Progression.prepare_rewards(Progression.RewardDefeat{}, 11n,
    rewards, participants, Progression.RewardLedger{[]})
  +replay = Progression.prepare_rewards(Progression.RewardVictory{}, 9n,
    rewards, participants, Progression.RewardLedger{[9n]})
  [victory_plan_ok(paid), capture_plan_ok(capture), loss_plan_ok(loss),
   replay_plan_ok(replay)]

def main() -> List<&2, U32>:
  +stats = stat_vectors()
  +predicates = predicate_vector(
    {Progression.EvolutionContext{10, [7], [8n], 2n, [9], [11n], 4}
      : Progression.EvolutionContext})
  +missing = predicate_vector(
    {Progression.EvolutionContext{9, [], [], 3n, [], [], 0}
      : Progression.EvolutionContext})
  +evolution = invalid_rule_skipped()
  +rewards = reward_vectors()
  List.append(&2, U32, stats,
    List.append(&2, U32, predicates,
      List.append(&2, U32, missing,
        evolution <> rewards)))
