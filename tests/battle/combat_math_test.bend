import Base
import ../../engine/battle/combat_math.bend as Combat

def bool_code(ok: Bool) -> Nat:
  match ok:
    case True{}:
      1n
    case False{}:
      0n

def both_code(left: Bool, right: Bool) -> Nat:
  match left right:
    case True{} True{}:
      1n
    case _ _:
      0n

def accuracy_code(result: Combat.AccuracyResult, expected: U32) -> Nat:
  match result expected:
    case Combat.AccuracyValue{chance} expected:
      bool_code(U32.is_eq(chance, expected))
    case _ _:
      0n

def bypass_code(result: Combat.AccuracyResult) -> Nat:
  match result:
    case Combat.AccuracyBypass{}:
      1n
    case _:
      0n

def damage_code(result: Combat.DamageResult, normal: U32, critical: U32) -> Nat:
  match result:
    case Combat.DamageValue{actual_normal, actual_critical}:
      both_code(U32.is_eq(actual_normal, normal),
        U32.is_eq(actual_critical, critical))
    case _:
      0n

def main() -> List<&2, Nat>:
  [accuracy_code(Combat.accuracy(Combat.OrdinaryAccuracy{9000},
      Combat.StageNeutral{}, Combat.StageUp{3n}), 4500),
   accuracy_code(Combat.accuracy(Combat.OrdinaryAccuracy{500},
      Combat.StageDown{6n}, Combat.StageUp{6n}), 500),
   accuracy_code(Combat.accuracy(Combat.OrdinaryAccuracy{10000},
      Combat.StageUp{6n}, Combat.StageDown{6n}), 10000),
   bypass_code(Combat.accuracy(Combat.AlwaysHit{}, Combat.StageDown{99n},
      Combat.StageUp{99n})),
   damage_code(Combat.damage(100, 50, 100, 100), 50, 100),
   damage_code(Combat.damage(1, 1, 1, 9999), 0, 0)]

#| [1, 1, 1, 1, 1, 1]
