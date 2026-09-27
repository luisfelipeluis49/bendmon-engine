import Base
import ../battle/rng.bend as Rng

# All distances use the authoritative Q10 world scale. Accumulation is kept
# in quarter-subunits so the approved 3/4, 1 and 3/2 mode weights are exact.
type MovementMode is Data:
  Walk{}
  Run{}
  Sprint{}

type Meter is Data:
  Meter{region: Maybe<&2, Nat>, weighted_quarters: Nat,
    threshold_quarters: Nat, safe_distance: Nat, rng: Rng.RngState}

type MeterResult is Data:
  MeterReady{meter: Meter}
  MeterTriggered{region: Nat, meter: Meter}
  MeterRejected{meter: Meter}

type EncounterEntry is Data:
  EncounterEntry{id: Nat, weight: Nat, min_level: Nat, max_level: Nat}

type EntryResult is Data:
  EntrySelected{id: Nat, level: Nat, rng: Rng.RngState}
  EntryRejected{rng: Rng.RngState}

def weight(mode: MovementMode) -> Nat:
  match mode:
    case Walk{}: 3n
    case Run{}: 4n
    case Sprint{}: 6n

def sample_threshold_result(result: Rng.RngSampleResult,
  +old: Meter, region: Nat, safe: Nat) -> MeterResult:
  match result:
    case Rng.RngSampled{next_rng, value, candidates}:
      MeterReady{Meter{Some{region}, 0n,
        Nat.mul(4n, Nat.add(24576n, U32.to_nat(value))), safe,
        next_rng}}
    case _: MeterRejected{old}

def draw_threshold(+old: Meter, region: Nat, safe: Nat) -> MeterResult:
  match old:
    case Meter{prior, weighted, threshold, prior_safe, +rng}:
      sample_threshold_result(Rng.sample(rng, 16385), old, region, safe)

def empty(rng: Rng.RngState) -> Meter:
  Meter{None{}, 0n, 0n, 0n, rng}

def leave(+old: Meter) -> Meter:
  match old:
    case Meter{region, weighted, threshold, safe, rng}:
      Meter{None{}, 0n, 0n, 0n, rng}

def enter_known(same_region: Bool, +old: Meter, region: Nat) -> MeterResult:
  match same_region:
    case True{}: MeterReady{old}
    case False{}: draw_threshold(old, region, 0n)

def enter(+old: Meter, +region: Nat) -> MeterResult:
  match old:
    case Meter{Some{current}, weighted, threshold, safe, rng}:
      enter_known(Nat.is_eq(current, region), old, region)
    case Meter{None{}, weighted, threshold, safe, rng}:
      draw_threshold(old, region, 0n)

# A completed encounter, regardless of battle outcome, draws the next
# threshold once. The 12-unit safe distance is unweighted and consumed first.
def after_battle(+old: Meter) -> MeterResult:
  match old:
    case Meter{Some{region}, weighted, threshold, safe, rng}:
      draw_threshold(old, region, 12288n)
    case Meter{None{}, weighted, threshold, safe, rng}:
      MeterRejected{old}

def advance_compare(triggered: Bool, region: Nat, next: Meter) -> MeterResult:
  match triggered:
    case True{}: MeterTriggered{region, next}
    case False{}: MeterReady{next}

def advance_ready(+old: Meter, +region: Nat, weighted: Nat,
  +threshold: Nat, +safe: Nat, rng: Rng.RngState,
  +distance: Nat, mode: MovementMode) -> MeterResult:
  +safe_used = Nat.min(safe, distance)
  +remaining = Nat.sub(distance, safe_used)
  +new_safe = Nat.sub(safe, safe_used)
  +new_weighted = Nat.add(weighted, Nat.mul(remaining, weight(mode)))
  +next: Meter = Meter{Some{region}, new_weighted, threshold, new_safe, rng}
  advance_compare(Nat.is_ge(new_weighted, threshold), region, next)

def advance_valid(valid: Bool, +old: Meter, region: Nat,
  weighted: Nat, threshold: Nat, safe: Nat, rng: Rng.RngState,
  distance: Nat, mode: MovementMode) -> MeterResult:
  match valid:
    case True{}:
      advance_ready(old, region, weighted, threshold, safe, rng,
        distance, mode)
    case False{}: MeterRejected{old}

