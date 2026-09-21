import Base

type MoveId is Data:
  MoveId{value: Nat}

type Stage is Data:
  StageDown{magnitude: Nat}
  StageNeutral{}
  StageUp{magnitude: Nat}

type AccuracyMode is Data:
  OrdinaryAccuracy{base: U32}
  AlwaysHit{}

type AccuracyResult is Data:
  AccuracyInvalid{}
  AccuracyBypass{}
  AccuracyValue{chance: U32}

type DamageResult is Data:
  DamageInvalid{}
  DamageValue{normal: U32, critical: U32}

type NetStage is Data:
  NetDown{magnitude: U32}
  NetUp{magnitude: U32}

def clamp_u32(+value: U32, +low: U32, +high: U32) -> U32:
  U32.max(low, U32.min(value, high))

def stage_ok(stage: Stage) -> Bool:
  match stage:
    case StageDown{magnitude}:
      Nat.is_le(magnitude, 6n)
    case StageNeutral{}:
      True{}
    case StageUp{magnitude}:
      Nat.is_le(magnitude, 6n)

def stage_index(stage: Stage) -> U32:
  match stage:
    case StageDown{magnitude}:
      U32.sub(6, U32.from_nat(Nat.min(magnitude, 6n)))
    case StageNeutral{}:
      6
    case StageUp{magnitude}:
      U32.add(6, U32.from_nat(Nat.min(magnitude, 6n)))

def net_stage_order(+left: U32, +right: U32, order: Cmp) -> NetStage:
  match order:
    case LT{}:
      NetDown{U32.min(U32.sub(right, left), 6)}
    case EQ{}:
      NetUp{0}
    case GT{}:
      NetUp{U32.min(U32.sub(left, right), 6)}

def net_stage(attacker: Stage, target: Stage) -> NetStage:
  +left = stage_index(attacker)
  +right = stage_index(target)
  net_stage_order(left, right, U32.cmp(left, right))

def accuracy_from_net(+base: U32, net: NetStage) -> U32:
  match net:
    case NetDown{magnitude}:
      clamp_u32(U32.div(U32.mul(base, 3), U32.add(3, magnitude)), 500,
        10000)
    case NetUp{magnitude}:
      clamp_u32(U32.div(U32.mul(base, U32.add(3, magnitude)), 3), 500,
        10000)

def accuracy_stages(
  stages_valid: Bool, +base: U32, attacker: Stage, target: Stage
) -> AccuracyResult:
  match stages_valid:
    case False{}:
      AccuracyInvalid{}
    case True{}:
      AccuracyValue{accuracy_from_net(base, net_stage(attacker, target))}

def accuracy_base(
  base_valid: Bool, +base: U32, +attacker: Stage, +target: Stage
) -> AccuracyResult:
  match base_valid:
    case False{}:
      AccuracyInvalid{}
    case True{}:
      accuracy_stages(Bool.and(stage_ok(attacker), stage_ok(target)), base,
        attacker, target)

def accuracy(mode: AccuracyMode, attacker: Stage, target: Stage) ->
  AccuracyResult:
  match mode:
    case AlwaysHit{}:
      AccuracyBypass{}
    case OrdinaryAccuracy{+base}:
      accuracy_base(Bool.and(U32.is_ge(base, 500), U32.is_le(base, 10000)),
        base, attacker, target)

def critical_chance(+bonus: U32) -> U32:
  U32.min(U32.add(625, U32.min(bonus, 10000)), 2500)

def damage_values(
  valid: Bool, +power: U32, +level: U32, +attack: U32, +defense: U32
) -> DamageResult:
  match valid:
    case False{}:
      DamageInvalid{}
    case True{}:
      +level_factor = U32.add(U32.mul(2, level), 50)
      +numerator = U32.mul(U32.mul(power, level_factor), attack)
      +denominator = U32.mul(300, defense)
      +normal = U32.div(numerator, denominator)
      DamageValue{normal, U32.mul(normal, 2)}

def damage(+power: U32, +level: U32, +attack: U32, +defense: U32) ->
  DamageResult:
  damage_values(Bool.and(Bool.and(U32.is_ge(power, 1), U32.is_le(power, 200)),
    Bool.and(Bool.and(U32.is_ge(level, 1), U32.is_le(level, 200)),
      Bool.and(Bool.and(U32.is_ge(attack, 1), U32.is_le(attack, 9999)),
        Bool.and(U32.is_ge(defense, 1), U32.is_le(defense, 9999))))),
    power, level, attack, defense)
