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

type EncounterState is Data:
  EncNeed{remaining: Nat, acc: List<&2, Model.Encounter>}
  EncCountBad{}
  EncCount{count: Nat, remaining: Nat, acc: List<&2, Model.Encounter>}
  EncTotalBad{}
  EncTotal{total: Nat, count: Nat, remaining: Nat,
    acc: List<&2, Model.Encounter>}
  EncEntries{left: Nat, remaining: Nat,
    current: List<&2, Model.EncounterEntry>, acc: List<&2, Model.Encounter>}

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

law parse_maps:
  for count: Nat
  for cursor: Cursor
  for acc: List<&2, Model.MapRecord>
  MapsResult

def after_refs(
  parsed: RefsResult, width: Nat, height: Nat, remaining: Nat,
  acc: List<&2, Model.MapRecord>
) -> MapsResult:
  match parsed:
    case RefsFail{reason}:
      MapsFail{reason}
    case RefsDone{RefsPart{refs, cursor}}:
      parse_maps(remaining, cursor,
        Model.MapRecord{width, height, refs} <> acc)

def ref_total(
  +total: Nat, count: Nat, cursor: Cursor, width: Nat, height: Nat,
  remaining: Nat, acc: List<&2, Model.MapRecord>
) -> MapsResult:
  match total:
    case 4097n:
      MapsFail{"reference-total"}
    case _:
      after_refs(parse_refs(count, cursor, Nil{}), width, height,
        remaining, acc)

def ref_count(
  count: Nat, cursor: Cursor, width: Nat, height: Nat,
  remaining: Nat, acc: List<&2, Model.MapRecord>
) -> MapsResult:
  match count:
    case 257n:
      MapsFail{"reference-count"}
    case _:
      Cursor{tokens, entries, +total} = cursor
      ref_total(Nat.min(Nat.add(total, count), 4097n), count,
        Cursor{tokens, entries, Nat.add(total, count)}, width, height,
        remaining, acc)

def parse_maps.count(
  raw: U32, cursor: Cursor, width: U32, height: U32,
  remaining: Nat, acc: List<&2, Model.MapRecord>
) -> MapsResult:
  ref_count(capped_count(raw), cursor, U32.to_nat(width), U32.to_nat(height),
    remaining, acc)

def parse_maps(count, cursor, acc):
  match count cursor:
    case 0n Cursor{tokens, entries, refs}:
      MapsDone{MapsPart{List.reverse(&2, Model.MapRecord, acc),
        Cursor{tokens, entries, refs}}}
    case 1n+p Cursor{Nil{}, entries, refs}:
      MapsFail{"missing"}
    case 1n+p Cursor{None{} <> rest, entries, refs}:
      MapsFail{"numeric"}
    case 1n+p Cursor{Some{width} <> Nil{}, entries, refs}:
      MapsFail{"missing"}
    case 1n+p Cursor{Some{width} <> None{} <> rest, entries, refs}:
      MapsFail{"numeric"}
    case 1n+p Cursor{Some{width} <> Some{height} <> Nil{}, entries, refs}:
      MapsFail{"missing"}
    case 1n+p Cursor{Some{width} <> Some{height} <> None{} <> rest, entries, refs}:
      MapsFail{"numeric"}
    case 1n+p Cursor{Some{width} <> Some{height} <> Some{raw} <> rest,
        entries, refs}:
      parse_maps.count(raw, Cursor{rest, entries, refs}, width, height, p, acc)

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

law parse_version:
  for version: U32
  for asset: U32
  for rest: List<&2, Maybe<&2, U32>>
  for ok: Bool
  WireResult

def parse_body(tokens: List<&2, Maybe<&2, U32>>) -> WireResult:
  match tokens:
    case Nil{}:
      WireFail{"missing"}
    case None{} <> rest:
      WireFail{"numeric"}
    case Some{version} <> Nil{}:
      WireFail{"missing"}
    case Some{version} <> None{} <> rest:
      WireFail{"numeric"}
    case Some{version} <> Some{asset} <> rest:
      parse_version(version, asset, rest, U32.is_eq(version, 1))

def parse_version(version, asset, rest, ok):
  match ok:
    case False{}:
      WireFail{"version"}
    case True{}:
      after_asset(capped_count(asset), Cursor{rest, 0n, 0n})

def token_count(
  tokens: List<&2, String>, ok: Bool
) -> WireResult:
  match ok:
    case False{}:
      WireFail{"token-count"}
    case True{}:
      parse_body(List.map(~String, ~Maybe<&2, U32>, ~U32.read, tokens))

def parse(text: String) -> WireResult:
  +tokens = String.split(text, ' ')
  token_count(tokens, Nat.is_le(List.length(&2, String, tokens), 140000n))
