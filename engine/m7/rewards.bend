import Base
import ../progression/core.bend as Progression
import ../economy/core.bend as Economy

# A save-owned individual paired with the engine-owned growth inputs needed to
# validate and apply one encounter XP award.
type OwnedRewardInput is Data:
  OwnedRewardInput{individual: Progression.Individual,
    base: Progression.StatBlock, ivs: Progression.StatBlock,
    alive: Bool, previously_active: Bool}

type EncounterItem is Data:
  EncounterItem{item_id: Nat, quantity: Nat}

# Validated inert species learning data supplied by the host content binder.
type LevelMove is Data:
  LevelMove{level: U32, move: U32}

type SpeciesLearning is Data:
  SpeciesLearning{species: Nat, entries: List<&2, LevelMove>}

type LearningChoice is Data:
  LearningChoice{individual: Nat, level: U32, move: U32, accept: Bool,
    replacement: Maybe<&2, U32>}

type RewardStatus is Data:
  RewardCommitted{}
  RewardRejected{}
  RewardSkipped{}

type TransactionResult is Data:
  RewardResult{status: RewardStatus,
    owned: List<&2, Progression.Individual>, economy: Economy.State,
    ledger: Progression.RewardLedger}
  RewardChoiceRequired{pending: PendingLearning}

type PendingLearning is Data:
  PendingLearning{outcome: Progression.ProgressionOutcome,
    encounter_id: Nat, defeated: List<&2, Progression.DefeatedReward>,
    inputs: List<&2, OwnedRewardInput>, items: List<&2, EncounterItem>,
    economy: Economy.State, ledger: Progression.RewardLedger,
    learning: List<&2, SpeciesLearning>, choices: List<&2, LearningChoice>,
    offered_individual: Nat, offered_level: U32, offered_move: U32}

type LearningScan is Data:
  LearningScan{individual: Nat, level: U32, move: U32,
    found: Maybe<&2, LearningChoice>, count: Nat}

type LearningAccumulator is Data:
  LearningAccumulator{id: Nat, old_level: U32, new_level: U32,
    capacity: U32, choices: List<&2, LearningChoice>,
    moves: List<&2, U32>, history: List<&2, Progression.MoveLearningRecord>,
    pending: Maybe<&2, LevelMove>, invalid: Bool, used_choices: Nat}

type LearningPreview is Data:
  LearningReady{individual: Progression.Individual}
  LearningPreviewChoice{individual: Progression.Individual, level: U32,
    offered: U32}
  LearningRejected{individual: Progression.Individual}

type LearningRow is Data:
  LearningRow{input: OwnedRewardInput,
    updated: Progression.Individual, catalog: SpeciesLearning}

type OwnedUpdate is Data:
  OwnedUpdate{input: OwnedRewardInput, updated: Progression.Individual}

type LearningCatalogScan is Data:
  LearningCatalogScan{species: Nat, found: Maybe<&2, SpeciesLearning>,
    matches: Nat}

type LearningFoldState is Data:
  LearningFoldState{owned: List<&2, Progression.Individual>,
    catalog: List<&2, SpeciesLearning>, capacity: Nat,
    choices: List<&2, LearningChoice>,
    blocked_individual: Maybe<&2, Nat>, blocked_level: Maybe<&2, U32>,
    blocked_move: Maybe<&2, U32>,
    invalid: Bool}

type LearningRequest is Data:
  LearningRequest{outcome: Progression.ProgressionOutcome,
    encounter_id: Nat, defeated: List<&2, Progression.DefeatedReward>,
    inputs: List<&2, OwnedRewardInput>, items: List<&2, EncounterItem>,
    economy: Economy.State, ledger: Progression.RewardLedger,
    learning: List<&2, SpeciesLearning>, choices: List<&2, LearningChoice>}

type LearningStep is Data:
  LearningResolved{moves: List<&2, U32>,
    history: List<&2, Progression.MoveLearningRecord>}
  LearningNeedsChoice{moves: List<&2, U32>, offered: U32,
    history: List<&2, Progression.MoveLearningRecord>}
  LearningInvalidChoice{}

type LearningPlan is Data:
  LearningPlanReady{individuals: List<&2, Progression.Individual>}
  LearningPlanBlocked{individual: Nat, offered: U32}
  LearningPlanInvalid{}

def individual_progress(value: Progression.Individual) -> Progression.ProgressState:
  match value:
    case Progression.Individual{id, species, level, xp, current_hp, max_hp,
        ivs, moves, move_history, observations, unlocks, harmony}:
      Progression.ProgressState{level, xp, current_hp}

def individual_id(value: Progression.Individual) -> Nat:
  match value:
    case Progression.Individual{id, species, level, xp, current_hp, max_hp,
        ivs, moves, move_history, observations, unlocks, harmony}: id

