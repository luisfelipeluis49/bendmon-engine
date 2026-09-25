import Base
import ../battle/model.bend as Battle
import ../battle/reducer.bend as Reducer
import ../battle/runtime.bend as Runtime
import ../battle/scheduler.bend as Scheduler
import ../capture/core.bend as Capture
import ../economy/core.bend as Economy
import ../economy/roster.bend as Roster
import ../progression/core.bend as Progression
import ./battle.bend as M7Battle
import ./ownership.bend as Ownership
import ./reward_bridge.bend as Bridge
import ./rewards.bend as Rewards

# One authoritative M7 encounter transaction. These bindings are installed
# from validated content and saved individual records when battle begins.
type Enemy is Data:
  Enemy{actor: Battle.ActorId, specimen: Progression.Individual,
    base: Progression.StatBlock, reward: Progression.DefeatedReward}

type OwnerActor is Data:
  OwnerActor{actor: Battle.ActorId, individual: Nat, was_active: Bool}

type State is Data:
  State{battle: M7Battle.State, rewards: Bridge.Context,
    enemies: List<&2, Enemy>, owners: List<&2, OwnerActor>}

type StepStatus is Data:
  Committed{}
  Skipped{}
  Advancing{}
  Rejected{}
  Idle{}

type StepResult is Data:
  SessionStep{status: StepStatus, state: State,
    emitted: List<&2, Battle.TransitionEvent>,
    captures: List<&2, M7Battle.CaptureEvent>}

# An interactive reward step can pause before any terminal battle or economy
# state commits. The caller presents the offered move, then retries the same
# queued step with a recorded choice; deterministic replay recomputes the
# complete transaction from the original state.
type InteractiveStepResult is Data:
  InteractiveStepped{result: StepResult}
  InteractiveMoveChoice{individual: Nat, level: U32, move: U32,
    state: State}
  InteractiveEvolutionChoice{individual: Nat, rule: Nat,
    target_species: Nat, state: State}

type SubmitResult is Data:
  SessionAccepted{state: State, emitted: List<&2, Battle.BattleEvent>}
  SessionRejected{state: State}

def capacity_equal(left: Economy.Capacity, right: Economy.Capacity) -> Bool:
  match left right:
    case Economy.Capacity{ap, am, ast, ak, ae, ac}
         Economy.Capacity{bp, bm, bst, bk, be, bc}:
      Bool.and(Nat.is_eq(ap, bp), Bool.and(Nat.is_eq(am, bm),
      Bool.and(Nat.is_eq(ast, bst), Bool.and(Nat.is_eq(ak, bk),
      Bool.and(Nat.is_eq(ae, be), Nat.is_eq(ac, bc))))))

def items_equal(left: List<&2, Economy.ItemStack>,
  right: List<&2, Economy.ItemStack>) -> Bool:
  match left right:
    case Nil{} Nil{}: True{}
    case Economy.ItemStack{item, quantity} <> left_rest
         Economy.ItemStack{other, other_quantity} <> right_rest:
      Bool.and(Economy.item_eq(item, other),
        Bool.and(Nat.is_eq(quantity, other_quantity),
          items_equal(left_rest, right_rest)))
    case _ _: False{}

def economy_equal(left: Economy.State, right: Economy.State) -> Bool:
  match left right:
    case Economy.State{+capacity, tier, party, storage, moves, currency,
        +inventory}
         Economy.State{+other_capacity, other_tier, other_party,
           other_storage, other_moves, other_currency, +other_inventory}:
      Bool.and(capacity_equal(capacity, other_capacity),
      Bool.and(Nat.is_eq(tier, other_tier),
      Bool.and(Nat.is_eq(party, other_party),
      Bool.and(Nat.is_eq(storage, other_storage),
      Bool.and(Nat.is_eq(moves, other_moves),
      Bool.and(Nat.is_eq(currency, other_currency),
        items_equal(inventory, other_inventory)))))))

def context_economy(context: Bridge.Context) -> Economy.State:
  match context:
    case Bridge.Context{encounter_id, defeated, owned_inputs,
        item_rewards, economy, ledger}: economy

def context_owned(context: Bridge.Context) -> List<&2, Rewards.OwnedRewardInput>:
  match context:
    case Bridge.Context{encounter_id, defeated, owned_inputs,
        item_rewards, economy, ledger}: owned_inputs

def context_defeated(context: Bridge.Context) ->
  List<&2, Progression.DefeatedReward>:
  match context:
    case Bridge.Context{encounter_id, defeated, owned_inputs,
        item_rewards, economy, ledger}: defeated

def owned_input_id(input: Rewards.OwnedRewardInput) -> Nat:
  match input:
    case Rewards.OwnedRewardInput{individual, base, ivs, alive,
        previously_active}: Rewards.individual_id(individual)

