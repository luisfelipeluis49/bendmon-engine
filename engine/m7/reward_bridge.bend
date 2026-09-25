import Base
import ../battle/model.bend as Battle
import ../economy/core.bend as Economy
import ../progression/core.bend as Progression
import ./rewards.bend as Rewards
import ./progression_bridge.bend as ProgressionBridge

# The M7 battle wrapper constructs this context from trusted loaded content and
# persistent save data. `defeated` contains only opponents actually defeated;
# it must be derived by matching terminal enemy actors to encounter records.
# The wrapper also supplies the encounter ID, item rewards, and durable ledger.
type Context is Data:
  Context{encounter_id: Nat,
    defeated: List<&2, Progression.DefeatedReward>,
    owned_inputs: List<&2, Rewards.OwnedRewardInput>,
    item_rewards: List<&2, Rewards.EncounterItem>,
    economy: Economy.State,
    ledger: Progression.RewardLedger}

type Status is Data:
  RewardBridgeCommitted{}
  RewardBridgeRejected{}
  RewardBridgeSkipped{}
  RewardBridgeNotTerminal{}

type BridgeResult is Data:
  RewardBridgeResult{status: Status, context: Context}

type ProgressionBridgeStatus is Data:
  ProgressionCommitted{}
  ProgressionRejected{}
  ProgressionSkipped{}
  ProgressionNotTerminal{}
  ProgressionLearningChoice{pending: Rewards.PendingLearning}
  ProgressionEvolutionChoice{owner: Nat, rule_id: Nat, target_species: Nat}

type ProgressionBridgeResult is Data:
  ProgressionBridgeResult{status: ProgressionBridgeStatus, context: Context}

type EvolutionInput is Data:
  EvolutionInput{owner: Nat, source_species: Nat,
    rules: List<&2, Progression.EvolutionRule>,
    targets: List<&2, Progression.EvolutionTarget>,
    items: List<&2, U32>, flags: List<&2, Nat>, time_profile: Nat,
    recipes: List<&2, Nat>, harmony_tier: U32}

type EvolutionChoice is Data:
  EvolutionChoice{owner: Nat, rule_id: Nat, accept: Bool}

type EvolutionDecisionStatus is Data:
  EvolutionDecisionApplied{}
  EvolutionDecisionOffered{owner: Nat, rule_id: Nat, target_species: Nat}
  EvolutionDecisionRejected{}

type EvolutionDecision is Data:
  EvolutionDecision{status: EvolutionDecisionStatus,
    individual: Progression.Individual, base: Progression.StatBlock}

type EvolutionTargetScan is Data:
  EvolutionTargetScan{species: Nat,
    selected: Maybe<&2, Progression.EvolutionTarget>, count: Nat}

type EvolutionChoiceScan is Data:
  EvolutionChoiceScan{owner: Nat, rule_id: Nat,
    selected: Maybe<&2, EvolutionChoice>, count: Nat}

type EvolutionConfigScan is Data:
  EvolutionConfigScan{owner: Nat, selected: Maybe<&2, EvolutionInput>,
    count: Nat}

type EvolutionRunStatus is Data:
  EvolutionRunComplete{}
  EvolutionRunPending{owner: Nat, rule_id: Nat, target_species: Nat}
  EvolutionRunRejected{}

type EvolutionRun is Data:
  EvolutionRun{status: EvolutionRunStatus,
    inputs: List<&2, Rewards.OwnedRewardInput>}

type EvolutionFold is Data:
  EvolutionFold{run: EvolutionRun, configs: List<&2, EvolutionInput>,
    choices: List<&2, EvolutionChoice>}

type EvolutionOwnerChoices is Data:
  EvolutionOwnerChoices{owner: Nat, count: Nat}

type EvolutionOwnedCount is Data:
  EvolutionOwnedCount{owner: Nat, count: Nat}

type RewardEvent is Data:
  Transition{event: Battle.TransitionEvent}
  CaptureSucceeded{}

def any_capture_success(events: List<&2, RewardEvent>) -> Bool:
  match events:
    case Nil{}: False{}
    case CaptureSucceeded{} <> rest: True{}
    case _ <> rest: any_capture_success(rest)

def terminal_outcome(status: Battle.BattleStatus, captured: Bool) ->
  Maybe<&2, Progression.ProgressionOutcome>:
  match status:
    case Battle.Victory{}:
      match captured:
        case True{}: Some{Progression.RewardCapture{}}
        case False{}: Some{Progression.RewardVictory{}}
    case Battle.Defeat{}: Some{Progression.RewardDefeat{}}
    case Battle.Draw{}: Some{Progression.RewardDraw{}}
    case Battle.Timeout{}: Some{Progression.RewardTimeout{}}
    case Battle.Escaped{}: Some{Progression.RewardEscape{}}
    case _: None{}

def completion_outcome(events: List<&2, RewardEvent>, captured: Bool) ->
  Maybe<&2, Progression.ProgressionOutcome>:
  match events:
    case Nil{}: None{}
    case Transition{Battle.BattleCompleted{status, tick}} <> rest:
      terminal_outcome(status, captured)
    case _ <> rest: completion_outcome(rest, captured)

def replace_owned_merge(rest: Maybe<List<&2, Rewards.OwnedRewardInput>>,
  head: Rewards.OwnedRewardInput) -> Maybe<List<&2, Rewards.OwnedRewardInput>>:
  match rest:
    case None{}: None{}
    case Some{tail}: Some{head <> tail}

