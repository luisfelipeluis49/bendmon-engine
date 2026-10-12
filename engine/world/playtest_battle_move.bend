import Base
import ../battle/model.bend as Battle
import ../battle/runtime.bend as Runtime
import ../battle/combat_math.bend as Math
import ../battle/effects.bend as Effects
import ../battle/multi_type.bend as Multi
import ../m7/dynamic_moves.bend as Moves
import ../m7/dynamic_species.bend as Species
import ../m7/rewards.bend as Rewards
import ../m7/session.bend as M7Session
import ../m7/battle.bend as M7Battle
import ../progression/core.bend as Progression
import ../battle/reducer.bend as Reducer
import ../battle/scheduler.bend as Scheduler
import ./battle_bridge.bend as BattleBridge
import ../m7/playable.bend as Playable
import ./world_session.bend as Session
import ./playtest_world_command.bend as Commands

@unsafe def move_record(+id: Nat, rows: List<&2, Moves.MoveRecord>) -> Maybe<Moves.MoveRecord>:
  match rows:
    case Nil{}: None{}
    case Moves.MoveRecord{+move_id, +power, +always, +accuracy, +windup,
        +recovery, +cooldown, +components, +category, +priority_bias,
        +effects} <> rest:
      move_record_test(Nat.is_eq(id, U32.to_nat(move_id)), id,
        Moves.MoveRecord{move_id, power, always, accuracy, windup, recovery,
          cooldown, components, category, priority_bias, effects}, rest)

def move_record_test(equal: Bool, +id: Nat, record: Moves.MoveRecord,
  rest: List<&2, Moves.MoveRecord>) -> Maybe<Moves.MoveRecord>:
  match equal:
    case True{}: Some{record}
    case False{}: move_record(id, rest)

@unsafe def species_record(+id: Nat,
  rows: List<&2, Species.SpeciesProgressionRecord>) ->
  Maybe<Species.SpeciesProgressionRecord>:
  match rows:
    case Nil{}: None{}
    case Species.SpeciesProgressionRecord{+species, +base, +capture, +xp,
        +currency, +types, +learning} <> rest:
      species_record_test(Nat.is_eq(id, species), id,
        Species.SpeciesProgressionRecord{species, base, capture, xp, currency,
          types, learning}, rest)

def species_record_test(equal: Bool, +id: Nat,
  record: Species.SpeciesProgressionRecord,
  rest: List<&2, Species.SpeciesProgressionRecord>) ->
  Maybe<Species.SpeciesProgressionRecord>:
  match equal:
    case True{}: Some{record}
    case False{}: species_record(id, rest)

@unsafe def owned_input(+id: Nat, inputs: List<&2, Rewards.OwnedRewardInput>) ->
  Maybe<Rewards.OwnedRewardInput>:
  match inputs:
    case Nil{}: None{}
    case Rewards.OwnedRewardInput{+individual, +base, +ivs, +alive, +active} <> rest:
      match individual:
        case Progression.Individual{individual_id, species, level, xp, hp,
            max_hp, saved_ivs, moves, history, observations, unlocks, harmony}:
          owned_input_test(Nat.is_eq(id, individual_id), id,
            Rewards.OwnedRewardInput{individual, base, ivs, alive, active},
            rest)

def owned_input_test(equal: Bool, +id: Nat, record: Rewards.OwnedRewardInput,
  rest: List<&2, Rewards.OwnedRewardInput>) -> Maybe<Rewards.OwnedRewardInput>:
  match equal:
    case True{}: Some{record}
    case False{}: owned_input(id, rest)

def move_learned(+id: U32, learned: List<&2, U32>) -> Bool:
  match learned:
    case Nil{}: False{}
    case known <> rest:
      Bool.or(U32.is_eq(id, known), move_learned(id, rest))

def typed_ids(types: List<&2, U32>) -> List<&2, Multi.TypeId>:
  match types:
    case Nil{}: []
    case value <> rest: Multi.TypeId{U32.to_nat(value)} <> typed_ids(rest)

def typed_components(components: List<&2, U32>) ->
  List<&2, Multi.TypeId>:
  typed_ids(components)

def move_category(category: U32) -> Effects.DamageCategory:
  match category:
    case 0: Effects.Physical{}
    case _: Effects.Special{}

def move_accuracy(always: Bool, accuracy: U32) -> Math.AccuracyMode:
  match always:
    case True{}: Math.AlwaysHit{}
    case False{}: Math.OrdinaryAccuracy{accuracy}

def effect_damage_power(program: Effects.EffectProgram) -> U32:
  match program:
    case Effects.EffectProgram{Effects.Leaf{
        Effects.Damage{node, target, category, power}} <> rest}: power
    case _: 1

