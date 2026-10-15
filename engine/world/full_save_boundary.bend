import Base
import ./save_boundary.bend as Save
import ./world_session.bend as Session
import ./catalog.bend as Catalog
import ../m7/persistent_state.bend as M7Persistent

type FullSnapshot is Data:
  FullSnapshot{world: Save.Snapshot,
    progression: M7Persistent.PersistentState}

type FullSnapshotResult is Data:
  FullSnapshotReady{snapshot: FullSnapshot}
  FullSnapshotRejected{}

type FullRestoreResult is Data:
  FullRestored{session: Session.WorldSession}
  FullRestoreRejected{}

def snapshot_identity(snapshot: Save.Snapshot) -> Nat:
  match snapshot:
    case Save.Snapshot{content_identity, map_id, point, region, weighted,
        threshold, safe, rng, values, entities}: content_identity

def progression_identity(state: M7Persistent.PersistentState) -> Nat:
  match state:
    case M7Persistent.PersistentState{economy, roster, owned, ledger,
        ruleset, identity}: identity

def combined(valid: Bool, world: Save.SnapshotResult,
  progression: Maybe<&2, M7Persistent.PersistentState>) -> FullSnapshotResult:
  match valid world progression:
    case True{} Save.SnapshotReady{snapshot} Some{persistent}:
      FullSnapshotReady{FullSnapshot{snapshot, persistent}}
    case _ _ _: FullSnapshotRejected{}

def combine(world: Save.SnapshotResult,
  progression: Maybe<&2, M7Persistent.PersistentState>) -> FullSnapshotResult:
  match world progression:
    case Save.SnapshotReady{+snapshot} Some{+persistent}:
      combined(Bool.and(Nat.is_eq(snapshot_identity(snapshot),
        progression_identity(persistent)),
        M7Persistent.state_valid(persistent)), world, progression)
    case _ _: FullSnapshotRejected{}

# M11 post-battle projection keeps stable world and validated M7 player state
# together. The historical M8 save entry remains closed to progression saves.
def project(+session: Session.WorldSession) -> FullSnapshotResult:
  match session:
    case Session.WorldSession{world, Some{progression}}:
      combine(Save.project_world(world), Some{progression})
    case _: FullSnapshotRejected{}

def restore_world(result: Save.RestoreResult,
  progression: M7Persistent.PersistentState) -> FullRestoreResult:
  match result:
    case Save.RestoreRejected{}: FullRestoreRejected{}
    case Save.Restored{Session.WorldSession{world, None{}}}:
      FullRestored{Session.WorldSession{world, Some{progression}}}
    case _: FullRestoreRejected{}

def restore_valid(valid: Bool, catalog: Catalog.Catalog,
  world: Save.Snapshot,
  progression: M7Persistent.PersistentState) -> FullRestoreResult:
  match valid:
    case False{}: FullRestoreRejected{}
    case True{}: restore_world(Save.restore(catalog, world), progression)

# Full restore checks both durable halves before recreating a live world.
def restore(catalog: Catalog.Catalog,
  snapshot: FullSnapshot) -> FullRestoreResult:
  match snapshot:
    case FullSnapshot{+world, +progression}:
      restore_valid(Bool.and(Nat.is_eq(snapshot_identity(world),
        progression_identity(progression)),
        M7Persistent.state_valid(progression)), catalog, world, progression)