def stat_blocks_equal(left: Progression.StatBlock,
  right: Progression.StatBlock) -> Bool:
  match left right:
    case Progression.StatBlock{lh, la, ld, lsa, lsd, lsp}
         Progression.StatBlock{rh, ra, rd, rsa, rsd, rsp}:
      Bool.and(U32.is_eq(lh, rh), Bool.and(U32.is_eq(la, ra),
      Bool.and(U32.is_eq(ld, rd), Bool.and(U32.is_eq(lsa, rsa),
      Bool.and(U32.is_eq(lsd, rsd), U32.is_eq(lsp, rsp))))))

def calculated_max_matches(stats: Maybe<&2, Progression.StatBlock>,
  stored_max: U32) -> Bool:
  match stats:
    case None{}: False{}
    case Some{Progression.StatBlock{calculated_max, _, _, _, _, _}}:
      U32.is_eq(calculated_max, stored_max)

def owned_input_consistent(value: Progression.Individual,
  base: Progression.StatBlock, +supplied_ivs: Progression.StatBlock) -> Bool:
  match value:
    case Progression.Individual{id, species, level, xp, current_hp,
        stored_max, stored_ivs, moves, history, observations, unlocks, harmony}:
      Bool.and(stat_blocks_equal(stored_ivs, supplied_ivs),
        calculated_max_matches(Progression.calculate_stats(base,
          supplied_ivs, level), stored_max))

def reward_input_valid(input: OwnedRewardInput) -> Bool:
  match input:
    case OwnedRewardInput{individual, base, ivs, alive, previously_active}:
      owned_input_consistent(individual, base, ivs)

def eligible_inputs(inputs: List<&2, OwnedRewardInput>) ->
  List<&2, Progression.RewardParticipant>:
  match inputs:
    case Nil{}: []
    case OwnedRewardInput{individual, base, ivs, alive, previously_active} <> rest:
      Progression.RewardParticipant{individual_id(individual), alive,
        previously_active} <> eligible_inputs(rest)

def xp_for(+id: Nat, awards: List<&2, Progression.ParticipantXp>) -> U32:
  match awards:
    case Nil{}: 0
    case Progression.ParticipantXp{other, xp} <> rest:
      U32.add(U32.mul(xp, Bool.to_u32(Nat.is_eq(id, other))),
        xp_for(id, rest))

def rebuild_individual(value: Progression.Individual,
  state: Progression.ProgressState, max_hp: U32) -> Progression.Individual:
  match value state:
    case Progression.Individual{id, species, old_level, old_xp, old_hp,
        old_max, ivs, moves, move_history, observations, unlocks, harmony}
         Progression.ProgressState{level, xp, current_hp}:
      Progression.Individual{id, species, level, xp, current_hp, max_hp,
        ivs, moves, move_history, observations, unlocks, harmony}

def rebuild_with_stats(stats: Maybe<&2, Progression.StatBlock>,
  individual: Progression.Individual, state: Progression.ProgressState) ->
  Maybe<&2, Progression.Individual>:
  match stats:
    case None{}: None{}
    case Some{Progression.StatBlock{new_max_hp, _, _, _, _, _}}:
      Some{rebuild_individual(individual, state, new_max_hp)}

def finish_update(result: Progression.ProgressResult,
  individual: Progression.Individual, base: Progression.StatBlock,
  ivs: Progression.StatBlock) -> Maybe<&2, Progression.Individual>:
  match result:
    case Progression.ProgressRejected{state}: None{}
    case Progression.ProgressAccepted{state, levels_gained}:
      match state:
        case Progression.ProgressState{+new_level, new_xp, new_hp}:
          rebuild_with_stats(Progression.calculate_stats(base, ivs,
            new_level), individual, state)

def update_one(valid: Bool, input: OwnedRewardInput,
  awards: List<&2, Progression.ParticipantXp>) -> Maybe<&2, Progression.Individual>:
  match valid input:
    case False{} _: None{}
    case True{} OwnedRewardInput{+individual, +base, +ivs, alive, previously_active}:
      match individual:
        case Progression.Individual{id, species, level, xp, current_hp,
            max_hp, stored_ivs, moves, move_history, observations, unlocks,
            harmony}:
          +awarded = xp_for(id, awards)
          finish_update(Progression.apply_xp(base, ivs,
            Progression.ProgressState{level, xp, current_hp}, awarded),
            individual, base, ivs)

def update_merge(one: Maybe<&2, Progression.Individual>,
  tail: Maybe<List<&2, Progression.Individual>>) ->
  Maybe<List<&2, Progression.Individual>>:
  match one tail:
    case None{} _: None{}
    case Some{updated} None{}: None{}
    case Some{updated} Some{values}: Some{updated <> values}

