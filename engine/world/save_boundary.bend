import Base
import ./world_session.bend as Session
import ./event_bridge.bend as EventBridge
import ./exploration.bend as Exploration
import ./catalog.bend as Catalog
import ./geometry.bend as Geometry
import ./encounters.bend as Encounters
import ./events.bend as Events
import ../battle/rng.bend as Rng

# This is the closed, deterministic core value persisted by the host. It
# contains no authored content or transient transition machine state.
type Snapshot is Data:
  Snapshot{content_identity: Nat, map_id: Nat, point: Geometry.Point,
    region: Maybe<&2, Nat>, weighted_quarters: Nat,
    threshold_quarters: Nat, safe_distance: Nat, rng: Rng.RngState,
    values: List<&2, Events.Value>, entities: List<&2, Nat>}

type SnapshotResult is Data:
  SnapshotReady{snapshot: Snapshot}
  SnapshotRejected{}

type RestoreResult is Data:
  Restored{session: Session.WorldSession}
  RestoreRejected{}

def bounded_values(rows: List<&2, Events.Value>) -> Bool:
  match rows:
    case Nil{}: True{}
    case Events.Value{key, value} <> rest:
      Bool.and(Nat.is_le(key, 4294967295n),
        Bool.and(Nat.is_le(value, 4294967295n),
          bounded_values(rest)))

def bounded_entities(rows: List<&2, Nat>) -> Bool:
  match rows:
    case Nil{}: True{}
    case entity <> rest:
      Bool.and(Nat.is_le(entity, 4294967295n),
        bounded_entities(rest))

def valid_persistent(world: Events.World) -> Bool:
  match world:
    case Events.World{+values, +entities}:
      Bool.and(Nat.is_le(List.length(&2, Events.Value, values), 4096n),
      Bool.and(Nat.is_le(List.length(&2, Nat, entities), 4096n),
      Bool.and(bounded_values(values), bounded_entities(entities))))

def valid_region_meter(region: Maybe<&2, Nat>, +weighted: Nat,
  +threshold: Nat, +safe: Nat) -> Bool:
  match region:
    case None{}:
      Bool.and(Nat.is_eq(weighted, 0n),
        Bool.and(Nat.is_eq(threshold, 0n), Nat.is_eq(safe, 0n)))
    case Some{id}:
      Bool.and(Nat.is_gt(id, 0n),
        Bool.and(Nat.is_ge(threshold, 98304n),
          Bool.and(Nat.is_le(threshold, 163840n),
            Bool.and(Nat.is_lt(weighted, threshold),
              Nat.is_le(safe, 12288n)))))

def valid_meter(meter: Encounters.Meter) -> Bool:
  match meter:
    case Encounters.Meter{region, weighted, threshold, safe, rng}:
      Bool.and(Rng.valid_state(rng),
        valid_region_meter(region, weighted, threshold, safe))

def stable_snapshot(valid: Bool, identity: Nat, map_id: Nat,
  point: Geometry.Point, meter: Encounters.Meter,
  persistent: Events.World) -> SnapshotResult:
  match valid:
    case False{}: SnapshotRejected{}
    case True{}:
      match meter persistent:
        case Encounters.Meter{region, weighted, threshold, safe, rng}
             Events.World{values, entities}:
          SnapshotReady{Snapshot{identity, map_id, point, region,
            weighted, threshold, safe, rng, values, entities}}

# Pending encounters, event activations, and battles have no stable save
# representation. Their constructors are rejected at this boundary.
def project_exploration(exploration: Exploration.State,
  persistent: Events.World) -> SnapshotResult:
  match exploration persistent:
    case Exploration.State{+map_id, +point, +meter, None{}, identity}
         Events.World{+values, +entities}:
      stable_snapshot(Bool.and(Nat.is_gt(map_id, 0n),
        Bool.and(Geometry.valid_point(point),
          Bool.and(valid_meter(meter),
            valid_persistent(Events.World{values, entities})))),
        identity, map_id, point, meter, Events.World{values, entities})
    case _ _: SnapshotRejected{}

def project_world(world: EventBridge.State) -> SnapshotResult:
  match world:
    case EventBridge.State{exploration, persistent, None{}}:
      project_exploration(exploration, persistent)
    case _: SnapshotRejected{}

def project(+session: Session.WorldSession) -> SnapshotResult:
  match session:
    case Session.WorldSession{world, None{}}: project_world(world)
    case _: SnapshotRejected{}

def region_id(found: Maybe<&2, Catalog.EncounterRegion>) -> Maybe<&2, Nat>:
  match found:
    case None{}: None{}
    case Some{Catalog.EncounterRegion{id, encounter_id, faces}}: Some{id}

def same_region(left: Maybe<&2, Nat>, right: Maybe<&2, Nat>) -> Bool:
  match left right:
    case None{} None{}: True{}
    case Some{a} Some{b}: Nat.is_eq(a, b)
    case _ _: False{}

