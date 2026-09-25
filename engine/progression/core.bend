import Base

# M7 progression rules. XP thresholds are shipped data; formulas and limits
# are engine-owned and bounded by the approved U06 contract.
type StatBlock is Data:
  StatBlock{hp: U32, attack: U32, defense: U32, special_attack: U32,
    special_defense: U32, speed: U32}

type ProgressState is Data:
  ProgressState{level: U32, xp: U32, current_hp: U32}

type ProgressResult is Data:
  ProgressAccepted{state: ProgressState, levels_gained: U32}
  ProgressRejected{state: ProgressState}

type EvolutionTarget is Data:
  EvolutionTarget{species: Nat, base_stats: StatBlock}

type Predicate is Data:
  MinimumLevel{level: U32}
  RequiredItem{item: U32}
  RequiredFlag{flag: Nat}
  TimeProfile{profile: Nat}
  KnownMove{move: U32}
  LearnedRecipe{recipe: Nat}
  MinimumHarmony{tier: U32}

type EvolutionRule is Data:
  EvolutionRule{id: Nat, target_species: Nat, automatic: Bool,
    predicates: List<&2, Predicate>}

type EvolutionContext is Data:
  EvolutionContext{level: U32, items: List<&2, U32>, flags: List<&2, Nat>,
    time_profile: Nat, moves: List<&2, U32>, recipes: List<&2, Nat>,
    harmony_tier: U32}

type EvolutionOffer is Data:
  EvolutionOffer{found: Bool, rule_id: Nat, target_species: Nat,
    automatic: Bool}

type MoveLearningRecord is Data:
  MoveLearnedRecord{move: U32}
  MoveReplacedRecord{offered: U32, removed: U32}
  MoveDeclinedRecord{move: U32}

type MoveLearning is Data:
  MoveLearned{moves: List<&2, U32>, history: List<&2, MoveLearningRecord>}
  MoveChoiceRequired{moves: List<&2, U32>, offered: U32,
    history: List<&2, MoveLearningRecord>}
  MoveDeclined{moves: List<&2, U32>, history: List<&2, MoveLearningRecord>}
  MoveReplaced{moves: List<&2, U32>, history: List<&2, MoveLearningRecord>}

type Individual is Data:
  Individual{id: Nat, species: Nat, level: U32, xp: U32,
    current_hp: U32, max_hp: U32, ivs: StatBlock,
    moves: List<&2, U32>, move_history: List<&2, MoveLearningRecord>,
    observations: List<&2, Nat>, unlocks: List<&2, Nat>, harmony: List<&2, U32>}

type EvolutionResult is Data:
  EvolutionAccepted{individual: Individual}
  EvolutionRejected{individual: Individual}


type ProgressionOutcome is Data:
  RewardVictory{}
  RewardCapture{}
  RewardDefeat{}
  RewardDraw{}
  RewardTimeout{}
  RewardEscape{}

type DefeatedReward is Data:
  DefeatedReward{level: U32, base_xp_yield: U32, base_currency_yield: U32}

type RewardParticipant is Data:
  RewardParticipant{individual: Nat, alive: Bool, previously_active: Bool}

type ParticipantXp is Data:
  ParticipantXp{individual: Nat, xp: U32}

type RewardLedger is Data:
  RewardLedger{completed_encounters: List<&2, Nat>}

type RewardPlan is Data:
  RewardPlan{participants: List<&2, ParticipantXp>, currency: U32}

type RewardPreparation is Data:
  RewardsPrepared{ledger: RewardLedger, plan: RewardPlan}
  RewardsRejected{ledger: RewardLedger}
  RewardsSkipped{ledger: RewardLedger}