def update_all_step(inputs: List<&2, OwnedRewardInput>,
  +awards: List<&2, Progression.ParticipantXp>) ->
  Maybe<List<&2, Progression.Individual>>:
  match inputs:
    case Nil{}: Some{[]}
    case +input <> rest:
      update_merge(update_one(reward_input_valid(input), input, awards),
        update_all_step(rest, awards))

def update_all(inputs: List<&2, OwnedRewardInput>,
  +awards: List<&2, Progression.ParticipantXp>) ->
  Maybe<List<&2, Progression.Individual>>:
  update_all_step(inputs, awards)

def replace_inventory(adjusted: Maybe<List<&2, Economy.ItemStack>>,
  state: Economy.State) -> Maybe<Economy.State>:
  match adjusted state:
    case None{} _: None{}
    case Some{inventory} Economy.State{capacity, tier, party, storage, moves,
        currency, old_inventory}:
      Some{Economy.State{capacity, tier, party, storage, moves, currency,
        inventory}}

def items_step(items: List<&2, EncounterItem>,
  current: Maybe<Economy.State>) -> Maybe<Economy.State>:
  match items current:
    case Nil{} _: current
    case EncounterItem{item_id, quantity} <> rest None{}: None{}
    case EncounterItem{item_id, quantity} <> rest
         Some{Economy.State{+capacity, tier, party, storage, moves, currency,
           +inventory}}:
      items_step(rest, replace_inventory(Economy.adjust_item(inventory,
        Economy.ItemId{item_id}, quantity, True{}, capacity),
        Economy.State{capacity, tier, party, storage, moves, currency,
          inventory}))

def economy_capacity(state: Economy.State) -> Economy.Capacity:
  match state:
    case Economy.State{capacity, tier, party, storage, moves, currency, inventory}:
      capacity

def apply_currency(result: Economy.Transaction) -> Maybe<Economy.State>:
  match result:
    case Economy.Rejected{state, reason}: None{}
    case Economy.Accepted{state}: Some{state}

def apply_items_and_currency(items: Maybe<Economy.State>, currency: U32) ->
  Maybe<Economy.State>:
  match items:
    case None{}: None{}
    case Some{state}:
      apply_currency(Economy.reward(state, U32.to_nat(currency),
        Economy.ItemId{0n}, 0n))

def items_valid(items: List<&2, EncounterItem>) -> Bool:
  match items:
    case Nil{}: True{}
    case EncounterItem{item_id, quantity} <> rest:
      Bool.and(Nat.is_gt(quantity, 0n),
        Bool.and(Nat.is_le(item_id, 4294967295n), items_valid(rest)))

def owned_individuals(inputs: List<&2, OwnedRewardInput>) ->
  List<&2, Progression.Individual>:
  match inputs:
    case Nil{}: []
    case OwnedRewardInput{individual, base, ivs, alive, previously_active} <> rest:
      individual <> owned_individuals(rest)

def learning_scan_first(found: Maybe<&2, LearningChoice>,
  choice: LearningChoice) -> Maybe<&2, LearningChoice>:
  match found:
    case None{}: Some{choice}
    case Some{old}: Some{old}

def update_learning_scan(matches: Bool, id: Nat, +level: U32, move: U32,
  found: Maybe<&2, LearningChoice>, count: Nat,
  choice_id: Nat, choice_level: U32, choice_move: U32, accept: Bool,
  replacement: Maybe<&2, U32>) -> LearningScan:
  match matches:
    case False{}: LearningScan{id, level, move, found, count}
    case True{}:
      LearningScan{id, level, move, learning_scan_first(found,
        LearningChoice{choice_id, choice_level, choice_move, accept, replacement}),
        Nat.add(count, 1n)}

def scan_learning_choice(state: LearningScan,
  choice: LearningChoice) -> LearningScan:
  match state choice:
    case LearningScan{+id, +level, +move, found, count}
         LearningChoice{+choice_id, +choice_level, +choice_move, accept, replacement}:
      update_learning_scan(Bool.and(Nat.is_eq(id, choice_id),
        Bool.and(U32.is_eq(level, choice_level),
          U32.is_eq(move, choice_move))), id, level, move, found, count, choice_id,
        choice_level, choice_move, accept, replacement)

def request_choice_scan(state: LearningAccumulator, level: U32, offered: U32) ->
  LearningScan:
  match state:
    case LearningAccumulator{id, old_level, new_level, capacity, choices,
        moves, history, pending, invalid, used}:
      List.foldl(&2, LearningChoice, LearningScan, scan_learning_choice,
        choices, LearningScan{id, level, offered, None{}, 0n})

def retain_learning_state(state: LearningAccumulator,
  moves: List<&2, U32>, history: List<&2, Progression.MoveLearningRecord>) ->
  LearningAccumulator:
  match state:
    case LearningAccumulator{id, old_level, new_level, capacity, choices,
        old_moves, old_history, pending, invalid, used}:
      LearningAccumulator{id, old_level, new_level, capacity, choices, moves,
        history, pending, invalid, used}

