import Base
import ./dynamic_content.bend as Content
import ./encounter_handoff.bend as Handoff
import ./encounters.bend as Encounters
import ../m7/dynamic_species.bend as Species

type PlaytestContent is Data:
  PlaytestContent{world: Content.BoundContent,
    species: Species.Catalog}

type JoinResult is Data:
  JoinRejected{reason: String}
  JoinAccepted{content: PlaytestContent}

def species_exists(+id: Nat,
  records: List<&2, Species.SpeciesProgressionRecord>) -> Bool:
  match records:
    case Nil{}: False{}
    case Species.SpeciesProgressionRecord{row_id, base, capture,
        xp, currency, combat_types, learning} <> rest:
      Bool.or(Nat.is_eq(id, row_id), species_exists(id, rest))

def entries_resolve(entries: List<&2, Encounters.EncounterEntry>,
  +records: List<&2, Species.SpeciesProgressionRecord>) -> Bool:
  match entries:
    case Nil{}: True{}
    case Encounters.EncounterEntry{id, weight, min_level,
        max_level} <> rest:
      Bool.and(species_exists(id, records),
        entries_resolve(rest, records))

def tables_resolve(tables: List<&2, Handoff.EncounterTable>,
  +records: List<&2, Species.SpeciesProgressionRecord>) -> Bool:
  match tables:
    case Nil{}: True{}
    case Handoff.EncounterTable{id, entries} <> rest:
      Bool.and(entries_resolve(entries, records),
        tables_resolve(rest, records))

def join_valid(valid: Bool, world: Content.BoundContent,
  species: Species.Catalog) -> JoinResult:
  match valid:
    case False{}:
      JoinRejected{"species identity or encounter species reference does not match"}
    case True{}: JoinAccepted{PlaytestContent{world, species}}

def join_records(world: Content.BoundContent,
  species: Species.Catalog) -> JoinResult:
  match world species:
    case Content.BoundContent{+world_identity, entry_map,
        catalog, +tables}
         Species.Catalog{+species_identity, move_count, +records}:
      join_valid(Bool.and(U32.is_eq(world_identity, species_identity),
        tables_resolve(tables, records)), world, species)

# A dynamic encounter must resolve to actual species progression before any
# session can be booted from the independently decoded world and M7 wires.
def join(world: Content.JoinResult,
  species: Species.DecodeResult) -> JoinResult:
  match world species:
    case Content.JoinRejected{reason} _: JoinRejected{"world content rejected"}
    case _ Species.DecodeRejected{reason}: JoinRejected{"species wire rejected"}
    case Content.JoinAccepted{content}
         Species.DecodeAccepted{catalog}:
      join_records(content, catalog)