# Canonical cumulative thresholds for levels 1 through 200.
def xp_thresholds() -> List<&2, U32>:
  [0,
    100,
    350,
    900,
    1900,
    3500,
    5850,
    9100,
    13400,
    18900,
    25750,
    34100,
    44100,
    55900,
    69650,
    85500,
    103600,
    124100,
    147150,
    172900,
    201500,
    233100,
    267850,
    305900,
    347400,
    392500,
    441350,
    494100,
    550900,
    611900,
    677250,
    747100,
    821600,
    900900,
    985150,
    1074500,
    1169100,
    1269100,
    1374650,
    1485900,
    1603000,
    1726100,
    1855350,
    1990900,
    2132900,
    2281500,
    2436850,
    2599100,
    2768400,
    2944900,
    3128750,
    3320100,
    3519100,
    3725900,
    3940650,
    4163500,
    4394600,
    4634100,
    4882150,
    5138900,
    5404500,
    5679100,
    5962850,
    6255900,
    6558400,
    6870500,
    7192350,
    7524100,
    7865900,
    8217900,
    8580250,
    8953100,
    9336600,
    9730900,
    10136150,
    10552500,
    10980100,
    11419100,
    11869650,
    12331900,
    12806000,
    13292100,
    13790350,
    14300900,
    14823900,
    15359500,
    15907850,
    16469100,
    17043400,
    17630900,
    18231750,
    18846100,
    19474100,
    20115900,
    20771650,
    21441500,
    22125600,
    22824100,
    23537150,
    24264900,
    25007500,
    25765100,
    26537850,
    27325900,
    28129400,
    28948500,
    29783350,
    30634100,
    31500900,
    32383900,
    33283250,
    34199100,
    35131600,
    36080900,
    37047150,
    38030500,
    39031100,
    40049100,
    41084650,
    42137900,
    43209000,
    44298100,
    45405350,
    46530900,
    47674900,
    48837500,
    50018850,
    51219100,
    52438400,
    53676900,
    54934750,
    56212100,
    57509100,
    58825900,
    60162650,
    61519500,
    62896600,
    64294100,
    65712150,
    67150900,
    68610500,
    70091100,
    71592850,
    73115900,
    74660400,
    76226500,
    77814350,
    79424100,
    81055900,
    82709900,
    84386250,
    86085100,
    87806600,
    89550900,
    91318150,
    93108500,
    94922100,
    96759100,
    98619650,
    100503900,
    102412000,
    104344100,
    106300350,
    108280900,
    110285900,
    112315500,
    114369850,
    116449100,
    118553400,
    120682900,
    122837750,
    125018100,
    127224100,
    129455900,
    131713650,
    133997500,
    136307600,
    138644100,
    141007150,
    143396900,
    145813500,
    148257100,
    150727850,
    153225900,
    155751400,
    158304500,
    160885350,
    163494100,
    166130900,
    168795900,
    171489250,
    174211100,
    176961600,
    179740900,
    182549150,
    185386500,
    188253100,
    191149100,
    194074650,
    197029900]

def xp_cap() -> U32:
  197029900

def threshold_at(index: Nat, values: List<&2, U32>) -> Maybe<&2, U32>:
  match index values:
    case 0n value <> rest: Some{value}
    case 1n+more _ <> rest: threshold_at(more, rest)
    case _ _: None{}

def threshold_for_level(valid: Bool, level: U32) -> Maybe<&2, U32>:
  match valid:
    case True{}: threshold_at(U32.to_nat(U32.sub(level, 1)), xp_thresholds())
    case False{}: None{}

def xp_threshold(+level: U32) -> Maybe<&2, U32>:
  threshold_for_level(Bool.and(U32.is_ge(level, 1), U32.is_le(level, 200)), level)

def capped_xp(xp: U32) -> U32:
  U32.min(xp, xp_cap())

def level_scan(rest: List<&2, U32>, +xp: U32, +level: U32) -> U32:
  match rest:
    case Nil{}: level
    case threshold <> tail:
      +candidate = level_scan(tail, xp, U32.add(level, 1))
      +delta = U32.sub(candidate, level)
      U32.add(level, U32.mul(delta, Bool.to_u32(U32.is_ge(xp, threshold))))

def level_for_xp(xp: U32) -> U32:
  level_scan(xp_thresholds(), capped_xp(xp), 0)

