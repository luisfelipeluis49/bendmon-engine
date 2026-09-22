import Base
import ./combat_math.bend as Math
import ./combat_resolver.bend as Combat
import ./rng.bend as Rng

# M4 closed effect algebra. Conditional branches contain leaf sequences; nested
# conditionals are deliberately absent from this ruleset version.
type EffectTarget is Data:
  Source{}
  Target{}

type DamageCategory is Data:
  Physical{}
  Special{}

type StatId is Data:
  Attack{}
  Defense{}
  SpecialAttack{}
  SpecialDefense{}
  Speed{}
  Accuracy{}
  Evasion{}

type StageDelta is Data:
  Raise{magnitude: U32}
  Lower{magnitude: U32}

type StatusId is Data:
  Burn{}
  Poison{}
  Sleep{}
  Stun{}
  Blind{}

type StatusInstance is Data:
  StatusInstance{status: StatusId, duration: U32, magnitude: U32}

type StatStages is Data:
  StatStages{attack: Math.Stage, defense: Math.Stage,
    special_attack: Math.Stage, special_defense: Math.Stage,
    speed: Math.Stage, accuracy: Math.Stage, evasion: Math.Stage}

type EffectActor is Data:
  EffectActor{hp: U32, max_hp: U32, physical_defense: U32,
    special_defense: U32, stages: StatStages,
    statuses: List<&2, StatusInstance>, protected: Bool,
    immunities: List<&2, StatusId>}

type EffectWorld is Data:
  EffectWorld{source: EffectActor, target: EffectActor}

type PhysicalDamageState is Data:
  NormalPhysical{}
  BurnedPhysical{}

type ActionSnapshot is Data:
  ActionSnapshot{level: U32, physical_attack: U32, special_attack: U32,
    accuracy: Math.Stage, accuracy_mode: Math.AccuracyMode,
    physical_damage: PhysicalDamageState,
    critical_bonus: U32}

type Predicate is Data:
  HpBelowHalf{target: EffectTarget}
  HasStatus{target: EffectTarget, status: StatusId}
  PriorDamagePositive{node: Nat}

type LeafEffect is Data:
  Damage{node: Nat, target: EffectTarget, category: DamageCategory, power: U32}
  Heal{target: EffectTarget, amount: U32}
  Drain{target: EffectTarget, from_node: Nat, numerator: U32, denominator: U32}
  Recoil{target: EffectTarget, from_node: Nat, numerator: U32, denominator: U32}
  ApplyStatus{target: EffectTarget, status: StatusId}
  RemoveStatus{target: EffectTarget, status: StatusId}
  ClearStatuses{target: EffectTarget}
  ModifyStat{target: EffectTarget, stat: StatId, delta: StageDelta}

type Effect is Data:
  Leaf{effect: LeafEffect}
  Conditional{predicate: Predicate, then_effects: List<&2, LeafEffect>,
    else_effects: List<&2, LeafEffect>}

type EffectProgram is Data:
  EffectProgram{effects: List<&2, Effect>}

type DamageRecord is Data:
  DamageRecord{node: Nat, actual: U32}

type NoEffectReason is Data:
  Protected{}
  Immune{}
  WeakerConflict{}
  AlreadyAbsent{}
  FullHp{}
  ZeroDerived{}
  ZeroDamage{}

type EffectEvent is Data:
  DamageApplied{node: Nat, target: EffectTarget, category: DamageCategory,
    amount: U32, critical: Bool}
  DamageMissed{node: Nat, target: EffectTarget, draw: U32}
  DamageNoEffect{node: Nat, target: EffectTarget, reason: NoEffectReason}
  HpRestored{target: EffectTarget, amount: U32}
  DerivedDamage{target: EffectTarget, from_node: Nat, amount: U32}
  StatusApplied{target: EffectTarget, status: StatusId, refreshed: Bool}
  StatusRemoved{target: EffectTarget, status: StatusId}
  StatusesCleared{target: EffectTarget, count: Nat}
  StatModified{target: EffectTarget, stat: StatId, before: Math.Stage,
    after: Math.Stage}
  NoEffect{target: EffectTarget, reason: NoEffectReason}
  ActionMissed{draw: U32}
  ActionBlocked{}
  OpportunityEnded{blocked: Bool, residual: U32}
  ConditionalSelected{taken: Bool}

type EffectDiagnostic is Data:
  EmptyProgram{}
  TopLevelLimit{count: Nat}
  CostLimit{cost: Nat}
  MultipleDamageNodes{}
  DamageMustBeFirst{node: Nat}
  DuplicateDamageNode{node: Nat}
  ForwardDamageReference{node: Nat}
  InvalidPower{power: U32}
  InvalidAmount{amount: U32}
  InvalidFraction{numerator: U32, denominator: U32}
  InvalidStageDelta{magnitude: U32}
  BranchDamageUnsupported{node: Nat}
  InvalidActorState{}

type EffectResult is Data:
  EffectsCommitted{world: EffectWorld, rng: Rng.RngState,
    events: List<&2, EffectEvent>, damage: List<&2, DamageRecord>}
  EffectsRejected{world: EffectWorld, rng: Rng.RngState,
    diagnostics: List<&2, EffectDiagnostic>}
  EffectsFaulted{world: EffectWorld, rng: Rng.RngState,
    reason: Rng.RngSampleResult}

type Validation is Data:
  Validation{diagnostics: List<&2, EffectDiagnostic>, seen: List<&2, Nat>,
    damage_count: Nat, cost: Nat}

type Execution is Data:
  Execution{world: EffectWorld, rng: Rng.RngState,
    events: List<&2, EffectEvent>, damage: List<&2, DamageRecord>}
  ExecutionStopped{world: EffectWorld, rng: Rng.RngState,
    events: List<&2, EffectEvent>, damage: List<&2, DamageRecord>}
  ExecutionFault{reason: Rng.RngSampleResult}

def status_eq(left: StatusId, right: StatusId) -> Bool:
  match left right:
    case Burn{} Burn{}: True{}
    case Poison{} Poison{}: True{}
    case Sleep{} Sleep{}: True{}
    case Stun{} Stun{}: True{}
    case Blind{} Blind{}: True{}
    case _ _: False{}

def target_actor(target: EffectTarget, world: EffectWorld) -> EffectActor:
  match target world:
    case Source{} EffectWorld{source, target_value}: source
    case Target{} EffectWorld{source, target_value}: target_value

def replace_actor(target: EffectTarget, actor: EffectActor,
  world: EffectWorld) -> EffectWorld:
  match target world:
    case Source{} EffectWorld{source, target_value}: EffectWorld{actor, target_value}
    case Target{} EffectWorld{source, target_value}: EffectWorld{source, actor}

def actor_hp(actor: EffectActor) -> U32:
  EffectActor{hp, max_hp, physical_defense, special_defense, stages, statuses,
    protected, immunities} = actor
  hp

def actor_max_hp(actor: EffectActor) -> U32:
  EffectActor{hp, max_hp, physical_defense, special_defense, stages, statuses,
    protected, immunities} = actor
  max_hp