def replace_owned_step(inputs: List<&2, Rewards.OwnedRewardInput>,
  individuals: List<&2, Progression.Individual>) ->
  Maybe<List<&2, Rewards.OwnedRewardInput>>:
  match inputs individuals:
    case Nil{} Nil{}: Some{[]}
    case Rewards.OwnedRewardInput{old_individual, base, ivs, alive,
        previously_active} <> input_rest
         +updated <> individual_rest:
      replace_owned_merge(replace_owned_step(input_rest, individual_rest),
        Rewards.OwnedRewardInput{updated, base, ivs, alive,
          previously_active})
    case _ _: None{}

def replace_context_owned(updated: Maybe<List<&2, Rewards.OwnedRewardInput>>,
  old: Context, economy: Economy.State,
  ledger: Progression.RewardLedger) -> Maybe<Context>:
  match updated old:
    case None{} Context{encounter_id, defeated, old_inputs, item_rewards,
        old_economy, old_ledger}:
      None{}
    case Some{updated_inputs} Context{encounter_id, defeated, old_inputs,
        item_rewards, old_economy, old_ledger}:
      Some{Context{encounter_id, defeated, updated_inputs, item_rewards,
        economy, ledger}}

def context_after_commit(old: Context,
  owned: List<&2, Progression.Individual>, economy: Economy.State,
  ledger: Progression.RewardLedger) -> Maybe<Context>:
  match old:
    case Context{encounter_id, defeated, +owned_inputs, item_rewards,
        old_economy, old_ledger}:
      replace_context_owned(replace_owned_step(owned_inputs, owned), old,
        economy, ledger)

def result_from_context(updated: Maybe<Context>, old: Context) -> BridgeResult:
  match updated:
    case None{}: RewardBridgeResult{RewardBridgeRejected{}, old}
    case Some{next_context}:
      RewardBridgeResult{RewardBridgeCommitted{}, next_context}

def commit_result(result: Rewards.TransactionResult, +old: Context) -> BridgeResult:
  match result:
    case Rewards.RewardResult{Rewards.RewardCommitted{}, owned, economy,
        ledger}:
      result_from_context(context_after_commit(old, owned, economy, ledger),
        old)
    case Rewards.RewardResult{Rewards.RewardRejected{}, owned, economy,
        ledger}:
      RewardBridgeResult{RewardBridgeRejected{}, old}
    case Rewards.RewardResult{Rewards.RewardSkipped{}, owned, economy,
        ledger}:
      RewardBridgeResult{RewardBridgeSkipped{}, old}
    case Rewards.RewardChoiceRequired{pending}:
      RewardBridgeResult{RewardBridgeRejected{}, old}

def transaction(outcome: Progression.ProgressionOutcome,
  +context: Context) -> BridgeResult:
  match context:
    case Context{encounter_id, defeated, +owned_inputs, item_rewards,
        +economy, +ledger}:
      commit_result(Rewards.transaction(outcome, encounter_id, defeated,
        owned_inputs, item_rewards, economy, ledger), context)

def resolve_optional(outcome: Maybe<&2, Progression.ProgressionOutcome>,
  context: Context) -> BridgeResult:
  match outcome:
    case None{}: RewardBridgeResult{RewardBridgeNotTerminal{}, context}
    case Some{value}: transaction(value, context)

# Only a newly emitted BattleCompleted event can cross the reward boundary.
# Capture is eligible only if that same terminal Victory followed a successful
# capture; intermediate capture attempts leave the encounter reward untouched.
def resolve(+events: List<&2, RewardEvent>, +context: Context) -> BridgeResult:
  resolve_optional(completion_outcome(events, any_capture_success(events)),
    context)

def target_scan_result(matches: Bool, state: EvolutionTargetScan,
  target: Progression.EvolutionTarget) -> EvolutionTargetScan:
  match matches:
    case False{}: state
    case True{}:
      match state:
        case EvolutionTargetScan{species, selected, count}:
          EvolutionTargetScan{species, Some{target}, Nat.add(count, 1n)}

def target_scan_step(state: EvolutionTargetScan,
  target: Progression.EvolutionTarget) -> EvolutionTargetScan:
  match state target:
    case EvolutionTargetScan{+species, selected, count}
         Progression.EvolutionTarget{+candidate, base_stats}:
      target_scan_result(Nat.is_eq(species, candidate), state, target)

def find_evolution_target(species: Nat,
  targets: List<&2, Progression.EvolutionTarget>) -> EvolutionTargetScan:
  List.foldl(&2, Progression.EvolutionTarget, EvolutionTargetScan,
    target_scan_step, targets, EvolutionTargetScan{species, None{}, 0n})

def choice_scan_result(matches: Bool, state: EvolutionChoiceScan,
  choice: EvolutionChoice) -> EvolutionChoiceScan:
  match matches:
    case False{}: state
    case True{}:
      match state:
        case EvolutionChoiceScan{owner, rule_id, selected, count}:
          EvolutionChoiceScan{owner, rule_id, Some{choice}, Nat.add(count, 1n)}