def stats_valid(base: StatBlock, ivs: StatBlock, +level: U32) -> Bool:
  match base ivs:
    case StatBlock{+bh, +ba, +bd, +bsa, +bsd, +bsp}
         StatBlock{ih, ia, id, isa, isd, isp}:
      Bool.and(Bool.and(U32.is_ge(level, 1), U32.is_le(level, 200)),
      Bool.and(Bool.and(U32.is_ge(bh, 1), U32.is_le(bh, 500)),
      Bool.and(Bool.and(U32.is_ge(ba, 1), U32.is_le(ba, 500)),
      Bool.and(Bool.and(U32.is_ge(bd, 1), U32.is_le(bd, 500)),
      Bool.and(Bool.and(U32.is_ge(bsa, 1), U32.is_le(bsa, 500)),
      Bool.and(Bool.and(U32.is_ge(bsd, 1), U32.is_le(bsd, 500)),
      Bool.and(Bool.and(U32.is_ge(bsp, 1), U32.is_le(bsp, 500)),
      Bool.and(Bool.and(U32.is_le(ih, 31), U32.is_le(ia, 31)),
      Bool.and(Bool.and(U32.is_le(id, 31), U32.is_le(isa, 31)),
      Bool.and(U32.is_le(isd, 31), U32.is_le(isp, 31)))))))))))

def hp_stat(base: U32, iv: U32, +level: U32) -> U32:
  (((U32.add(U32.mul(2, base), iv) * level / 100) : U32) + level + 10 : U32)

def other_stat(base: U32, iv: U32, +level: U32) -> U32:
  (((U32.add(U32.mul(2, base), iv) * level / 100) : U32) + 5 : U32)

def stats_from_valid(valid: Bool, base: StatBlock, ivs: StatBlock,
  +level: U32) -> Maybe<&2, StatBlock>:
  match valid base ivs:
    case True{} StatBlock{bh, ba, bd, bsa, bsd, bsp}
         StatBlock{ih, ia, id, isa, isd, isp}:
      Some{StatBlock{hp_stat(bh, ih, level), other_stat(ba, ia, level),
        other_stat(bd, id, level), other_stat(bsa, isa, level),
        other_stat(bsd, isd, level), other_stat(bsp, isp, level)}}
    case _ _ _: None{}

def calculate_stats(+base: StatBlock, +ivs: StatBlock, +level: U32) -> Maybe<&2, StatBlock>:
  stats_from_valid(stats_valid(base, ivs, level), base, ivs, level)

def xp_sum(reaches_cap: Bool, xp: U32, awarded: U32) -> U32:
  match reaches_cap:
    case True{}: xp_cap()
    case False{}: U32.add(xp, awarded)

def add_xp_bounded(xp: U32, +awarded: U32) -> U32:
  +safe_xp = capped_xp(xp)
  xp_sum(U32.is_ge(awarded, U32.sub(xp_cap(), safe_xp)), safe_xp, awarded)

def finish_xp_hp(increased: Bool, +new_hp: U32, old_hp: U32,
  level: U32, +current_hp: U32, +new_xp: U32, +new_level: U32) -> ProgressResult:
  match increased:
    case True{}:
      +delta = U32.sub(new_hp, old_hp)
      ProgressAccepted{ProgressState{new_level, new_xp,
        U32.min(new_hp, U32.add(current_hp, delta))}, U32.sub(new_level, level)}
    case False{}:
      ProgressAccepted{ProgressState{new_level, new_xp,
        U32.min(current_hp, new_hp)}, U32.sub(new_level, level)}

def finish_xp_some(+new_hp: U32, +old_hp: U32, state: ProgressState,
  new_xp: U32, new_level: U32) -> ProgressResult:
  match state:
    case ProgressState{level, xp, current_hp}:
      finish_xp_hp(U32.is_gt(new_hp, old_hp), new_hp, old_hp, level,
        current_hp, new_xp, new_level)