def retain_learning_result(state: LearningAccumulator,
  result: Progression.MoveLearning) -> LearningAccumulator:
  match result:
    case Progression.MoveLearned{moves, history}:
      retain_learning_state(state, moves, history)
    case Progression.MoveDeclined{moves, history}:
      retain_learning_state(state, moves, history)
    case Progression.MoveReplaced{moves, history}:
      retain_learning_state(state, moves, history)
    case Progression.MoveChoiceRequired{moves, offered, history}:
      retain_learning_state(state, moves, history)

def apply_learning_choice_result(+state: LearningAccumulator,
  result: Progression.MoveLearning) -> LearningAccumulator:
  match state result:
    case LearningAccumulator{id, old_level, new_level, capacity, choices,
        old_moves, old_history, pending, invalid, used}
         Progression.MoveChoiceRequired{moves, offered, history}:
      LearningAccumulator{id, old_level, new_level, capacity, choices,
        old_moves, old_history, None{}, True{}, used}
    case LearningAccumulator{id, old_level, new_level, capacity, choices,
        old_moves, old_history, pending, invalid, used}
         Progression.MoveLearned{moves, history}:
      LearningAccumulator{id, old_level, new_level, capacity, choices, moves,
        history, pending, invalid, used}
    case LearningAccumulator{id, old_level, new_level, capacity, choices,
        old_moves, old_history, pending, invalid, used}
         Progression.MoveDeclined{moves, history}:
      LearningAccumulator{id, old_level, new_level, capacity, choices, moves,
        history, pending, invalid, Nat.add(used, 1n)}
    case LearningAccumulator{id, old_level, new_level, capacity, choices,
        old_moves, old_history, pending, invalid, used}
         Progression.MoveReplaced{moves, history}:
      LearningAccumulator{id, old_level, new_level, capacity, choices, moves,
        history, pending, invalid, Nat.add(used, 1n)}

def apply_learning_decision(state: LearningAccumulator,
  barrier: Progression.MoveLearning, accept: Bool,
  replacement: Maybe<&2, U32>) -> LearningAccumulator:
  apply_learning_choice_result(state,
    Progression.resolve_move_choice(barrier, accept, replacement))


def apply_scanned_choice(valid: Bool, state: LearningAccumulator,
  offered: U32, barrier: Progression.MoveLearning,
  choice: LearningChoice) -> LearningAccumulator:
  match valid:
    case False{}:
      match state:
        case LearningAccumulator{id, old_level, new_level, capacity, choices,
            moves, history, pending, invalid, used}:
          LearningAccumulator{id, old_level, new_level, capacity, choices,
            moves, history, None{}, True{}, used}
    case True{}:
      match choice:
        case LearningChoice{id, level, move, accept, replacement}:
          apply_learning_decision(state, barrier, accept, replacement)

def mark_learning_pending(state: LearningAccumulator,
  level: U32, offered: U32) -> LearningAccumulator:
  match state:
    case LearningAccumulator{id, old_level, new_level, capacity, choices,
        moves, history, pending, invalid, used}:
      LearningAccumulator{id, old_level, new_level, capacity, choices, moves,
        history, Some{LevelMove{level, offered}}, invalid, used}

def apply_learning_scan(state: LearningAccumulator, level: U32, offered: U32,
  barrier: Progression.MoveLearning, scan: LearningScan) -> LearningAccumulator:
  match scan:
    case LearningScan{id, level, move, None{}, count}:
      mark_learning_pending(state, level, offered)
    case LearningScan{id, level, move, Some{choice}, count}:
      apply_scanned_choice(Nat.is_eq(count, 1n), state, offered, barrier,
        choice)

def resolve_learning_request(+state: LearningAccumulator, +level: U32, offered: U32,
  +request: Progression.MoveLearning) -> LearningAccumulator:
  match request:
    case Progression.MoveLearned{moves, history}:
      retain_learning_state(state, moves, history)
    case Progression.MoveDeclined{moves, history}:
      retain_learning_state(state, moves, history)
    case Progression.MoveReplaced{moves, history}:
      retain_learning_state(state, moves, history)
    case Progression.MoveChoiceRequired{moves, +offered, history}:
      apply_learning_scan(state, level, offered, request,
        request_choice_scan(state, level, offered))

def apply_crossed_level(crosses: Bool, level: U32, id: Nat, old_level: U32,
  new_level: U32, +capacity: U32, choices: List<&2, LearningChoice>,
  +moves: List<&2, U32>,
  +history: List<&2, Progression.MoveLearningRecord>,
  pending: Maybe<&2, LevelMove>, invalid: Bool, used: Nat, +move: U32) -> LearningAccumulator:
  match crosses:
    case False{}:
      LearningAccumulator{id, old_level, new_level, capacity, choices, moves,
        history, pending, invalid, used}
    case True{}:
      resolve_learning_request(LearningAccumulator{id, old_level, new_level,
        capacity, choices, moves, history, pending, invalid, used}, level, move,
        Progression.request_move(moves, move, capacity, history))

