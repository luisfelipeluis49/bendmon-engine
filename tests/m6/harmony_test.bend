import Base
import ../../engine/mixing/harmony.bend as Harmony
import ../../engine/battle/effects.bend as Effects
import ../../engine/battle/combat_math.bend as Math

def package_matches(result: Harmony.HarmonyPackage, accuracy: U32,
  critical: U32) -> Bool:
  Harmony.HarmonyPackage{actual_accuracy, actual_critical} = result
  Bool.and(U32.is_eq(actual_accuracy, accuracy),
    U32.is_eq(actual_critical, critical))

def package_is(progress: U32, accuracy: U32, critical: U32) -> Bool:
  package_matches(Harmony.bonuses(progress), accuracy, critical)

def award_state_matches(+state: Harmony.AwardState) -> Bool:
  Harmony.AwardState{progress, +completed_actions} = state
  Bool.and(U32.is_eq(progress, 5),
    Bool.and(Nat.is_eq(List.length(&2, Nat, completed_actions), 1n),
      Harmony.nat_member(12n, completed_actions)))

def award_is_idempotent() -> Bool:
  +initial = Harmony.award_state(4)
  +first = Harmony.award_once(True{}, True{}, 12n, initial)
  +again = Harmony.award_once(True{}, True{}, 12n, first)
  award_state_matches(again)

def failed_state_matches(state: Harmony.AwardState) -> Bool:
  Harmony.AwardState{progress, completed_actions} = state
  Bool.and(U32.is_eq(progress, 39),
    Nat.is_eq(List.length(&2, Nat, completed_actions), 0n))

def saturation_matches(+state: Harmony.AwardState) -> Bool:
  Harmony.AwardState{progress, +completed_actions} = state
  Bool.and(U32.is_eq(progress, 40),
    Bool.and(Nat.is_eq(List.length(&2, Nat, completed_actions), 1n),
      Harmony.nat_member(99n, completed_actions)))

def failed_commit_does_not_award() -> Bool:
  +initial = Harmony.award_state(39)
  +same = Harmony.award_once(False{}, True{}, 8n, initial)
  failed_state_matches(same)

def harmony_saturates_at_forty() -> Bool:
  +initial = Harmony.award_state(40)
  +completed = Harmony.award_once(True{}, True{}, 99n, initial)
  saturation_matches(completed)

def successful_event_families() -> Bool:
  Bool.and(Harmony.event_changes_gameplay(False{}, Effects.DamageApplied{0n,
      Effects.Target{}, Effects.Physical{}, 1, False{}}),
    Bool.and(Harmony.event_changes_gameplay(False{}, Effects.HpRestored{
        Effects.Source{}, 1}),
    Bool.and(Harmony.event_changes_gameplay(True{}, Effects.StatusApplied{
        Effects.Target{}, Effects.Burn{}, False{}}),
    Bool.and(Harmony.event_changes_gameplay(True{}, Effects.StatusApplied{
        Effects.Target{}, Effects.Burn{}, True{}}),
    Bool.and(Harmony.event_changes_gameplay(False{}, Effects.StatusRemoved{
        Effects.Target{}, Effects.Poison{}}),
    Bool.and(Harmony.event_changes_gameplay(False{}, Effects.StatusesCleared{
        Effects.Source{}, 1n}),
    Harmony.event_changes_gameplay(False{}, Effects.StatModified{Effects.Target{},
      Effects.Attack{}, Math.StageNeutral{}, Math.StageUp{1n}})))))))

def unsuccessful_event_families() -> Bool:
  Bool.and(Bool.not(Harmony.event_changes_gameplay(False{}, Effects.DamageApplied{0n,
      Effects.Target{}, Effects.Physical{}, 0, False{}})),
    Bool.and(Bool.not(Harmony.event_changes_gameplay(False{}, Effects.DerivedDamage{
        Effects.Target{}, 0n, 7})),
    Bool.and(Bool.not(Harmony.event_changes_gameplay(False{}, Effects.DamageMissed{
        0n, Effects.Target{}, 9000})),
    Bool.and(Bool.not(Harmony.event_changes_gameplay(False{}, Effects.StatusesCleared{
        Effects.Target{}, 0n})),
    Bool.and(Bool.not(Harmony.event_changes_gameplay(False{}, Effects.StatusApplied{
        Effects.Target{}, Effects.Burn{}, True{}})),
      Bool.not(Harmony.event_changes_gameplay(False{}, Effects.StatModified{
        Effects.Target{}, Effects.Attack{}, Math.StageUp{3n},
        Math.StageUp{3n}})))))))

def tier_packages() -> Bool:
  Bool.and(package_is(0, 0, 0),
  Bool.and(package_is(4, 0, 0),
  Bool.and(package_is(5, 100, 125),
  Bool.and(package_is(9, 100, 125),
  Bool.and(package_is(10, 200, 250),
  Bool.and(package_is(19, 200, 250),
  Bool.and(package_is(20, 300, 375),
  Bool.and(package_is(29, 300, 375),
  Bool.and(package_is(30, 400, 500),
  Bool.and(package_is(39, 400, 500),
  Bool.and(package_is(40, 500, 625),
  Bool.and(package_is(99, 500, 625), True{}))))))))))))

def main() -> Bool:
  Bool.and(tier_packages(),
    Bool.and(award_is_idempotent(),
    Bool.and(failed_commit_does_not_award(),
    Bool.and(harmony_saturates_at_forty(),
    Bool.and(successful_event_families(), unsuccessful_event_families())))))