def choice_scan_step(state: EvolutionChoiceScan,
  choice: EvolutionChoice) -> EvolutionChoiceScan:
  match state choice:
    case EvolutionChoiceScan{+owner, +rule_id, selected, count}
         EvolutionChoice{+choice_owner, +choice_rule, accept}:
      choice_scan_result(Bool.and(Nat.is_eq(owner, choice_owner),
        Nat.is_eq(rule_id, choice_rule)), state, choice)

def find_evolution_choice(owner: Nat, rule_id: Nat,
  choices: List<&2, EvolutionChoice>) -> EvolutionChoiceScan:
  List.foldl(&2, EvolutionChoice, EvolutionChoiceScan, choice_scan_step,
    choices, EvolutionChoiceScan{owner, rule_id, None{}, 0n})

def owner_choice_scan_result(matches: Bool, state: EvolutionOwnerChoices) ->
  EvolutionOwnerChoices:
  match matches:
    case True{}:
      match state:
        case EvolutionOwnerChoices{owner, count}:
          EvolutionOwnerChoices{owner, Nat.add(count, 1n)}
    case False{}: state

def owner_choice_scan_step(state: EvolutionOwnerChoices,
  choice: EvolutionChoice) -> EvolutionOwnerChoices:
  match state choice:
    case EvolutionOwnerChoices{+owner, count}
         EvolutionChoice{+choice_owner, rule_id, accept}:
      owner_choice_scan_result(Nat.is_eq(owner, choice_owner), state)

def owner_choices(owner: Nat,
  choices: List<&2, EvolutionChoice>) -> EvolutionOwnerChoices:
  List.foldl(&2, EvolutionChoice, EvolutionOwnerChoices,
    owner_choice_scan_step, choices, EvolutionOwnerChoices{owner, 0n})

def owned_count_result(matches: Bool, state: EvolutionOwnedCount) ->
  EvolutionOwnedCount:
  match matches:
    case True{}:
      match state:
        case EvolutionOwnedCount{owner, count}:
          EvolutionOwnedCount{owner, Nat.add(count, 1n)}
    case False{}: state

def owned_count_step(state: EvolutionOwnedCount,
  input: Rewards.OwnedRewardInput) -> EvolutionOwnedCount:
  match state input:
    case EvolutionOwnedCount{+owner, count}
         Rewards.OwnedRewardInput{individual, base, ivs, alive, active}:
      owned_count_result(Nat.is_eq(owner, Rewards.individual_id(individual)),
        state)

def evolution_owned_count(owner: Nat,
  inputs: List<&2, Rewards.OwnedRewardInput>) -> EvolutionOwnedCount:
  List.foldl(&2, Rewards.OwnedRewardInput, EvolutionOwnedCount,
    owned_count_step, inputs, EvolutionOwnedCount{owner, 0n})

def individual_species(individual: Progression.Individual) -> Nat:
  match individual:
    case Progression.Individual{id, species, level, xp, current_hp, max_hp,
        ivs, moves, history, observations, unlocks, harmony}: species

def evolution_source_species_matches(+owner: Nat, +source_species: Nat,
  inputs: List<&2, Rewards.OwnedRewardInput>) -> Bool:
  match inputs:
    case Nil{}: False{}
    case Rewards.OwnedRewardInput{+individual, base, ivs, alive, active}
         <> +rest:
      Bool.or(Bool.and(Nat.is_eq(owner, Rewards.individual_id(individual)),
        Nat.is_eq(source_species, individual_species(individual))),
        evolution_source_species_matches(owner, source_species, rest))

def config_scan_result(matches: Bool, state: EvolutionConfigScan,
  input: EvolutionInput) -> EvolutionConfigScan:
  match matches:
    case False{}: state
    case True{}:
      match state:
        case EvolutionConfigScan{owner, selected, count}:
          EvolutionConfigScan{owner, Some{input}, Nat.add(count, 1n)}

def config_scan_step(state: EvolutionConfigScan,
  input: EvolutionInput) -> EvolutionConfigScan:
  match state input:
    case EvolutionConfigScan{+owner, selected, count}
         EvolutionInput{+input_owner, source_species, rules, targets, items, flags,
           time_profile, recipes, harmony_tier}:
      config_scan_result(Nat.is_eq(owner, input_owner), state, input)

def find_evolution_config(owner: Nat,
  inputs: List<&2, EvolutionInput>) -> EvolutionConfigScan:
  List.foldl(&2, EvolutionInput, EvolutionConfigScan, config_scan_step,
    inputs, EvolutionConfigScan{owner, None{}, 0n})

def valid_config_owner(owned_count: EvolutionOwnedCount,
  config_count: EvolutionConfigScan) -> Bool:
  match owned_count config_count:
    case EvolutionOwnedCount{owner, 1n}
         EvolutionConfigScan{config_owner, selected, 1n}:
      Nat.is_eq(owner, config_owner)
    case _ _: False{}

def evolution_configs_valid(+configs: List<&2, EvolutionInput>,
  +owned: List<&2, Rewards.OwnedRewardInput>) -> Bool:
  match configs:
    case Nil{}: True{}
    case EvolutionInput{+owner, source_species, rules, targets, items, flags, time_profile,
         recipes, harmony_tier} <> +rest:
      Bool.and(Bool.and(valid_config_owner(evolution_owned_count(owner, owned),
          find_evolution_config(owner, configs)),
        evolution_source_species_matches(owner, source_species, owned)),
        evolution_configs_valid(rest, owned))

