import Base
import ../progression/core.bend as Progression

# Evolution runs after XP and every move-learning barrier have settled, so
# predicates such as KnownMove inspect the final individual state.
type EvolutionStatus is Data:
  EvolutionUnchanged{}
  EvolutionChoiceRequired{}
  EvolutionApplied{}
  EvolutionInvalid{}

type EvolutionStep is Data:
  EvolutionStep{status: EvolutionStatus,
    individual: Progression.Individual,
    offer: Progression.EvolutionOffer}

def unchanged(status: EvolutionStatus, individual: Progression.Individual,
  offer: Progression.EvolutionOffer) -> EvolutionStep:
  EvolutionStep{status, individual, offer}

def auto_result(result: Progression.EvolutionResult,
  offer: Progression.EvolutionOffer) -> EvolutionStep:
  match result:
    case Progression.EvolutionAccepted{next}:
      EvolutionStep{EvolutionApplied{}, next, offer}
    case Progression.EvolutionRejected{same}:
      EvolutionStep{EvolutionInvalid{}, same, offer}

def target_species(target: Progression.EvolutionTarget) -> Nat:
  match target:
    case Progression.EvolutionTarget{species, base_stats}: species

def auto_target_species(matches: Bool,
  target: Progression.EvolutionTarget,
  individual: Progression.Individual,
  +context: Progression.EvolutionContext,
  +rules: List<&2, Progression.EvolutionRule>,
  offer: Progression.EvolutionOffer) -> EvolutionStep:
  match matches:
    case False{}: unchanged(EvolutionInvalid{}, individual, offer)
    case True{}:
      auto_result(Progression.evolve_checked(individual, context, rules,
        target), offer)

def auto_target(target: Maybe<&2, Progression.EvolutionTarget>,
  species: Nat,
  individual: Progression.Individual,
  +context: Progression.EvolutionContext,
  +rules: List<&2, Progression.EvolutionRule>,
  offer: Progression.EvolutionOffer) -> EvolutionStep:
  match target:
    case None{}: unchanged(EvolutionInvalid{}, individual, offer)
    case Some{+value}:
      auto_target_species(Nat.is_eq(species, target_species(value)), value,
        individual, context, rules, offer)

def automatic_offer(individual: Progression.Individual,
  +context: Progression.EvolutionContext,
  +rules: List<&2, Progression.EvolutionRule>,
  offer: Progression.EvolutionOffer,
  target: Maybe<&2, Progression.EvolutionTarget>) -> EvolutionStep:
  match offer:
    case Progression.EvolutionOffer{True{}, rule_id, +species, True{}}:
      auto_target(target, species, individual, context, rules, offer)
    case Progression.EvolutionOffer{True{}, rule_id, +species, False{}}:
      unchanged(EvolutionChoiceRequired{}, individual, offer)
    case _:
      unchanged(EvolutionUnchanged{}, individual, offer)

# The offer is sorted by EvolutionRuleId in the progression core. Automatic
# rules apply immediately; authored manual rules are returned for a UI choice.
def resolve_evolution(individual: Progression.Individual,
  +context: Progression.EvolutionContext,
  +rules: List<&2, Progression.EvolutionRule>,
  target: Maybe<&2, Progression.EvolutionTarget>) -> EvolutionStep:
  automatic_offer(individual, context, rules,
    Progression.first_evolution(context, rules), target)

def accept_result(result: Progression.EvolutionResult,
  offer: Progression.EvolutionOffer) -> EvolutionStep:
  match result:
    case Progression.EvolutionAccepted{next}:
      EvolutionStep{EvolutionApplied{}, next, offer}
    case Progression.EvolutionRejected{same}:
      EvolutionStep{EvolutionInvalid{}, same, offer}

# Explicit manual acceptance uses the same sorted predicate scan and target
# validation as automatic evolution. A non-manual or absent offer is unchanged.
def accept_target(matches: Bool, individual: Progression.Individual,
  context: Progression.EvolutionContext,
  rules: List<&2, Progression.EvolutionRule>,
  target: Progression.EvolutionTarget,
  offer: Progression.EvolutionOffer) -> EvolutionStep:
  match matches:
    case True{}:
      accept_result(Progression.evolve_checked(individual, context,
        rules, target), offer)
    case False{}: unchanged(EvolutionInvalid{}, individual, offer)

def accept_offer(offer: Progression.EvolutionOffer,
  individual: Progression.Individual,
  context: Progression.EvolutionContext,
  rules: List<&2, Progression.EvolutionRule>,
  target: Progression.EvolutionTarget) -> EvolutionStep:
  match offer:
    case Progression.EvolutionOffer{True{}, rule_id, +species, False{}}:
      match target:
        case Progression.EvolutionTarget{+target_species, base_stats}:
          accept_target(Nat.is_eq(species, target_species), individual,
            context, rules, target, offer)
    case _:
      unchanged(EvolutionUnchanged{}, individual, offer)

def accept_evolution(individual: Progression.Individual,
  +context: Progression.EvolutionContext,
  +rules: List<&2, Progression.EvolutionRule>,
  target: Progression.EvolutionTarget) -> EvolutionStep:
  accept_offer(Progression.first_evolution(context, rules), individual,
    context, rules, target)