def apply_level_move_values(pending: Maybe<&2, LevelMove>, invalid: Bool, used: Nat,
  crosses: Bool, level: U32, id: Nat, old_level: U32, new_level: U32,
  +capacity: U32, choices: List<&2, LearningChoice>, +moves: List<&2, U32>,
  +history: List<&2, Progression.MoveLearningRecord>, +move: U32) ->
  LearningAccumulator:
  match pending invalid:
    case Some{offered} _: LearningAccumulator{id, old_level, new_level,
      capacity, choices, moves, history, Some{offered}, invalid, used}
    case None{} True{}: LearningAccumulator{id, old_level, new_level,
      capacity, choices, moves, history, None{}, True{}, used}
    case None{} False{}:
      apply_crossed_level(crosses, level, id, old_level, new_level, capacity,
        choices, moves, history, pending, invalid, used, move)

def apply_level_move(state: LearningAccumulator,
  entry: LevelMove) -> LearningAccumulator:
  match state entry:
    case LearningAccumulator{+id, +old_level, +new_level, capacity, +choices,
        +moves, +history, pending, invalid, used} LevelMove{+level, move}:
      apply_level_move_values(pending, invalid,
        used,
        Bool.and(U32.is_gt(level, old_level),
        U32.is_le(level, new_level)), level, id, old_level, new_level, capacity,
        choices, moves, history, move)

def finalize_learning_state(pending: Maybe<&2, LevelMove>, invalid: Bool,
  individual: Progression.Individual, moves: List<&2, U32>,
  history: List<&2, Progression.MoveLearningRecord>) -> LearningPreview:
  match pending invalid:
    case Some{LevelMove{offered_level, offered}} False{}:
      LearningPreviewChoice{individual, offered_level, offered}
    case _ True{}: LearningRejected{individual}
    case None{} False{}:
      LearningReady{Progression.commit_move_learning(individual,
        Progression.MoveLearned{moves, history})}
    case None{} _: LearningRejected{individual}

def finalize_learning_flags(choices_valid: Bool, pending: Maybe<&2, LevelMove>,
  invalid: Bool,
  individual: Progression.Individual, moves: List<&2, U32>,
  history: List<&2, Progression.MoveLearningRecord>) -> LearningPreview:
  match choices_valid:
    case False{}: LearningRejected{individual}
    case True{}:
      finalize_learning_state(pending, invalid, individual, moves, history)

def choices_for_individual(+id: Nat,
  choices: List<&2, LearningChoice>) -> Nat:
  match choices:
    case Nil{}: 0n
    case LearningChoice{owner, level, move, accept, replacement} <> rest:
      Nat.add(U32.to_nat(Bool.to_u32(Nat.is_eq(id, owner))),
        choices_for_individual(id, rest))


def finalize_learning(state: LearningAccumulator,
  individual: Progression.Individual) -> LearningPreview:
  match state:
    case LearningAccumulator{id, old_level, new_level, capacity, choices,
        moves, history, pending, invalid, used}:
      finalize_learning_flags(Nat.is_eq(used,
        choices_for_individual(id, choices)), pending, invalid,
        individual, moves, history)

def learn_level_moves(+individual: Progression.Individual, old_level: U32,
  new_level: U32, entries: List<&2, LevelMove>, capacity: Nat,
  choices: List<&2, LearningChoice>) -> LearningPreview:
  match individual:
    case Progression.Individual{id, species, level, xp, current_hp, max_hp,
        ivs, +moves, +history, observations, unlocks, harmony}:
      finalize_learning(List.foldl(&2, LevelMove, LearningAccumulator,
        apply_level_move, entries, LearningAccumulator{id, old_level,
        new_level, U32.from_nat(capacity), choices, moves, history, None{},
        False{}, 0n}), individual)

def transaction_economy(updated: Maybe<Economy.State>,
  individuals: List<&2, Progression.Individual>,
  next_ledger: Progression.RewardLedger,
  inputs: List<&2, OwnedRewardInput>, economy: Economy.State,
  ledger: Progression.RewardLedger) -> TransactionResult:
  match updated:
    case None{}:
      RewardResult{RewardRejected{}, owned_individuals(inputs), economy, ledger}
    case Some{next_economy}:
      RewardResult{RewardCommitted{}, individuals, next_economy, next_ledger}

def transaction_xp(updated: Maybe<List<&2, Progression.Individual>>,
  currency: U32, next_ledger: Progression.RewardLedger,
  +inputs: List<&2, OwnedRewardInput>, +items: List<&2, EncounterItem>,
  +economy: Economy.State, ledger: Progression.RewardLedger) -> TransactionResult:
  match updated:
    case None{}:
      RewardResult{RewardRejected{}, owned_individuals(inputs), economy, ledger}
    case Some{individuals}:
      transaction_economy(apply_items_and_currency(items_step(items, Some{economy}),
        currency), individuals, next_ledger, inputs, economy, ledger)