def owned_contains(inputs: List<&2, Rewards.OwnedRewardInput>,
  +wanted: Nat) -> Bool:
  match inputs:
    case Nil{}: False{}
    case input <> rest:
      Bool.or(Nat.is_eq(owned_input_id(input), wanted),
        owned_contains(rest, wanted))

def roster_ids_have_owners(ids: List<&2, Roster.IndividualId>,
  +inputs: List<&2, Rewards.OwnedRewardInput>) -> Bool:
  match ids:
    case Nil{}: True{}
    case Roster.IndividualId{id} <> rest:
      Bool.and(owned_contains(inputs, id),
        roster_ids_have_owners(rest, inputs))

def owned_id_in_roster(+id: Nat, roster: Roster.Roster) -> Bool:
  match roster:
    case Roster.Roster{capacity, party, storage}:
      Bool.or(Roster.id_in(party, Roster.IndividualId{id}),
        Roster.id_in(storage, Roster.IndividualId{id}))

def owned_inputs_in_roster(inputs: List<&2, Rewards.OwnedRewardInput>,
  +roster: Roster.Roster) -> Bool:
  match inputs:
    case Nil{}: True{}
    case input <> rest:
      Bool.and(owned_id_in_roster(owned_input_id(input),
        roster), owned_inputs_in_roster(rest, roster))

def owned_roster_valid(+inputs: List<&2, Rewards.OwnedRewardInput>,
  +roster: Roster.Roster) -> Bool:
  match roster:
    case Roster.Roster{capacity, +party, +storage}:
      Bool.and(Nat.is_eq(List.length(&2, Rewards.OwnedRewardInput, inputs),
        Nat.add(List.length(&2, Roster.IndividualId, party),
          List.length(&2, Roster.IndividualId, storage))),
      Bool.and(roster_ids_have_owners(party, inputs),
      Bool.and(roster_ids_have_owners(storage, inputs),
        owned_inputs_in_roster(inputs, roster))))

def battle_economy(state: M7Battle.State) -> Economy.State:
  match state:
    case M7Battle.State{runtime, economy, roster, captured, catalog}: economy

def battle_valid(state: M7Battle.State) -> Bool:
  match state:
    case M7Battle.State{runtime, +economy, +roster, captured, catalog}:
      Bool.and(M7Battle.state_roster_valid(economy, roster),
        Economy.state_matches_tiers(economy,
          M7Battle.capture_catalog_tiers(catalog)))

def battle_roster(state: M7Battle.State) -> Roster.Roster:
  match state:
    case M7Battle.State{runtime, economy, roster, captured, catalog}: roster

def session_base_valid(state: State) -> Bool:
  match state:
    case State{+battle, +rewards, enemies, owners}:
      Bool.and(economy_equal(context_economy(rewards), battle_economy(battle)),
      Bool.and(battle_valid(battle),
        owned_roster_valid(context_owned(rewards), battle_roster(battle))))

def rejected(+original: State) -> StepResult:
  SessionStep{Rejected{}, original, [], []}

def idle(+original: State) -> StepResult:
  SessionStep{Idle{}, original, [], []}

def battle_runtime(state: M7Battle.State) -> Runtime.RuntimeState:
  match state:
    case M7Battle.State{runtime, economy, roster, captured, catalog}: runtime

def battle_state(state: M7Battle.State) -> Battle.BattleState:
  Runtime.runtime_battle(battle_runtime(state))

def actor_hp(found: Maybe<&2, Battle.Actor>) -> Maybe<U32>:
  match found:
    case None{}: None{}
    case Some{Battle.Actor{id, side, hp, speed, phase, cooldown}}:
      Some{U32.from_nat(hp)}

def target_hp(target: Battle.ActorId, state: M7Battle.State) -> Maybe<U32>:
  actor_hp(Scheduler.find_actor(target,
    Reducer.state_actors(battle_state(state))))

def matching_enemy(equal: Bool, entry: Enemy,
  rest: Maybe<&2, Enemy>) -> Maybe<&2, Enemy>:
  match equal:
    case True{}: Some{entry}
    case False{}: rest

def enemy_for(+target: Battle.ActorId, enemies: List<&2, Enemy>) ->
  Maybe<&2, Enemy>:
  match enemies:
    case Nil{}: None{}
    case +entry <> rest:
      match entry:
        case Enemy{actor, specimen, base, reward}:
          matching_enemy(Battle.ActorId.eq(target, actor), entry,
            enemy_for(target, rest))

def individual_ivs(individual: Progression.Individual) ->
  Progression.StatBlock:
  match individual:
    case Progression.Individual{id, species, level, xp, current_hp,
        max_hp, ivs, moves, move_history, observations, unlocks, harmony}:
      ivs

