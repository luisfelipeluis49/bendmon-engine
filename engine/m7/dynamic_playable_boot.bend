import Base
import ../battle/model.bend as Battle
import ../battle/runtime.bend as Runtime
import ../battle/combat_math.bend as Math
import ../battle/sources.bend as Sources
import ../battle/effects.bend as Effects
import ../economy/core.bend as Economy
import ../economy/roster.bend as Roster
import ../progression/core.bend as Progression
import ./dynamic_battle_boot.bend as Boot
import ./dynamic_species.bend as Species
import ./dynamic_moves.bend as Moves
import ./playable.bend as Playable
import ./session.bend as Session
import ./battle.bend as M7
import ./reward_bridge.bend as Bridge
import ./rewards.bend as Rewards

# M10 bootstrap uses a fixed versioned ruleset. Legal initial move IDs receive
# runtime source slots; dynamic descriptors remain inert content data.
def ruleset_version() -> Nat: 7n

def default_capacity() -> Economy.Capacity: Economy.defaults()

def individual_hp(+value: Progression.Individual) -> U32:
  match value:
    case Progression.Individual{id, species, level, xp, hp, max_hp,
        ivs, moves, history, observations, unlocks, harmony}: hp

def stat_speed(stats: Progression.StatBlock) -> Nat:
  match stats:
    case Progression.StatBlock{hp, attack, defense, special_attack,
        special_defense, speed}: U32.to_nat(speed)

def stat_defense(stats: Progression.StatBlock) -> U32:
  match stats:
    case Progression.StatBlock{hp, attack, defense, special_attack,
        special_defense, speed}: defense

def stat_special_defense(stats: Progression.StatBlock) -> U32:
  match stats:
    case Progression.StatBlock{hp, attack, defense, special_attack,
        special_defense, speed}: special_defense

def stat_attack(stats: Progression.StatBlock) -> U32:
  match stats:
    case Progression.StatBlock{hp, attack, defense, special_attack,
        special_defense, speed}: attack

def stat_special_attack(stats: Progression.StatBlock) -> U32:
  match stats:
    case Progression.StatBlock{hp, attack, defense, special_attack,
        special_defense, speed}: special_attack

def neutral_stages() -> Effects.StatStages:
  Effects.StatStages{Math.StageNeutral{}, Math.StageNeutral{},
    Math.StageNeutral{}, Math.StageNeutral{}, Math.StageNeutral{},
    Math.StageNeutral{}, Math.StageNeutral{}}

def effect_actor(+individual: Progression.Individual,
  +stats: Progression.StatBlock) -> Effects.EffectActor:
  Effects.EffectActor{individual_hp(individual), individual_hp(individual),
    stat_defense(stats), stat_special_defense(stats), neutral_stages(),
    [], False{}, []}

def initial_world(starter: Progression.Individual,
  wild: Progression.Individual, starter_base: Progression.StatBlock,
  wild_base: Progression.StatBlock) -> Effects.EffectWorld:
  Effects.EffectWorld{effect_actor(starter, starter_base),
    effect_actor(wild, wild_base)}

def combat_profile(individual: Progression.Individual,
  +stats: Progression.StatBlock) -> Runtime.CombatProfile:
  match individual:
    case Progression.Individual{id, species, level, xp, hp, max_hp,
        ivs, moves, history, observations, unlocks, harmony}:
      Runtime.CombatProfile{Math.AlwaysHit{}, Math.StageNeutral{},
        Math.StageNeutral{}, 0, level, stat_attack(stats), stat_defense(stats), 0}

def actual_stats_result(result: Maybe<&2, Progression.StatBlock>,
  base: Progression.StatBlock) -> Progression.StatBlock:
  match result:
    case Some{stats}: stats
    case None{}: base

def actual_stats(+base: Progression.StatBlock,
  individual: Progression.Individual) -> Progression.StatBlock:
  match individual:
    case Progression.Individual{id, species, level, xp, hp, max_hp,
        ivs, moves, history, observations, unlocks, harmony}:
      actual_stats_result(Progression.calculate_stats(base, ivs, level), base)

def defender_snapshots(starter: Progression.Individual,
  wild: Progression.Individual, starter_base: Progression.StatBlock,
  wild_base: Progression.StatBlock) -> List<&2, Runtime.DefenderSnapshot>:
  [Runtime.DefenderSnapshot{Battle.ActorId{0n},
      combat_profile(starter, starter_base)},
    Runtime.DefenderSnapshot{Battle.ActorId{1n},
      combat_profile(wild, wild_base)}]

def move_sources(+owner: Battle.ActorId, moves: List<&2, U32>) ->
  List<&2, Sources.MoveSource>:
  match moves:
    case Nil{}: []
    case +move <> rest:
      Sources.MoveSource{owner, Math.MoveId{U32.to_nat(move)}, 0, False{}} <>
        move_sources(owner, rest)