def advance(+old: Meter, +distance: Nat,
  mode: MovementMode) -> MeterResult:
  match old:
    case Meter{Some{region}, weighted, threshold, safe, rng}:
      advance_valid(Bool.and(Nat.is_le(distance, 524288n),
        Bool.and(Nat.is_le(weighted, 1048576n),
          Bool.and(Nat.is_ge(threshold, 98304n),
            Nat.is_le(threshold, 163840n)))), old, region,
        weighted, threshold, safe, rng, distance, mode)
    case Meter{None{}, weighted, threshold, safe, rng}:
      MeterReady{old}

def entry_valid(entry: EncounterEntry) -> Bool:
  match entry:
    case EncounterEntry{id, +weight, +min_level, +max_level}:
      Bool.and(Nat.is_ge(weight, 1n),
        Bool.and(Nat.is_le(weight, 10000n),
          Bool.and(Nat.is_ge(min_level, 1n),
            Bool.and(Nat.is_le(min_level, max_level),
              Nat.is_le(max_level, 200n)))))

def entries_valid(entries: List<&2, EncounterEntry>) -> Bool:
  match entries:
    case Nil{}: False{}
    case entry <> Nil{}: entry_valid(entry)
    case entry <> rest:
      Bool.and(entry_valid(entry), entries_valid(rest))

def total_weight(entries: List<&2, EncounterEntry>) -> Nat:
  match entries:
    case Nil{}: 0n
    case EncounterEntry{id, weight, min_level, max_level} <> rest:
      Nat.add(weight, total_weight(rest))

def select_compare(rest: List<&2, EncounterEntry>, +entry: EncounterEntry,
  draw: Nat, weight: Nat, selected: Bool) ->
  Maybe<&2, EncounterEntry>:
  match rest selected:
    case _ True{}: Some{entry}
    case Nil{} False{}: None{}
    case EncounterEntry{id, +next_weight, min_level, max_level} <> tail False{}:
      +next_draw = Nat.sub(draw, weight)
      select_compare(tail,
        EncounterEntry{id, next_weight, min_level, max_level},
        next_draw, next_weight, Nat.is_lt(next_draw, next_weight))

def select_at(entries: List<&2, EncounterEntry>, +draw: Nat) ->
  Maybe<&2, EncounterEntry>:
  match entries:
    case Nil{}: None{}
    case entry <> rest:
      match entry:
        case EncounterEntry{id, +weight, min_level, max_level}:
          select_compare(rest, entry, draw, weight,
            Nat.is_lt(draw, weight))

def level_sample(result: Rng.RngSampleResult,
  entry: EncounterEntry, +original: Rng.RngState) -> EntryResult:
  match result entry:
    case Rng.RngSampled{next_rng, value, candidates}
         EncounterEntry{id, weight, min_level, max_level}:
      EntrySelected{id, Nat.add(min_level, U32.to_nat(value)), next_rng}
    case _ _: EntryRejected{original}

def entry_selected(found: Maybe<&2, EncounterEntry>,
  +next_rng: Rng.RngState, +original: Rng.RngState) -> EntryResult:
  match found:
    case None{}: EntryRejected{original}
    case Some{+entry}:
      match entry:
        case EncounterEntry{id, weight, min_level, max_level}:
          level_sample(Rng.sample(next_rng,
            U32.from_nat(Nat.add(1n, Nat.sub(max_level, min_level)))),
            entry, original)

def entry_sample(result: Rng.RngSampleResult,
  entries: List<&2, EncounterEntry>, +original: Rng.RngState) -> EntryResult:
  match result:
    case Rng.RngSampled{next_rng, value, candidates}:
      entry_selected(select_at(entries, U32.to_nat(value)), next_rng,
        original)
    case _: EntryRejected{original}

def choose_valid(valid: Bool, +entries: List<&2, EncounterEntry>,
  +rng: Rng.RngState, total: Nat) -> EntryResult:
  match valid:
    case False{}: EntryRejected{rng}
    case True{}:
      entry_sample(Rng.sample(rng, U32.from_nat(total)), entries, rng)

def choose(+entries: List<&2, EncounterEntry>,
  +rng: Rng.RngState) -> EntryResult:
  +total = total_weight(entries)
  choose_valid(Bool.and(entries_valid(entries),
    Bool.and(Nat.is_le(List.length(&2, EncounterEntry, entries), 256n),
      Nat.is_le(total, 2560000n))), entries, rng, total)
