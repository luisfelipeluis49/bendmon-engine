import Base
import ./model.bend as Model

type Cursor is Data:
  Cursor{tokens: List<&2, Maybe<&2, U32>>, total_entries: Nat, total_refs: Nat}

type SpeciesPart is Data:
  SpeciesPart{values: List<&2, Model.Species>, cursor: Cursor}

type EntriesPart is Data:
  EntriesPart{values: List<&2, Model.EncounterEntry>, cursor: Cursor}

type EncountersPart is Data:
  EncountersPart{values: List<&2, Model.Encounter>, cursor: Cursor}

type RefsPart is Data:
  RefsPart{values: List<&2, Model.EncounterId>, cursor: Cursor}

type MapsPart is Data:
  MapsPart{values: List<&2, Model.MapRecord>, cursor: Cursor}

type SpeciesResult is Data:
  SpeciesFail{reason: String}
  SpeciesDone{value: SpeciesPart}

type EntriesResult is Data:
  EntriesFail{reason: String}
  EntriesDone{value: EntriesPart}

type EncountersResult is Data:
  EncountersFail{reason: String}
  EncountersDone{value: EncountersPart}

type RefsResult is Data:
  RefsFail{reason: String}
  RefsDone{value: RefsPart}

type MapsResult is Data:
  MapsFail{reason: String}
  MapsDone{value: MapsPart}

type WireResult is Data:
  WireFail{reason: String}
  WireDone{content: Model.Content}

type TokenResult is Data:
  TokenFail{reason: String}
  TokenDone{values: List<&2, Maybe<&2, U32>>}

type ScanState is Data:
  ScanRun{count: Nat, values: List<&2, Maybe<&2, U32>>,
    value: U32, has_digit: Bool}
  ScanStop{reason: String}

type EncounterState is Data:
  EncNeed{remaining: Nat, acc: List<&2, Model.Encounter>}
  EncCountBad{}
  EncCount{count: Nat, remaining: Nat, acc: List<&2, Model.Encounter>}
  EncTotalBad{}
  EncTotal{total: Nat, count: Nat, remaining: Nat,
    acc: List<&2, Model.Encounter>}
  EncEntries{left: Nat, remaining: Nat,
    current: List<&2, Model.EncounterEntry>, acc: List<&2, Model.Encounter>}

type MapState is Data:
  MapNeed{remaining: Nat, acc: List<&2, Model.MapRecord>}
  MapCountBad{}
  MapTotalBad{}
  MapRefs{left: Nat, total: Nat, width: Nat, height: Nat, remaining: Nat,
    current: List<&2, Model.EncounterId>, acc: List<&2, Model.MapRecord>}

def capped_count(value: U32) -> Nat:
  U32.to_nat(U32.min(value, 257))

def encounter_count_state(
  ok: Bool, count: Nat, remaining: Nat, acc: List<&2, Model.Encounter>
) -> EncounterState:
  match ok:
    case False{}:
      EncCountBad{}
    case True{}:
      EncCount{count, remaining, acc}

def encounter_total_state(
  ok: Bool, total: Nat, count: Nat, remaining: Nat,
  acc: List<&2, Model.Encounter>
) -> EncounterState:
  match ok:
    case False{}:
      EncTotalBad{}
    case True{}:
      EncTotal{total, count, remaining, acc}

def map_start_state(
  count_ok: Bool, total_ok: Bool, count: Nat, total: Nat, width: Nat,
  height: Nat, remaining: Nat, acc: List<&2, Model.MapRecord>
) -> MapState:
  match count_ok:
    case False{}:
      MapCountBad{}
    case True{}:
      match total_ok:
        case False{}:
          MapTotalBad{}
        case True{}:
          MapRefs{count, total, width, height, remaining, Nil{}, acc}