def actor_statuses(actor: EffectActor) -> List<&2, StatusInstance>:
  EffectActor{hp, max_hp, physical_defense, special_defense, stages, statuses,
    protected, immunities} = actor
  statuses

def actor_protected(actor: EffectActor) -> Bool:
  EffectActor{hp, max_hp, physical_defense, special_defense, stages, statuses,
    protected, immunities} = actor
  protected

def actor_immunities(actor: EffectActor) -> List<&2, StatusId>:
  EffectActor{hp, max_hp, physical_defense, special_defense, stages, statuses,
    protected, immunities} = actor
  immunities

def status_present(+wanted: StatusId,
  values: List<&2, StatusInstance>) -> Bool:
  match values:
    case Nil{}: False{}
    case StatusInstance{+status, duration, magnitude} <> +rest:
      Bool.or(status_eq(wanted, status), status_present(wanted, rest))

def immune_present(+wanted: StatusId, values: List<&2, StatusId>) -> Bool:
  match values:
    case Nil{}: False{}
    case status <> rest:
      Bool.or(status_eq(wanted, status), immune_present(wanted, rest))

def nat_present(+wanted: Nat, values: List<&2, Nat>) -> Bool:
  match values:
    case Nil{}: False{}
    case value <> rest: Bool.or(Nat.is_eq(wanted, value),
      nat_present(wanted, rest))

def damage_amount(+wanted: Nat, records: List<&2, DamageRecord>) -> U32:
  match records:
    case Nil{}: 0
    case DamageRecord{node, actual} <> rest:
      U32.add(U32.mul(Bool.to_u32(Nat.is_eq(wanted, node)), actual),
        damage_amount(wanted, rest))

def stage_from_order(order: Cmp, +index: U32) -> Math.Stage:
  match order:
    case LT{}: Math.StageDown{U32.to_nat(U32.sub(6, index))}
    case EQ{}: Math.StageNeutral{}
    case GT{}: Math.StageUp{U32.to_nat(U32.sub(index, 6))}

def stage_from_index(+index: U32) -> Math.Stage:
  stage_from_order(U32.cmp(index, 6), index)

def apply_delta(+stage: Math.Stage, delta: StageDelta) -> Math.Stage:
  match delta:
    case Raise{magnitude}:
      +index = Math.stage_index(stage)
      stage_from_index(U32.min(12, U32.add(index, magnitude)))
    case Lower{magnitude}:
      +index = Math.stage_index(stage)
      stage_from_index(U32.sub(index, U32.min(index, magnitude)))

def select_stage(stat: StatId, stages: StatStages) -> Math.Stage:
  match stat stages:
    case Attack{} StatStages{attack, defense, special_attack, special_defense,
        speed, accuracy, evasion}: attack
    case Defense{} StatStages{attack, defense, special_attack, special_defense,
        speed, accuracy, evasion}: defense
    case SpecialAttack{} StatStages{attack, defense, special_attack,
        special_defense, speed, accuracy, evasion}: special_attack
    case SpecialDefense{} StatStages{attack, defense, special_attack,
        special_defense, speed, accuracy, evasion}: special_defense
    case Speed{} StatStages{attack, defense, special_attack, special_defense,
        speed, accuracy, evasion}: speed
    case Accuracy{} StatStages{attack, defense, special_attack, special_defense,
        speed, accuracy, evasion}: accuracy
    case Evasion{} StatStages{attack, defense, special_attack, special_defense,
        speed, accuracy, evasion}: evasion

def replace_stage(stat: StatId, value: Math.Stage,
  stages: StatStages) -> StatStages:
  match stat stages:
    case Attack{} StatStages{attack, defense, special_attack, special_defense,
        speed, accuracy, evasion}: StatStages{value, defense, special_attack,
          special_defense, speed, accuracy, evasion}
    case Defense{} StatStages{attack, defense, special_attack, special_defense,
        speed, accuracy, evasion}: StatStages{attack, value, special_attack,
          special_defense, speed, accuracy, evasion}
    case SpecialAttack{} StatStages{attack, defense, special_attack,
        special_defense, speed, accuracy, evasion}: StatStages{attack, defense,
          value, special_defense, speed, accuracy, evasion}
    case SpecialDefense{} StatStages{attack, defense, special_attack,
        special_defense, speed, accuracy, evasion}: StatStages{attack, defense,
          special_attack, value, speed, accuracy, evasion}
    case Speed{} StatStages{attack, defense, special_attack, special_defense,
        speed, accuracy, evasion}: StatStages{attack, defense, special_attack,
          special_defense, value, accuracy, evasion}
    case Accuracy{} StatStages{attack, defense, special_attack, special_defense,
        speed, accuracy, evasion}: StatStages{attack, defense, special_attack,
          special_defense, speed, value, evasion}
    case Evasion{} StatStages{attack, defense, special_attack, special_defense,
        speed, accuracy, evasion}: StatStages{attack, defense, special_attack,
          special_defense, speed, accuracy, value}

def actor_stage(+stat: StatId, actor: EffectActor) -> Math.Stage:
  EffectActor{hp, max_hp, physical_defense, special_defense, stages, statuses,
    protected, immunities} = actor
  select_stage(stat, stages)

def damage_actor(+amount: U32, actor: EffectActor) -> EffectActor:
  match actor:
    case EffectActor{+hp, max_hp, physical_defense, special_defense, stages,
        statuses, protected, immunities}:
      EffectActor{U32.sub(hp, U32.min(hp, amount)), max_hp, physical_defense,
        special_defense, stages, statuses, protected, immunities}

def heal_actor(+amount: U32, actor: EffectActor) -> EffectActor:
  match actor:
    case EffectActor{+hp, +max_hp, physical_defense, special_defense, stages,
        statuses, protected, immunities}:
      +room = U32.sub(max_hp, hp)
      EffectActor{U32.add(hp, U32.min(room, amount)), max_hp,
        physical_defense, special_defense, stages, statuses, protected,
        immunities}

def modify_actor(+stat: StatId, +delta: StageDelta,
  actor: EffectActor) -> EffectActor:
  match actor:
    case EffectActor{hp, max_hp, physical_defense, special_defense, +stages,
        statuses, protected, immunities}:
      EffectActor{hp, max_hp, physical_defense, special_defense,
        replace_stage(stat, apply_delta(select_stage(stat, stages), delta), stages),
        statuses, protected, immunities}

def status_duration(status: StatusId) -> U32:
  match status:
    case Burn{}: 3
    case Poison{}: 4
    case Sleep{}: 2
    case Stun{}: 1
    case Blind{}: 3

def status_magnitude(status: StatusId, +maximum: U32) -> U32:
  match status:
    case Burn{}: U32.max(1, U32.div(maximum, 16))
    case Poison{}: U32.max(1, U32.div(maximum, 8))
    case Sleep{}: 0
    case Stun{}: 0
    case Blind{}: 2

