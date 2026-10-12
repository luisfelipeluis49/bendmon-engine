import Base
import ../../engine/world/geometry.bend as Geometry
import ../../engine/world/catalog.bend as Catalog
import ../../engine/world/dialogue.bend as Dialogue
import ../../engine/world/dialogue_wire.bend as Wire
import ../../engine/world/dynamic_dialogue_join.bend as Join

def world(identity: Nat) -> Catalog.Catalog:
  Catalog.Catalog{8n, identity, [Catalog.WorldMap{1n,
    Geometry.NavSurface{[], [], []}, [],
    [Catalog.Npc{7n, Geometry.Point{Geometry.Coord{False{}, 0},
      Geometry.Coord{False{}, 0}, Geometry.Coord{False{}, 0}}, None{}}],
    [], []}], []}

def records() -> List<&2, Dialogue.Record>:
  [Dialogue.Record{2n, [Dialogue.Line{[65], [66]}]},
   Dialogue.Record{1n, [Dialogue.Line{[67], [68]}]}]

def association() -> Wire.Association:
  Wire.Association{1n, 7n, 2n}

def accepted(+associations: List<&2, Wire.Association>) -> Wire.DecodeResult:
  Wire.DecodeAccepted{88, records(), associations}

def accepts_valid() -> Bool:
  Join.validate(accepted([association()]), world(88n))

def rejects_identity() -> Bool:
  Bool.not(Join.validate(accepted([association()]), world(89n)))

def rejects_missing_npc() -> Bool:
  Bool.not(Join.validate(accepted([Wire.Association{1n, 8n, 2n}]),
    world(88n)))

def rejects_missing_map() -> Bool:
  Bool.not(Join.validate(accepted([Wire.Association{2n, 7n, 2n}]),
    world(88n)))

def rejects_missing_dialogue() -> Bool:
  Bool.not(Join.validate(accepted([Wire.Association{1n, 7n, 3n}]),
    world(88n)))

def rejects_duplicate_association() -> Bool:
  Bool.not(Join.validate(accepted([association(), association()]),
    world(88n)))

def rejects_duplicate_record_id() -> Bool:
  Bool.not(Join.validate(Wire.DecodeAccepted{88,
    [Dialogue.Record{1n, [Dialogue.Line{[65], [66]}]},
     Dialogue.Record{1n, [Dialogue.Line{[67], [68]}]}], [association()]},
    world(88n)))

def rejects_sparse_record_ids() -> Bool:
  Bool.not(Join.validate(Wire.DecodeAccepted{88,
    [Dialogue.Record{1n, [Dialogue.Line{[65], [66]}]},
     Dialogue.Record{3n, [Dialogue.Line{[67], [68]}]}], [association()]},
    world(88n)))

def main() -> Bool:
  Bool.and(accepts_valid(), Bool.and(rejects_identity(),
    Bool.and(rejects_missing_npc(), Bool.and(rejects_missing_map(),
      Bool.and(rejects_missing_dialogue(), Bool.and(rejects_duplicate_association(),
        Bool.and(rejects_duplicate_record_id(), rejects_sparse_record_ids())))))))

#| True
