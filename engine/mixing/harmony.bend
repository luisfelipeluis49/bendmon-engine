import Base
import ../battle/effects.bend as Effects
import ../battle/combat_math.bend as Math

# Harmony is stored as successful-use progress, with all public operations
# saturating at the D06 ceiling. Learned recipe ownership lives in Learning.
type HarmonyTier is Data:
  Novice{}
  Familiar{}
  Practiced{}
  Expert{}
  Master{}
  Perfected{}

type HarmonyPackage is Data:
  HarmonyPackage{accuracy: U32, critical: U32}

type AwardState is Data:
  AwardState{progress: U32, completed_actions: List<&2, Nat>}

def harmony_zero() -> U32:
  0

def progress_cap(progress: U32) -> U32:
  U32.min(40, progress)

def next_progress(progress: U32) -> U32:
  U32.min(40, U32.add(progress_cap(progress), 1))

def tier_from_flags(at40: Bool, at30: Bool, at20: Bool, at10: Bool,
  at5: Bool) -> HarmonyTier:
  match at40 at30 at20 at10 at5:
    case True{} _ _ _ _: Perfected{}
    case False{} True{} _ _ _: Master{}
    case False{} False{} True{} _ _: Expert{}
    case False{} False{} False{} True{} _: Practiced{}
    case False{} False{} False{} False{} True{}: Familiar{}
    case False{} False{} False{} False{} False{}: Novice{}

def tier(progress: U32) -> HarmonyTier:
  +value = progress_cap(progress)
  tier_from_flags(U32.is_le(40, value), U32.is_le(30, value),
    U32.is_le(20, value), U32.is_le(10, value), U32.is_le(5, value))

def package(value: HarmonyTier) -> HarmonyPackage:
  match value:
    case Novice{}: HarmonyPackage{0, 0}
    case Familiar{}: HarmonyPackage{100, 125}
    case Practiced{}: HarmonyPackage{200, 250}
    case Expert{}: HarmonyPackage{300, 375}
    case Master{}: HarmonyPackage{400, 500}
    case Perfected{}: HarmonyPackage{500, 625}

def bonuses(progress: U32) -> HarmonyPackage:
  package(tier(progress))

def nat_member(+needle: Nat, values: List<&2, Nat>) -> Bool:
  match values:
    case Nil{}: False{}
    case value <> rest:
      Bool.or(Nat.is_eq(needle, value), nat_member(needle, rest))

def award_state(progress: U32) -> AwardState:
  AwardState{progress_cap(progress), Nil{}}

def award_unseen(seen: Bool, successful_effect: Bool, +action: Nat,
  +progress: U32, completed_actions: List<&2, Nat>) -> AwardState:
  match seen successful_effect:
    case True{} _: AwardState{progress_cap(progress), completed_actions}
    case False{} True{}: AwardState{next_progress(progress),
      action <> completed_actions}
    case False{} False{}: AwardState{progress_cap(progress),
      action <> completed_actions}

def award_committed(successful_effect: Bool, +action: Nat,
  +state: AwardState) -> AwardState:
  match state:
    case AwardState{progress, completed_actions}:
      award_unseen(nat_member(action, completed_actions), successful_effect,
        action, progress, completed_actions)

# Call only at the committed action boundary. A committed unsuccessful action
# is recorded too, so a replayed completion cannot later award it.
def award_once(committed: Bool, successful_effect: Bool, action: Nat,
  state: AwardState) -> AwardState:
  match committed:
    case False{}: state
    case True{}: award_committed(successful_effect, action, state)

def stage_changed(before: Math.Stage, after: Math.Stage) -> Bool:
  match before after:
    case Math.StageDown{left} Math.StageDown{right}: Nat.is_ne(left, right)
    case Math.StageNeutral{} Math.StageNeutral{}: False{}
    case Math.StageUp{left} Math.StageUp{right}: Nat.is_ne(left, right)
    case _ _: True{}

def event_changes_gameplay(status_state_changed: Bool,
  event: Effects.EffectEvent) -> Bool:
  match status_state_changed event:
    case _ Effects.DamageApplied{node, target, category, amount, critical}:
      U32.is_gt(amount, 0)
    case _ Effects.HpRestored{target, amount}: U32.is_gt(amount, 0)
    case True{} Effects.StatusApplied{target, status, refreshed}: True{}
    case False{} Effects.StatusApplied{target, status, refreshed}: False{}
    case _ Effects.StatusRemoved{target, status}: True{}
    case _ Effects.StatusesCleared{target, count}: Nat.is_gt(count, 0n)
    case _ Effects.StatModified{target, stat, before, after}:
      stage_changed(before, after)
    # Drain/recoil are aftermath. They never independently qualify as a mix
    # program effect (the originating DamageApplied event does).
    case _ Effects.DerivedDamage{target, from_node, amount}: False{}
    case _ Effects.DamageMissed{node, target, draw}: False{}
    case _ Effects.DamageComponentsApplied{node, components}: False{}
    case _ Effects.DamageNoEffect{node, target, reason}: False{}
    case _ Effects.NoEffect{target, reason}: False{}
    case _ Effects.ActionMissed{draw}: False{}
    case _ Effects.ActionBlocked{}: False{}
    case _ Effects.OpportunityEnded{blocked, residual}: False{}
    case _ Effects.ConditionalSelected{taken}: False{}

def any_effects(+status_state_changed: Bool,
  +events: List<&2, Effects.EffectEvent>) -> Bool:
  match events:
    case Nil{}: False{}
    case event <> rest:
      Bool.or(event_changes_gameplay(status_state_changed, event),
        any_effects(status_state_changed, rest))

def committed_effect_success(committed: Bool, status_state_changed: Bool,
  events: List<&2, Effects.EffectEvent>) -> Bool:
  match committed:
    case False{}: False{}
    case True{}: any_effects(status_state_changed, events)