def snapshot_point(snapshot: Snapshot) -> Geometry.Point:
  match snapshot:
    case Snapshot{content_identity, map_id, point, region, weighted,
        threshold, safe, rng, values, entities}: point

def snapshot_region(snapshot: Snapshot) -> Maybe<&2, Nat>:
  match snapshot:
    case Snapshot{content_identity, map_id, point, region, weighted,
        threshold, safe, rng, values, entities}: region

def snapshot_weighted(snapshot: Snapshot) -> Nat:
  match snapshot:
    case Snapshot{content_identity, map_id, point, region, weighted,
        threshold, safe, rng, values, entities}: weighted

def snapshot_threshold(snapshot: Snapshot) -> Nat:
  match snapshot:
    case Snapshot{content_identity, map_id, point, region, weighted,
        threshold, safe, rng, values, entities}: threshold

def snapshot_safe(snapshot: Snapshot) -> Nat:
  match snapshot:
    case Snapshot{content_identity, map_id, point, region, weighted,
        threshold, safe, rng, values, entities}: safe

def snapshot_rng(snapshot: Snapshot) -> Rng.RngState:
  match snapshot:
    case Snapshot{content_identity, map_id, point, region, weighted,
        threshold, safe, rng, values, entities}: rng

def accepted_face(face: Geometry.FaceChoice) -> Bool:
  match face:
    case Geometry.FaceAccepted{value}: True{}
    case Geometry.FaceRejected{}: False{}

def validate_map(found: Maybe<&2, Catalog.WorldMap>,
  +snapshot: Snapshot) -> Bool:
  match found:
    case None{}: False{}
    case Some{Catalog.WorldMap{id, +navigation, regions, npcs,
        triggers, transitions}}:
      Bool.and(Geometry.surface_valid(navigation),
        Bool.and(accepted_face(Geometry.face_for_point(navigation,
          snapshot_point(snapshot))),
          same_region(snapshot_region(snapshot),
            region_id(Catalog.region_at_point(
              Catalog.WorldMap{id, navigation, regions, npcs, triggers,
                transitions}, snapshot_point(snapshot))))))

def snapshot_identity(snapshot: Snapshot) -> Nat:
  match snapshot:
    case Snapshot{content_identity, map_id, point, region, weighted,
        threshold, safe, rng, values, entities}: content_identity

def snapshot_map(snapshot: Snapshot) -> Nat:
  match snapshot:
    case Snapshot{content_identity, map_id, point, region, weighted,
        threshold, safe, rng, values, entities}: map_id

def snapshot_persistent_valid(snapshot: Snapshot) -> Bool:
  match snapshot:
    case Snapshot{content_identity, map_id, point, region, weighted,
        threshold, safe, rng, values, entities}:
      valid_persistent(Events.World{values, entities})

def restore_surface(valid: Bool, snapshot: Snapshot) -> RestoreResult:
  match valid:
    case False{}: RestoreRejected{}
    case True{}:
      match snapshot:
        case Snapshot{content_identity, map_id, point, region, weighted,
            threshold, safe, rng, values, entities}:
          Restored{Session.WorldSession{EventBridge.State{
            Exploration.State{map_id, point,
              Encounters.Meter{region, weighted, threshold, safe, rng},
              None{}, content_identity}, Events.World{values, entities},
            None{}}, None{}}}

def restore_map(identity_ok: Bool,
  found: Maybe<&2, Catalog.WorldMap>, +snapshot: Snapshot) -> RestoreResult:
  match identity_ok:
    case False{}: RestoreRejected{}
    case True{}:
      match found:
        case None{}: RestoreRejected{}
        case Some{Catalog.WorldMap{id, navigation, regions, npcs,
            triggers, transitions}}:
          restore_surface(validate_map(found, snapshot), snapshot)

def restore_checked(ready: Bool, catalog: Catalog.Catalog,
  +snapshot: Snapshot) -> RestoreResult:
  match ready:
    case False{}: RestoreRejected{}
    case True{}:
      match catalog:
        case Catalog.Catalog{ruleset, content_identity, maps, events}:
          restore_map(Nat.is_eq(content_identity,
              snapshot_identity(snapshot)),
            Catalog.map_by_id(maps, snapshot_map(snapshot)), snapshot)

# Restore checks the exact catalog identity and verifies the saved position
# against the same baked surface and encounter region before reconstruction.
def restore(+catalog: Catalog.Catalog, +snapshot: Snapshot) -> RestoreResult:
  match catalog:
    case Catalog.Catalog{+ruleset, +content_identity, +maps, events}:
      restore_checked(Bool.and(Nat.is_eq(ruleset, 8n),
        Bool.and(valid_meter(Encounters.Meter{snapshot_region(snapshot),
          snapshot_weighted(snapshot), snapshot_threshold(snapshot),
          snapshot_safe(snapshot), snapshot_rng(snapshot)}),
          snapshot_persistent_valid(snapshot))), catalog,
        snapshot)