def finish_xp(new_stats: Maybe<&2, StatBlock>, old_stats: StatBlock,
  state: ProgressState, new_xp: U32, new_level: U32) -> ProgressResult:
  match new_stats:
    case None{}: ProgressRejected{state}
    case Some{StatBlock{new_hp, _, _, _, _, _}}:
      match old_stats:
        case StatBlock{old_hp, _, _, _, _, _}:
          finish_xp_some(new_hp, old_hp, state, new_xp, new_level)

def apply_xp_consistent(valid: Bool, base: StatBlock, ivs: StatBlock,
  +state: ProgressState, awarded: U32, old_stats: StatBlock) -> ProgressResult:
  match valid state:
    case False{} _: ProgressRejected{state}
    case True{} ProgressState{level, +xp, current_hp}:
      +new_xp = add_xp_bounded(xp, awarded)
      +new_level = level_for_xp(new_xp)
      finish_xp(calculate_stats(base, ivs, new_level), old_stats, state,
        new_xp, new_level)

def valid_progress_inputs(stats: StatBlock, +level: U32, +xp: U32,
  current_hp: U32) -> Bool:
  match stats:
    case StatBlock{max_hp, _, _, _, _, _}:
      Bool.and(U32.is_le(xp, xp_cap()),
        Bool.and(U32.is_eq(level_for_xp(xp), level),
          U32.is_le(current_hp, max_hp)))

def apply_xp_from_stats(old_stats: Maybe<&2, StatBlock>, base: StatBlock,
  ivs: StatBlock, +state: ProgressState, awarded: U32) -> ProgressResult:
  match old_stats state:
    case None{} _: ProgressRejected{state}
    case Some{+stats} ProgressState{level, xp, current_hp}:
      apply_xp_consistent(valid_progress_inputs(stats, level, xp, current_hp),
        base, ivs, state, awarded, stats)

def apply_xp(+base: StatBlock, +ivs: StatBlock, +state: ProgressState,
  awarded: U32) -> ProgressResult:
  match state:
    case ProgressState{level, xp, current_hp}:
      apply_xp_from_stats(calculate_stats(base, ivs, level), base, ivs,
        state, awarded)

def contains_u32(+value: U32, values: List<&2, U32>) -> Bool:
  match values:
    case Nil{}: False{}
    case +item <> rest: Bool.or(U32.is_eq(value, item), contains_u32(value, rest))

def contains_nat(+value: Nat, values: List<&2, Nat>) -> Bool:
  match values:
    case Nil{}: False{}
    case +item <> rest: Bool.or(Nat.is_eq(value, item), contains_nat(value, rest))

def predicate_holds(predicate: Predicate, context: EvolutionContext) -> Bool:
  match predicate context:
    case MinimumLevel{required} EvolutionContext{level, _, _, _, _, _, _}:
      U32.is_ge(level, required)
    case RequiredItem{item} EvolutionContext{_, items, _, _, _, _, _}:
      contains_u32(item, items)
    case RequiredFlag{flag} EvolutionContext{_, _, flags, _, _, _, _}:
      contains_nat(flag, flags)
    case TimeProfile{profile} EvolutionContext{_, _, _, current, _, _, _}:
      Nat.is_eq(profile, current)
    case KnownMove{move} EvolutionContext{_, _, _, _, moves, _, _}:
      contains_u32(move, moves)
    case LearnedRecipe{recipe} EvolutionContext{_, _, _, _, _, recipes, _}:
      contains_nat(recipe, recipes)
    case MinimumHarmony{tier} EvolutionContext{_, _, _, _, _, _, current}:
      U32.is_ge(current, tier)

def predicate_is_valid(predicate: Predicate) -> Bool:
  match predicate:
    case MinimumLevel{+level}:
      Bool.and(U32.is_ge(level, 1), U32.is_le(level, 200))
    case RequiredItem{item}: True{}
    case RequiredFlag{flag}: True{}
    case TimeProfile{profile}: True{}
    case KnownMove{move}: True{}
    case LearnedRecipe{recipe}: True{}
    case MinimumHarmony{tier}: U32.is_le(tier, 5)

