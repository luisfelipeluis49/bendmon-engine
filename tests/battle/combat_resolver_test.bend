import Base
import ../../engine/battle/combat_math.bend as Math
import ../../engine/battle/combat_resolver.bend as Combat
import ../../engine/battle/rng.bend as Rng

def miss_code(result: Combat.CombatResolution) -> Nat:
  match result:
    case Combat.CombatResolved{Rng.RngState{7, 0, 1026, 12288},
        Combat.CombatMiss{1520, 1n}}:
      1n
    case _:
      0n

def critical_code(result: Combat.CombatResolution) -> Nat:
  match result:
    case Combat.CombatResolved{rng,
        Combat.CombatHit{100, True{}, 1520, 0n, 1n}}:
      1n
    case _:
      0n

def zero_code(result: Combat.CombatResolution) -> Nat:
  match result:
    case Combat.CombatResolved{rng,
        Combat.CombatNoDamage{True{}, 1520, 0n, 1n}}:
      1n
    case _:
      0n

def invalid_code(result: Combat.CombatResolution) -> Nat:
  match result:
    case Combat.CombatInvalid{Rng.RngState{1, 2, 3, 4}}:
      1n
    case _:
      0n

def effect_code(result: Combat.CombatResolution) -> Nat:
  match result:
    case Combat.CombatResolved{Rng.RngState{1, 2, 3, 4},
        Combat.CombatEffect{0n}}:
      1n
    case _:
      0n

def immune_code(result: Combat.CombatResolution) -> Nat:
  match result:
    case Combat.CombatResolved{Rng.RngState{7, 0, 1026, 12288},
        Combat.CombatImmune{1n}}:
      1n
    case _:
      0n

def main() -> List<&2, Nat>:
  +seed = {Rng.RngState{1, 2, 3, 4} : Rng.RngState}
  [miss_code(Combat.resolve(seed, Math.OrdinaryAccuracy{500},
      Math.StageNeutral{}, Math.StageNeutral{}, 100, 50, 100, 100, 0)),
   critical_code(Combat.resolve(seed, Math.AlwaysHit{}, Math.StageNeutral{},
      Math.StageNeutral{}, 100, 50, 100, 100, 1875)),
   zero_code(Combat.resolve(seed, Math.AlwaysHit{}, Math.StageNeutral{},
      Math.StageNeutral{}, 1, 1, 1, 9999, 1875)),
   invalid_code(Combat.resolve(seed, Math.AlwaysHit{}, Math.StageNeutral{},
      Math.StageNeutral{}, 100, 50, 100, 0, 0)),
   effect_code(Combat.resolve_noncritical(seed, Combat.NonDamaging{},
      Math.AlwaysHit{}, Math.StageNeutral{}, Math.StageNeutral{})),
   immune_code(Combat.resolve_noncritical(seed, Combat.DeterministicImmune{},
      Math.OrdinaryAccuracy{10000}, Math.StageNeutral{}, Math.StageNeutral{}))]

#| [1, 1, 1, 1, 1, 1]