def conflicts(left: StatusId, right: StatusId) -> Bool:
  match left right:
    case Burn{} Poison{}: True{}
    case Poison{} Burn{}: True{}
    case Sleep{} Stun{}: True{}
    case Stun{} Sleep{}: True{}
    case _ _: False{}

def remove_status(+wanted: StatusId,
  values: List<&2, StatusInstance>) -> List<&2, StatusInstance>:
  match wanted values:
    case _ Nil{}: Nil{}
    case Burn{} StatusInstance{Burn{}, duration, magnitude} <> rest:
      remove_status(Burn{}, rest)
    case Poison{} StatusInstance{Poison{}, duration, magnitude} <> rest:
      remove_status(Poison{}, rest)
    case Sleep{} StatusInstance{Sleep{}, duration, magnitude} <> rest:
      remove_status(Sleep{}, rest)
    case Stun{} StatusInstance{Stun{}, duration, magnitude} <> rest:
      remove_status(Stun{}, rest)
    case Blind{} StatusInstance{Blind{}, duration, magnitude} <> rest:
      remove_status(Blind{}, rest)
    case wanted StatusInstance{status, duration, magnitude} <> rest:
      StatusInstance{status, duration, magnitude} <> remove_status(wanted, rest)

type StatusConflict is Data:
  NoConflict{}
  Conflict{status: StatusId, duration: U32, magnitude: U32}

def find_conflict(+wanted: StatusId,
  values: List<&2, StatusInstance>) -> StatusConflict:
  match wanted values:
    case _ Nil{}: NoConflict{}
    case Burn{} StatusInstance{Poison{}, duration, magnitude} <> rest:
      Conflict{Poison{}, duration, magnitude}
    case Poison{} StatusInstance{Burn{}, duration, magnitude} <> rest:
      Conflict{Burn{}, duration, magnitude}
    case Sleep{} StatusInstance{Stun{}, duration, magnitude} <> rest:
      Conflict{Stun{}, duration, magnitude}
    case Stun{} StatusInstance{Sleep{}, duration, magnitude} <> rest:
      Conflict{Sleep{}, duration, magnitude}
    case wanted StatusInstance{status, duration, magnitude} <> rest:
      find_conflict(wanted, rest)

def replace_statuses(+values: List<&2, StatusInstance>,
  actor: EffectActor) -> EffectActor:
  match actor:
    case EffectActor{hp, +max_hp, +physical_defense, +special_defense, stages,
        statuses, protected, immunities}:
      EffectActor{hp, max_hp, physical_defense, special_defense, stages, values,
        protected, immunities}

def refresh_status(+wanted: StatusId, +duration: U32, +magnitude: U32,
  values: List<&2, StatusInstance>) -> List<&2, StatusInstance>:
  match wanted values:
    case wanted Nil{}: [StatusInstance{wanted, duration, magnitude}]
    case Burn{} StatusInstance{Burn{}, old_duration, old_magnitude} <> rest:
      StatusInstance{Burn{}, duration, U32.max(old_magnitude, magnitude)} <> rest
    case Poison{} StatusInstance{Poison{}, old_duration, old_magnitude} <> rest:
      StatusInstance{Poison{}, duration, U32.max(old_magnitude, magnitude)} <> rest
    case Sleep{} StatusInstance{Sleep{}, old_duration, old_magnitude} <> rest:
      StatusInstance{Sleep{}, duration, U32.max(old_magnitude, magnitude)} <> rest
    case Stun{} StatusInstance{Stun{}, old_duration, old_magnitude} <> rest:
      StatusInstance{Stun{}, duration, U32.max(old_magnitude, magnitude)} <> rest
    case Blind{} StatusInstance{Blind{}, old_duration, old_magnitude} <> rest:
      StatusInstance{Blind{}, duration, U32.max(old_magnitude, magnitude)} <> rest
    case wanted StatusInstance{status, old_duration, old_magnitude} <> rest:
      StatusInstance{status, old_duration, old_magnitude} <>
        refresh_status(wanted, duration, magnitude, rest)

def conflict_wins(status: StatusId, +duration: U32, +magnitude: U32,
  +old_duration: U32, +old_magnitude: U32) -> Bool:
  match status:
    case Burn{}: U32.is_gt(U32.mul(duration, magnitude),
      U32.mul(old_duration, old_magnitude))
    case Poison{}: U32.is_gt(U32.mul(duration, magnitude),
      U32.mul(old_duration, old_magnitude))
    case _: True{}

def apply_conflict_win(wins: Bool, +status: StatusId, +duration: U32,
  +magnitude: U32, +old_status: StatusId,
  values: List<&2, StatusInstance>, actor: EffectActor) -> Maybe<&2, EffectActor>:
  match wins:
    case False{}: None{}
    case True{}: Some{replace_statuses(StatusInstance{status, duration,
      magnitude} <> remove_status(old_status, values), actor)}

def apply_conflict(conflict: StatusConflict, +status: StatusId,
  +duration: U32, +magnitude: U32,
  values: List<&2, StatusInstance>, actor: EffectActor) -> Maybe<&2, EffectActor>:
  match conflict:
    case NoConflict{}: Some{replace_statuses(StatusInstance{status, duration,
      magnitude} <> values, actor)}
    case Conflict{old_status, old_duration, old_magnitude}:
      apply_conflict_win(conflict_wins(status, duration, magnitude,
        old_duration, old_magnitude), status, duration, magnitude, old_status,
        values, actor)

def apply_status_present(present: Bool, +status: StatusId, +duration: U32,
  +magnitude: U32, +values: List<&2, StatusInstance>, actor: EffectActor) ->
  Maybe<&2, EffectActor>:
  match present:
    case True{}: Some{replace_statuses(refresh_status(status, duration,
      magnitude, values), actor)}
    case False{}: apply_conflict(find_conflict(status, values), status,
      duration, magnitude, values, actor)

def apply_status(+status: StatusId, +actor: EffectActor) -> Maybe<&2, EffectActor>:
  +values = actor_statuses(actor)
  +duration = status_duration(status)
  +magnitude = status_magnitude(status, actor_max_hp(actor))
  apply_status_present(status_present(status, values), status, duration,
    magnitude, values, actor)

def stages_valid(stages: StatStages) -> Bool:
  match stages:
    case StatStages{attack, defense, special_attack, special_defense, speed,
        accuracy, evasion}:
      Bool.and(Math.stage_ok(attack), Bool.and(Math.stage_ok(defense),
        Bool.and(Math.stage_ok(special_attack), Bool.and(
        Math.stage_ok(special_defense), Bool.and(Math.stage_ok(speed),
        Bool.and(Math.stage_ok(accuracy), Math.stage_ok(evasion)))))))