def effect_has_damage(program: Effects.EffectProgram) -> Bool:
  match program:
    case Effects.EffectProgram{Effects.Leaf{
        Effects.Damage{node, target, category, power}} <> rest}: True{}
    case _: False{}

def move_command(damaging: Bool, source: Battle.ActorId,
  target: Battle.ActorId, move_id: U32, windup: U32,
  recovery: U32, cooldown: U32, priority_bias: U32,
  profile: Runtime.CombatProfile, program: Effects.EffectProgram,
  components: List<&2, U32>, actor_types: List<&2, U32>,
  target_types: List<&2, U32>, snapshot: Effects.ActionSnapshot) ->
  Runtime.RuntimeCommand:
  match damaging:
    case True{}:
      Runtime.RuntimeTypedMove{source, target, Math.MoveId{U32.to_nat(move_id)},
        windup, recovery, cooldown, U32.to_nat(U32.sub(16, priority_bias)),
        0n, profile, program, typed_components(components),
        typed_ids(actor_types), typed_ids(target_types), snapshot}
    case False{}:
      Runtime.RuntimeEffectMove{source, target, Math.MoveId{U32.to_nat(move_id)},
        windup, recovery, cooldown, U32.to_nat(U32.sub(16, priority_bias)),
        0n, profile, program, snapshot}

def typed_move(source: Battle.ActorId, target: Battle.ActorId,
  actor: Progression.Individual, stats: Progression.StatBlock,
  record: Moves.MoveRecord, actor_types: List<&2, U32>,
  target_types: List<&2, U32>) -> Runtime.RuntimeCommand:
  match source target actor stats record actor_types target_types:
    case source_id target_id
         Progression.Individual{id, species, +level, xp, hp, max_hp,
            ivs, moves, history, observations, unlocks, harmony}
         Progression.StatBlock{hp_stat, +attack, +defense, +special_attack,
        special_defense, speed}
         Moves.MoveRecord{+move_id, +power, +always, +accuracy, +windup,
           +recovery, +cooldown, +components, +category, +priority_bias,
           +effects}
         actor_type_ids target_type_ids:
          +snapshot = {Effects.ActionSnapshot{level, attack, special_attack,
            Math.StageNeutral{}, move_accuracy(always, accuracy),
            Effects.NormalPhysical{}, 0} : Effects.ActionSnapshot}
          move_command(effect_has_damage(effects), source_id, target_id,
            move_id, windup, recovery, cooldown, priority_bias,
            Runtime.CombatProfile{move_accuracy(always, accuracy),
              Math.StageNeutral{}, Math.StageNeutral{},
              effect_damage_power(effects), level, attack, defense, 0},
            effects, components, actor_type_ids, target_type_ids, snapshot)

def owner_command(valid: Bool, actor: Progression.Individual,
  stats: Progression.StatBlock, record: Moves.MoveRecord,
  actor_types: List<&2, U32>, target_types: List<&2, U32>,
  target: Battle.ActorId) -> Maybe<Runtime.RuntimeCommand>:
  match valid:
    case True{}: Some{typed_move(Battle.ActorId{0n}, target, actor, stats,
      record, actor_types, target_types)}
    case False{}: None{}

def lower_found(target_valid: Bool, learned: Bool, active: Bool,
  actor: Progression.Individual, stats: Progression.StatBlock,
  record: Moves.MoveRecord, actor_types: List<&2, U32>,
  target_types: List<&2, U32>, target: Battle.ActorId) ->
  Maybe<Runtime.RuntimeCommand>:
  match target_valid:
    case False{}: None{}
    case True{}:
      match learned active:
        case True{} True{}:
          owner_command(True{}, actor, stats, record, actor_types,
            target_types, target)
        case _ _: None{}

def lower_target(source: Maybe<&2, Battle.Actor>,
  target: Maybe<&2, Battle.Actor>, learned: Bool, actor: Progression.Individual,
  stats: Progression.StatBlock, record: Moves.MoveRecord,
  actor_types: List<&2, U32>, target_types: List<&2, U32>,
  target_id: Battle.ActorId) -> Maybe<Runtime.RuntimeCommand>:
  match source target:
    case Some{+source_actor} Some{target_actor}:
      lower_found(Scheduler.target_ok(source_actor, target_actor), learned,
        Scheduler.Actor.is_ready(source_actor), actor, stats, record,
        actor_types, target_types, target_id)
    case _ _: None{}

@unsafe def lower_input(input: Maybe<Rewards.OwnedRewardInput>,
  target: Maybe<Species.SpeciesProgressionRecord>, target_id: Battle.ActorId,
  move: Moves.MoveRecord, learned: Bool, battle: Battle.BattleState,
  species_rows: List<&2, Species.SpeciesProgressionRecord>) ->
  Maybe<Runtime.RuntimeCommand>:
  match input target:
    case Some{Rewards.OwnedRewardInput{individual, base, ivs, alive, active}}
         Some{Species.SpeciesProgressionRecord{species, target_base, capture,
           xp, currency, target_types, learning}}:
      lower_owner_types(individual, base, ivs, alive, target_types,
        target_id, move, battle, species_rows)
    case _ _: None{}