def captured_owned(result: Ownership.CaptureResult,
  base: Progression.StatBlock, inputs: List<&2, Rewards.OwnedRewardInput>) ->
  Maybe<List<&2, Rewards.OwnedRewardInput>>:
  match result:
    case Ownership.CaptureRejected{original}: None{}
    case Ownership.CaptureOwned{+individual}:
      Some{Rewards.OwnedRewardInput{individual, base,
        individual_ivs(individual), False{}, False{}} <> inputs}

def capture_enemy(found: Maybe<&2, Enemy>, id: Nat, species: Nat,
  hp: U32, inputs: List<&2, Rewards.OwnedRewardInput>) ->
  Maybe<List<&2, Rewards.OwnedRewardInput>>:
  match found:
    case None{}: None{}
    case Some{Enemy{actor, specimen, +base, reward}}:
      captured_owned(Ownership.capture(id, species, hp, specimen, base),
        base, inputs)

def capture_hp(found: Maybe<U32>, target: Battle.ActorId, id: Nat,
  species: Nat, enemies: List<&2, Enemy>,
  inputs: List<&2, Rewards.OwnedRewardInput>) ->
  Maybe<List<&2, Rewards.OwnedRewardInput>>:
  match found:
    case None{}: None{}
    case Some{hp}:
      capture_enemy(enemy_for(target, enemies), id, species, hp, inputs)

def capture_one(event: M7Battle.CaptureEvent,
  +before: M7Battle.State, +enemies: List<&2, Enemy>,
  inputs: List<&2, Rewards.OwnedRewardInput>) ->
  Maybe<List<&2, Rewards.OwnedRewardInput>>:
  match event:
    case M7Battle.CaptureResolved{source, target, individual, species,
        False{}, destination, chance, draw}:
      Some{inputs}
    case M7Battle.CaptureResolved{source, +target,
        Roster.IndividualId{id}, species, True{}, destination, chance, draw}:
      capture_hp(target_hp(target, before), target, id, species,
        enemies, inputs)

def capture_recurse(event: M7Battle.CaptureEvent,
  +before: M7Battle.State, +enemies: List<&2, Enemy>,
  staged: Maybe<List<&2, Rewards.OwnedRewardInput>>) ->
  Maybe<List<&2, Rewards.OwnedRewardInput>>:
  match staged:
    case None{}: None{}
    case Some{inputs}: capture_one(event, before, enemies, inputs)

def capture_inputs(events: List<&2, M7Battle.CaptureEvent>,
  +before: M7Battle.State, +enemies: List<&2, Enemy>,
  inputs: List<&2, Rewards.OwnedRewardInput>) ->
  Maybe<List<&2, Rewards.OwnedRewardInput>>:
  match events:
    case Nil{}: Some{inputs}
    case event <> rest:
      capture_recurse(event, before, enemies,
        capture_inputs(rest, before, enemies, inputs))

def actor_is_defeated(found: Maybe<&2, Battle.Actor>) -> Bool:
  match found:
    case Some{Battle.Actor{id, side, 0n, speed, phase, cooldown}}: True{}
    case _: False{}

def actor_was_live(found: Maybe<&2, Battle.Actor>) -> Bool:
  match found:
    case Some{Battle.Actor{id, side, 0n, speed, phase, cooldown}}: False{}
    case Some{Battle.Actor{id, side, hp, speed, phase, cooldown}}: True{}
    case None{}: False{}

def capture_target_success(+target: Battle.ActorId,
  captures: List<&2, M7Battle.CaptureEvent>) -> Bool:
  match captures:
    case Nil{}: False{}
    case M7Battle.CaptureResolved{source, found, individual, species,
        success, destination, chance, draw} <> rest:
      Bool.or(Bool.and(success, Battle.ActorId.eq(target, found)),
        capture_target_success(target, rest))

def enemy_reward_eligible(+actor: Battle.ActorId,
  +before: M7Battle.State, +battle: M7Battle.State,
  +captures: List<&2, M7Battle.CaptureEvent>) -> Bool:
  Bool.or(Bool.and(actor_was_live(Scheduler.find_actor(actor,
      Reducer.state_actors(battle_state(before)))),
    actor_is_defeated(Scheduler.find_actor(actor,
      Reducer.state_actors(battle_state(battle))))),
    capture_target_success(actor, captures))

def maybe_reward(include: Bool, reward: Progression.DefeatedReward,
  rest: List<&2, Progression.DefeatedReward>) ->
  List<&2, Progression.DefeatedReward>:
  match include:
    case True{}: reward <> rest
    case False{}: rest

def keep_enemy(captured: Bool, enemy: Enemy,
  rest: List<&2, Enemy>) -> List<&2, Enemy>:
  match captured:
    case True{}: rest
    case False{}: enemy <> rest

