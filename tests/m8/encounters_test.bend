import Base
import ../../engine/world/encounters.bend as Encounters
import ../../engine/battle/rng.bend as Rng

def ready_threshold(result: Encounters.MeterResult) -> Bool:
  match result:
    case Encounters.MeterReady{Encounters.Meter{Some{0n}, 0n,
      +threshold, 0n, rng}}:
      Bool.and(Nat.is_ge(threshold, 98304n),
        Nat.is_le(threshold, 163840n))
    case _: False{}

def same_region_keeps_meter(result: Encounters.MeterResult) -> Bool:
  match result:
    case Encounters.MeterReady{Encounters.Meter{Some{0n}, 0n,
      threshold, 0n, Rng.RngState{1, 2, 3, 4}}}:
      Nat.is_eq(threshold, 98304n)
    case _: False{}

def triggered(result: Encounters.MeterResult) -> Bool:
  match result:
    case Encounters.MeterTriggered{0n, meter}: True{}
    case _: False{}

def safe_meter(result: Encounters.MeterResult) -> Bool:
  match result:
    case Encounters.MeterReady{Encounters.Meter{Some{0n}, 0n,
      threshold, safe, rng}}:
      Nat.is_eq(safe, 12288n)
    case _: False{}

def safe_walk(result: Encounters.MeterResult) -> Bool:
  match result:
    case Encounters.MeterReady{Encounters.Meter{Some{0n}, 0n,
      threshold, safe, rng}}:
      Nat.is_eq(safe, 4096n)
    case _: False{}

def threshold_reference(result: Encounters.MeterResult) -> Bool:
  match result:
    case Encounters.MeterReady{Encounters.Meter{Some{0n}, 0n,
      threshold, 0n, Rng.RngState{7, 0, 1026, 12288}}}:
      Nat.is_eq(threshold, 144384n)
    case _: False{}

def entry_selected(result: Encounters.EntryResult) -> Bool:
  match result:
    case Encounters.EntrySelected{7n, +level, rng}:
      Bool.and(Nat.is_ge(level, 5n), Nat.is_le(level, 8n))
    case _: False{}

def rejected(result: Encounters.EntryResult) -> Bool:
  match result:
    case Encounters.EntryRejected{rng}: True{}
    case _: False{}

def main() -> List<&2, Bool>:
  +rng: Rng.RngState = Rng.RngState{1, 2, 3, 4}
  +fixed: Encounters.Meter =
    Encounters.Meter{Some{0n}, 0n, 98304n, 0n, rng}
  [ready_threshold(Encounters.enter(Encounters.empty(rng), 0n)),
   threshold_reference(Encounters.enter(Encounters.empty(rng), 0n)),
   same_region_keeps_meter(Encounters.enter(fixed, 0n)),
   triggered(Encounters.advance(fixed, 32768n, Encounters.Walk{})),
   Bool.not(triggered(Encounters.advance(fixed, 8192n,
     Encounters.Run{}))),
   safe_meter(Encounters.after_battle(fixed)),
   safe_walk(Encounters.advance(
     Encounters.Meter{Some{0n}, 0n, 98304n, 12288n, rng},
     8192n, Encounters.Sprint{})),
   entry_selected(Encounters.choose([
     Encounters.EncounterEntry{7n, 1n, 5n, 8n}], rng)),
   rejected(Encounters.choose([], rng)),
   rejected(Encounters.choose([
     Encounters.EncounterEntry{7n, 0n, 5n, 8n}], rng))]