@unsafe def lower_owner_types(+individual: Progression.Individual,
  base: Progression.StatBlock, ivs: Progression.StatBlock, alive: Bool,
  target_types: List<&2, U32>, target_id: Battle.ActorId,
  +move: Moves.MoveRecord, +battle: Battle.BattleState,
  species_rows: List<&2, Species.SpeciesProgressionRecord>) ->
  Maybe<Runtime.RuntimeCommand>:
  match individual:
    case Progression.Individual{id, species, level, xp, hp, max_hp, saved_ivs,
        moves, history, observations, unlocks, harmony}:
      lower_owner_types_found(species_record(species, species_rows), individual,
        base, ivs, alive, target_types, target_id, move, battle)

@unsafe def lower_owner_types_found(found: Maybe<Species.SpeciesProgressionRecord>,
  +individual: Progression.Individual, base: Progression.StatBlock,
  ivs: Progression.StatBlock, alive: Bool, target_types: List<&2, U32>,
  target_id: Battle.ActorId, +move: Moves.MoveRecord,
  +battle: Battle.BattleState) -> Maybe<Runtime.RuntimeCommand>:
  match found:
    case None{}: None{}
    case Some{Species.SpeciesProgressionRecord{species, base_stats, capture,
        xp, currency, actor_types, learning}}:
      lower_owner_input(individual, base, ivs, alive, actor_types,
        target_types, target_id, move, battle)

@unsafe def lower_owner_input(+individual: Progression.Individual,
  base: Progression.StatBlock, ivs: Progression.StatBlock, alive: Bool,
  actor_types: List<&2, U32>, target_types: List<&2, U32>,
  target_id: Battle.ActorId, +move: Moves.MoveRecord,
  +battle: Battle.BattleState) ->
  Maybe<Runtime.RuntimeCommand>:
  match individual base ivs:
    case Progression.Individual{id, species_id, +level, xp_value, hp, max_hp,
        saved_ivs, +known, history, observations, unlocks, harmony}
         base_stats individual_ivs:
      calculated_owner(Progression.calculate_stats(base_stats,
        individual_ivs, level), move_learned(move_id_of(move), known), alive,
        individual, move, actor_types, target_types, target_id, battle)

@unsafe def calculated_owner(calculated: Maybe<&2, Progression.StatBlock>, learned: Bool,
  alive: Bool, individual: Progression.Individual, +move: Moves.MoveRecord,
  actor_types: List<&2, U32>, target_types: List<&2, U32>,
  +target_id: Battle.ActorId,
  +battle: Battle.BattleState) -> Maybe<Runtime.RuntimeCommand>:
  match calculated:
    case None{}: None{}
    case Some{actual}:
      lower_target(Scheduler.find_actor(Battle.ActorId{0n},
          Reducer.state_actors(battle)),
        Scheduler.find_actor(target_id, Reducer.state_actors(battle)),
        Bool.and(learned, Bool.and(alive, move_executable(move))),
        individual, actual, move, actor_types, target_types, target_id)

def move_id_of(move: Moves.MoveRecord) -> U32:
  match move:
    case Moves.MoveRecord{id, power, always, accuracy, windup, recovery,
        cooldown, components, category, priority_bias, effects}: id

def move_executable(move: Moves.MoveRecord) -> Bool:
  match move:
    case Moves.MoveRecord{id, power, always, accuracy, windup, recovery,
        cooldown, components, category, priority_bias,
        Effects.EffectProgram{Nil{}}}: False{}
    case _: True{}

@unsafe def lower_snapshot(command: Commands.WorldCommand,
  owner: Nat, inputs: List<&2, Rewards.OwnedRewardInput>,
  enemies: List<&2, M7Session.Enemy>, battle: Battle.BattleState,
  species: Species.Catalog, moves: Moves.Catalog) ->
  Maybe<Runtime.RuntimeCommand>:
  match command:
    case Commands.PlayBattleMove{actor_id, target_id, move_id}:
      lower_actor_valid(Nat.is_eq(actor_id, 0n), move_id, target_id, owner,
        inputs, enemies, battle, species, moves)
    case _: None{}

@unsafe def lower_actor_valid(valid_actor: Bool, move_id: Nat,
  target_id: Nat, owner: Nat, inputs: List<&2, Rewards.OwnedRewardInput>,
  enemies: List<&2, M7Session.Enemy>, battle: Battle.BattleState,
  species: Species.Catalog, moves: Moves.Catalog) ->
  Maybe<Runtime.RuntimeCommand>:
  match valid_actor:
    case False{}: None{}
    case True{}:
      lower_catalogs(species, moves, move_id, target_id, owner, inputs,
        enemies, battle)