def valid_choice_owner(owned_count: EvolutionOwnedCount,
  config_count: EvolutionConfigScan) -> Bool:
  match owned_count config_count:
    case EvolutionOwnedCount{owner, 1n}
         EvolutionConfigScan{config_owner, Some{input}, 1n}:
      Nat.is_eq(owner, config_owner)
    case _ _: False{}

def evolution_choices_valid(choices: List<&2, EvolutionChoice>,
  +configs: List<&2, EvolutionInput>,
  +owned: List<&2, Rewards.OwnedRewardInput>) -> Bool:
  match choices:
    case Nil{}: True{}
    case EvolutionChoice{+owner, rule_id, accept} <> +rest:
      Bool.and(valid_choice_owner(evolution_owned_count(owner, owned),
        find_evolution_config(owner, configs)),
        evolution_choices_valid(rest, configs, owned))

def evolution_context(input: EvolutionInput,
  individual: Progression.Individual) -> Progression.EvolutionContext:
  match input individual:
    case EvolutionInput{owner, source_species, rules, targets, items, flags, time_profile,
         recipes, harmony_tier}
         Progression.Individual{id, species, level, xp, current_hp, max_hp,
           ivs, moves, history, observations, unlocks, harmony}:
      Progression.EvolutionContext{level, items, flags, time_profile, moves,
        recipes, harmony_tier}

def replace_owned_individual(input: Rewards.OwnedRewardInput,
  individual: Progression.Individual, base: Progression.StatBlock) ->
  Rewards.OwnedRewardInput:
  match input:
    case Rewards.OwnedRewardInput{old, old_base, ivs, alive, active}:
      Rewards.OwnedRewardInput{individual, base, ivs, alive, active}

def evolution_applied_match(matches: Bool,
  individual: Progression.Individual, base: Progression.StatBlock,
  target_base: Progression.StatBlock) -> EvolutionDecision:
  match matches:
    case True{}:
      EvolutionDecision{EvolutionDecisionApplied{}, individual, target_base}
    case False{}:
      EvolutionDecision{EvolutionDecisionRejected{}, individual, base}

def evolution_applied_base(offer: Progression.EvolutionOffer,
  individual: Progression.Individual, owner: Nat,
  base: Progression.StatBlock,
  target: Maybe<&2, Progression.EvolutionTarget>) -> EvolutionDecision:
  match offer target:
    case Progression.EvolutionOffer{True{}, rule, species, automatic}
         Some{Progression.EvolutionTarget{+target_species, +target_base}}:
      evolution_applied_match(Nat.is_eq(species, target_species), individual,
        base, target_base)
    case _ _:
      EvolutionDecision{EvolutionDecisionRejected{}, individual, base}

def evolution_decision_result(result: ProgressionBridge.EvolutionStep,
  owner: Nat, base: Progression.StatBlock,
  target: Maybe<&2, Progression.EvolutionTarget>) -> EvolutionDecision:
  match result:
    case ProgressionBridge.EvolutionStep{
        ProgressionBridge.EvolutionApplied{}, individual, offer}:
      evolution_applied_base(offer, individual, owner, base, target)
    case ProgressionBridge.EvolutionStep{
        ProgressionBridge.EvolutionUnchanged{}, individual, offer}:
      EvolutionDecision{EvolutionDecisionApplied{}, individual, base}
    case ProgressionBridge.EvolutionStep{
        ProgressionBridge.EvolutionChoiceRequired{}, individual,
        Progression.EvolutionOffer{True{}, rule_id, target_species, False{}}}:
      EvolutionDecision{EvolutionDecisionOffered{owner, rule_id,
        target_species}, individual, base}
    case ProgressionBridge.EvolutionStep{
        ProgressionBridge.EvolutionInvalid{}, individual, offer}:
      EvolutionDecision{EvolutionDecisionRejected{}, individual, base}
    case ProgressionBridge.EvolutionStep{status, individual, offer}:
      EvolutionDecision{EvolutionDecisionRejected{}, individual, base}

def target_scan_unique_result(unique: Bool,
  selected: Maybe<&2, Progression.EvolutionTarget>) ->
  Maybe<&2, Progression.EvolutionTarget>:
  match unique:
    case True{}: selected
    case False{}: None{}

def target_scan_unique(scan: EvolutionTargetScan) ->
  Maybe<&2, Progression.EvolutionTarget>:
  match scan:
    case EvolutionTargetScan{species, selected, count}:
      target_scan_unique_result(Nat.is_eq(count, 1n), selected)

def manual_choice_zero(is_zero: Bool, owner: Nat,
  individual: Progression.Individual, base: Progression.StatBlock,
  offer: Progression.EvolutionOffer) -> EvolutionDecision:
  match is_zero:
    case False{}: EvolutionDecision{EvolutionDecisionRejected{}, individual,
      base}
    case True{}:
      match offer:
        case Progression.EvolutionOffer{True{}, rule_id, target_species,
             False{}}:
          EvolutionDecision{EvolutionDecisionOffered{owner, rule_id,
            target_species}, individual, base}
        case _:
          EvolutionDecision{EvolutionDecisionRejected{}, individual, base}

def offer_target(offer: Progression.EvolutionOffer) -> Nat:
  match offer:
    case Progression.EvolutionOffer{found, rule_id, target_species, automatic}:
      target_species