def parse_species(
  count: Nat, cursor: Cursor, acc: List<&2, Model.Species>
) -> SpeciesResult:
  match count cursor:
    case 0n Cursor{tokens, entries, refs}:
      SpeciesDone{SpeciesPart{List.reverse(&2, Model.Species, acc),
        Cursor{tokens, entries, refs}}}
    case 1n+p Cursor{Nil{}, entries, refs}:
      SpeciesFail{"missing"}
    case 1n+p Cursor{None{} <> rest, entries, refs}:
      SpeciesFail{"numeric"}
    case 1n+p Cursor{Some{asset} <> rest, entries, refs}:
      parse_species(p, Cursor{rest, entries, refs},
        Model.Species{Model.AssetId{U32.to_nat(asset)}} <> acc)

def parse_entries(
  count: Nat, cursor: Cursor, acc: List<&2, Model.EncounterEntry>
) -> EntriesResult:
  match count cursor:
    case 0n Cursor{tokens, entries, refs}:
      EntriesDone{EntriesPart{List.reverse(&2, Model.EncounterEntry, acc),
        Cursor{tokens, entries, refs}}}
    case 1n+p Cursor{Nil{}, entries, refs}:
      EntriesFail{"missing"}
    case 1n+p Cursor{None{} <> rest, entries, refs}:
      EntriesFail{"numeric"}
    case 1n+p Cursor{Some{species} <> Nil{}, entries, refs}:
      EntriesFail{"missing"}
    case 1n+p Cursor{Some{species} <> None{} <> rest, entries, refs}:
      EntriesFail{"numeric"}
    case 1n+p Cursor{Some{species} <> Some{level} <> rest, entries, refs}:
      parse_entries(p, Cursor{rest, entries, refs}, Model.EncounterEntry{
        Model.SpeciesId{U32.to_nat(species)}, U32.to_nat(level)} <> acc)

def parse_refs(
  count: Nat, cursor: Cursor, acc: List<&2, Model.EncounterId>
) -> RefsResult:
  match count cursor:
    case 0n Cursor{tokens, entries, refs}:
      RefsDone{RefsPart{List.reverse(&2, Model.EncounterId, acc),
        Cursor{tokens, entries, refs}}}
    case 1n+p Cursor{Nil{}, entries, refs}:
      RefsFail{"missing"}
    case 1n+p Cursor{None{} <> rest, entries, refs}:
      RefsFail{"numeric"}
    case 1n+p Cursor{Some{id} <> rest, entries, refs}:
      parse_refs(p, Cursor{rest, entries, refs},
        Model.EncounterId{U32.to_nat(id)} <> acc)

def encounter_machine(fuel: Nat, state: EncounterState, +cursor: Cursor) ->
  EncountersResult:
  match fuel:
    case 0n:
      EncountersFail{"fuel"}
    case 1n++f:
      match state:
        case EncNeed{0n, acc}:
          match cursor:
            case Cursor{tokens, entries, refs}:
              EncountersDone{EncountersPart{
                List.reverse(&2, Model.Encounter, acc),
                Cursor{tokens, entries, refs}}}
        case EncNeed{1n+remaining, acc}:
          match cursor:
            case Cursor{Nil{}, entries, refs}:
              EncountersFail{"missing"}
            case Cursor{None{} <> rest, entries, refs}:
              EncountersFail{"numeric"}
            case Cursor{Some{+raw} <> rest, entries, refs}:
              encounter_machine(f, encounter_count_state(
                U32.is_le(raw, 256), capped_count(raw), remaining, acc),
                Cursor{rest, entries, refs})
        case EncCountBad{}:
          EncountersFail{"entry-count"}
        case EncCount{+count, remaining, acc}:
          match cursor:
            case Cursor{tokens, +entries, refs}:
              +total = Nat.add(entries, count)
              encounter_machine(f, encounter_total_state(
                Nat.is_le(total, 4096n), total, count, remaining, acc),
                Cursor{tokens, entries, refs})
        case EncTotalBad{}:
          EncountersFail{"entry-total"}
        case EncTotal{total, count, remaining, acc}:
          match cursor:
            case Cursor{tokens, entries, refs}:
              encounter_machine(f, EncEntries{count, remaining, Nil{}, acc},
                Cursor{tokens, total, refs})
        case EncEntries{0n, remaining, current, acc}:
          encounter_machine(f, EncNeed{remaining, Model.Encounter{
            List.reverse(&2, Model.EncounterEntry, current)} <> acc}, cursor)
        case EncEntries{1n+left, remaining, current, acc}:
          match cursor:
            case Cursor{Nil{}, entries, refs}:
              EncountersFail{"missing"}
            case Cursor{None{} <> rest, entries, refs}:
              EncountersFail{"numeric"}
            case Cursor{Some{species} <> Nil{}, entries, refs}:
              EncountersFail{"missing"}
            case Cursor{Some{species} <> None{} <> rest, entries, refs}:
              EncountersFail{"numeric"}
            case Cursor{Some{species} <> Some{level} <> rest, entries, refs}:
              encounter_machine(f, EncEntries{left, remaining,
                Model.EncounterEntry{Model.SpeciesId{U32.to_nat(species)},
                  U32.to_nat(level)} <> current, acc},
                Cursor{rest, entries, refs})