def initial_sources(starter: Progression.Individual,
  wild: Progression.Individual) -> List<&2, Sources.MoveSource>:
  match starter wild:
    case Progression.Individual{id, species, level, xp, hp, max_hp, ivs,
        +starter_moves, history, observations, unlocks, harmony}
         Progression.Individual{wild_id, wild_species, wild_level, wild_xp,
        wild_hp, wild_max_hp, wild_ivs, +wild_moves, wild_history,
        wild_observations, wild_unlocks, wild_harmony}:
      List.append(&2, Sources.MoveSource,
        move_sources(Battle.ActorId{0n}, starter_moves),
        move_sources(Battle.ActorId{1n}, wild_moves))

def initial_economy(capacity: Economy.Capacity) -> Economy.State:
  Economy.State{capacity, 0n, 1n, 0n, 0n, 0n, []}

def initial_roster(capacity: Economy.Capacity) -> Roster.Roster:
  Roster.Roster{capacity, [Roster.IndividualId{1n}], []}

def initial_capture_catalog(wild: M7.SpeciesCaptureProfile,
  capacity: Economy.Capacity) -> M7.CaptureCatalog:
  M7.CaptureCatalog{[wild], [], [], [Economy.CapacityTier{capacity}]}

def initial_runtime(pair: Boot.BootPair, wait_ticks: U32,
  +starter: Progression.Individual, +wild: Progression.Individual,
  +starter_base: Progression.StatBlock,
  +wild_base: Progression.StatBlock) -> Runtime.RuntimeState:
  match pair:
    case Boot.BootPair{starter_value, wild_value, encounter_id, identity,
        rng, wait}:
      Runtime.RuntimeState{
        Battle.BattleState{0, wait_ticks,
          [Battle.Actor{Battle.ActorId{0n}, Battle.Player{},
             U32.to_nat(individual_hp(starter)), stat_speed(starter_base),
             Battle.Ready{}, 0},
           Battle.Actor{Battle.ActorId{1n}, Battle.Enemy{},
             U32.to_nat(individual_hp(wild)), stat_speed(wild_base),
             Battle.Ready{}, 0}], [], 0n, Battle.AwaitingCommands{}},
        rng, Runtime.WildEncounter{}, 0, initial_sources(starter, wild),
        [], [], defender_snapshots(starter, wild, starter_base, wild_base),
        Some{Runtime.RuntimeEffectState{Battle.ActorId{0n},
          Battle.ActorId{1n}, initial_world(starter, wild,
            starter_base, wild_base)}}}

def initial_m7(runtime: Runtime.RuntimeState, economy: Economy.State,
  roster: Roster.Roster, catalog: M7.CaptureCatalog) -> M7.State:
  M7.State{runtime, economy, roster, [], catalog}

def species_record(+wanted: Nat,
  rows: List<&2, Species.SpeciesProgressionRecord>) -> Maybe<Species.SpeciesProgressionRecord>:
  match rows:
    case Nil{}: None{}
    case +row <> rest:
      match row:
        case Species.SpeciesProgressionRecord{id, base, capture, xp, currency,
            combat_types, learning}:
          Bool.pick(Maybe<Species.SpeciesProgressionRecord>, Nat.is_eq(id, wanted),
            Some{row}, species_record(wanted, rest))

def species_rows(catalog: Species.Catalog) -> List<&2, Species.SpeciesProgressionRecord>:
  match catalog:
    case Species.Catalog{identity, move_count, species}: species

def learning_rows(rows: List<&2, Species.SpeciesProgressionRecord>) ->
  List<&2, Rewards.SpeciesLearning>:
  match rows:
    case Nil{}: []
    case Species.SpeciesProgressionRecord{species, base, capture, xp,
        currency, combat_types, learning} <> rest: learning <> learning_rows(rest)

def individual_level(value: Progression.Individual) -> U32:
  match value:
    case Progression.Individual{id, species, level, xp, hp, max_hp,
        ivs, moves, history, observations, unlocks, harmony}: level

def individual_ivs(value: Progression.Individual) -> Progression.StatBlock:
  match value:
    case Progression.Individual{id, species, level, xp, hp, max_hp,
        ivs, moves, history, observations, unlocks, harmony}: ivs

def initial_owner(+starter: Progression.Individual,
  base: Progression.StatBlock) -> Rewards.OwnedRewardInput:
  Rewards.OwnedRewardInput{starter, base, individual_ivs(starter),
    True{}, True{}}

def initial_context(encounter_id: Nat, owner: Rewards.OwnedRewardInput,
  economy: Economy.State) -> Bridge.Context:
  Bridge.Context{encounter_id, [], [owner], [], economy,
    Progression.RewardLedger{[]}}

def initial_enemy(+wild: Progression.Individual,
  base: Progression.StatBlock, xp: U32, currency: U32) -> Session.Enemy:
  Session.Enemy{Battle.ActorId{1n}, wild, base,
    Progression.DefeatedReward{individual_level(wild), xp, currency}}