def transaction_prepared(valid_items: Bool, plan: Progression.RewardPlan,
  next_ledger: Progression.RewardLedger,
  +inputs: List<&2, OwnedRewardInput>, items: List<&2, EncounterItem>,
  +economy: Economy.State, ledger: Progression.RewardLedger) -> TransactionResult:
  match valid_items:
    case False{}:
      RewardResult{RewardRejected{}, owned_individuals(inputs), economy, ledger}
    case True{}:
      match plan:
        case Progression.RewardPlan{awards, currency}:
          transaction_xp(update_all(inputs, awards), currency, next_ledger,
            inputs, items, economy, ledger)

def transaction_preparation(preparation: Progression.RewardPreparation,
  +inputs: List<&2, OwnedRewardInput>, +items: List<&2, EncounterItem>,
  +economy: Economy.State, ledger: Progression.RewardLedger) -> TransactionResult:
  match preparation:
    case Progression.RewardsSkipped{next_ledger}:
      RewardResult{RewardSkipped{}, owned_individuals(inputs), economy, ledger}
    case Progression.RewardsRejected{next_ledger}:
      RewardResult{RewardRejected{}, owned_individuals(inputs), economy, ledger}
    case Progression.RewardsPrepared{next_ledger, plan}:
      transaction_prepared(items_valid(items), plan, next_ledger, inputs,
        items, economy, ledger)

def transaction(outcome: Progression.ProgressionOutcome, encounter_id: Nat,
  defeated: List<&2, Progression.DefeatedReward>,
  +inputs: List<&2, OwnedRewardInput>, items: List<&2, EncounterItem>,
  economy: Economy.State, +ledger: Progression.RewardLedger) -> TransactionResult:
  transaction_preparation(Progression.prepare_rewards(outcome, encounter_id,
    defeated, eligible_inputs(inputs), ledger), inputs, items, economy, ledger)

def learning_rows(inputs: List<&2, OwnedRewardInput>,
  updated: List<&2, Progression.Individual>) -> List<&2, OwnedUpdate>:
  match inputs updated:
    case Nil{} Nil{}: []
    case input <> input_rest updated_one <> updated_rest:
      OwnedUpdate{input, updated_one} <> learning_rows(input_rest,
        updated_rest)
    case _ _: []

def append_learning_individual(state: LearningFoldState,
  individual: Progression.Individual) -> LearningFoldState:
  match state:
    case LearningFoldState{owned, catalog, capacity, choices,
        blocked_individual, blocked_level, blocked_move, invalid}:
      LearningFoldState{List.append(&2, Progression.Individual, owned,
        [individual]), catalog, capacity, choices, blocked_individual, blocked_level,
        blocked_move, invalid}

def set_learning_barrier(state: LearningFoldState,
  individual: Progression.Individual, level: U32, offered: U32) -> LearningFoldState:
  match state:
    case LearningFoldState{owned, catalog, capacity, choices,
        blocked_individual, blocked_level, blocked_move, invalid}:
      LearningFoldState{owned, catalog, capacity, choices,
        Some{individual_id(individual)}, Some{level}, Some{offered}, invalid}

def mark_learning_rejected(state: LearningFoldState) -> LearningFoldState:
  match state:
    case LearningFoldState{owned, catalog, capacity, choices,
        blocked_individual, blocked_level, blocked_move, invalid}:
      LearningFoldState{owned, catalog, capacity, choices, blocked_individual, blocked_level,
        blocked_move, True{}}

def learning_row_result(state: LearningFoldState,
  preview: LearningPreview) -> LearningFoldState:
  match preview:
    case LearningReady{individual}:
      append_learning_individual(state, individual)
    case LearningPreviewChoice{individual, level, offered}:
      set_learning_barrier(state, individual, level, offered)
    case LearningRejected{individual}:
      mark_learning_rejected(state)

def learning_input_values(state: LearningFoldState,
  original: Progression.Individual, +updated: Progression.Individual,
  entries: List<&2, LevelMove>, capacity: Nat,
  choices: List<&2, LearningChoice>) -> LearningFoldState:
  match original updated:
    case Progression.Individual{id, species, old_level, xp, hp, max_hp, ivs,
        moves, history, observations, unlocks, harmony}
         Progression.Individual{id2, species2, +new_level, xp2, hp2, max_hp2,
        ivs2, moves2, history2, observations2, unlocks2, harmony2}:
      learning_row_result(state, learn_level_moves(updated, old_level,
        new_level, entries, capacity, choices))