def parse_encounters(
  count: Nat, cursor: Cursor, acc: List<&2, Model.Encounter>
) -> EncountersResult:
  Cursor{+tokens, entries, refs} = cursor
  encounter_machine(Nat.add(List.length(&2, Maybe<&2, U32>, tokens), 1024n),
    EncNeed{count, acc}, Cursor{tokens, entries, refs})

def map_machine(fuel: Nat, state: MapState, +cursor: Cursor) -> MapsResult:
  match fuel:
    case 0n:
      MapsFail{"fuel"}
    case 1n++f:
      match state:
        case MapNeed{0n, acc}:
          match cursor:
            case Cursor{tokens, entries, refs}:
              MapsDone{MapsPart{List.reverse(&2, Model.MapRecord, acc),
                Cursor{tokens, entries, refs}}}
        case MapNeed{1n+remaining, acc}:
          match cursor:
            case Cursor{Nil{}, entries, refs}:
              MapsFail{"missing"}
            case Cursor{None{} <> rest, entries, refs}:
              MapsFail{"numeric"}
            case Cursor{Some{width} <> Nil{}, entries, refs}:
              MapsFail{"missing"}
            case Cursor{Some{width} <> None{} <> rest, entries, refs}:
              MapsFail{"numeric"}
            case Cursor{Some{width} <> Some{height} <> Nil{}, entries, refs}:
              MapsFail{"missing"}
            case Cursor{Some{width} <> Some{height} <> None{} <> rest,
                entries, refs}:
              MapsFail{"numeric"}
            case Cursor{Some{width} <> Some{height} <> Some{+raw} <> rest,
                entries, +refs}:
              +count = capped_count(raw)
              +total = Nat.add(refs, count)
              map_machine(f, map_start_state(U32.is_le(raw, 256),
                Nat.is_le(total, 4096n), count, total, U32.to_nat(width),
                U32.to_nat(height), remaining, acc),
                Cursor{rest, entries, refs})
        case MapCountBad{}:
          MapsFail{"reference-count"}
        case MapTotalBad{}:
          MapsFail{"reference-total"}
        case MapRefs{0n, total, width, height, remaining, current, acc}:
          match cursor:
            case Cursor{tokens, entries, refs}:
              map_machine(f, MapNeed{remaining, Model.MapRecord{width, height,
                List.reverse(&2, Model.EncounterId, current)} <> acc},
                Cursor{tokens, entries, total})
        case MapRefs{1n+left, total, width, height, remaining, current, acc}:
          match cursor:
            case Cursor{Nil{}, entries, refs}:
              MapsFail{"missing"}
            case Cursor{None{} <> rest, entries, refs}:
              MapsFail{"numeric"}
            case Cursor{Some{id} <> rest, entries, refs}:
              map_machine(f, MapRefs{left, total, width, height, remaining,
                Model.EncounterId{U32.to_nat(id)} <> current, acc},
                Cursor{rest, entries, refs})

