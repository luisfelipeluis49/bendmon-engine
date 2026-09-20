import Base

# Dense identifiers are deliberately different types.  The loader assigns the
# dense values after sorting each namespace; constructors prevent accidental
# cross-kind resolution inside the kernel.
type AssetId is Data:
  AssetId{value: Nat}

type SpeciesId is Data:
  SpeciesId{value: Nat}

type EncounterId is Data:
  EncounterId{value: Nat}

type MapId is Data:
  MapId{value: Nat}

type Species is Data:
  Species{sprite: AssetId}

type EncounterEntry is Data:
  EncounterEntry{species: SpeciesId, level: Nat}

type Encounter is Data:
  Encounter{entries: List<&2, EncounterEntry>}

type MapRecord is Data:
  MapRecord{width: Nat, height: Nat, encounters: List<&2, EncounterId>}

type Content is Data:
  Content{
    asset_count: Nat,
    species: List<&2, Species>,
    encounters: List<&2, Encounter>,
    maps: List<&2, MapRecord>,
    entry_map: MapId
  }

# A stable semantic diagnostic.  The code meanings and zero-based indices are
# frozen in docs/schemas/CONTENT-0.md.
type Validation is Data:
  Valid{}
  Invalid{code: Nat, record: Nat, item: Nat}