def predicates_valid(predicates: List<&2, Predicate>) -> Bool:
  match predicates:
    case Nil{}: True{}
    case predicate <> rest:
      Bool.and(predicate_is_valid(predicate), predicates_valid(rest))

def predicates_hold(predicates: List<&2, Predicate>, +context: EvolutionContext) -> Bool:
  match predicates:
    case Nil{}: True{}
    case predicate <> rest:
      Bool.and(predicate_holds(predicate, context), predicates_hold(rest, context))

def evolution_rule_le(left: EvolutionRule, right: EvolutionRule) -> Bool:
  match left right:
    case EvolutionRule{id_left, _, _, _} EvolutionRule{id_right, _, _, _}:
      Nat.is_le(id_left, id_right)

def evolution_rule_valid(rule: EvolutionRule) -> Bool:
  match rule:
    case EvolutionRule{id, target_species, automatic, +predicates}:
      Bool.and(Nat.is_le(List.length(&2, Predicate, predicates), 4n),
        predicates_valid(predicates))

def select_evolution(+candidate: Bool, rule: EvolutionRule,
  current: EvolutionOffer) -> EvolutionOffer:
  match rule current:
    case EvolutionRule{id, target, automatic, predicates}
         EvolutionOffer{+found, rule_id, target_species, was_automatic}:
      +take = Bool.and(candidate, Bool.not(found))
      +take_n = U32.to_nat(Bool.to_u32(take))
      +keep_n = U32.to_nat(Bool.to_u32(Bool.not(take)))
      EvolutionOffer{Bool.or(found, candidate),
        Nat.add(Nat.mul(take_n, id), Nat.mul(keep_n, rule_id)),
        Nat.add(Nat.mul(take_n, target), Nat.mul(keep_n, target_species)),
        Bool.or(Bool.and(take, automatic),
          Bool.and(Bool.not(take), was_automatic))}

def evolution_scan(rules: List<&2, EvolutionRule>,
  +context: EvolutionContext, +current: EvolutionOffer) -> EvolutionOffer:
  match rules:
    case Nil{}: current
    case +rule <> rest:
      match rule:
        case EvolutionRule{id, target, automatic, predicates}:
          evolution_scan(rest, context,
            select_evolution(Bool.and(evolution_rule_valid(rule),
              predicates_hold(predicates, context)), rule, current))

def first_evolution(context: EvolutionContext,
  rules: List<&2, EvolutionRule>) -> EvolutionOffer:
  +ordered = List.sort(~EvolutionRule, ~evolution_rule_le, rules)
  evolution_scan(ordered, context, EvolutionOffer{False{}, 0n, 0n, False{}})

# Evolve only through the engine's sorted rule scan, and require the supplied
# growth record to identify that rule's target. Max HP follows the target
# species; current HP preserves the max-HP delta, or clamps on a decrease.
def evolution_target_matches(found: Bool, target_species: Nat,
  target: EvolutionTarget) -> Bool:
  match found target:
    case True{} EvolutionTarget{species, base_stats}:
      Nat.is_eq(target_species, species)
    case _ _: False{}

def evolution_hp(increased: Bool, +new_hp: U32, +old_hp: U32,
  current_hp: U32) -> U32:
  match increased:
    case True{}: U32.min(new_hp, U32.add(current_hp, U32.sub(new_hp, old_hp)))
    case False{}: U32.min(current_hp, new_hp)

def evolve_target_hp(valid_hp: Bool, increased: Bool, +new_hp: U32,
  +old_hp: U32, individual: Individual, target_species: Nat) -> EvolutionResult:
  match valid_hp:
    case False{}: EvolutionRejected{individual}
    case True{}:
      match individual:
        case Individual{id, species, level, xp, current_hp, max_hp, ivs,
            moves, move_history, observations, unlocks, harmony}:
          EvolutionAccepted{Individual{id, target_species, level, xp,
            evolution_hp(increased, new_hp, old_hp, current_hp), new_hp, ivs,
            moves, move_history, observations, unlocks, harmony}}