def enemies_after_capture(enemies: List<&2, Enemy>,
  +captures: List<&2, M7Battle.CaptureEvent>) -> List<&2, Enemy>:
  match enemies:
    case Nil{}: []
    case +enemy <> rest:
      match enemy:
        case Enemy{actor, specimen, base, reward}:
          keep_enemy(capture_target_success(actor, captures), enemy,
            enemies_after_capture(rest, captures))

def defeated_rewards(enemies: List<&2, Enemy>,
  +before: M7Battle.State, +battle: M7Battle.State,
  +captures: List<&2, M7Battle.CaptureEvent>) ->
  List<&2, Progression.DefeatedReward>:
  match enemies:
    case Nil{}: []
    case Enemy{actor, specimen, base, reward} <> rest:
      maybe_reward(enemy_reward_eligible(actor, before, battle, captures), reward,
        defeated_rewards(rest, before, battle, captures))

def owner_actor_select(equal: Bool, owner: OwnerActor,
  rest: Maybe<&2, OwnerActor>) -> Maybe<&2, OwnerActor>:
  match equal:
    case True{}: Some{owner}
    case False{}: rest

def owner_actor_for(+id: Nat, owners: List<&2, OwnerActor>) ->
  Maybe<&2, OwnerActor>:
  match owners:
    case Nil{}: None{}
    case +owner <> rest:
      match owner:
        case OwnerActor{actor, individual, was_active}:
          owner_actor_select(Nat.is_eq(id, individual), owner,
            owner_actor_for(id, rest))

def actor_alive(found: Maybe<&2, Battle.Actor>) -> Bool:
  match found:
    case Some{Battle.Actor{id, side, 0n, speed, phase, cooldown}}: False{}
    case Some{Battle.Actor{id, side, hp, speed, phase, cooldown}}: True{}
    case None{}: False{}

def active_phase(phase: Battle.Phase) -> Bool:
  match phase:
    case Battle.Ready{}: True{}
    case Battle.Windup{tick}: True{}
    case Battle.Recovery{tick}: True{}
    case _: False{}

def actor_previously_active(found: Maybe<&2, Battle.Actor>) -> Bool:
  match found:
    case None{}: False{}
    case Some{Battle.Actor{id, side, hp, speed, phase, cooldown}}:
      active_phase(phase)

def switched_in(+actor: Battle.ActorId,
  emitted: List<&2, Battle.TransitionEvent>) -> Bool:
  match emitted:
    case Nil{}: False{}
    case Battle.BattleActorSwitched{outgoing, incoming} <> rest:
      Bool.or(Battle.ActorId.eq(actor, incoming), switched_in(actor, rest))
    case _ <> rest: switched_in(actor, rest)

def owner_advance(owners: List<&2, OwnerActor>,
  +before: M7Battle.State,
  +emitted: List<&2, Battle.TransitionEvent>) ->
  List<&2, OwnerActor>:
  match owners:
    case Nil{}: []
    case OwnerActor{+actor, individual, was_active} <> rest:
      OwnerActor{actor, individual,
        Bool.or(was_active,
        Bool.or(actor_previously_active(Scheduler.find_actor(actor,
          Reducer.state_actors(battle_state(before)))),
          switched_in(actor, emitted)))} <>
        owner_advance(rest, before, emitted)

def actor_on_side(found: Maybe<&2, Battle.Actor>,
  wanted: Battle.Side) -> Bool:
  match found:
    case None{}: False{}
    case Some{Battle.Actor{id, side, hp, speed, phase, cooldown}}:
      Scheduler.same_side(side, wanted)

def enemy_id_in(+actor: Battle.ActorId, enemies: List<&2, Enemy>) -> Bool:
  match enemies:
    case Nil{}: False{}
    case Enemy{other, specimen, base, reward} <> rest:
      Bool.or(Battle.ActorId.eq(actor, other), enemy_id_in(actor, rest))

def owner_id_in(+actor: Battle.ActorId,
  owners: List<&2, OwnerActor>) -> Bool:
  match owners:
    case Nil{}: False{}
    case OwnerActor{other, individual, active} <> rest:
      Bool.or(Battle.ActorId.eq(actor, other), owner_id_in(actor, rest))

def owner_individual_in(+id: Nat,
  owners: List<&2, OwnerActor>) -> Bool:
  match owners:
    case Nil{}: False{}
    case OwnerActor{actor, other, active} <> rest:
      Bool.or(Nat.is_eq(id, other), owner_individual_in(id, rest))

def specimen_valid(specimen: Progression.Individual,
  +base: Progression.StatBlock, reward: Progression.DefeatedReward) -> Bool:
  match specimen reward:
    case Progression.Individual{id, species, +level, xp, +current_hp,
        +max_hp, +ivs, moves, history, observations, unlocks, harmony}
         Progression.DefeatedReward{reward_level, base_xp, currency}:
      Bool.and(U32.is_eq(level, reward_level),
      Bool.and(Progression.stats_valid(base, ivs, level),
      Bool.and(Rewards.calculated_max_matches(
        Progression.calculate_stats(base, ivs, level), max_hp),
      Bool.and(U32.is_eq(level, Progression.level_for_xp(xp)),
      Bool.and(U32.is_le(current_hp, max_hp),
        U32.is_ge(current_hp, 1))))))