def scan_catalog_match(matches_row: Bool, species: Nat,
  found: Maybe<&2, SpeciesLearning>, matches: Nat,
  species_row: Nat, entries: List<&2, LevelMove>) -> LearningCatalogScan:
  match matches_row:
    case False{}: LearningCatalogScan{species, found, matches}
    case True{}:
      LearningCatalogScan{species,
        Some{SpeciesLearning{species_row, entries}}, Nat.add(matches, 1n)}

def scan_catalog_row(state: LearningCatalogScan,
  row: SpeciesLearning) -> LearningCatalogScan:
  match state row:
    case LearningCatalogScan{+species, found, matches}
         SpeciesLearning{+species_row, entries}:
      scan_catalog_match(Nat.is_eq(species, species_row), species, found,
        matches, species_row, entries)

def find_species_catalog(species: Nat,
  catalog: List<&2, SpeciesLearning>) -> LearningCatalogScan:
  List.foldl(&2, SpeciesLearning, LearningCatalogScan, scan_catalog_row,
    catalog, LearningCatalogScan{species, None{}, 0n})

def apply_catalog_entries(+state: LearningFoldState,
  original: Progression.Individual, updated: Progression.Individual,
  row: SpeciesLearning) -> LearningFoldState:
  match state row:
    case LearningFoldState{owned, catalog, capacity, choices,
        blocked_individual, blocked_level, blocked_move, invalid}
         SpeciesLearning{species, entries}:
      learning_input_values(state, original, updated, entries, capacity, choices)

def apply_catalog_result(state: LearningFoldState,
  original: Progression.Individual, updated: Progression.Individual,
  scan: LearningCatalogScan) -> LearningFoldState:
  match scan:
    case LearningCatalogScan{species, None{}, matches}:
      mark_learning_rejected(state)
    case LearningCatalogScan{species, Some{row}, 1n}:
      apply_catalog_entries(state, original, updated, row)
    case LearningCatalogScan{species, Some{row}, matches}:
      mark_learning_rejected(state)

def apply_learning_catalog(+state: LearningFoldState,
  +original: Progression.Individual, updated: Progression.Individual) ->
  LearningFoldState:
  match state original:
    case LearningFoldState{owned, catalog, capacity, choices,
        blocked_individual, blocked_level, blocked_move, invalid}
         Progression.Individual{id, species, level, xp, hp, max_hp, ivs,
        moves, history, observations, unlocks, harmony}:
      apply_catalog_result(state, original, updated,
        find_species_catalog(species, catalog))

def apply_learning_row_state(+state: LearningFoldState,
  input: OwnedRewardInput, updated: Progression.Individual) -> LearningFoldState:
  match state:
    case LearningFoldState{owned, catalog, capacity, choices,
        Some{blocked_id}, blocked_level, blocked_move, invalid}: state
    case LearningFoldState{owned, catalog, capacity, choices,
        blocked_individual, blocked_level, blocked_move, True{}}: state
    case LearningFoldState{owned, catalog, capacity, choices, None{}, None{}, None{}, False{}}:
      match input:
        case OwnedRewardInput{individual, base, ivs, alive, active}:
          apply_learning_catalog(state, individual, updated)
    case LearningFoldState{owned, catalog, capacity, choices,
        blocked_individual, blocked_level, blocked_move, invalid}: state

def apply_learning_row(state: LearningFoldState, row: OwnedUpdate) ->
  LearningFoldState:
  match row:
    case OwnedUpdate{input, updated}:
      apply_learning_row_state(state, input, updated)

def apply_learning_rows(rows: List<&2, OwnedUpdate>,
  catalog: List<&2, SpeciesLearning>, capacity: Nat,
  choices: List<&2, LearningChoice>) -> LearningFoldState:
  List.foldl(&2, OwnedUpdate, LearningFoldState, apply_learning_row, rows,
    LearningFoldState{[], catalog, capacity, choices, None{}, None{}, None{}, False{}})

def pending_individual(pending: PendingLearning) -> Nat:
  match pending:
    case PendingLearning{outcome, encounter_id, defeated, inputs, items,
        economy, ledger, learning, choices, offered_individual, offered_level, offered_move}:
      offered_individual

def pending_level(pending: PendingLearning) -> U32:
  match pending:
    case PendingLearning{outcome, encounter_id, defeated, inputs, items,
        economy, ledger, learning, choices, offered_individual, offered_level, offered_move}:
      offered_level

def pending_move(pending: PendingLearning) -> U32:
  match pending:
    case PendingLearning{outcome, encounter_id, defeated, inputs, items,
        economy, ledger, learning, choices, offered_individual, offered_level, offered_move}:
      offered_move

def economy_move_capacity(economy: Economy.State) -> Nat:
  match economy:
    case Economy.State{capacity, tier, party, storage, moves, currency,
        inventory}:
      match capacity:
        case Economy.Capacity{party_cap, move_cap, storage_cap, stack_cap,
            entry_cap, currency_cap}:
          move_cap