@unsafe def lower_catalogs(species: Species.Catalog, moves: Moves.Catalog,
  move_id: Nat, target_id: Nat, owner: Nat,
  inputs: List<&2, Rewards.OwnedRewardInput>,
  enemies: List<&2, M7Session.Enemy>, battle: Battle.BattleState) ->
  Maybe<Runtime.RuntimeCommand>:
  match species moves:
    case Species.Catalog{identity, move_count, species_rows}
         Moves.Catalog{move_identity, move_rows}:
      catalog_identity_valid(U32.is_eq(identity, move_identity), move_id,
        target_id, owner, inputs, enemies, battle, species_rows, move_rows)

@unsafe def catalog_identity_valid(valid: Bool, +move_id: Nat, +target_id: Nat,
  +owner: Nat, inputs: List<&2, Rewards.OwnedRewardInput>,
  enemies: List<&2, M7Session.Enemy>, battle: Battle.BattleState,
  species_rows: List<&2, Species.SpeciesProgressionRecord>,
  move_rows: List<&2, Moves.MoveRecord>) -> Maybe<Runtime.RuntimeCommand>:
  match valid:
    case False{}: None{}
    case True{}:
      lower_move_record(move_record(move_id, move_rows), owner, inputs,
        enemies, battle, species_rows, target_id)

@unsafe def lower_move_record(found: Maybe<Moves.MoveRecord>, owner: Nat,
  inputs: List<&2, Rewards.OwnedRewardInput>,
  enemies: List<&2, M7Session.Enemy>, battle: Battle.BattleState,
  species_rows: List<&2, Species.SpeciesProgressionRecord>, +target_id: Nat) ->
  Maybe<Runtime.RuntimeCommand>:
  match found:
    case None{}: None{}
    case Some{record}:
      lower_enemy_record(enemy_record(target_id, enemies), owner, inputs,
        battle, species_rows, record, target_id)

@unsafe def lower_enemy_record(found: Maybe<M7Session.Enemy>, owner: Nat,
  inputs: List<&2, Rewards.OwnedRewardInput>, battle: Battle.BattleState,
  +species_rows: List<&2, Species.SpeciesProgressionRecord>,
  record: Moves.MoveRecord, target_id: Nat) -> Maybe<Runtime.RuntimeCommand>:
  match found:
    case None{}: None{}
    case Some{M7Session.Enemy{actor, specimen, base, reward}}:
      lower_input(owned_input(owner, inputs),
        species_record(specimen_species(specimen), species_rows),
        Battle.ActorId{target_id}, record, True{}, battle, species_rows)

def specimen_species(specimen: Progression.Individual) -> Nat:
  match specimen:
    case Progression.Individual{id, species, level, xp, hp, max_hp, ivs,
        moves, history, observations, unlocks, harmony}: species

@unsafe def enemy_record(+id: Nat, enemies: List<&2, M7Session.Enemy>) ->
  Maybe<M7Session.Enemy>:
  match enemies:
    case Nil{}: None{}
    case enemy <> rest:
      match enemy:
        case M7Session.Enemy{actor, specimen, base, reward}:
          match actor:
            case Battle.ActorId{+value}:
              enemy_record_test(Nat.is_eq(id, value), id, enemy, rest)

def enemy_record_test(equal: Bool, id: Nat, enemy: M7Session.Enemy,
  rest: List<&2, M7Session.Enemy>) -> Maybe<M7Session.Enemy>:
  match equal:
    case True{}: Some{enemy}
    case False{}: enemy_record(id, rest)

@unsafe def lower(command: Commands.WorldCommand, session: Session.WorldSession,
  species: Species.Catalog, moves: Moves.Catalog) ->
  Maybe<Runtime.RuntimeCommand>:
  match session:
    case Session.Battling{persistent,
        BattleBridge.State{world,
          Playable.PlayableSession{M7Session.State{battle, rewards, enemies,
            owners}, learning, evolution, choices, evolution_choices,
            pending, ruleset, identity}, returned}}:
      match battle:
        case M7Battle.State{runtime, economy, roster, captured, catalog}:
          lower_snapshot(command, owner_id(owners),
            M7Session.context_owned(rewards), enemies,
            Runtime.runtime_battle(runtime), species, moves)
    case _: None{}

def owner_id(owners: List<&2, M7Session.OwnerActor>) -> Nat:
  match owners:
    case Nil{}: 0n
    case M7Session.OwnerActor{actor, individual, was_active} <> rest:
      match actor:
        case Battle.ActorId{0n}: individual
        case _: owner_id(rest)