def owner_in_party(id: Nat, roster: Roster.Roster) -> Bool:
  match roster:
    case Roster.Roster{capacity, party, storage}:
      Roster.id_in(party, Roster.IndividualId{id})

def enemies_valid(enemies: List<&2, Enemy>,
  +battle: M7Battle.State) -> Bool:
  match enemies:
    case Nil{}: True{}
    case Enemy{+actor, specimen, base, reward} <> +rest:
      Bool.and(actor_on_side(Scheduler.find_actor(actor,
        Reducer.state_actors(battle_state(battle))), Battle.Enemy{}),
      Bool.and(Bool.not(enemy_id_in(actor, rest)),
      Bool.and(specimen_valid(specimen, base, reward),
        enemies_valid(rest, battle))))

def owners_valid(owners: List<&2, OwnerActor>,
  +inputs: List<&2, Rewards.OwnedRewardInput>,
  +battle: M7Battle.State) -> Bool:
  match owners:
    case Nil{}: True{}
    case OwnerActor{+actor, +individual, active} <> +rest:
      Bool.and(actor_on_side(Scheduler.find_actor(actor,
        Reducer.state_actors(battle_state(battle))), Battle.Player{}),
      Bool.and(Bool.and(owned_contains(inputs, individual),
        owner_in_party(individual, battle_roster(battle))),
      Bool.and(Bool.not(owner_id_in(actor, rest)),
      Bool.and(Bool.not(owner_individual_in(individual, rest)),
        owners_valid(rest, inputs, battle)))))

def actor_has_binding(actor: Battle.ActorId, side: Battle.Side,
  enemies: List<&2, Enemy>, owners: List<&2, OwnerActor>) -> Bool:
  match side:
    case Battle.Player{}: owner_id_in(actor, owners)
    case Battle.Enemy{}: enemy_id_in(actor, enemies)

def actors_have_bindings(actors: List<&2, Battle.Actor>,
  +enemies: List<&2, Enemy>, +owners: List<&2, OwnerActor>) -> Bool:
  match actors:
    case Nil{}: True{}
    case Battle.Actor{+id, side, hp, speed, phase, cooldown} <> rest:
      Bool.and(actor_has_binding(id, side, enemies, owners),
        actors_have_bindings(rest, enemies, owners))

def session_valid(+state: State) -> Bool:
  match state:
    case State{+battle, +rewards, +enemies, +owners}:
      Bool.and(session_base_valid(state),
      Bool.and(enemies_valid(enemies, battle),
      Bool.and(owners_valid(owners, context_owned(rewards), battle),
        actors_have_bindings(Reducer.state_actors(battle_state(battle)),
          enemies, owners))))

def unbound_flags_select(is_party: Bool, alive: Bool,
  active: Bool) -> List<&2, Bool>:
  match is_party:
    case True{}: [alive, active]
    case False{}: [False{}, False{}]

def unbound_flags(input: Rewards.OwnedRewardInput,
  roster: Roster.Roster) -> List<&2, Bool>:
  match input roster:
    case Rewards.OwnedRewardInput{individual, base, ivs, alive, active}
         Roster.Roster{capacity, party, storage}:
      unbound_flags_select(Roster.id_in(party, Roster.IndividualId{
          Rewards.individual_id(individual)}), alive, active)

def owner_flags(found: Maybe<&2, OwnerActor>, battle: M7Battle.State,
  input: Rewards.OwnedRewardInput) ->
  List<&2, Bool>:
  match found:
    case None{}: unbound_flags(input, battle_roster(battle))
    case Some{OwnerActor{actor, individual, was_active}}:
      [actor_alive(Scheduler.find_actor(actor,
        Reducer.state_actors(battle_state(battle)))), was_active]

def input_with_flags(input: Rewards.OwnedRewardInput,
  flags: List<&2, Bool>) -> Rewards.OwnedRewardInput:
  match input flags:
    case Rewards.OwnedRewardInput{individual, base, ivs, old_alive,
        old_active} alive <> active <> Nil{}:
      Rewards.OwnedRewardInput{individual, base, ivs, alive, active}
    case _ _: input

def reward_owned_inputs(inputs: List<&2, Rewards.OwnedRewardInput>,
  +owners: List<&2, OwnerActor>, +battle: M7Battle.State) ->
  List<&2, Rewards.OwnedRewardInput>:
  match inputs:
    case Nil{}: []
    case +input <> rest:
      input_with_flags(input, owner_flags(owner_actor_for(
        owned_input_id(input), owners), battle, input)) <>
        reward_owned_inputs(rest, owners, battle)