def accept_manual_selected(owner: Nat,
  individual: Progression.Individual,
  base: Progression.StatBlock,
  +context: Progression.EvolutionContext,
  rules: List<&2, Progression.EvolutionRule>,
  offer: Progression.EvolutionOffer,
  target: Maybe<&2, Progression.EvolutionTarget>) -> EvolutionDecision:
  match target:
    case None{}: EvolutionDecision{EvolutionDecisionRejected{}, individual, base}
    case Some{+value}:
      evolution_decision_result(ProgressionBridge.accept_evolution(
        individual, context, rules, value), owner, base, Some{value})

def resolve_manual_target(owner: Nat, rule_id: Nat,
  targets: List<&2, Progression.EvolutionTarget>,
  individual: Progression.Individual,
  base: Progression.StatBlock,
  +context: Progression.EvolutionContext,
  rules: List<&2, Progression.EvolutionRule>,
  +offer: Progression.EvolutionOffer) -> EvolutionDecision:
  +target_scan = find_evolution_target(offer_target(offer), targets)
  +selected = target_scan_unique(target_scan)
  accept_manual_selected(owner, individual, base, context, rules, offer,
    selected)

def manual_choice_selected(scan: EvolutionChoiceScan,
  owner: Nat, rule_id: Nat,
  targets: List<&2, Progression.EvolutionTarget>,
  individual: Progression.Individual,
  base: Progression.StatBlock,
  +context: Progression.EvolutionContext,
  rules: List<&2, Progression.EvolutionRule>,
  offer: Progression.EvolutionOffer) -> EvolutionDecision:
  match scan:
    case EvolutionChoiceScan{scan_owner, scan_rule, Some{choice}, count}:
      match choice:
        case EvolutionChoice{choice_owner, choice_rule, accept}:
          match accept:
            case False{}:
              EvolutionDecision{EvolutionDecisionApplied{}, individual, base}
            case True{}:
              resolve_manual_target(owner, rule_id, targets, individual, base,
                context, rules, offer)
    case _:
      EvolutionDecision{EvolutionDecisionRejected{}, individual, base}

def owner_choice_empty(scan: EvolutionOwnerChoices) -> Bool:
  match scan:
    case EvolutionOwnerChoices{owner, 0n}: True{}
    case _: False{}

def manual_choice_count(count_is_one: Bool,
  scan: EvolutionChoiceScan, owner: Nat, rule_id: Nat,
  targets: List<&2, Progression.EvolutionTarget>,
  individual: Progression.Individual,
  base: Progression.StatBlock,
  +context: Progression.EvolutionContext,
  rules: List<&2, Progression.EvolutionRule>,
  offer: Progression.EvolutionOffer,
  no_other_choice: Bool) -> EvolutionDecision:
  match count_is_one:
    case False{}:
      match scan:
        case EvolutionChoiceScan{scan_owner, scan_rule, selected, count}:
          manual_choice_zero(Bool.and(Nat.is_eq(count, 0n),
            no_other_choice), owner, individual, base,
            offer)
    case True{}:
      manual_choice_selected(scan, owner, rule_id, targets, individual, base,
        context, rules, offer)

def evolution_choice_scan_count(scan: EvolutionChoiceScan) -> Nat:
  match scan:
    case EvolutionChoiceScan{owner, rule_id, selected, count}: count

def resolve_manual_choice(+owner: Nat, +rule_id: Nat, target_species: Nat,
  rules: List<&2, Progression.EvolutionRule>,
  targets: List<&2, Progression.EvolutionTarget>,
  +choices: List<&2, EvolutionChoice>,
  individual: Progression.Individual,
  base: Progression.StatBlock,
  +context: Progression.EvolutionContext,
  offer: Progression.EvolutionOffer) -> EvolutionDecision:
  +scan = find_evolution_choice(owner, rule_id, choices)
  manual_choice_count(Nat.is_eq(evolution_choice_scan_count(scan), 1n), scan, owner, rule_id,
    targets, individual, base, context, rules, offer,
    owner_choice_empty(owner_choices(owner, choices)))

def reject_stale_owner_scan(scan: EvolutionOwnerChoices,
  individual: Progression.Individual,
  base: Progression.StatBlock) -> EvolutionDecision:
  match scan:
    case EvolutionOwnerChoices{owner, 0n}:
      EvolutionDecision{EvolutionDecisionApplied{}, individual, base}
    case _:
      EvolutionDecision{EvolutionDecisionRejected{}, individual, base}

def reject_stale_owner_choice(owner: Nat,
  choices: List<&2, EvolutionChoice>,
  individual: Progression.Individual,
  base: Progression.StatBlock) -> EvolutionDecision:
  reject_stale_owner_scan(owner_choices(owner, choices), individual, base)

def resolve_auto_target_valid(valid: Bool, owner: Nat,
  rules: List<&2, Progression.EvolutionRule>,
  targets: List<&2, Progression.EvolutionTarget>,
  individual: Progression.Individual,
  base: Progression.StatBlock,
  +context: Progression.EvolutionContext,
  offer: Progression.EvolutionOffer, target_species: Nat) -> EvolutionDecision:
  match valid:
    case False{}:
      EvolutionDecision{EvolutionDecisionRejected{}, individual, base}
    case True{}:
      +target_scan = find_evolution_target(target_species, targets)
      +target = target_scan_unique(target_scan)
      evolution_decision_result(ProgressionBridge.resolve_evolution(individual,
        context, rules, target), owner, base, target)