def status_magnitude_valid(status: StatusId, +magnitude: U32,
  +maximum: U32) -> Bool:
  match status:
    case Burn{}: Bool.and(U32.is_ge(magnitude,
      U32.max(1, U32.div(maximum, 16))), U32.is_le(magnitude, 9999))
    case Poison{}: Bool.and(U32.is_ge(magnitude,
      U32.max(1, U32.div(maximum, 8))), U32.is_le(magnitude, 9999))
    case Sleep{}: U32.is_eq(magnitude, 0)
    case Stun{}: U32.is_eq(magnitude, 0)
    case Blind{}: Bool.and(U32.is_ge(magnitude, 2), U32.is_le(magnitude, 6))

def status_instance_valid(+maximum: U32, instance: StatusInstance) -> Bool:
  match instance:
    case StatusInstance{+status, +duration, magnitude}:
      Bool.and(Bool.and(U32.is_ge(duration, 1),
        U32.is_le(duration, status_duration(status))),
        status_magnitude_valid(status, magnitude, maximum))

def no_conflict(conflict: StatusConflict) -> Bool:
  match conflict:
    case NoConflict{}: True{}
    case Conflict{status, duration, magnitude}: False{}

def status_list_valid(+maximum: U32,
  values: List<&2, StatusInstance>) -> Bool:
  match values:
    case Nil{}: True{}
    case StatusInstance{+status, duration, magnitude} <> +rest:
      Bool.and(status_instance_valid(maximum,
        StatusInstance{status, duration, magnitude}), Bool.and(
        Bool.not(status_present(status, rest)), Bool.and(
        no_conflict(find_conflict(status, rest)),
        status_list_valid(maximum, rest))))

def physical_damage_burn(burned: Bool, +damage: U32) -> U32:
  match burned:
    case False{}: damage
    case True{}: U32.div(U32.mul(damage, 3), 4)

def physical_damage_after_status(+damage: U32,
  values: List<&2, StatusInstance>) -> U32:
  physical_damage_burn(status_present(Burn{}, values), damage)

def accuracy_after_blind(blind: Bool, stage: Math.Stage) -> Math.Stage:
  match blind:
    case False{}: stage
    case True{}: apply_delta(stage, Lower{2})

def accuracy_after_status(stage: Math.Stage,
  values: List<&2, StatusInstance>) -> Math.Stage:
  accuracy_after_blind(status_present(Blind{}, values), stage)

def blocks_action(+values: List<&2, StatusInstance>) -> Bool:
  Bool.or(status_present(Sleep{}, values), status_present(Stun{}, values))

def residual_damage(+maximum: U32,
  values: List<&2, StatusInstance>) -> U32:
  match values:
    case Nil{}: 0
    case StatusInstance{Burn{}, duration, magnitude} <> rest:
      U32.add(U32.max(1, magnitude),
        residual_damage(maximum, rest))
    case StatusInstance{Poison{}, duration, magnitude} <> rest:
      U32.add(U32.max(1, magnitude),
        residual_damage(maximum, rest))
    case instance <> rest: residual_damage(maximum, rest)

def decrement_put(expired: Bool, status: StatusId, +duration: U32,
  +magnitude: U32, out: List<&2, StatusInstance>) ->
  List<&2, StatusInstance>:
  match expired:
    case True{}: out
    case False{}: StatusInstance{status, U32.sub(duration, 1), magnitude} <> out

def decrement_one(out: List<&2, StatusInstance>,
  instance: StatusInstance) -> List<&2, StatusInstance>:
  match instance:
    case StatusInstance{status, +duration, magnitude}:
      decrement_put(U32.is_le(duration, 1), status, duration, magnitude, out)

def decrement_statuses(values: List<&2, StatusInstance>) ->
  List<&2, StatusInstance>:
  List.reverse(&2, StatusInstance, List.foldl(~&2, ~StatusInstance,
    ~List<&2, StatusInstance>, ~decrement_one, values, Nil{}))

type OpportunityResult is Data:
  OpportunityCompleted{actor: EffectActor, blocked: Bool, residual: U32}

def complete_opportunity(actor: EffectActor) -> OpportunityResult:
  match actor:
    case EffectActor{+hp, +max_hp, physical_defense, special_defense, stages,
        +statuses, protected, immunities}:
      +residual = U32.min(hp, residual_damage(max_hp, statuses))
      OpportunityCompleted{EffectActor{U32.sub(hp, residual), max_hp,
        physical_defense, special_defense, stages, decrement_statuses(statuses),
        protected, immunities}, blocks_action(statuses), residual}

def actor_valid(actor: EffectActor) -> Bool:
  match actor:
    case EffectActor{hp, +max_hp, +physical_defense, +special_defense, stages,
        statuses, protected, immunities}:
      Bool.and(Bool.and(Bool.and(U32.is_ge(max_hp, 1), U32.is_le(hp, max_hp)),
        Bool.and(Bool.and(U32.is_ge(physical_defense, 1),
          U32.is_le(physical_defense, 9999)), Bool.and(
          U32.is_ge(special_defense, 1), U32.is_le(special_defense, 9999)))),
        Bool.and(stages_valid(stages), status_list_valid(max_hp, statuses)))

def accuracy_mode_valid(mode: Math.AccuracyMode) -> Bool:
  match mode:
    case Math.AlwaysHit{}: True{}
    case Math.OrdinaryAccuracy{+base}: Bool.and(U32.is_ge(base, 500),
      U32.is_le(base, 10000))

def snapshot_valid(snapshot: ActionSnapshot) -> Bool:
  match snapshot:
    case ActionSnapshot{+level, +physical_attack, +special_attack, accuracy,
        accuracy_mode, physical_damage, critical_bonus}:
      Bool.and(Bool.and(U32.is_ge(level, 1), U32.is_le(level, 200)),
        Bool.and(Bool.and(U32.is_ge(physical_attack, 1),
          U32.is_le(physical_attack, 9999)), Bool.and(
          U32.is_ge(special_attack, 1), Bool.and(
          U32.is_le(special_attack, 9999), Bool.and(Math.stage_ok(accuracy),
          accuracy_mode_valid(accuracy_mode))))))

def add_diag(diagnostic: EffectDiagnostic, validation: Validation) -> Validation:
  Validation{diagnostics, seen, damage_count, cost} = validation
  Validation{diagnostic <> diagnostics, seen, damage_count, cost}

def add_cost(validation: Validation) -> Validation:
  Validation{diagnostics, seen, damage_count, cost} = validation
  Validation{diagnostics, seen, damage_count, 1n+cost}

def validate_ref_present(present: Bool, +node: Nat,
  validation: Validation) -> Validation:
  match present:
    case True{}: validation
    case False{}: add_diag(ForwardDamageReference{node}, validation)

def validate_ref(+node: Nat, validation: Validation) -> Validation:
  Validation{diagnostics, +seen, damage_count, +cost} = validation
  validate_ref_present(nat_present(node, seen), node,
    Validation{diagnostics, seen, damage_count, cost})

def validate_fraction_ok(ok: Bool, +numerator: U32, +denominator: U32,
  validation: Validation) -> Validation:
  match ok:
    case True{}: validation
    case False{}: add_diag(InvalidFraction{numerator, denominator}, validation)

