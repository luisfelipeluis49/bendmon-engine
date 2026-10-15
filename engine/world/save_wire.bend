import Base
import ./save_boundary.bend as Save
import ./geometry.bend as Geometry
import ./events.bend as Events
import ../battle/rng.bend as Rng

# A closed numeric projection of the same stable snapshot that M8 restores.
# A rejected snapshot has no payload, so the host cannot infer saveability from
# a rendered map or a dialogue cursor.
def coordinate(value: Geometry.Coord) -> String:
  match value:
    case Geometry.Coord{negative, magnitude}:
      sign = Bool.pick(String, negative, "1", "0")
      sign ++ "," ++ U32.show(magnitude)

def point(value: Geometry.Point) -> String:
  match value:
    case Geometry.Point{x, y, z}:
      coordinate(x) ++ "," ++ coordinate(y) ++ "," ++ coordinate(z)

def region(value: Maybe<&2, Nat>) -> String:
  match value:
    case None{}: "0"
    case Some{id}: Nat.show(id)

def rng(value: Rng.RngState) -> String:
  match value:
    case Rng.RngState{a, b, c, d}:
      U32.show(a) ++ "," ++ U32.show(b) ++ "," ++ U32.show(c) ++ "," ++
        U32.show(d)

def values(rows: List<&2, Events.Value>) -> String:
  match rows:
    case Nil{}: ""
    case Events.Value{key, value} <> rest:
      "," ++ Nat.show(key) ++ "," ++ Nat.show(value) ++ values(rest)

def entities(rows: List<&2, Nat>) -> String:
  match rows:
    case Nil{}: ""
    case entity <> rest: "," ++ Nat.show(entity) ++ entities(rest)

def serialize(result: Save.SnapshotResult) -> String:
  match result:
    case Save.SnapshotRejected{}: "0"
    case Save.SnapshotReady{Save.Snapshot{identity, map_id, position,
        region_id, weighted, threshold, safe, random, +persistent,
        +members}}:
      "1," ++ Nat.show(identity) ++ "," ++ Nat.show(map_id) ++ "," ++
        point(position) ++ "," ++ region(region_id) ++ "," ++
        Nat.show(weighted) ++ "," ++ Nat.show(threshold) ++ "," ++
        Nat.show(safe) ++ "," ++ rng(random) ++ "," ++
        Nat.show(List.length(&2, Events.Value, persistent)) ++
        values(persistent) ++ "," ++ Nat.show(List.length(&2, Nat,
          members)) ++ entities(members)