def resolve_auto_target(+owner: Nat,
  rules: List<&2, Progression.EvolutionRule>,
  targets: List<&2, Progression.EvolutionTarget>,
  choices: List<&2, EvolutionChoice>,
  individual: Progression.Individual,
  base: Progression.StatBlock,
  +context: Progression.EvolutionContext,
  offer: Progression.EvolutionOffer, target_species: Nat) -> EvolutionDecision:
  resolve_auto_target_valid(owner_choice_empty(owner_choices(owner, choices)),
    owner, rules, targets, individual, base, context, offer, target_species)

def resolve_evolution_offer(owner: Nat,
  rules: List<&2, Progression.EvolutionRule>,
  targets: List<&2, Progression.EvolutionTarget>,
  choices: List<&2, EvolutionChoice>,
  individual: Progression.Individual,
  base: Progression.StatBlock,
  +context: Progression.EvolutionContext,
  +offer: Progression.EvolutionOffer) -> EvolutionDecision:
  match offer:
    case Progression.EvolutionOffer{False{}, rule_id, target_species,
         automatic}:
      reject_stale_owner_choice(owner, choices, individual, base)
    case Progression.EvolutionOffer{True{}, rule_id, +target_species,
         True{}}:
      resolve_auto_target(owner, rules, targets, choices, individual, base,
        context, offer, target_species)
    case Progression.EvolutionOffer{True{}, rule_id, target_species, False{}}:
      resolve_manual_choice(owner, rule_id, target_species, rules, targets,
        choices, individual, base, context, offer)

def resolve_evolution_source(matches: Bool, owner: Nat,
  +rules: List<&2, Progression.EvolutionRule>,
  targets: List<&2, Progression.EvolutionTarget>,
  choices: List<&2, EvolutionChoice>,
  individual: Progression.Individual,
  base: Progression.StatBlock,
  +context: Progression.EvolutionContext) -> EvolutionDecision:
  match matches:
    case True{}:
      resolve_evolution_offer(owner, rules, targets, choices, individual, base,
        context, Progression.first_evolution(context, rules))
    case False{}:
      EvolutionDecision{EvolutionDecisionRejected{}, individual, base}

def resolve_evolution_input(+input: EvolutionInput,
  +individual: Progression.Individual,
  base: Progression.StatBlock,
  choices: List<&2, EvolutionChoice>) -> EvolutionDecision:
  match input:
    case EvolutionInput{+owner, +source_species, rules, targets, items, flags, time_profile,
        recipes, harmony_tier}:
      +context = evolution_context(input, individual)
      resolve_evolution_source(Nat.is_eq(source_species,
        individual_species(individual)), owner, rules, targets, choices,
        individual, base, context)

def append_evolved_row(decision: EvolutionDecision,
  input: Rewards.OwnedRewardInput) -> Rewards.OwnedRewardInput:
  match decision:
    case EvolutionDecision{EvolutionDecisionApplied{}, individual, base}:
      replace_owned_individual(input, individual, base)
    case EvolutionDecision{status, individual, base}:
      replace_owned_individual(input, individual, base)

def evolve_without_config_scan(scan: EvolutionOwnerChoices,
  input: Rewards.OwnedRewardInput) -> EvolutionRun:
  match scan:
    case EvolutionOwnerChoices{owner, 0n}:
      EvolutionRun{EvolutionRunComplete{}, [input]}
    case _:
      EvolutionRun{EvolutionRunRejected{}, [input]}

def evolve_ineligible_owner(owner: Nat, input: Rewards.OwnedRewardInput,
  individual: Progression.Individual, base: Progression.StatBlock,
  choices: List<&2, EvolutionChoice>) -> EvolutionRun:
  evolve_without_config_scan(owner_choices(owner, choices), input)

def run_from_decision(decision: EvolutionDecision,
  input: Rewards.OwnedRewardInput) -> EvolutionRun:
  match decision:
    case EvolutionDecision{EvolutionDecisionApplied{}, individual, base}:
      EvolutionRun{EvolutionRunComplete{},
        [replace_owned_individual(input, individual, base)]}
    case EvolutionDecision{EvolutionDecisionOffered{owner, rule_id,
        target_species}, individual, base}:
      EvolutionRun{EvolutionRunPending{owner, rule_id, target_species}, [input]}
    case EvolutionDecision{EvolutionDecisionRejected{}, individual, base}:
      EvolutionRun{EvolutionRunRejected{}, [input]}

def evolve_configured(config: EvolutionInput,
  input: Rewards.OwnedRewardInput,
  individual: Progression.Individual, base: Progression.StatBlock,
  choices: List<&2, EvolutionChoice>) -> EvolutionRun:
  run_from_decision(resolve_evolution_input(config, individual, base, choices),
    input)

def evolve_owned_config(scan: EvolutionConfigScan,
  input: Rewards.OwnedRewardInput,
  individual: Progression.Individual, base: Progression.StatBlock,
  configs: List<&2, EvolutionInput>, choices: List<&2, EvolutionChoice>) ->
  EvolutionRun:
  match scan:
    case EvolutionConfigScan{owner, None{}, 0n}:
      evolve_without_config_scan(owner_choices(owner, choices), input)
    case EvolutionConfigScan{owner, Some{config}, 1n}:
      evolve_configured(config, input, individual, base, choices)
    case _:
      EvolutionRun{EvolutionRunRejected{}, [input]}