def context_stage(old: Bridge.Context,
  owned: List<&2, Rewards.OwnedRewardInput>,
  defeated: List<&2, Progression.DefeatedReward>,
  economy: Economy.State) -> Bridge.Context:
  match old:
    case Bridge.Context{encounter_id, old_defeated, old_owned, items,
        old_economy, ledger}:
      Bridge.Context{encounter_id, defeated, owned, items, economy, ledger}

def capture_bridge_event(event: M7Battle.CaptureEvent,
  rest: List<&2, Bridge.RewardEvent>) -> List<&2, Bridge.RewardEvent>:
  match event:
    case M7Battle.CaptureResolved{source, target, id, species, True{},
        destination, chance, draw}:
      Bridge.CaptureSucceeded{} <> rest
    case _: rest

def bridge_capture_events(captures: List<&2, M7Battle.CaptureEvent>) ->
  List<&2, Bridge.RewardEvent>:
  match captures:
    case Nil{}: []
    case event <> rest:
      capture_bridge_event(event, bridge_capture_events(rest))

def bridge_events(transitions: List<&2, Battle.TransitionEvent>,
  captures: List<&2, M7Battle.CaptureEvent>) ->
  List<&2, Bridge.RewardEvent>:
  match transitions:
    case Nil{}: bridge_capture_events(captures)
    case event <> rest:
      Bridge.Transition{event} <> bridge_events(rest, captures)

def battle_with_economy(old: M7Battle.State,
  economy: Economy.State) -> M7Battle.State:
  match old:
    case M7Battle.State{runtime, prior, roster, captured, catalog}:
      M7Battle.State{runtime, economy, roster, captured, catalog}

def context_economy_to_battle(context: Bridge.Context,
  battle: M7Battle.State) -> M7Battle.State:
  battle_with_economy(battle, context_economy(context))

def final_battle(sync: Bool, context: Bridge.Context,
  next_battle: M7Battle.State) -> M7Battle.State:
  match sync:
    case True{}: context_economy_to_battle(context, next_battle)
    case False{}: next_battle

def final_state(status: StepStatus, sync: Bool,
  +context: Bridge.Context, next_battle: M7Battle.State,
  +emitted: List<&2, Battle.TransitionEvent>,
  +captures: List<&2, M7Battle.CaptureEvent>,
  original: State) -> StepResult:
  match original:
    case State{+before, old_context, +enemies, +owners}:
      SessionStep{status,
        State{final_battle(sync, context, next_battle), context,
          enemies_after_capture(enemies, captures),
          owner_advance(owners, before, emitted)}, emitted, captures}

def step_from_reward(result: Bridge.BridgeResult,
  +next_battle: M7Battle.State,
  +emitted: List<&2, Battle.TransitionEvent>,
  +captures: List<&2, M7Battle.CaptureEvent>,
  +original: State) -> StepResult:
  match result:
    case Bridge.RewardBridgeResult{Bridge.RewardBridgeRejected{}, context}:
      rejected(original)
    case Bridge.RewardBridgeResult{Bridge.RewardBridgeCommitted{}, context}:
      final_state(Committed{}, True{}, context, next_battle, emitted,
        captures, original)
    case Bridge.RewardBridgeResult{Bridge.RewardBridgeSkipped{}, context}:
      final_state(Skipped{}, False{}, context, next_battle, emitted,
        captures, original)
    case Bridge.RewardBridgeResult{Bridge.RewardBridgeNotTerminal{}, context}:
      final_state(Advancing{}, False{}, context, next_battle, emitted,
        captures, original)

def prepared_context(owned: List<&2, Rewards.OwnedRewardInput>,
  +next_battle: M7Battle.State,
  +emitted: List<&2, Battle.TransitionEvent>,
  +captures: List<&2, M7Battle.CaptureEvent>,
  original: State) -> Bridge.Context:
  match original:
    case State{+before, +old_context, +enemies, +owners}:
      context_stage(old_context,
        reward_owned_inputs(owned, owner_advance(owners, before, emitted),
          next_battle),
        List.append(&2, Progression.DefeatedReward,
          context_defeated(old_context),
          defeated_rewards(enemies, before, next_battle, captures)),
        battle_economy(next_battle))

def step_owned_valid(valid: Bool,
  owned: List<&2, Rewards.OwnedRewardInput>,
  +next_battle: M7Battle.State,
  +emitted: List<&2, Battle.TransitionEvent>,
  +captures: List<&2, M7Battle.CaptureEvent>,
  +original: State) -> StepResult:
  match valid:
    case False{}: rejected(original)
    case True{}:
      +context = prepared_context(owned, next_battle, emitted, captures,
        original)
      step_from_reward(Bridge.resolve(bridge_events(emitted, captures),
        context), next_battle, emitted, captures, original)

