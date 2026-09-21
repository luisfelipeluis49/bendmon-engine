import Base
import ./model.bend as Model

def ref_ok(id: Nat, count: Nat) -> Bool:
  match count:
    case 0n:
      False{}
    case 1n+p:
      Nat.is_lt(id, 1n+p)

def level_ok(+level: Nat) -> Bool:
  Bool.and(Nat.is_ge(level, 1n), Nat.is_le(level, 200n))

def dimension_ok(+size: Nat) -> Bool:
  Bool.and(Nat.is_ge(size, 1n), Nat.is_le(size, 512n))

def choose(ok: Bool, good: Model.Validation, bad: Model.Validation) -> Model.Validation:
  match ok:
    case True{}:
      good
    case False{}:
      bad

def first(left: Model.Validation, right: Model.Validation) -> Model.Validation:
  match left:
    case Model.Valid{}:
      right
    case Model.Invalid{code, record, item}:
      Model.Invalid{code, record, item}

def validate_species(
  species: List<&2, Model.Species>, +asset_count: Nat, +index: Nat
) -> Model.Validation:
  match species:
    case Nil{}:
      Model.Valid{}
    case Model.Species{Model.AssetId{id}} <> rest:
      choose(ref_ok(id, asset_count),
        validate_species(rest, asset_count, 1n+index),
        Model.Invalid{1n, index, 0n})

def validate_entries(
  entries: List<&2, Model.EncounterEntry>, +species_count: Nat,
  +record: Nat, +item: Nat
) -> Model.Validation:
  match entries:
    case Nil{}:
      Model.Valid{}
    case Model.EncounterEntry{Model.SpeciesId{id}, level} <> rest:
      choose(ref_ok(id, species_count),
        choose(level_ok(level),
          validate_entries(rest, species_count, record, 1n+item),
          Model.Invalid{3n, record, item}),
        Model.Invalid{2n, record, item})

def validate_encounters(
  encounters: List<&2, Model.Encounter>, +species_count: Nat, +record: Nat
) -> Model.Validation:
  match encounters:
    case Nil{}:
      Model.Valid{}
    case Model.Encounter{entries} <> rest:
      first(validate_entries(entries, species_count, record, 0n),
        validate_encounters(rest, species_count, 1n+record))

def validate_map_refs(
  refs: List<&2, Model.EncounterId>, +encounter_count: Nat,
  +record: Nat, +item: Nat
) -> Model.Validation:
  match refs:
    case Nil{}:
      Model.Valid{}
    case Model.EncounterId{id} <> rest:
      choose(ref_ok(id, encounter_count),
        validate_map_refs(rest, encounter_count, record, 1n+item),
        Model.Invalid{5n, record, item})

def validate_maps(
  maps: List<&2, Model.MapRecord>, +encounter_count: Nat, +record: Nat
) -> Model.Validation:
  match maps:
    case Nil{}:
      Model.Valid{}
    case Model.MapRecord{width, height, refs} <> rest:
      first(
        choose(dimension_ok(width),
          choose(dimension_ok(height),
            validate_map_refs(refs, encounter_count, record, 0n),
            Model.Invalid{4n, record, 0n}),
          Model.Invalid{4n, record, 0n}),
        validate_maps(rest, encounter_count, 1n+record))

def validate.entry(entry_map: Nat, map_count: Nat) -> Model.Validation:
  choose(ref_ok(entry_map, map_count), Model.Valid{},
    Model.Invalid{6n, 0n, 0n})

def validate.maps_and_entry(
  maps: List<&2, Model.MapRecord>, +encounter_count: Nat,
  +entry_map: Nat, +map_count: Nat
) -> Model.Validation:
  maps_result entry_result =
    validate_maps(maps, encounter_count, 0n)
    validate.entry(entry_map, map_count)
  first(maps_result, entry_result)

def validate.rest(
  encounters: List<&2, Model.Encounter>, +species_count: Nat,
  maps: List<&2, Model.MapRecord>, +encounter_count: Nat,
  +entry_map: Nat, +map_count: Nat
) -> Model.Validation:
  encounters_result maps_result =
    validate_encounters(encounters, species_count, 0n)
    validate.maps_and_entry(maps, encounter_count, entry_map, map_count)
  first(encounters_result, maps_result)

def validate(+content: Model.Content) -> Model.Validation:
  Model.Content{+asset_count, +species, +encounters, +maps,
    Model.MapId{+entry_map}} = content
  +species_count = List.length(&2, Model.Species, species)
  +encounter_count = List.length(&2, Model.Encounter, encounters)
  +map_count = List.length(&2, Model.MapRecord, maps)
  species_result rest_result =
    validate_species(species, asset_count, 0n)
    validate.rest(encounters, species_count, maps, encounter_count,
      entry_map, map_count)
  first(species_result, rest_result)