def parse_maps(
  count: Nat, cursor: Cursor, acc: List<&2, Model.MapRecord>
) -> MapsResult:
  Cursor{+tokens, entries, refs} = cursor
  map_machine(Nat.add(List.length(&2, Maybe<&2, U32>, tokens), 1024n),
    MapNeed{count, acc}, Cursor{tokens, entries, refs})

def finish(
  asset_count: Nat, species: List<&2, Model.Species>,
  encounters: List<&2, Model.Encounter>, maps: List<&2, Model.MapRecord>,
  cursor: Cursor
) -> WireResult:
  match cursor:
    case Cursor{Nil{}, entries, refs}:
      WireFail{"missing"}
    case Cursor{None{} <> rest, entries, refs}:
      WireFail{"numeric"}
    case Cursor{Some{entry_map} <> Nil{}, entries, refs}:
      WireDone{Model.Content{asset_count, species, encounters, maps,
        Model.MapId{U32.to_nat(entry_map)}}}
    case Cursor{Some{entry_map} <> h <> t, entries, refs}:
      WireFail{"trailing"}

def after_maps(
  parsed: MapsResult, asset_count: Nat, species: List<&2, Model.Species>,
  encounters: List<&2, Model.Encounter>
) -> WireResult:
  match parsed:
    case MapsFail{reason}:
      WireFail{reason}
    case MapsDone{MapsPart{maps, cursor}}:
      finish(asset_count, species, encounters, maps, cursor)

def map_count(
  count: Nat, cursor: Cursor, asset_count: Nat,
  species: List<&2, Model.Species>, encounters: List<&2, Model.Encounter>
) -> WireResult:
  match count:
    case 257n:
      WireFail{"map-count"}
    case _:
      after_maps(parse_maps(count, cursor, Nil{}), asset_count, species,
        encounters)

def after_encounters(
  parsed: EncountersResult, asset_count: Nat,
  species: List<&2, Model.Species>
) -> WireResult:
  match parsed:
    case EncountersFail{reason}:
      WireFail{reason}
    case EncountersDone{EncountersPart{encounters,
        Cursor{Nil{}, entries, refs}}}:
      WireFail{"missing"}
    case EncountersDone{EncountersPart{encounters,
        Cursor{None{} <> rest, entries, refs}}}:
      WireFail{"numeric"}
    case EncountersDone{EncountersPart{encounters,
        Cursor{Some{raw} <> rest, entries, refs}}}:
      map_count(capped_count(raw), Cursor{rest, entries, refs}, asset_count,
        species, encounters)

def encounter_count(
  count: Nat, cursor: Cursor, asset_count: Nat,
  species: List<&2, Model.Species>
) -> WireResult:
  match count:
    case 257n:
      WireFail{"encounter-count"}
    case _:
      after_encounters(parse_encounters(count, cursor, Nil{}), asset_count,
        species)

def after_species(parsed: SpeciesResult, asset_count: Nat) -> WireResult:
  match parsed:
    case SpeciesFail{reason}:
      WireFail{reason}
    case SpeciesDone{SpeciesPart{species, Cursor{Nil{}, entries, refs}}}:
      WireFail{"missing"}
    case SpeciesDone{SpeciesPart{species,
        Cursor{None{} <> rest, entries, refs}}}:
      WireFail{"numeric"}
    case SpeciesDone{SpeciesPart{species,
        Cursor{Some{raw} <> rest, entries, refs}}}:
      encounter_count(capped_count(raw), Cursor{rest, entries, refs},
        asset_count, species)

def species_count(count: Nat, cursor: Cursor, asset_count: Nat) -> WireResult:
  match count:
    case 257n:
      WireFail{"species-count"}
    case _:
      after_species(parse_species(count, cursor, Nil{}), asset_count)

def after_asset(asset_count: Nat, cursor: Cursor) -> WireResult:
  match asset_count:
    case 257n:
      WireFail{"asset-count"}
    case _:
      match cursor:
        case Cursor{Nil{}, entries, refs}:
          WireFail{"missing"}
        case Cursor{None{} <> rest, entries, refs}:
          WireFail{"numeric"}
        case Cursor{Some{raw} <> rest, entries, refs}:
          species_count(capped_count(raw), Cursor{rest, entries, refs},
            asset_count)

