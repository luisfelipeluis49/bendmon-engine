import Base
import ../../engine/progression/core.bend as Progression
import ../../engine/m7/progression_bridge.bend as Bridge

def ivs() -> Progression.StatBlock:
  Progression.StatBlock{0, 0, 0, 0, 0, 0}

def individual() -> Progression.Individual:
  Progression.Individual{99n, 4n, 10, 18900, 30, 40, ivs(), [7],
    [Progression.MoveLearnedRecord{7}], [3n], [5n], [2]}

def context() -> Progression.EvolutionContext:
  Progression.EvolutionContext{10, [99], [], 0n, [7], [], 2}

def target() -> Progression.EvolutionTarget:
  Progression.EvolutionTarget{40n,
    Progression.StatBlock{200, 100, 100, 100, 100, 100}}

def rules(automatic: Bool) -> List<&2, Progression.EvolutionRule>:
  [Progression.EvolutionRule{2n, 40n, automatic,
    [Progression.MinimumLevel{10}, Progression.RequiredItem{99}]}]

def auto_result_is_valid(result: Bridge.EvolutionStep) -> Bool:
  match result:
    case Bridge.EvolutionStep{Bridge.EvolutionApplied{},
        Progression.Individual{99n, 40n, 10, 18900, 50, 60, _, [7],
          [Progression.MoveLearnedRecord{7}], [3n], [5n], [2]},
        Progression.EvolutionOffer{True{}, 2n, 40n, True{}}}: True{}
    case _: False{}

def automatic_evolution_preserves_state() -> Bool:
  auto_result_is_valid(Bridge.resolve_evolution(individual(), context(),
    rules(True{}), Some{target()}))

def unchanged_manual_individual(value: Progression.Individual) -> Bool:
  match value:
    case Progression.Individual{99n, 4n, 10, 18900, 30, 40, _, _, _, _, _, _}:
      True{}
    case _: False{}

def manual_result_is_valid(result: Bridge.EvolutionStep) -> Bool:
  match result:
    case Bridge.EvolutionStep{Bridge.EvolutionChoiceRequired{}, same,
        Progression.EvolutionOffer{True{}, 2n, 40n, False{}}}:
      unchanged_manual_individual(same)
    case _: False{}

def manual_offer_waits_for_choice() -> Bool:
  manual_result_is_valid(Bridge.resolve_evolution(individual(), context(),
    rules(False{}), Some{target()}))

def accepted_manual_result_is_valid(result: Bridge.EvolutionStep) -> Bool:
  match result:
    case Bridge.EvolutionStep{Bridge.EvolutionApplied{},
        Progression.Individual{99n, 40n, 10, 18900, 50, 60, _, _, _, _, _, _},
        Progression.EvolutionOffer{True{}, 2n, 40n, False{}}}: True{}
    case _: False{}

def accepted_manual_changes_form() -> Bool:
  accepted_manual_result_is_valid(Bridge.accept_evolution(individual(),
    context(), rules(False{}), target()))

def unchanged_missing_individual(value: Progression.Individual) -> Bool:
  match value:
    case Progression.Individual{99n, 4n, 10, 18900, 30, 40, _, _, _, _, _, _}:
      True{}
    case _: False{}

def missing_target_result_is_valid(result: Bridge.EvolutionStep) -> Bool:
  match result:
    case Bridge.EvolutionStep{Bridge.EvolutionInvalid{}, same,
        Progression.EvolutionOffer{True{}, 2n, 40n, True{}}}:
      unchanged_missing_individual(same)
    case _: False{}

def missing_auto_target_is_unchanged() -> Bool:
  missing_target_result_is_valid(Bridge.resolve_evolution(individual(),
    context(), rules(True{}), None{}))

def main() -> List<&2, Bool>:
  [automatic_evolution_preserves_state(), manual_offer_waits_for_choice(),
   accepted_manual_changes_form(), missing_auto_target_is_unchanged()]