def evolve_target_stats(stats: Maybe<&2, StatBlock>, individual: Individual,
  target_species: Nat) -> EvolutionResult:
  match stats individual:
    case None{} _: EvolutionRejected{individual}
    case Some{StatBlock{+new_hp, _, _, _, _, _}}
         Individual{id, species, level, xp, +current_hp, +old_hp, ivs,
           moves, move_history, observations, unlocks, harmony}:
      evolve_target_hp(U32.is_le(current_hp, old_hp),
        U32.is_gt(new_hp, old_hp), new_hp, old_hp, individual, target_species)

def evolve_checked_result(match_ok: Bool, individual: Individual,
  target: EvolutionTarget) -> EvolutionResult:
  match match_ok individual target:
    case False{} _ _: EvolutionRejected{individual}
    case True{} Individual{id, species, +level, xp, current_hp, max_hp, +ivs,
        moves, move_history, observations, unlocks, harmony}
        EvolutionTarget{target_species, base_stats}:
      evolve_target_stats(calculate_stats(base_stats, ivs, level), individual,
        target_species)

def evolve_checked_inputs(offer: EvolutionOffer, individual: Individual,
  context_level: U32, +target: EvolutionTarget) -> EvolutionResult:
  match offer individual:
    case EvolutionOffer{found, rule_id, target_species, automatic}
         Individual{id, species, +level, +xp, +current_hp, +max_hp, +ivs,
           moves, move_history, observations, unlocks, harmony}:
      evolve_checked_result(Bool.and(U32.is_eq(context_level, level),
        Bool.and(evolution_target_matches(found, target_species, target),
          Bool.and(U32.is_le(xp, xp_cap()),
            Bool.and(U32.is_eq(level_for_xp(xp), level),
              U32.is_le(current_hp, max_hp))))), individual, target)

def evolve_checked(individual: Individual, context: EvolutionContext,
  rules: List<&2, EvolutionRule>, target: EvolutionTarget) -> EvolutionResult:
  match context:
    case EvolutionContext{+context_level, items, flags, time_profile, moves,
        recipes, harmony_tier}:
      evolve_checked_inputs(first_evolution(context, rules), individual,
        context_level, target)


def move_contains(move: U32, moves: List<&2, U32>) -> Bool:
  contains_u32(move, moves)

def append_learning_record(record: MoveLearningRecord,
  history: List<&2, MoveLearningRecord>) -> List<&2, MoveLearningRecord>:
  List.append(&2, MoveLearningRecord, history, [record])

def request_move_result(present: Bool, room: Bool,
  +moves: List<&2, U32>, +offered: U32,
  +history: List<&2, MoveLearningRecord>) -> MoveLearning:
  match present room:
    case True{} _: MoveLearned{moves, history}
    case False{} True{}:
      MoveLearned{List.append(&2, U32, moves, [offered]),
        append_learning_record(MoveLearnedRecord{offered}, history)}
    case False{} False{}: MoveChoiceRequired{moves, offered, history}

def request_move(+moves: List<&2, U32>, +offered: U32, capacity: U32,
  +history: List<&2, MoveLearningRecord>) -> MoveLearning:
  request_move_result(move_contains(offered, moves),
    Nat.is_lt(List.length(&2, U32, moves), U32.to_nat(capacity)), moves,
    offered, history)

def replace_move(+old: U32, +new: U32,
  moves: List<&2, U32>) -> List<&2, U32>:
  match moves:
    case Nil{}: []
    case +item <> rest:
      +replace_flag = Bool.to_u32(U32.is_eq(old, item))
      +keep_flag = U32.sub(1, replace_flag)
      +value = U32.add(U32.mul(new, replace_flag), U32.mul(item, keep_flag))
      value <> replace_move(old, new, rest)

