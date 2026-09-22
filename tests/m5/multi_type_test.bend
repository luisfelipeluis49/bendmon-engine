import Base
import ../../engine/battle/multi_type.bend as Multi

def profile() -> Multi.DamageProfile:
  Multi.DamageProfile{50, 100, 100}

def dual_chart_code(result: Multi.MultiDamageResult) -> Nat:
  match result:
    case Multi.MultiDamageResolved{
        Multi.ComponentDamage{Multi.TypeId{1n}, 100, 300, False{}, True{}} <> Nil{}, 300}:
      1n
    case _:
      0n

def authored_order_code(result: Multi.MultiDamageResult) -> Nat:
  match result:
    case Multi.MultiDamageResolved{
        Multi.ComponentDamage{Multi.TypeId{7n}, 50, 25, False{}, False{}} <>
        Multi.ComponentDamage{Multi.TypeId{2n}, 51, 25, False{}, False{}} <> Nil{}, 50}:
      1n
    case _:
      0n

def one_floor_code(result: Multi.MultiDamageResult) -> Nat:
  match result:
    case Multi.MultiDamageResolved{
        Multi.ComponentDamage{Multi.TypeId{0n}, 1, 0, False{}, False{}} <> Nil{}, 0}:
      1n
    case _:
      0n

def invalid_snapshot_code(result: Multi.MultiDamageResult) -> Nat:
  match result:
    case Multi.MultiDamageRejected{Multi.InvalidActorTypes{}}:
      1n
    case _:
      0n

def small_allocation_code(result: Multi.AllocationResult) -> Nat:
  match result:
    case Multi.Allocated{
        Multi.DamageComponent{Multi.TypeId{4n}, 1} <>
        Multi.DamageComponent{Multi.TypeId{1n}, 1} <>
        Multi.DamageComponent{Multi.TypeId{8n}, 0} <>
        Multi.DamageComponent{Multi.TypeId{2n}, 1} <> Nil{}}:
      1n
    case _:
      0n

def single_stab_code(result: Multi.MultiDamageResult) -> Nat:
  match result:
    case Multi.MultiDamageResolved{
        Multi.ComponentDamage{Multi.TypeId{1n}, 100, 75, False{}, True{}} <>
        Nil{}, 75}:
      1n
    case _:
      0n

def invalid_interaction_code(result: Multi.ComponentResult) -> Nat:
  match result:
    case Multi.ComponentRejected{Multi.InvalidTypeInteraction{
        Multi.TypeId{1n}}}:
      1n
    case _:
      0n

def duplicate_diagnostic_code(result: Multi.AllocationResult) -> Nat:
  match result:
    case Multi.AllocationRejectedResult{Multi.DuplicateType{
        Multi.TypeId{7n}}}:
      1n
    case _:
      0n

def invalid_type_diagnostic_code(result: Multi.AllocationResult) -> Nat:
  match result:
    case Multi.AllocationRejectedResult{Multi.InvalidTypeId{
        Multi.TypeId{11n}}}:
      1n
    case _:
      0n

def main() -> List<&2, Nat>:
  [dual_chart_code(Multi.resolve_chart(profile(), 100,
      [Multi.TypeId{1n}], [Multi.TypeId{1n}],
      [Multi.TypeId{3n}, Multi.TypeId{7n}])),
   authored_order_code(Multi.resolve_chart(profile(), 101,
      [Multi.TypeId{7n}, Multi.TypeId{2n}], [Multi.TypeId{1n}],
      [Multi.TypeId{2n}])),
   one_floor_code(Multi.resolve_chart(Multi.DamageProfile{1, 1, 9999}, 1,
      [Multi.TypeId{0n}], [Multi.TypeId{1n}], [Multi.TypeId{2n}])),
   invalid_snapshot_code(Multi.resolve_chart(profile(), 100,
      [Multi.TypeId{1n}], [], [Multi.TypeId{2n}])),
   small_allocation_code(Multi.allocate(3, [Multi.TypeId{4n},
      Multi.TypeId{1n}, Multi.TypeId{8n}, Multi.TypeId{2n}])),
   single_stab_code(Multi.resolve_chart(profile(), 100,
      [Multi.TypeId{1n}], [Multi.TypeId{1n}, Multi.TypeId{2n}],
      [Multi.TypeId{0n}])),
   invalid_interaction_code(Multi.component_damage(profile(),
      Multi.DamageComponent{Multi.TypeId{1n}, 100},
      Multi.TypeMultiplier{1, 0}, False{})),
   duplicate_diagnostic_code(Multi.allocate(100,
      [Multi.TypeId{7n}, Multi.TypeId{2n}, Multi.TypeId{7n}])),
   invalid_type_diagnostic_code(Multi.allocate(100,
      [Multi.TypeId{1n}, Multi.TypeId{11n}]))]

#| [1, 1, 1, 1, 1, 1, 1, 1, 1]