def initial_owner_actor() -> Session.OwnerActor:
  Session.OwnerActor{Battle.ActorId{0n}, 1n, True{}}

def move_catalog_valid(pair: Boot.BootPair, species: Species.Catalog,
  moves: Moves.Catalog) -> Bool:
  match pair species moves:
    case Boot.BootPair{starter, wild, encounter, +identity, rng, wait}
         Species.Catalog{species_identity, species_move_count, rows}
         Moves.Catalog{move_identity, move_rows}:
      Bool.and(U32.is_eq(identity, species_identity),
        Bool.and(U32.is_eq(identity, move_identity),
          U32.is_eq(species_move_count,
            U32.from_nat(List.length(&2, Moves.MoveRecord, move_rows)))))

def capture_profile(row: Species.SpeciesProgressionRecord,
  individual: Progression.Individual) -> M7.SpeciesCaptureProfile:
  match row individual:
    case Species.SpeciesProgressionRecord{species, base, rate, xp, currency,
         combat_types, learning}
         Progression.Individual{id, actual_species, level, gained, current_hp,
           max_hp, ivs, moves, history, observations, unlocks, harmony}:
      M7.SpeciesCaptureProfile{species, rate, max_hp, False{}}

def build_battle(+pair: Boot.BootPair, starter_row: Species.SpeciesProgressionRecord,
  wild_row: Species.SpeciesProgressionRecord) -> Session.State:
  match pair starter_row wild_row:
    case Boot.BootPair{starter, wild, encounter_id, identity, rng, wait_ticks}
         Species.SpeciesProgressionRecord{starter_species, +starter_base,
           starter_capture, starter_xp, starter_currency, starter_types,
           starter_learning}
         Species.SpeciesProgressionRecord{wild_species, +wild_base,
           wild_capture, +wild_xp, +wild_currency, wild_types, wild_learning}:
      +starter_stats = actual_stats(starter_base, starter)
      +wild_stats = actual_stats(wild_base, wild)
      starter_speed = stat_speed(starter_stats)
      wild_speed = stat_speed(wild_stats)
      +capacity = default_capacity()
      +economy = initial_economy(capacity)
      roster = initial_roster(capacity)
      capture_catalog = initial_capture_catalog(capture_profile(wild_row, wild),
        capacity)
      runtime = initial_runtime(pair, wait_ticks, starter, wild,
        starter_stats, wild_stats)
      m7 = initial_m7(runtime, economy, roster, capture_catalog)
      owner = initial_owner(starter, starter_base)
      reward_context = initial_context(encounter_id, owner, economy)
      enemy = initial_enemy(wild, wild_base, wild_xp, wild_currency)
      owner_actor = initial_owner_actor()
      Session.State{m7, reward_context, [enemy], [owner_actor]}

def checked_session(valid: Bool, pair: Boot.BootPair,
  starter_row: Maybe<Species.SpeciesProgressionRecord>,
  wild_row: Maybe<Species.SpeciesProgressionRecord>,
  learning: List<&2, Rewards.SpeciesLearning>, +identity: Nat) -> Maybe<Playable.PlayableSession>:
  match valid starter_row wild_row:
    case False{} _ _: None{}
    case True{} None{} _: None{}
    case True{} _ None{}: None{}
    case True{} Some{starter} Some{wild}:
      state = build_battle(pair, starter, wild)
      Playable.open(state,
        Playable.ContentCatalog{learning, [], ruleset_version(), identity},
        ruleset_version(), identity)

# Creates a fresh, session_valid M7 world from matching validated catalogs.
# Move descriptors are retained as inert content; this starter session supports
# wait and escape until trusted runtime move/effect bindings are provided.
def build(+pair: Boot.BootPair, +species: Species.Catalog,
  moves: Moves.Catalog, starter_id: Nat, starter_level: U32,
  wild_id: Nat, wild_level: U32) -> Maybe<Playable.PlayableSession>:
  match pair:
    case Boot.BootPair{starter, wild, encounter, identity, rng, wait}:
      match starter wild:
        case Progression.Individual{starter_id_actual, starter_species,
            level, xp, hp, max_hp, ivs, starter_moves, _, _, _, _}
             Progression.Individual{wild_id_actual, wild_species,
            wild_actual_level, wild_xp, wild_hp, wild_max, wild_ivs,
            _, _, _, _, _}:
          learning = learning_rows(species_rows(species))
          checked_session(Bool.and(move_catalog_valid(pair, species, moves),
            Bool.and(Nat.is_eq(starter_id_actual, starter_id),
            Bool.and(Nat.is_eq(wild_id_actual, wild_id),
            Bool.and(U32.is_eq(level, starter_level),
            U32.is_eq(wild_actual_level, wild_level))))), pair,
            species_record(starter_species, species_rows(species)),
            species_record(wild_species, species_rows(species)), learning,
            U32.to_nat(identity))