def evolve_owned_activity(eligible: Bool, scan: EvolutionConfigScan,
  input: Rewards.OwnedRewardInput,
  +individual: Progression.Individual, base: Progression.StatBlock,
  configs: List<&2, EvolutionInput>, choices: List<&2, EvolutionChoice>) ->
  EvolutionRun:
  match eligible:
    case True{}:
      evolve_owned_config(scan, input, individual, base, configs, choices)
    case False{}:
      evolve_ineligible_owner(Rewards.individual_id(individual), input,
        individual, base, choices)

def evolve_owned_row(+input: Rewards.OwnedRewardInput,
  +configs: List<&2, EvolutionInput>, choices: List<&2, EvolutionChoice>) ->
  EvolutionRun:
  match input:
    case Rewards.OwnedRewardInput{+individual, base, ivs, alive, active}:
      evolve_owned_activity(Bool.or(alive, active),
        find_evolution_config(Rewards.individual_id(individual), configs),
        input, individual, base, configs, choices)

def merge_evolution_rows(left: EvolutionRun, right: EvolutionRun) -> EvolutionRun:
  match left right:
    case EvolutionRun{EvolutionRunComplete{}, left_inputs}
         EvolutionRun{right_status, right_inputs}:
      EvolutionRun{right_status,
        List.append(&2, Rewards.OwnedRewardInput, left_inputs, right_inputs)}
    case EvolutionRun{status, left_inputs} right:
      EvolutionRun{status, left_inputs}

def evolve_fold_row(run: EvolutionRun, input: Rewards.OwnedRewardInput,
  +configs: List<&2, EvolutionInput>, +choices: List<&2, EvolutionChoice>) ->
  EvolutionFold:
  match run:
    case EvolutionRun{EvolutionRunComplete{}, old_inputs}:
      EvolutionFold{merge_evolution_rows(run,
        evolve_owned_row(input, configs, choices)), configs, choices}
    case _:
      EvolutionFold{run, configs, choices}

def evolve_row_step(state: EvolutionFold,
  input: Rewards.OwnedRewardInput) -> EvolutionFold:
  match state:
    case EvolutionFold{run, configs, choices}:
      evolve_fold_row(run, input, configs, choices)

def extract_evolution_run(fold: EvolutionFold) -> EvolutionRun:
  match fold:
    case EvolutionFold{run, configs, choices}: run

def evolve_owned_rows(inputs: List<&2, Rewards.OwnedRewardInput>,
  configs: List<&2, EvolutionInput>, choices: List<&2, EvolutionChoice>) ->
  EvolutionRun:
  extract_evolution_run(List.foldl(&2, Rewards.OwnedRewardInput,
    EvolutionFold, evolve_row_step, inputs,
    EvolutionFold{EvolutionRun{EvolutionRunComplete{}, []}, configs, choices}))

def progression_after_commit(updated: Maybe<Context>, old: Context) ->
  ProgressionBridgeResult:
  match updated:
    case None{}: ProgressionBridgeResult{ProgressionRejected{}, old}
    case Some{next_context}:
      ProgressionBridgeResult{ProgressionCommitted{}, next_context}

def progression_transaction_result(result: Rewards.TransactionResult,
  +context: Context) -> ProgressionBridgeResult:
  match result:
    case Rewards.RewardResult{Rewards.RewardCommitted{}, owned, economy,
        ledger}:
      progression_after_commit(context_after_commit(context, owned, economy,
        ledger), context)
    case Rewards.RewardResult{Rewards.RewardRejected{}, owned, economy,
        ledger}:
      ProgressionBridgeResult{ProgressionRejected{}, context}
    case Rewards.RewardResult{Rewards.RewardSkipped{}, owned, economy,
        ledger}:
      ProgressionBridgeResult{ProgressionSkipped{}, context}
    case Rewards.RewardChoiceRequired{pending}:
      ProgressionBridgeResult{ProgressionLearningChoice{pending}, context}

def progression_transaction(outcome: Progression.ProgressionOutcome,
  learning: List<&2, Rewards.SpeciesLearning>,
  choices: List<&2, Rewards.LearningChoice>, +context: Context) ->
  ProgressionBridgeResult:
  match context:
    case Context{encounter_id, defeated, +owned_inputs, item_rewards,
        +economy, +ledger}:
      progression_transaction_result(Rewards.transaction_with_learning(
        outcome, encounter_id, defeated, owned_inputs, item_rewards, economy,
        ledger, learning, choices), context)

def resolve_with_learning_outcome(
  outcome: Maybe<&2, Progression.ProgressionOutcome>,
  learning: List<&2, Rewards.SpeciesLearning>,
  choices: List<&2, Rewards.LearningChoice>, context: Context) ->
  ProgressionBridgeResult:
  match outcome:
    case None{}:
      ProgressionBridgeResult{ProgressionNotTerminal{}, context}
    case Some{value}:
      progression_transaction(value, learning, choices, context)

# Choice-aware terminal reward entry point. Call again with the original
# context and accumulated choices after each explicit move-learning decision.
def resolve_with_learning(+events: List<&2, RewardEvent>, +context: Context,
  learning: List<&2, Rewards.SpeciesLearning>,
  choices: List<&2, Rewards.LearningChoice>) -> ProgressionBridgeResult:
  resolve_with_learning_outcome(
    completion_outcome(events, any_capture_success(events)), learning, choices,
    context)