def learning_input_contains(+id: Nat,
  inputs: List<&2, OwnedRewardInput>) -> Bool:
  match inputs:
    case Nil{}: False{}
    case OwnedRewardInput{individual, base, ivs, alive, active} <> rest:
      Bool.or(Nat.is_eq(id, individual_id(individual)),
        learning_input_contains(id, rest))

def learning_choice_owners_valid(choices: List<&2, LearningChoice>,
  +inputs: List<&2, OwnedRewardInput>) -> Bool:
  match choices:
    case Nil{}: True{}
    case LearningChoice{owner, level, move, accept, replacement} <> rest:
      Bool.and(learning_input_contains(owner, inputs),
        learning_choice_owners_valid(rest, inputs))

def learning_rows_valid(+inputs: List<&2, OwnedRewardInput>,
  +updated: List<&2, Progression.Individual>,
  choices: List<&2, LearningChoice>) -> Bool:
  Bool.and(Nat.is_eq(List.length(&2, OwnedRewardInput, inputs),
      List.length(&2, Progression.Individual, updated)),
    learning_choice_owners_valid(choices, inputs))

def learning_fold_result(state: LearningFoldState,
  +base: TransactionResult, request: LearningRequest) -> TransactionResult:
  match state:
    case LearningFoldState{owned, catalog, capacity, choices,
        Some{offered_individual}, Some{offered_level}, Some{offered_move}, False{}}:
      match request:
        case LearningRequest{outcome, encounter_id, defeated, inputs, items,
            economy, ledger, learning, choices}:
          RewardChoiceRequired{PendingLearning{outcome, encounter_id,
            defeated, inputs, items, economy, ledger, learning, choices,
            offered_individual, offered_level, offered_move}}
    case LearningFoldState{owned, catalog, capacity, choices, None{}, None{}, None{}, False{}}:
      match base:
        case RewardResult{RewardCommitted{}, old_owned, next_economy,
            next_ledger}:
          RewardResult{RewardCommitted{}, owned, next_economy, next_ledger}
        case other: other
    case LearningFoldState{owned, catalog, capacity, choices, _, _, _, True{}}:
      match request:
        case LearningRequest{outcome, encounter_id, defeated, inputs, items,
            economy, ledger, learning, choices}:
          RewardResult{RewardRejected{}, owned_individuals(inputs), economy,
            ledger}
    case other: base

def learning_rows_result(valid: Bool, rows: List<&2, OwnedUpdate>,
  +base: TransactionResult, +request: LearningRequest) -> TransactionResult:
  match valid:
    case False{}:
      match request:
        case LearningRequest{outcome, encounter_id, defeated, inputs, items,
            economy, ledger, learning, choices}:
          RewardResult{RewardRejected{}, owned_individuals(inputs), economy,
            ledger}
    case True{}:
      match request:
        case LearningRequest{outcome, encounter_id, defeated, inputs, items,
            economy, ledger, learning, choices}:
          learning_fold_result(apply_learning_rows(rows, learning,
            economy_move_capacity(economy), choices), base, request)

def learning_transaction_base(+base: TransactionResult,
  +request: LearningRequest) -> TransactionResult:
  match base:
    case RewardResult{RewardCommitted{}, +owned, next_economy, next_ledger}:
      match request:
        case LearningRequest{outcome, encounter_id, defeated, inputs, items,
            economy, ledger, +learning, choices}:
          learning_rows_result(learning_rows_valid(inputs, owned, choices),
            learning_rows(inputs, owned), base, request)
    case other: other

def transaction_with_learning(+outcome: Progression.ProgressionOutcome,
  +encounter_id: Nat, +defeated: List<&2, Progression.DefeatedReward>,
  +inputs: List<&2, OwnedRewardInput>, +items: List<&2, EncounterItem>,
  +economy: Economy.State, +ledger: Progression.RewardLedger,
  +learning: List<&2, SpeciesLearning>, +choices: List<&2, LearningChoice>) ->
  TransactionResult:
  learning_transaction_base(transaction(outcome, encounter_id, defeated,
    inputs, items, economy, ledger), LearningRequest{outcome, encounter_id,
    defeated, inputs, items, economy, ledger, learning, choices})

def resolve_learning_choice(pending: PendingLearning, accept: Bool,
  replacement: Maybe<&2, U32>) -> TransactionResult:
  match pending:
    case PendingLearning{outcome, encounter_id, defeated, inputs, items,
        economy, ledger, learning, choices, offered_individual, offered_level, offered_move}:
      transaction_with_learning(outcome, encounter_id, defeated, inputs, items,
        economy, ledger, learning, List.append(&2, LearningChoice, choices,
          [LearningChoice{offered_individual, offered_level, offered_move, accept,
            replacement}]))
