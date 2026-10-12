import Base
import ./catalog.bend as Catalog
import ./dialogue_wire.bend as Wire
import ./dialogue.bend as Dialogue

def npc_has_id(npcs: List<&2, Catalog.Npc>, +id: Nat) -> Bool:
  match npcs:
    case Nil{}: False{}
    case Catalog.Npc{+npc_id, point, event_id} <> rest:
      Bool.or(Nat.is_eq(npc_id, id), npc_has_id(rest, id))

def npc_in_map(found: Maybe<&2, Catalog.WorldMap>, id: Nat) -> Bool:
  match found:
    case None{}: False{}
    case Some{Catalog.WorldMap{map_id, navigation, regions, npcs,
        triggers, transitions}}:
      npc_has_id(npcs, id)

def association_target(catalog: Catalog.Catalog,
  association: Wire.Association) -> Bool:
  match catalog association:
    case Catalog.Catalog{ruleset, content_identity, maps, events}
        Wire.Association{map_id, npc_id, dialogue_id}:
      npc_in_map(Catalog.map_by_id(maps, map_id), npc_id)

def record_exists(records: List<&2, Dialogue.Record>, +id: Nat) -> Bool:
  match records:
    case Nil{}: False{}
    case Dialogue.Record{record_id, lines} <> rest:
      Bool.or(Nat.is_eq(record_id, id), record_exists(rest, id))

def record_id_exists(records: List<&2, Dialogue.Record>, +id: Nat) -> Bool:
  match records:
    case Nil{}: False{}
    case Dialogue.Record{record_id, lines} <> rest:
      Bool.or(Nat.is_eq(record_id, id), record_id_exists(rest, id))

def records_dense(records: List<&2, Dialogue.Record>, +maximum: Nat) -> Bool:
  match records:
    case Nil{}: True{}
    case Dialogue.Record{+id, lines} <> +rest:
      Bool.and(Bool.and(Nat.is_lt(0n, id), Nat.is_le(id, maximum)),
        Bool.and(Bool.not(record_id_exists(rest, id)),
          records_dense(rest, maximum)))

def association_same_key(+left: Wire.Association,
  right: Wire.Association) -> Bool:
  match left right:
    case Wire.Association{left_map, left_npc, left_dialogue}
        Wire.Association{right_map, right_npc, right_dialogue}:
      Bool.and(Nat.is_eq(left_map, right_map),
        Nat.is_eq(left_npc, right_npc))

def association_appears(+needle: Wire.Association,
  associations: List<&2, Wire.Association>) -> Bool:
  match associations:
    case Nil{}: False{}
    case row <> rest:
      Bool.or(association_same_key(needle, row),
        association_appears(needle, rest))

def associations_unique(+associations: List<&2, Wire.Association>) -> Bool:
  match associations:
    case Nil{}: True{}
    case row <> rest:
      Bool.and(Bool.not(association_appears(row, rest)),
        associations_unique(rest))

def associations_resolve(associations: List<&2, Wire.Association>,
  +catalog: Catalog.Catalog, +records: List<&2, Dialogue.Record>) -> Bool:
  match associations catalog records:
    case Nil{} world dialogue_records: True{}
    case (Wire.Association{map_id, npc_id, dialogue_id} <> rest)
        Catalog.Catalog{ruleset, content_identity, maps, events}
        dialogue_records:
      Bool.and(npc_in_map(Catalog.map_by_id(maps, map_id), npc_id),
        Bool.and(record_exists(dialogue_records, dialogue_id),
          associations_resolve(rest, Catalog.Catalog{ruleset, content_identity, maps, events}, dialogue_records)))

# Join only after decoding: the identity binds these rows to the exact world,
# while dense dialogue IDs make wire references bounded by the record count.
def validate(result: Wire.DecodeResult, +catalog: Catalog.Catalog) -> Bool:
  match result:
    case Wire.DecodeRejected{reason}: False{}
    case Wire.DecodeAccepted{identity, +records, +associations}:
      match catalog:
        case Catalog.Catalog{ruleset, content_identity, maps, events}:
          Bool.and(Nat.is_eq(content_identity, U32.to_nat(identity)),
            Bool.and(records_dense(records, List.length(&2, Dialogue.Record, records)),
              Bool.and(associations_unique(associations),
                associations_resolve(associations, catalog, records))))