def validate_fraction(+numerator: U32, +denominator: U32,
  validation: Validation) -> Validation:
  validate_fraction_ok(Bool.and(Bool.and(U32.is_ge(numerator, 1),
    U32.is_le(numerator, 16)), Bool.and(U32.is_ge(denominator, 1),
    U32.is_le(denominator, 16))), numerator, denominator, validation)

def validate_damage_power(ok: Bool, +power: U32,
  validation: Validation) -> Validation:
  match ok:
    case True{}: validation
    case False{}: add_diag(InvalidPower{power}, validation)

def validate_damage_duplicate(duplicate: Bool, +node: Nat, +power: U32,
  validation: Validation) -> Validation:
  match duplicate:
    case True{}: validate_damage_power(Bool.and(U32.is_ge(power, 1),
      U32.is_le(power, 200)), power, add_diag(DuplicateDamageNode{node}, validation))
    case False{}: validate_damage_power(Bool.and(U32.is_ge(power, 1),
      U32.is_le(power, 200)), power, validation)

def finish_damage_validation(+node: Nat, validation: Validation) -> Validation:
  match validation:
    case Validation{diagnostics, seen, damage_count, cost}:
      Validation{diagnostics, node <> seen, 1n+damage_count, cost}

def validate_damage_position(first: Bool, +node: Nat,
  validation: Validation) -> Validation:
  match first:
    case True{}: validation
    case False{}: add_diag(DamageMustBeFirst{node}, validation)

def validate_damage(+node: Nat, +power: U32,
  validation: Validation) -> Validation:
  Validation{diagnostics, +seen, damage_count, +cost} = validation
  finish_damage_validation(node, validate_damage_position(Nat.is_eq(cost, 1n),
    node, validate_damage_duplicate(
    nat_present(node, seen), node, power,
    Validation{diagnostics, seen, damage_count, cost})))

def delta_magnitude(delta: StageDelta) -> U32:
  match delta:
    case Raise{magnitude}: magnitude
    case Lower{magnitude}: magnitude

def validate_amount_ok(ok: Bool, +amount: U32,
  validation: Validation) -> Validation:
  match ok:
    case True{}: validation
    case False{}: add_diag(InvalidAmount{amount}, validation)

def validate_delta_ok(ok: Bool, +magnitude: U32,
  validation: Validation) -> Validation:
  match ok:
    case True{}: validation
    case False{}: add_diag(InvalidStageDelta{magnitude}, validation)

def validate_leaf(effect: LeafEffect, validation: Validation) -> Validation:
  match effect:
    case Damage{node, target, category, power}: validate_damage(node, power,
      add_cost(validation))
    case Heal{target, +amount}: validate_amount_ok(Bool.and(U32.is_ge(amount, 1),
      U32.is_le(amount, 9999)), amount, add_cost(validation))
    case Drain{target, from_node, numerator, denominator}:
      validate_fraction(numerator, denominator, validate_ref(from_node,
        add_cost(validation)))
    case Recoil{target, from_node, numerator, denominator}:
      validate_fraction(numerator, denominator, validate_ref(from_node,
        add_cost(validation)))
    case ModifyStat{target, stat, delta}:
      +magnitude = delta_magnitude(delta)
      validate_delta_ok(Bool.and(U32.is_ge(magnitude, 1),
        U32.is_le(magnitude, 6)), magnitude, add_cost(validation))
    case _: add_cost(validation)

def validate_branch_leaf(effect: LeafEffect,
  validation: Validation) -> Validation:
  match effect:
    case Damage{node, target, category, power}:
      add_diag(BranchDamageUnsupported{node}, add_cost(validation))
    case other: validate_leaf(other, validation)

def validate_leaves(effects: List<&2, LeafEffect>,
  validation: Validation) -> Validation:
  match effects:
    case Nil{}: validation
    case effect <> rest: validate_leaves(rest,
      validate_branch_leaf(effect, validation))

def validate_effect(effect: Effect, validation: Validation) -> Validation:
  match effect:
    case Leaf{leaf}: validate_leaf(leaf, validation)
    case Conditional{predicate, then_effects, else_effects}:
      +after_node = add_cost(validation)
      +after_then = validate_leaves(then_effects, after_node)
      validate_leaves(else_effects, after_then)

def validate_effects(effects: List<&2, Effect>,
  validation: Validation) -> Validation:
  match effects:
    case Nil{}: validation
    case effect <> rest: validate_effects(rest, validate_effect(effect, validation))

def add_empty(ok: Bool, validation: Validation) -> Validation:
  match ok:
    case True{}: validation
    case False{}: add_diag(EmptyProgram{}, validation)

def add_top(ok: Bool, +count: Nat, validation: Validation) -> Validation:
  match ok:
    case True{}: validation
    case False{}: add_diag(TopLevelLimit{count}, validation)

def add_state(ok: Bool, validation: Validation) -> Validation:
  match ok:
    case True{}: validation
    case False{}: add_diag(InvalidActorState{}, validation)

def add_damage_limit(ok: Bool, validation: Validation) -> Validation:
  match ok:
    case True{}: validation
    case False{}: add_diag(MultipleDamageNodes{}, validation)

def add_cost_limit(ok: Bool, +cost: Nat, validation: Validation) -> Validation:
  match ok:
    case True{}: validation
    case False{}: add_diag(CostLimit{cost}, validation)

def finish_validation(validation: Validation) -> Validation:
  Validation{diagnostics, seen, +damage_count, +cost} = validation
  +damage_checked = add_damage_limit(Nat.is_le(damage_count, 1n),
    Validation{diagnostics, seen, damage_count, cost})
  add_cost_limit(Nat.is_le(cost, 64n), cost, damage_checked)

def validate(program: EffectProgram, world: EffectWorld,
  snapshot: ActionSnapshot) -> Validation:
  match program world:
    case EffectProgram{+effects} EffectWorld{source, target}:
      +count = List.length(&2, Effect, effects)
      +base = {Validation{Nil{}, Nil{}, 0n, 0n} : Validation}
      +nonempty = add_empty(Nat.is_ge(count, 1n), base)
      +top = add_top(Nat.is_le(count, 16n), count, nonempty)
      +state = add_state(Bool.and(Bool.and(actor_valid(source),
        actor_valid(target)), snapshot_valid(snapshot)), top)
      finish_validation(validate_effects(effects, state))

def heal_event(zero: Bool, +target: EffectTarget, +actual: U32) -> EffectEvent:
  match zero:
    case True{}: NoEffect{target, FullHp{}}
    case False{}: HpRestored{target, actual}

def derived_event(zero: Bool, +target: EffectTarget, +node: Nat,
  +actual: U32) -> EffectEvent:
  match zero:
    case True{}: NoEffect{target, ZeroDerived{}}
    case False{}: DerivedDamage{target, node, actual}

def damage_event(zero: Bool, +node: Nat, +target: EffectTarget,
  +category: DamageCategory, +actual: U32, critical: Bool) -> EffectEvent:
  match zero:
    case True{}: DamageNoEffect{node, target, ZeroDamage{}}
    case False{}: DamageApplied{node, target, category, actual, critical}