def parse_version(
  version: U32, asset: U32, rest: List<&2, Maybe<&2, U32>>, ok: Bool
) -> WireResult:
  match ok:
    case False{}:
      WireFail{"version"}
    case True{}:
      after_asset(capped_count(asset), Cursor{rest, 0n, 0n})

def parse_body(tokens: List<&2, Maybe<&2, U32>>) -> WireResult:
  match tokens:
    case Nil{}:
      WireFail{"missing"}
    case None{} <> rest:
      WireFail{"numeric"}
    case Some{+version} <> rest:
      match rest:
        case Nil{}:
          WireFail{"missing"}
        case None{} <> tail:
          WireFail{"numeric"}
        case Some{asset} <> tail:
          parse_version(version, asset, tail, U32.is_eq(version, 1))

def scan.push_state(
  count: Nat, values: List<&2, Maybe<&2, U32>>, value: U32, room: Bool
) -> ScanState:
  match room:
    case False{}:
      ScanStop{"token-count"}
    case True{}:
      ScanRun{1n+count, Some{value} <> values, 0, False{}}

def scan.space_state(
  +count: Nat, values: List<&2, Maybe<&2, U32>>,
  value: U32, has_digit: Bool
) -> ScanState:
  match has_digit:
    case False{}:
      ScanStop{"numeric"}
    case True{}:
      scan.push_state(count, values, value, Nat.is_lt(count, 140000n))

def scan.overflow_state(
  count: Nat, values: List<&2, Maybe<&2, U32>>,
  next: U32, ok: Bool
) -> ScanState:
  match ok:
    case False{}:
      ScanStop{"numeric"}
    case True{}:
      ScanRun{count, values, next, True{}}

def scan.digit_state(
  code: U32, count: Nat,
  values: List<&2, Maybe<&2, U32>>, +value: U32, ok: Bool
) -> ScanState:
  match ok:
    case False{}:
      ScanStop{"numeric"}
    case True{}:
      +next = U32.add(U32.mul(value, 10), U32.sub(code, 48))
      scan.overflow_state(count, values, next,
        U32.is_eq(U32.div(next, 10), value))

def scan.char_state(
  +code: U32, count: Nat,
  values: List<&2, Maybe<&2, U32>>, value: U32,
  has_digit: Bool, space: Bool
) -> ScanState:
  match space:
    case True{}:
      scan.space_state(count, values, value, has_digit)
    case False{}:
      scan.digit_state(code, count, values, value,
        Bool.and(U32.is_ge(code, 48), U32.is_le(code, 57)))

def scan.finish_room(
  values: List<&2, Maybe<&2, U32>>, value: U32, room: Bool
) -> TokenResult:
  match room:
    case False{}:
      TokenFail{"token-count"}
    case True{}:
      TokenDone{List.reverse(&2, Maybe<&2, U32>, Some{value} <> values)}

def scan.finish(
  count: Nat, values: List<&2, Maybe<&2, U32>>,
  value: U32, has_digit: Bool
) -> TokenResult:
  match has_digit:
    case False{}:
      TokenFail{"numeric"}
    case True{}:
      scan.finish_room(values, value, Nat.is_lt(count, 140000n))

def scan(text: String, state: ScanState) -> TokenResult:
  match text state:
    case _ ScanStop{reason}:
      TokenFail{reason}
    case SNil{} ScanRun{count, values, value, has_digit}:
      scan.finish(count, values, value, has_digit)
    case SCon{Chr{+code}, rest} ScanRun{count, values, value, has_digit}:
      scan(rest, scan.char_state(code, count, values, value, has_digit,
        U32.is_eq(code, 32)))

def parse_tokens(result: TokenResult) -> WireResult:
  match result:
    case TokenFail{reason}:
      WireFail{reason}
    case TokenDone{values}:
      parse_body(values)

def parse(text: String) -> WireResult:
  parse_tokens(scan(text, ScanRun{0n, Nil{}, 0, False{}}))
