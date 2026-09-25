import Base
import ./reward_bridge_test.bend as Fixture
import ../../engine/m7/reward_bridge.bend as Bridge
import ../../engine/m7/rewards.bend as Rewards
import ../../engine/progression/core.bend as Progression

def learning() -> List<&2, Rewards.SpeciesLearning>:
  [Rewards.SpeciesLearning{4n, []}]

def target() -> Progression.EvolutionTarget:
  Progression.EvolutionTarget{40n,
    Progression.StatBlock{200, 100, 100, 100, 100, 100}}

def evolution(automatic: Bool, targets: List<&2,
  Progression.EvolutionTarget>) -> List<&2, Bridge.EvolutionInput>:
  [Bridge.EvolutionInput{77n, 4n,
    [Progression.EvolutionRule{1n, 40n, automatic,
      [Progression.MinimumLevel{2}]}], targets, [], [], 0n, [], 0}]

def resolve(evolution_inputs: List<&2, Bridge.EvolutionInput>,
  choices: List<&2, Bridge.EvolutionChoice>) ->
  Bridge.ProgressionBridgeResult:
  Bridge.resolve_with_progression([Fixture.terminal_victory_event()],
    Fixture.context(), learning(), [], evolution_inputs, choices)

def evolved(result: Bridge.ProgressionBridgeResult) -> Bool:
  match result:
    case Bridge.ProgressionBridgeResult{Bridge.ProgressionCommitted{},
        Bridge.Context{7n, defeated,
          [Rewards.OwnedRewardInput{
            Progression.Individual{77n, 40n, 2, 200, hp, max_hp, ivs,
              [3], history, [8n], [9n], [2]},
            Progression.StatBlock{200, 100, 100, 100, 100, 100},
            input_ivs, alive, active}], items, economy,
          Progression.RewardLedger{[7n]}}}: True{}
    case _: False{}

def automatic_evolves_atomically() -> Bool:
  evolved(resolve(evolution(True{}, [target()]), []))

def manual_offer(result: Bridge.ProgressionBridgeResult) -> Bool:
  match result:
    case Bridge.ProgressionBridgeResult{
        Bridge.ProgressionEvolutionChoice{77n, 1n, 40n},
        Bridge.Context{7n, defeated, owned, items, economy,
          Progression.RewardLedger{[]}}}: True{}
    case _: False{}

def manual_pauses_without_commit() -> Bool:
  manual_offer(resolve(evolution(False{}, [target()]), []))

def manual_accept_evolves() -> Bool:
  evolved(resolve(evolution(False{}, [target()]),
    [Bridge.EvolutionChoice{77n, 1n, True{}}]))

def declined(result: Bridge.ProgressionBridgeResult) -> Bool:
  match result:
    case Bridge.ProgressionBridgeResult{Bridge.ProgressionCommitted{},
        Bridge.Context{7n, defeated,
          [Rewards.OwnedRewardInput{
            Progression.Individual{77n, 4n, 2, 200, hp, max_hp, ivs,
              [3], history, [8n], [9n], [2]},
            base, input_ivs, alive, active}], items, economy,
          Progression.RewardLedger{[7n]}}}: True{}
    case _: False{}

def manual_decline_commits() -> Bool:
  declined(resolve(evolution(False{}, [target()]),
    [Bridge.EvolutionChoice{77n, 1n, False{}}]))

def rejected(result: Bridge.ProgressionBridgeResult) -> Bool:
  match result:
    case Bridge.ProgressionBridgeResult{Bridge.ProgressionRejected{},
        Bridge.Context{7n, defeated, owned, items, economy,
          Progression.RewardLedger{[]}}}: True{}
    case _: False{}

def missing_auto_target_rolls_back() -> Bool:
  rejected(resolve(evolution(True{}, []), []))

def stale_source_species_rejects() -> Bool:
  rejected(resolve([Bridge.EvolutionInput{77n, 9n,
    [Progression.EvolutionRule{1n, 40n, True{},
      [Progression.MinimumLevel{2}]}], [target()], [], [], 0n, [], 0}], []))

def stale_source_species_config_valid(context: Bridge.Context) -> Bool:
  match context:
    case Bridge.Context{encounter_id, defeated, +owned, items, economy,
        ledger}:
      Bridge.evolution_configs_valid([Bridge.EvolutionInput{77n, 9n,
        [Progression.EvolutionRule{1n, 40n, True{},
          [Progression.MinimumLevel{2}]}], [target()], [], [], 0n, [], 0}],
        owned)

def stale_source_species_fails_config_validation() -> Bool:
  Bool.not(stale_source_species_config_valid(Fixture.context()))

def unknown_config_rejects() -> Bool:
  rejected(resolve([Bridge.EvolutionInput{999n, 4n, [], [], [], [], 0n,
    [], 0}], []))

def stale_manual_choice_rejects() -> Bool:
  rejected(resolve(evolution(False{}, [target()]),
    [Bridge.EvolutionChoice{77n, 2n, False{}}]))

def stale_auto_choice_rejects() -> Bool:
  rejected(resolve(evolution(True{}, [target()]),
    [Bridge.EvolutionChoice{77n, 1n, False{}}]))

def duplicate_config_rejects() -> Bool:
  rejected(resolve(List.append(&2, Bridge.EvolutionInput,
    evolution(True{}, [target()]), evolution(True{}, [target()])), []))

def duplicate_target_rejects() -> Bool:
  rejected(resolve(evolution(True{}, [target(), target()]), []))

def learned_move_evolution_result(result: Bridge.ProgressionBridgeResult) ->
  Bool:
  match result:
    case Bridge.ProgressionBridgeResult{Bridge.ProgressionCommitted{},
        Bridge.Context{7n, defeated,
          [Rewards.OwnedRewardInput{
            Progression.Individual{77n, 40n, 2, 200, hp, max_hp, ivs,
              [3, 7], [Progression.MoveLearnedRecord{3},
                Progression.MoveLearnedRecord{7}], [8n], [9n], [2]},
            Progression.StatBlock{200, 100, 100, 100, 100, 100},
            input_ivs, alive, active}], items, economy,
          Progression.RewardLedger{[7n]}}}: True{}
    case _: False{}

def learned_move_enables_evolution() -> Bool:
  learned_move_evolution_result(Bridge.resolve_with_progression(
    [Fixture.terminal_victory_event()], Fixture.context(),
    [Rewards.SpeciesLearning{4n, [Rewards.LevelMove{2, 7}]}], [],
    [Bridge.EvolutionInput{77n, 4n,
      [Progression.EvolutionRule{1n, 40n, True{},
        [Progression.MinimumLevel{2}, Progression.KnownMove{7}]}],
      [target()], [], [], 0n, [], 0}], []))

def main() -> List<&2, Bool>:
  [automatic_evolves_atomically(), manual_pauses_without_commit(),
    manual_accept_evolves(), manual_decline_commits(),
    missing_auto_target_rolls_back(), stale_source_species_rejects(),
    stale_source_species_fails_config_validation(),
    learned_move_enables_evolution(), unknown_config_rejects(),
    stale_manual_choice_rejects(), stale_auto_choice_rejects(),
    duplicate_config_rejects(), duplicate_target_rejects()]