def execute_heal(+target: EffectTarget, +amount: U32,
  execution: Execution) -> Execution:
  match execution:
    case ExecutionFault{reason}: ExecutionFault{reason}
    case ExecutionStopped{world, rng, events, damage}:
      ExecutionStopped{world, rng, events, damage}
    case Execution{+world, rng, events, damage}:
      +actor = target_actor(target, world)
      +before = actor_hp(actor)
      +next_actor = heal_actor(amount, actor)
      +actual = U32.sub(actor_hp(next_actor), before)
      Execution{replace_actor(target, next_actor, world), rng,
        List.append(&2, EffectEvent, events,
          [heal_event(U32.is_zero(actual), target, actual)]), damage}

def execute_drain_amount(zero: Bool, +target: EffectTarget, +amount: U32,
  execution: Execution) -> Execution:
  match zero execution:
    case True{} ExecutionFault{reason}: ExecutionFault{reason}
    case True{} ExecutionStopped{world, rng, events, damage}:
      ExecutionStopped{world, rng, events, damage}
    case True{} Execution{world, rng, events, damage}:
      Execution{world, rng, List.append(&2, EffectEvent, events,
        [NoEffect{target, ZeroDerived{}}]), damage}
    case False{} execution: execute_heal(target, amount, execution)

def execute_derived_heal(+target: EffectTarget, +node: Nat, +numerator: U32,
  +denominator: U32, execution: Execution) -> Execution:
  match execution:
    case ExecutionFault{reason}: ExecutionFault{reason}
    case ExecutionStopped{world, rng, events, damage}:
      ExecutionStopped{world, rng, events, damage}
    case Execution{world, rng, events, +damage}:
      +amount = U32.div(U32.mul(damage_amount(node, damage), numerator), denominator)
      execute_drain_amount(U32.is_zero(amount), target, amount,
        Execution{world, rng, events, damage})

def execute_derived_damage(+target: EffectTarget, +node: Nat,
  +numerator: U32, +denominator: U32, execution: Execution) -> Execution:
  match execution:
    case ExecutionFault{reason}: ExecutionFault{reason}
    case ExecutionStopped{world, rng, events, damage}:
      ExecutionStopped{world, rng, events, damage}
    case Execution{+world, rng, events, +damage}:
      +amount = U32.div(U32.mul(damage_amount(node, damage), numerator), denominator)
      +actor = target_actor(target, world)
      +actual = U32.min(actor_hp(actor), amount)
      Execution{replace_actor(target, damage_actor(actual, actor), world), rng,
        List.append(&2, EffectEvent, events,
          [derived_event(U32.is_zero(actual), target, node, actual)]), damage}

def category_attack(category: DamageCategory, snapshot: ActionSnapshot) -> U32:
  match category snapshot:
    case Physical{} ActionSnapshot{level, physical_attack, special_attack,
        accuracy, mode, physical_damage, critical_bonus}: physical_attack
    case Special{} ActionSnapshot{level, physical_attack, special_attack,
        accuracy, mode, physical_damage, critical_bonus}: special_attack

def category_modifier_numerator(category: DamageCategory,
  physical: PhysicalDamageState) -> U32:
  match category physical:
    case Physical{} BurnedPhysical{}: 3
    case _ _: 1

def category_modifier_denominator(category: DamageCategory,
  physical: PhysicalDamageState) -> U32:
  match category physical:
    case Physical{} BurnedPhysical{}: 4
    case _ _: 1

def category_defense(category: DamageCategory, actor: EffectActor) -> U32:
  match category actor:
    case Physical{} EffectActor{hp, max_hp, physical_defense, special_defense,
        stages, statuses, protected, immunities}: physical_defense
    case Special{} EffectActor{hp, max_hp, physical_defense, special_defense,
        stages, statuses, protected, immunities}: special_defense

def damage_outcome(+node: Nat, +target: EffectTarget,
  +category: DamageCategory, +world: EffectWorld,
  resolution: Combat.CombatResolution, events: List<&2, EffectEvent>,
  records: List<&2, DamageRecord>) -> Execution:
  match resolution:
    case Combat.CombatInvalid{rng}: ExecutionFault{Rng.RngInvalidBound{rng}}
    case Combat.CombatRngFault{rng, reason}: ExecutionFault{reason}
    case Combat.CombatResolved{rng, Combat.CombatMiss{draw, candidates}}:
      ExecutionStopped{world, rng, List.append(&2, EffectEvent, events,
        [DamageMissed{node, target, draw}]), DamageRecord{node, 0} <> records}
    case Combat.CombatResolved{rng, Combat.CombatNoDamage{critical, draw,
        accuracy_candidates, critical_candidates}}:
      Execution{world, rng, List.append(&2, EffectEvent, events,
        [DamageNoEffect{node, target, ZeroDamage{}}]), DamageRecord{node, 0} <> records}
    case Combat.CombatResolved{rng, Combat.CombatHit{amount, critical, draw,
        accuracy_candidates, critical_candidates}}:
      +actor = target_actor(target, world)
      +actual = U32.min(actor_hp(actor), amount)
      Execution{replace_actor(target, damage_actor(actual, actor), world), rng,
        List.append(&2, EffectEvent, events,
          [damage_event(U32.is_zero(actual), node, target, category, actual,
            critical)]), DamageRecord{node, actual} <> records}
    case Combat.CombatResolved{rng, outcome}:
      Execution{world, rng, List.append(&2, EffectEvent, events,
        [DamageNoEffect{node, target, Immune{}}]), DamageRecord{node, 0} <> records}

def execute_damage(+node: Nat, +target: EffectTarget,
  +category: DamageCategory, +power: U32, +snapshot: ActionSnapshot,
  execution: Execution) -> Execution:
  match snapshot execution:
    case ActionSnapshot{level, physical_attack, special_attack, accuracy, mode,
        physical_damage, critical_bonus} ExecutionFault{reason}:
      ExecutionFault{reason}
    case ActionSnapshot{level, physical_attack, special_attack, accuracy, mode,
        physical_damage, critical_bonus}
        ExecutionStopped{world, rng, events, records}:
      ExecutionStopped{world, rng, events, records}
    case ActionSnapshot{level, physical_attack, special_attack, accuracy, mode,
        +physical_damage, critical_bonus} Execution{+world, rng, events, records}:
      +defender = target_actor(target, world)
      +snapshot_value = {ActionSnapshot{level, physical_attack, special_attack,
        accuracy, mode, physical_damage, critical_bonus} : ActionSnapshot}
      damage_outcome(node, target, category, world, Combat.resolve_modified(rng, mode,
        accuracy, actor_stage(Evasion{}, defender), power, level,
        category_attack(category, snapshot_value), category_defense(category, defender),
        critical_bonus, category_modifier_numerator(category, physical_damage),
        category_modifier_denominator(category, physical_damage)), events, records)