def step_owned(staged: Maybe<List<&2, Rewards.OwnedRewardInput>>,
  +next_battle: M7Battle.State,
  +emitted: List<&2, Battle.TransitionEvent>,
  +captures: List<&2, M7Battle.CaptureEvent>,
  +original: State) -> StepResult:
  match staged:
    case None{}: rejected(original)
    case Some{+owned}:
      step_owned_valid(owned_roster_valid(owned, battle_roster(next_battle)),
        owned, next_battle, emitted, captures, original)

def capture_inputs_from_state(
  +events: List<&2, M7Battle.CaptureEvent>, original: State) ->
  Maybe<List<&2, Rewards.OwnedRewardInput>>:
  match original:
    case State{before, context, enemies, owners}:
      capture_inputs(events, before, enemies, context_owned(context))

def step_advanced(+next_battle: M7Battle.State,
  +emitted: List<&2, Battle.TransitionEvent>,
  +captures: List<&2, M7Battle.CaptureEvent>,
  +original: State) -> StepResult:
  step_owned(capture_inputs_from_state(captures, original), next_battle,
    emitted, captures, original)

def step_battle(result: M7Battle.StepResult, +original: State) -> StepResult:
  match result:
    case M7Battle.Stepped{next_battle, emitted, combat_events, +captures}:
      step_advanced(next_battle, emitted, captures, original)
    case M7Battle.Idle{state}: idle(original)
    case M7Battle.RejectedStep{state, diagnostics}: rejected(original)
    case M7Battle.Faulted{state, reason}: rejected(original)

def step_valid(valid: Bool, +original: State) -> StepResult:
  match valid:
    case False{}: rejected(original)
    case True{}:
      match original:
        case State{battle, rewards, enemies, owners}:
          step_battle(M7Battle.step(battle), original)

def step(+original: State) -> StepResult:
  step_valid(session_valid(original), original)

def interactive_reward(result: Bridge.ProgressionBridgeResult,
  +next_battle: M7Battle.State,
  +emitted: List<&2, Battle.TransitionEvent>,
  +captures: List<&2, M7Battle.CaptureEvent>,
  +original: State) -> InteractiveStepResult:
  match result:
    case Bridge.ProgressionBridgeResult{Bridge.ProgressionCommitted{}, context}:
      InteractiveStepped{final_state(Committed{}, True{}, context,
        next_battle, emitted, captures, original)}
    case Bridge.ProgressionBridgeResult{Bridge.ProgressionRejected{}, context}:
      InteractiveStepped{rejected(original)}
    case Bridge.ProgressionBridgeResult{Bridge.ProgressionSkipped{}, context}:
      InteractiveStepped{final_state(Skipped{}, False{}, context,
        next_battle, emitted, captures, original)}
    case Bridge.ProgressionBridgeResult{Bridge.ProgressionNotTerminal{}, context}:
      InteractiveStepped{final_state(Advancing{}, False{}, context,
        next_battle, emitted, captures, original)}
    case Bridge.ProgressionBridgeResult{
        Bridge.ProgressionLearningChoice{pending}, context}:
      match pending:
        case Rewards.PendingLearning{outcome, encounter_id, defeated, inputs,
            items, economy, ledger, learning, choices, individual, level,
            move}:
          InteractiveMoveChoice{individual, level, move, original}
    case Bridge.ProgressionBridgeResult{
        Bridge.ProgressionEvolutionChoice{owner, rule, target}, context}:
      InteractiveEvolutionChoice{owner, rule, target, original}

def interactive_prepared_valid(valid: Bool,
  owned: List<&2, Rewards.OwnedRewardInput>,
  +next_battle: M7Battle.State,
  +emitted: List<&2, Battle.TransitionEvent>,
  +captures: List<&2, M7Battle.CaptureEvent>,
  +original: State,
  +learning: List<&2, Rewards.SpeciesLearning>,
  +choices: List<&2, Rewards.LearningChoice>,
  +evolution: List<&2, Bridge.EvolutionInput>,
  +evolution_choices: List<&2, Bridge.EvolutionChoice>) ->
  InteractiveStepResult:
  match valid:
    case False{}: InteractiveStepped{rejected(original)}
    case True{}:
      +context = prepared_context(owned, next_battle, emitted, captures,
        original)
      interactive_reward(Bridge.resolve_with_progression(
        bridge_events(emitted, captures), context, learning, choices,
        evolution, evolution_choices),
        next_battle, emitted, captures, original)