def evolution_commit_result(run: EvolutionRun, +context: Context,
  economy: Economy.State, ledger: Progression.RewardLedger) ->
  ProgressionBridgeResult:
  match run:
    case EvolutionRun{EvolutionRunComplete{}, inputs}:
      progression_after_commit(replace_context_owned(Some{inputs}, context,
        economy, ledger), context)
    case EvolutionRun{EvolutionRunPending{owner, rule_id, target_species}, _}:
      ProgressionBridgeResult{ProgressionEvolutionChoice{owner, rule_id,
        target_species}, context}
    case EvolutionRun{EvolutionRunRejected{}, _}:
      ProgressionBridgeResult{ProgressionRejected{}, context}

def staged_evolution_valid(valid: Bool,
  inputs: List<&2, Rewards.OwnedRewardInput>,
  +context: Context, economy: Economy.State,
  ledger: Progression.RewardLedger,
  evolution: List<&2, EvolutionInput>,
  choices: List<&2, EvolutionChoice>) -> ProgressionBridgeResult:
  match valid:
    case False{}: ProgressionBridgeResult{ProgressionRejected{}, context}
    case True{}:
      evolution_commit_result(evolve_owned_rows(inputs, evolution, choices),
        context, economy, ledger)

def staged_evolution_result(staged: Maybe<List<&2,
  Rewards.OwnedRewardInput>>, +context: Context, economy: Economy.State,
  ledger: Progression.RewardLedger,
  +evolution: List<&2, EvolutionInput>,
  +choices: List<&2, EvolutionChoice>) -> ProgressionBridgeResult:
  match staged:
    case None{}: ProgressionBridgeResult{ProgressionRejected{}, context}
    case Some{+inputs}:
      staged_evolution_valid(Bool.and(evolution_configs_valid(evolution,
        inputs), evolution_choices_valid(choices, evolution, inputs)),
        inputs, context, economy, ledger, evolution, choices)

def stage_evolution_transaction(owned: List<&2, Progression.Individual>,
  economy: Economy.State, ledger: Progression.RewardLedger, +context: Context,
  evolution: List<&2, EvolutionInput>,
  choices: List<&2, EvolutionChoice>) -> ProgressionBridgeResult:
  match context:
    case Context{encounter_id, defeated, +owned_inputs, item_rewards,
        old_economy, old_ledger}:
      staged_evolution_result(replace_owned_step(owned_inputs, owned), context,
        economy, ledger, evolution, choices)

def progression_transaction_with_evolution(
  result: Rewards.TransactionResult, +context: Context,
  evolution: List<&2, EvolutionInput>,
  choices: List<&2, EvolutionChoice>) -> ProgressionBridgeResult:
  match result:
    case Rewards.RewardResult{Rewards.RewardCommitted{}, owned, economy,
        ledger}:
      stage_evolution_transaction(owned, economy, ledger, context, evolution,
        choices)
    case Rewards.RewardResult{Rewards.RewardRejected{}, owned, economy,
        ledger}:
      ProgressionBridgeResult{ProgressionRejected{}, context}
    case Rewards.RewardResult{Rewards.RewardSkipped{}, owned, economy,
        ledger}:
      ProgressionBridgeResult{ProgressionSkipped{}, context}
    case Rewards.RewardChoiceRequired{pending}:
      ProgressionBridgeResult{ProgressionLearningChoice{pending}, context}

def progression_transaction_all(outcome: Progression.ProgressionOutcome,
  learning: List<&2, Rewards.SpeciesLearning>,
  learning_choices: List<&2, Rewards.LearningChoice>,
  evolution: List<&2, EvolutionInput>,
  evolution_choices: List<&2, EvolutionChoice>, +context: Context) ->
  ProgressionBridgeResult:
  match context:
    case Context{encounter_id, defeated, +owned_inputs, item_rewards,
        +economy, +ledger}:
      progression_transaction_with_evolution(
        Rewards.transaction_with_learning(outcome, encounter_id, defeated,
          owned_inputs, item_rewards, economy, ledger, learning,
          learning_choices), context, evolution, evolution_choices)

def resolve_with_progression_outcome(
  outcome: Maybe<&2, Progression.ProgressionOutcome>, learning:
  List<&2, Rewards.SpeciesLearning>,
  learning_choices: List<&2, Rewards.LearningChoice>,
  evolution: List<&2, EvolutionInput>,
  evolution_choices: List<&2, EvolutionChoice>, context: Context) ->
  ProgressionBridgeResult:
  match outcome:
    case None{}:
      ProgressionBridgeResult{ProgressionNotTerminal{}, context}
    case Some{value}:
      progression_transaction_all(value, learning, learning_choices,
        evolution, evolution_choices, context)

# The complete progression barrier stages learning, then evolution, and only
# returns a committed context after all automatic/manual evolution work settles.
def resolve_with_progression(+events: List<&2, RewardEvent>, +context: Context,
  learning: List<&2, Rewards.SpeciesLearning>,
  learning_choices: List<&2, Rewards.LearningChoice>,
  evolution: List<&2, EvolutionInput>,
  evolution_choices: List<&2, EvolutionChoice>) -> ProgressionBridgeResult:
  resolve_with_progression_outcome(
    completion_outcome(events, any_capture_success(events)), learning,
    learning_choices, evolution, evolution_choices, context)