def apply_status_result(result: Maybe<&2, EffectActor>, refreshed: Bool,
  +target: EffectTarget, +status: StatusId, world: EffectWorld,
  rng: Rng.RngState, events: List<&2, EffectEvent>,
  records: List<&2, DamageRecord>) -> Execution:
  match result:
    case None{}: Execution{world, rng, List.append(&2, EffectEvent, events,
      [NoEffect{target, WeakerConflict{}}]), records}
    case Some{actor}: Execution{replace_actor(target, actor, world), rng,
      List.append(&2, EffectEvent, events,
        [StatusApplied{target, status, refreshed}]), records}

def apply_status_immune(immune: Bool, +target: EffectTarget, +status: StatusId,
  +actor: EffectActor, world: EffectWorld, rng: Rng.RngState,
  events: List<&2, EffectEvent>, records: List<&2, DamageRecord>) -> Execution:
  match immune:
    case True{}: Execution{world, rng, List.append(&2, EffectEvent, events,
      [NoEffect{target, Immune{}}]), records}
    case False{}: apply_status_result(apply_status(status, actor),
      status_present(status, actor_statuses(actor)), target, status, world, rng,
      events, records)

def apply_status_protected(protected: Bool, +target: EffectTarget,
  +status: StatusId, +actor: EffectActor, world: EffectWorld,
  rng: Rng.RngState, events: List<&2, EffectEvent>,
  records: List<&2, DamageRecord>) -> Execution:
  match protected:
    case True{}: Execution{world, rng, List.append(&2, EffectEvent, events,
      [NoEffect{target, Protected{}}]), records}
    case False{}:
      apply_status_immune(immune_present(status, actor_immunities(actor)), target, status,
        actor, world, rng, events, records)

def execute_apply_status(+target: EffectTarget, +status: StatusId,
  execution: Execution) -> Execution:
  match execution:
    case ExecutionFault{reason}: ExecutionFault{reason}
    case ExecutionStopped{world, rng, events, damage}:
      ExecutionStopped{world, rng, events, damage}
    case Execution{+world, rng, events, records}:
      +actor = target_actor(target, world)
      apply_status_protected(actor_protected(actor), target, status, actor, world, rng,
        events, records)

def remove_status_present(present: Bool, +target: EffectTarget,
  +status: StatusId, +actor: EffectActor, world: EffectWorld,
  rng: Rng.RngState, events: List<&2, EffectEvent>,
  records: List<&2, DamageRecord>) -> Execution:
  match present:
    case False{}: Execution{world, rng, List.append(&2, EffectEvent, events,
      [NoEffect{target, AlreadyAbsent{}}]), records}
    case True{}: Execution{replace_actor(target,
      replace_statuses(remove_status(status, actor_statuses(actor)), actor), world),
      rng, List.append(&2, EffectEvent, events,
        [StatusRemoved{target, status}]), records}

def execute_remove_status(+target: EffectTarget, +status: StatusId,
  execution: Execution) -> Execution:
  match execution:
    case ExecutionFault{reason}: ExecutionFault{reason}
    case ExecutionStopped{world, rng, events, damage}:
      ExecutionStopped{world, rng, events, damage}
    case Execution{+world, rng, events, records}:
      +actor = target_actor(target, world)
      remove_status_present(status_present(status, actor_statuses(actor)), target,
        status, actor, world, rng, events, records)

def execute_clear(+target: EffectTarget, execution: Execution) -> Execution:
  match execution:
    case ExecutionFault{reason}: ExecutionFault{reason}
    case ExecutionStopped{world, rng, events, damage}:
      ExecutionStopped{world, rng, events, damage}
    case Execution{+world, rng, events, records}:
      +actor = target_actor(target, world)
      +count = List.length(&2, StatusInstance, actor_statuses(actor))
      Execution{replace_actor(target, replace_statuses(Nil{}, actor), world),
        rng, List.append(&2, EffectEvent, events,
          [StatusesCleared{target, count}]), records}

def execute_modify(+target: EffectTarget, +stat: StatId, +delta: StageDelta,
  execution: Execution) -> Execution:
  match execution:
    case ExecutionFault{reason}: ExecutionFault{reason}
    case ExecutionStopped{world, rng, events, damage}:
      ExecutionStopped{world, rng, events, damage}
    case Execution{+world, rng, events, records}:
      +actor = target_actor(target, world)
      +before = actor_stage(stat, actor)
      +next_actor = modify_actor(stat, delta, actor)
      Execution{replace_actor(target, next_actor, world), rng,
        List.append(&2, EffectEvent, events,
          [StatModified{target, stat, before, actor_stage(stat, next_actor)}]), records}

def execute_leaf(effect: LeafEffect, +snapshot: ActionSnapshot,
  execution: Execution) -> Execution:
  match effect:
    case Damage{node, target, category, power}: execute_damage(node, target,
      category, power, snapshot, execution)
    case Heal{target, amount}: execute_heal(target, amount, execution)
    case Drain{target, node, numerator, denominator}: execute_derived_heal(
      target, node, numerator, denominator, execution)
    case Recoil{target, node, numerator, denominator}: execute_derived_damage(
      target, node, numerator, denominator, execution)
    case ApplyStatus{target, status}: execute_apply_status(target, status, execution)
    case RemoveStatus{target, status}: execute_remove_status(target, status, execution)
    case ClearStatuses{target}: execute_clear(target, execution)
    case ModifyStat{target, stat, delta}: execute_modify(target, stat, delta, execution)

def execute_leaves(effects: List<&2, LeafEffect>, +snapshot: ActionSnapshot,
  execution: Execution) -> Execution:
  match effects:
    case Nil{}: execution
    case effect <> rest: execute_leaves(rest, snapshot,
      execute_leaf(effect, snapshot, execution))

def predicate_value(predicate: Predicate, world: EffectWorld,
  records: List<&2, DamageRecord>) -> Bool:
  match predicate:
    case HpBelowHalf{target}:
      +actor = target_actor(target, world)
      +maximum = actor_max_hp(actor)
      U32.is_lt(actor_hp(actor), U32.add(U32.div(maximum, 2),
        U32.mod(maximum, 2)))
    case HasStatus{target, status}: status_present(status,
      actor_statuses(target_actor(target, world)))
    case PriorDamagePositive{node}: U32.is_gt(damage_amount(node, records), 0)

def execute_branch(taken: Bool, then_effects: List<&2, LeafEffect>,
  else_effects: List<&2, LeafEffect>, +snapshot: ActionSnapshot,
  execution: Execution) -> Execution:
  match taken:
    case True{}: execute_leaves(then_effects, snapshot, execution)
    case False{}: execute_leaves(else_effects, snapshot, execution)

