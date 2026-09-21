import Base
import ./combat_math.bend as Math
import ./rng.bend as Rng

type CombatOutcome is Data:
  CombatMiss{draw: U32, accuracy_candidates: Nat}
  CombatEffect{accuracy_candidates: Nat}
  CombatImmune{accuracy_candidates: Nat}
  CombatNoDamage{
    critical: Bool,
    critical_draw: U32,
    accuracy_candidates: Nat,
    critical_candidates: Nat
  }
  CombatHit{
    damage: U32,
    critical: Bool,
    critical_draw: U32,
    accuracy_candidates: Nat,
    critical_candidates: Nat
  }

type CombatResolution is Data:
  CombatResolved{rng: Rng.RngState, outcome: CombatOutcome}
  CombatInvalid{rng: Rng.RngState}
  CombatRngFault{rng: Rng.RngState}

type NonCriticalKind is Data:
  NonDamaging{}
  DeterministicImmune{}

def choose_damage(critical: Bool, +normal: U32, +critical_damage: U32) -> U32:
  match critical:
    case True{}:
      critical_damage
    case False{}:
      normal

def finish_damage_kind(
  is_zero: Bool, +damage: U32, critical: Bool, +draw: U32, +accuracy_candidates: Nat,
  +critical_candidates: Nat
) -> CombatOutcome:
  match is_zero:
    case True{}:
      CombatNoDamage{critical, draw, accuracy_candidates, critical_candidates}
    case False{}:
      CombatHit{damage, critical, draw, accuracy_candidates, critical_candidates}

def finish_damage(
  +damage: U32, critical: Bool, +draw: U32, +accuracy_candidates: Nat,
  +critical_candidates: Nat
) -> CombatOutcome:
  finish_damage_kind(U32.is_zero(damage), damage, critical, draw,
    accuracy_candidates, critical_candidates)

def critical_sample(
  sample: Rng.RngSampleResult, +original: Rng.RngState, +normal: U32,
  +critical_damage: U32, +critical_chance: U32,
  +accuracy_candidates: Nat
) -> CombatResolution:
  match sample:
    case Rng.RngSampled{next_rng, +draw, critical_candidates}:
      +is_critical = U32.is_lt(draw, critical_chance)
      CombatResolved{next_rng, finish_damage(
        choose_damage(is_critical, normal, critical_damage), is_critical,
        draw, accuracy_candidates, critical_candidates)}
    case _:
      CombatRngFault{original}

def run_critical(
  +original: Rng.RngState, current: Rng.RngState, +normal: U32,
  +critical_damage: U32, +critical_bonus: U32,
  +accuracy_candidates: Nat
) -> CombatResolution:
  critical_sample(Rng.sample(current, 10000), original, normal,
    critical_damage, Math.critical_chance(critical_bonus), accuracy_candidates)

def accuracy_hit(
  hit: Bool, +original: Rng.RngState, next_rng: Rng.RngState, +draw: U32,
  +candidates: Nat, +normal: U32, +critical_damage: U32,
  +critical_bonus: U32
) -> CombatResolution:
  match hit:
    case False{}:
      CombatResolved{next_rng, CombatMiss{draw, candidates}}
    case True{}:
      run_critical(original, next_rng, normal, critical_damage, critical_bonus,
        candidates)

def accuracy_draw(
  sample: Rng.RngSampleResult, +original: Rng.RngState, +chance: U32,
  +normal: U32, +critical_damage: U32, +critical_bonus: U32
) -> CombatResolution:
  match sample:
    case Rng.RngSampled{+next_rng, +draw, candidates}:
      accuracy_hit(U32.is_lt(draw, chance), original, next_rng, draw,
        candidates, normal, critical_damage, critical_bonus)
    case _:
      CombatRngFault{original}

def resolve_accuracy(
  accuracy: Math.AccuracyResult, +original: Rng.RngState,
  +normal: U32, +critical_damage: U32, +critical_bonus: U32
) -> CombatResolution:
  match accuracy:
    case Math.AccuracyInvalid{}:
      CombatInvalid{original}
    case Math.AccuracyBypass{}:
      run_critical(original, original, normal, critical_damage, critical_bonus,
        0n)
    case Math.AccuracyValue{chance}:
      accuracy_draw(Rng.sample(original, 10000), original, chance, normal,
        critical_damage, critical_bonus)

def resolve_damage(
  damage: Math.DamageResult, accuracy: Math.AccuracyResult,
  +original: Rng.RngState, +critical_bonus: U32
) -> CombatResolution:
  match damage:
    case Math.DamageInvalid{}:
      CombatInvalid{original}
    case Math.DamageValue{normal, critical_damage}:
      resolve_accuracy(accuracy, original, normal, critical_damage,
        critical_bonus)

def resolve(
  +rng: Rng.RngState, mode: Math.AccuracyMode,
  attacker_accuracy: Math.Stage, target_evasion: Math.Stage,
  +power: U32, +level: U32, +attack: U32, +defense: U32,
  +critical_bonus: U32
) -> CombatResolution:
  resolve_damage(Math.damage(power, level, attack, defense),
    Math.accuracy(mode, attacker_accuracy, target_evasion), rng,
    critical_bonus)

def noncritical_hit(
  kind: NonCriticalKind, +rng: Rng.RngState, +candidates: Nat
) -> CombatResolution:
  match kind:
    case NonDamaging{}:
      CombatResolved{rng, CombatEffect{candidates}}
    case DeterministicImmune{}:
      CombatResolved{rng, CombatImmune{candidates}}

def noncritical_draw_hit(
  hit: Bool, kind: NonCriticalKind, +original: Rng.RngState,
  +next_rng: Rng.RngState, +draw: U32, +candidates: Nat
) -> CombatResolution:
  match hit:
    case False{}:
      CombatResolved{next_rng, CombatMiss{draw, candidates}}
    case True{}:
      noncritical_hit(kind, next_rng, candidates)

def noncritical_sample(
  sample: Rng.RngSampleResult, kind: NonCriticalKind,
  +original: Rng.RngState, +chance: U32
) -> CombatResolution:
  match sample:
    case Rng.RngSampled{+next_rng, +draw, candidates}:
      noncritical_draw_hit(U32.is_lt(draw, chance), kind, original, next_rng,
        draw, candidates)
    case _:
      CombatRngFault{original}

def resolve_noncritical_accuracy(
  accuracy: Math.AccuracyResult, kind: NonCriticalKind,
  +original: Rng.RngState
) -> CombatResolution:
  match accuracy:
    case Math.AccuracyInvalid{}:
      CombatInvalid{original}
    case Math.AccuracyBypass{}:
      noncritical_hit(kind, original, 0n)
    case Math.AccuracyValue{chance}:
      noncritical_sample(Rng.sample(original, 10000), kind, original, chance)

def resolve_noncritical(
  +rng: Rng.RngState, kind: NonCriticalKind, mode: Math.AccuracyMode,
  attacker_accuracy: Math.Stage, target_evasion: Math.Stage
) -> CombatResolution:
  resolve_noncritical_accuracy(Math.accuracy(mode, attacker_accuracy,
    target_evasion), kind, rng)