def interactive_prepared(+owned: List<&2, Rewards.OwnedRewardInput>,
  +next_battle: M7Battle.State,
  +emitted: List<&2, Battle.TransitionEvent>,
  +captures: List<&2, M7Battle.CaptureEvent>,
  +original: State,
  +learning: List<&2, Rewards.SpeciesLearning>,
  +choices: List<&2, Rewards.LearningChoice>,
  +evolution: List<&2, Bridge.EvolutionInput>,
  +evolution_choices: List<&2, Bridge.EvolutionChoice>) ->
  InteractiveStepResult:
  interactive_prepared_valid(owned_roster_valid(owned,
    battle_roster(next_battle)), owned, next_battle, emitted, captures,
    original, learning, choices, evolution, evolution_choices)

def interactive_staged(staged: Maybe<List<&2, Rewards.OwnedRewardInput>>,
  +next_battle: M7Battle.State,
  +emitted: List<&2, Battle.TransitionEvent>,
  +captures: List<&2, M7Battle.CaptureEvent>,
  +original: State,
  +learning: List<&2, Rewards.SpeciesLearning>,
  +choices: List<&2, Rewards.LearningChoice>,
  +evolution: List<&2, Bridge.EvolutionInput>,
  +evolution_choices: List<&2, Bridge.EvolutionChoice>) ->
  InteractiveStepResult:
  match staged:
    case None{}: InteractiveStepped{rejected(original)}
    case Some{owned}:
      interactive_prepared(owned, next_battle, emitted, captures,
        original, learning, choices, evolution, evolution_choices)

def interactive_battle(result: M7Battle.StepResult,
  +original: State,
  +learning: List<&2, Rewards.SpeciesLearning>,
  +choices: List<&2, Rewards.LearningChoice>,
  +evolution: List<&2, Bridge.EvolutionInput>,
  +evolution_choices: List<&2, Bridge.EvolutionChoice>) ->
  InteractiveStepResult:
  match result:
    case M7Battle.Stepped{next_battle, emitted, combat_events, +captures}:
      interactive_staged(capture_inputs_from_state(captures, original),
        next_battle, emitted, captures, original, learning, choices,
        evolution, evolution_choices)
    case M7Battle.Idle{state}: InteractiveStepped{idle(original)}
    case M7Battle.RejectedStep{state, diagnostics}:
      InteractiveStepped{rejected(original)}
    case M7Battle.Faulted{state, reason}:
      InteractiveStepped{rejected(original)}

# Retrying a queued terminal step with an explicit LearningChoice reproduces
# the same battle events and RNG, then commits all rewards once choices settle.
# A pending result deliberately returns the original pre-step State.
def step_with_progression_valid(valid: Bool, +original: State,
  +learning: List<&2, Rewards.SpeciesLearning>,
  +choices: List<&2, Rewards.LearningChoice>,
  +evolution: List<&2, Bridge.EvolutionInput>,
  +evolution_choices: List<&2, Bridge.EvolutionChoice>) ->
  InteractiveStepResult:
  match valid:
    case False{}: InteractiveStepped{rejected(original)}
    case True{}:
      match original:
        case State{battle, rewards, enemies, owners}:
          interactive_battle(M7Battle.step(battle), original,
            learning, choices, evolution, evolution_choices)

def step_with_progression(+original: State,
  +learning: List<&2, Rewards.SpeciesLearning>,
  +choices: List<&2, Rewards.LearningChoice>,
  +evolution: List<&2, Bridge.EvolutionInput>,
  +evolution_choices: List<&2, Bridge.EvolutionChoice>) ->
  InteractiveStepResult:
  step_with_progression_valid(session_valid(original), original,
    learning, choices, evolution, evolution_choices)

def step_with_learning(+original: State,
  +learning: List<&2, Rewards.SpeciesLearning>,
  +choices: List<&2, Rewards.LearningChoice>) -> InteractiveStepResult:
  step_with_progression(original, learning, choices, [], [])

def submit_battle(result: M7Battle.SubmitResult,
  +original: State) -> SubmitResult:
  match result:
    case M7Battle.Accepted{battle, emitted}:
      match original:
        case State{old_battle, context, enemies, owners}:
          SessionAccepted{State{battle, context, enemies, owners}, emitted}
    case M7Battle.Rejected{battle, reason}: SessionRejected{original}
    case M7Battle.RuntimeRejected{battle, diagnostics}:
      SessionRejected{original}

def submit_valid(valid: Bool, fuel: Nat, +original: State,
  commands: List<&2, Runtime.RuntimeCommand>) -> SubmitResult:
  match valid:
    case False{}: SessionRejected{original}
    case True{}:
      match original:
        case State{battle, context, enemies, owners}:
          submit_battle(M7Battle.submit(fuel, battle, commands), original)

def submit(fuel: Nat, +original: State,
  commands: List<&2, Runtime.RuntimeCommand>) -> SubmitResult:
  submit_valid(session_valid(original), fuel, original, commands)