def resolve_move_replacement(valid: Bool, +moves: List<&2, U32>,
  +offered: U32, +slot_move: U32,
  +history: List<&2, MoveLearningRecord>) -> MoveLearning:
  match valid:
    case True{}:
      MoveReplaced{replace_move(slot_move, offered, moves),
        append_learning_record(MoveReplacedRecord{offered, slot_move}, history)}
    case False{}: MoveChoiceRequired{moves, offered, history}

def resolve_move_choice(barrier: MoveLearning, accept: Bool,
  replacement: Maybe<&2, U32>) -> MoveLearning:
  match barrier accept replacement:
    case MoveChoiceRequired{moves, offered, history} False{} _:
      MoveDeclined{moves,
        append_learning_record(MoveDeclinedRecord{offered}, history)}
    case MoveChoiceRequired{+moves, +offered, +history} True{} Some{+slot_move}:
      resolve_move_replacement(move_contains(slot_move, moves), moves,
        offered, slot_move, history)
    case MoveChoiceRequired{moves, offered, history} _ _:
      MoveChoiceRequired{moves, offered, history}
    case other _ _: other

def commit_move_learning(individual: Individual,
  result: MoveLearning) -> Individual:
  match individual result:
    case Individual{id, species, level, xp, current_hp, max_hp, ivs,
         old_moves, old_history, observations, unlocks, harmony}
         MoveLearned{moves, history}:
      Individual{id, species, level, xp, current_hp, max_hp, ivs,
        moves, history, observations, unlocks, harmony}
    case Individual{id, species, level, xp, current_hp, max_hp, ivs,
         old_moves, old_history, observations, unlocks, harmony}
         MoveDeclined{moves, history}:
      Individual{id, species, level, xp, current_hp, max_hp, ivs,
        moves, history, observations, unlocks, harmony}
    case Individual{id, species, level, xp, current_hp, max_hp, ivs,
         old_moves, old_history, observations, unlocks, harmony}
         MoveReplaced{moves, history}:
      Individual{id, species, level, xp, current_hp, max_hp, ivs,
        moves, history, observations, unlocks, harmony}
    case individual MoveChoiceRequired{moves, offered, history}: individual

def nat_le(left: Nat, right: Nat) -> Bool:
  Nat.is_le(left, right)

def eligible(participant: RewardParticipant) -> Bool:
  match participant:
    case RewardParticipant{individual, alive, previously_active}:
      Bool.or(alive, previously_active)

def eligible_count(participants: List<&2, RewardParticipant>) -> U32:
  match participants:
    case Nil{}: 0
    case participant <> rest:
      U32.add(Bool.to_u32(eligible(participant)), eligible_count(rest))

def valid_defeated_rewards(rewards: List<&2, DefeatedReward>) -> Bool:
  match rewards:
    case Nil{}: True{}
    case reward <> rest:
      match reward:
        case DefeatedReward{+level, +base_xp, base_currency}:
          Bool.and(Bool.and(U32.is_ge(level, 1), U32.is_le(level, 200)),
          Bool.and(Bool.and(U32.is_ge(base_xp, 1), U32.is_le(base_xp, 1000)),
            Bool.and(U32.is_le(base_currency, 100000),
              valid_defeated_rewards(rest))))

def participant_id_in(+id: Nat,
  participants: List<&2, RewardParticipant>) -> Bool:
  match participants:
    case Nil{}: False{}
    case participant <> rest:
      match participant:
        case RewardParticipant{other, alive, previously_active}:
          Bool.or(Nat.is_eq(id, other), participant_id_in(id, rest))

def participant_ids_unique(participants: List<&2, RewardParticipant>) -> Bool:
  match participants:
    case Nil{}: True{}
    case participant <> +rest:
      match participant:
        case RewardParticipant{id, alive, previously_active}:
          Bool.and(Bool.not(participant_id_in(id, rest)),
            participant_ids_unique(rest))

