import Base
import ./dynamic_species.bend as Species
import ./playable.bend as Playable
import ./rewards.bend as Rewards

# Convert the inert, bounded M10 progression catalog at the trusted M7 entry.
# Dynamic content supplies learning descriptors only; evolution and executable
# move effects remain owned by the selected trusted ruleset.
def learning_rows(rows: List<&2, Species.SpeciesProgressionRecord>) ->
  List<&2, Rewards.SpeciesLearning>:
  match rows:
    case Nil{}: Nil{}
    case Species.SpeciesProgressionRecord{species, base, capture_rate,
        xp_yield, currency_yield, combat_types,
        Rewards.SpeciesLearning{species_id, entries}} <> rest:
      Rewards.SpeciesLearning{species, entries} <>
        learning_rows(rest)

def catalog_valid(valid: Bool, identity: U32,
  +records: List<&2, Species.SpeciesProgressionRecord>) ->
  Maybe<Playable.ContentCatalog>:
  match valid:
    case False{}: None{}
    case True{}:
      Some{Playable.ContentCatalog{learning_rows(records), [], 7n,
        U32.to_nat(identity)}}

# Require the exact compact identity from the decoded wire before exposing
# descriptors to Playable.open.
def playable_catalog(catalog: Species.Catalog,
  expected_identity: U32) -> Maybe<Playable.ContentCatalog>:
  match catalog:
    case Species.Catalog{+identity, move_count, records}:
      catalog_valid(U32.is_eq(identity, expected_identity), identity, records)