def execute_effect(effect: Effect, +snapshot: ActionSnapshot,
  execution: Execution) -> Execution:
  match effect:
    case Leaf{leaf}: execute_leaf(leaf, snapshot, execution)
    case Conditional{predicate, then_effects, else_effects}:
      match execution:
        case ExecutionFault{reason}: ExecutionFault{reason}
        case ExecutionStopped{world, rng, events, damage}:
          ExecutionStopped{world, rng, events, damage}
        case Execution{+world, rng, events, +records}:
          +taken = predicate_value(predicate, world, records)
          execute_branch(taken, then_effects, else_effects, snapshot,
            Execution{world, rng, List.append(&2, EffectEvent, events,
              [ConditionalSelected{taken}]), records})

def execute_effects(effects: List<&2, Effect>, +snapshot: ActionSnapshot,
  execution: Execution) -> Execution:
  match effects:
    case Nil{}: execution
    case effect <> rest: execute_effects(rest, snapshot,
      execute_effect(effect, snapshot, execution))

def finish_execution(+original_world: EffectWorld,
  +original_rng: Rng.RngState, execution: Execution) -> EffectResult:
  match execution:
    case ExecutionFault{reason}: EffectsFaulted{original_world, original_rng, reason}
    case ExecutionStopped{world, rng, events, records}:
      EffectsCommitted{world, rng, events,
        List.reverse(&2, DamageRecord, records)}
    case Execution{world, rng, events, records}: EffectsCommitted{world, rng,
      events, List.reverse(&2, DamageRecord, records)}

def nondamage_outcome(resolution: Combat.CombatResolution,
  effects: List<&2, Effect>, +world: EffectWorld,
  +snapshot: ActionSnapshot, +original_rng: Rng.RngState) -> EffectResult:
  match resolution:
    case Combat.CombatInvalid{rng}:
      EffectsRejected{world, original_rng, [InvalidActorState{}]}
    case Combat.CombatRngFault{rng, reason}:
      EffectsFaulted{world, original_rng, reason}
    case Combat.CombatResolved{rng, Combat.CombatMiss{draw, candidates}}:
      EffectsCommitted{world, rng, [ActionMissed{draw}], Nil{}}
    case Combat.CombatResolved{rng, outcome}:
      finish_execution(world, original_rng, execute_effects(effects, snapshot,
        Execution{world, rng, Nil{}, Nil{}}))

def run_nondamage(effects: List<&2, Effect>, snapshot: ActionSnapshot,
  world: EffectWorld, +rng: Rng.RngState) -> EffectResult:
  match snapshot world:
    case ActionSnapshot{level, physical_attack, special_attack,
        +accuracy, +mode, physical_damage, critical_bonus}
        EffectWorld{source, +target}:
      +snapshot_value = {ActionSnapshot{level, physical_attack, special_attack,
        accuracy, mode, physical_damage, critical_bonus} : ActionSnapshot}
      +world_value = {EffectWorld{source, target} : EffectWorld}
      nondamage_outcome(Combat.resolve_noncritical(rng, Combat.NonDamaging{},
        mode, accuracy, actor_stage(Evasion{}, target)), effects, world_value,
        snapshot_value, rng)

def run_valid_program(has_damage: Bool, effects: List<&2, Effect>,
  +world: EffectWorld, +snapshot: ActionSnapshot,
  +rng: Rng.RngState) -> EffectResult:
  match has_damage:
    case True{}:
      finish_execution(world, rng, execute_effects(effects, snapshot,
        Execution{world, rng, Nil{}, Nil{}}))
    case False{}: run_nondamage(effects, snapshot, world, rng)

def validated_run(validation: Validation, effects: List<&2, Effect>,
  +world: EffectWorld, +snapshot: ActionSnapshot,
  +rng: Rng.RngState) -> EffectResult:
  match validation:
    case Validation{diagnostic <> rest, seen, damage_count, cost}:
      EffectsRejected{world, rng,
        List.reverse(&2, EffectDiagnostic, diagnostic <> rest)}
    case Validation{Nil{}, seen, damage_count, cost}:
      run_valid_program(Nat.is_eq(damage_count, 1n), effects, world, snapshot,
        rng)

def run(program: EffectProgram, +world: EffectWorld, +snapshot: ActionSnapshot,
  rng: Rng.RngState) -> EffectResult:
  match program:
    case EffectProgram{+effects}: validated_run(validate(EffectProgram{effects},
      world, snapshot), effects, world, snapshot, rng)

def finish_opportunity(result: OpportunityResult, target: EffectActor,
  rng: Rng.RngState, events: List<&2, EffectEvent>,
  records: List<&2, DamageRecord>) -> EffectResult:
  match result:
    case OpportunityCompleted{source, blocked, residual}:
      EffectsCommitted{EffectWorld{source, target}, rng,
        List.append(&2, EffectEvent, events,
          [OpportunityEnded{blocked, residual}]), records}

def finish_attempt(apply_aftermath: Bool, result: EffectResult) -> EffectResult:
  match apply_aftermath result:
    case _ EffectsRejected{world, rng, diagnostics}:
      EffectsRejected{world, rng, diagnostics}
    case _ EffectsFaulted{world, rng, reason}:
      EffectsFaulted{world, rng, reason}
    case False{} EffectsCommitted{world, rng, events, records}:
      EffectsCommitted{world, rng, events, records}
    case True{} EffectsCommitted{EffectWorld{source, target}, rng, events,
        records}:
      finish_opportunity(complete_opportunity(source), target, rng, events,
        records)

def blocked_attempt(result: OpportunityResult, target: EffectActor,
  rng: Rng.RngState) -> EffectResult:
  match result:
    case OpportunityCompleted{source, blocked, residual}:
      EffectsCommitted{EffectWorld{source, target}, rng,
        [ActionBlocked{}, OpportunityEnded{blocked, residual}], Nil{}}

def attempt_blocked(blocked: Bool, program: EffectProgram,
  +world: EffectWorld, +snapshot: ActionSnapshot, +rng: Rng.RngState,
  apply_aftermath: Bool) -> EffectResult:
  match blocked:
    case True{}:
      EffectWorld{source, target} = world
      blocked_attempt(complete_opportunity(source), target, rng)
    case False{}: finish_attempt(apply_aftermath,
      run(program, world, snapshot, rng))

def attempt_validated(validation: Validation, program: EffectProgram,
  +world: EffectWorld, +snapshot: ActionSnapshot, +rng: Rng.RngState,
  apply_aftermath: Bool) -> EffectResult:
  match validation:
    case Validation{diagnostic <> rest, seen, damage_count, cost}:
      EffectsRejected{world, rng,
        List.reverse(&2, EffectDiagnostic, diagnostic <> rest)}
    case Validation{Nil{}, seen, damage_count, cost}:
      EffectWorld{source, target} = world
      attempt_blocked(blocks_action(actor_statuses(source)), program, world,
        snapshot, rng, apply_aftermath)

def attempt(+program: EffectProgram, +world: EffectWorld,
  +snapshot: ActionSnapshot, +rng: Rng.RngState,
  apply_aftermath: Bool) -> EffectResult:
  attempt_validated(validate(program, world, snapshot), program, world,
    snapshot, rng, apply_aftermath)