def reward_inputs_valid(+rewards: List<&2, DefeatedReward>,
  +participants: List<&2, RewardParticipant>) -> Bool:
  Bool.and(Bool.and(Nat.is_le(List.length(&2, DefeatedReward, rewards), 12n),
      valid_defeated_rewards(rewards)),
    Bool.and(Bool.and(Nat.is_ge(List.length(&2, RewardParticipant, participants), 1n),
        Nat.is_le(List.length(&2, RewardParticipant, participants), 12n)),
      Bool.and(participant_ids_unique(participants),
        U32.is_gt(eligible_count(participants), 0))))

def zero_participant_xp(participants: List<&2, RewardParticipant>) ->
  List<&2, ParticipantXp>:
  match participants:
    case Nil{}: []
    case participant <> rest:
      match participant:
        case RewardParticipant{id, alive, previously_active}:
          ParticipantXp{id, 0} <> zero_participant_xp(rest)

def award_one_opponent(+level: U32, +base_xp: U32,
  participants: List<&2, RewardParticipant>,
  awards: List<&2, ParticipantXp>, +eligible_total: U32) -> List<&2, ParticipantXp>:
  match participants awards:
    case Nil{} Nil{}: []
    case RewardParticipant{id, alive, previously_active} <> participant_rest
         ParticipantXp{award_id, xp} <> award_rest:
      +eligible_flag = Bool.to_u32(Bool.or(alive, previously_active))
      +gain = U32.div(U32.mul(base_xp, level), eligible_total)
      +next_xp = U32.add(xp, U32.mul(gain, eligible_flag))
      ParticipantXp{award_id, next_xp} <>
        award_one_opponent(level, base_xp, participant_rest, award_rest,
          eligible_total)
    case _ _: []

def award_opponents(rewards: List<&2, DefeatedReward>,
  +participants: List<&2, RewardParticipant>,
  awards: List<&2, ParticipantXp>, +currency: U32,
  +eligible_total: U32) -> RewardPlan:
  match rewards:
    case Nil{}: RewardPlan{awards, currency}
    case reward <> rest:
      match reward:
        case DefeatedReward{level, base_xp, base_currency}:
          +next_awards = award_one_opponent(level, base_xp, participants,
            awards, eligible_total)
          award_opponents(rest, participants, next_awards,
            U32.add(currency, base_currency), eligible_total)

def paid_reward_plan(+rewards: List<&2, DefeatedReward>,
  +participants: List<&2, RewardParticipant>) -> RewardPlan:
  +eligible_total = eligible_count(participants)
  +initial = zero_participant_xp(participants)
  award_opponents(rewards, participants, initial, 0, eligible_total)

def paid_rewards_result(valid: Bool, +encounter_id: Nat,
  +rewards: List<&2, DefeatedReward>, +participants: List<&2, RewardParticipant>,
  +ledger: RewardLedger) -> RewardPreparation:
  match valid ledger:
    case False{} _: RewardsRejected{ledger}
    case True{} RewardLedger{+completed}:
      +plan = paid_reward_plan(rewards, participants)
      +next_completed = List.sort(~Nat, ~nat_le, encounter_id <> completed)
      RewardsPrepared{RewardLedger{next_completed}, plan}

def prepare_paid_rewards(+encounter_id: Nat,
  +rewards: List<&2, DefeatedReward>,
  +participants: List<&2, RewardParticipant>, +ledger: RewardLedger) -> RewardPreparation:
  match ledger:
    case RewardLedger{+completed}:
      paid_rewards_result(Bool.and(Nat.is_gt(encounter_id, 0n),
        Bool.and(reward_inputs_valid(rewards, participants),
          Bool.not(contains_nat(encounter_id, completed)))),
        encounter_id, rewards, participants, ledger)

def prepare_rewards(outcome: ProgressionOutcome, encounter_id: Nat,
  rewards: List<&2, DefeatedReward>, participants: List<&2, RewardParticipant>,
  ledger: RewardLedger) -> RewardPreparation:
  match outcome:
    case RewardVictory{}: prepare_paid_rewards(encounter_id, rewards, participants, ledger)
    case RewardCapture{}: prepare_paid_rewards(encounter_id, rewards, participants, ledger)
    case _: RewardsSkipped{ledger}
