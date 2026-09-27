import Base
import ../battle/rng.bend as Rng
import ./catalog.bend as Catalog
import ./encounters.bend as Encounters
import ./geometry.bend as Geometry

type PendingEncounter is Data:
  PendingEncounter{region_id: Nat, encounter_id: Nat}

type State is Data:
  State{map_id: Nat, point: Geometry.Point, meter: Encounters.Meter,
    pending: Maybe<&2, PendingEncounter>, content_identity: Nat}

type OpenResult is Data:
  Opened{state: State}
  OpenRejected{}

type StepResult is Data:
  Moved{state: State}
  EncounterReached{state: State, encounter_id: Nat}
  MoveRejected{state: State}

type SegmentOutcome is Data:
  SegmentProgress{state: State}
  SegmentTriggered{state: State, encounter_id: Nat}
  SegmentInvalid{state: State}

def mode_from_geometry(mode: Geometry.MoveMode) -> Encounters.MovementMode:
  match mode:
    case Geometry.Walk{}: Encounters.Walk{}
    case Geometry.Run{}: Encounters.Run{}
    case Geometry.Sprint{}: Encounters.Sprint{}

def open_region_meter(result: Encounters.MeterResult,
  point: Geometry.Point, map_id: Nat, identity: Nat) -> OpenResult:
  match result:
    case Encounters.MeterReady{meter}:
      Opened{State{map_id, point, meter, None{}, identity}}
    case _: OpenRejected{}

def open_region(found: Maybe<&2, Catalog.EncounterRegion>,
  point: Geometry.Point, rng: Rng.RngState,
  map_id: Nat, identity: Nat) -> OpenResult:
  match found:
    case None{}:
      Opened{State{map_id, point, Encounters.empty(rng), None{}, identity}}
    case Some{Catalog.EncounterRegion{region_id, encounter_id, faces}}:
      open_region_meter(Encounters.enter(Encounters.empty(rng), region_id),
        point, map_id, identity)

def open_position(face: Geometry.FaceChoice,
  regions: List<&2, Catalog.EncounterRegion>, point: Geometry.Point,
  rng: Rng.RngState, map_id: Nat, identity: Nat) -> OpenResult:
  match face:
    case Geometry.FaceRejected{}: OpenRejected{}
    case Geometry.FaceAccepted{index}:
      open_region(Catalog.region_for_face(regions, index), point, rng,
        map_id, identity)

def open_surface(valid: Bool, navigation: Geometry.NavSurface,
  regions: List<&2, Catalog.EncounterRegion>,
  +point: Geometry.Point, rng: Rng.RngState,
  map_id: Nat, identity: Nat) -> OpenResult:
  match valid:
    case False{}: OpenRejected{}
    case True{}:
      open_position(Geometry.face_for_point(navigation, point), regions,
        point, rng, map_id, identity)

def open_map(found: Maybe<&2, Catalog.WorldMap>, point: Geometry.Point,
  rng: Rng.RngState, map_id: Nat, identity: Nat) -> OpenResult:
  match found:
    case None{}: OpenRejected{}
    case Some{Catalog.WorldMap{id, +navigation, regions, npcs,
        triggers, transitions}}:
      open_surface(Geometry.surface_valid(navigation), navigation, regions,
        point, rng, map_id, identity)

def open_valid(valid: Bool, catalog: Catalog.Catalog,
  +map_id: Nat, point: Geometry.Point, rng: Rng.RngState,
  identity: Nat) -> OpenResult:
  match valid catalog:
    case False{} _: OpenRejected{}
    case True{} Catalog.Catalog{ruleset, content_identity, maps, events}:
      open_map(Catalog.map_by_id(maps, map_id), point, rng,
        map_id, identity)

# A world opens only under exact M8 content identity and a valid baked surface.
def open(+catalog: Catalog.Catalog, map_id: Nat, point: Geometry.Point,
  +rng: Rng.RngState, +expected_identity: Nat) -> OpenResult:
  match catalog:
    case Catalog.Catalog{ruleset, identity, maps, events}:
      open_valid(Bool.and(Nat.is_eq(ruleset, 8n),
        Bool.and(Nat.is_eq(identity, expected_identity),
          Rng.valid_state(rng))), catalog, map_id, point, rng,
        expected_identity)

def with_motion(old: State, point: Geometry.Point,
  meter: Encounters.Meter, pending: Maybe<&2, PendingEncounter>) -> State:
  match old:
    case State{map_id, prior, prior_meter, prior_pending, identity}:
      State{map_id, point, meter, pending, identity}

def process_advance(result: Encounters.MeterResult, +old: State,
  point: Geometry.Point, region_id: Nat, +encounter_id: Nat) -> SegmentOutcome:
  match result:
    case Encounters.MeterRejected{meter}: SegmentInvalid{old}
    case Encounters.MeterReady{meter}:
      SegmentProgress{with_motion(old, point, meter, None{})}
    case Encounters.MeterTriggered{region, meter}:
      SegmentTriggered{with_motion(old, point, meter,
        Some{PendingEncounter{region_id, encounter_id}}), encounter_id}

def process_enter(result: Encounters.MeterResult, +old: State,
  point: Geometry.Point, distance: U32, mode: Encounters.MovementMode,
  region_id: Nat, encounter_id: Nat) -> SegmentOutcome:
  match result:
    case Encounters.MeterRejected{meter}: SegmentInvalid{old}
    case Encounters.MeterTriggered{region, meter}: SegmentInvalid{old}
    case Encounters.MeterReady{meter}:
      process_advance(Encounters.advance(meter, U32.to_nat(distance), mode),
        old, point, region_id, encounter_id)

def process_region(found: Maybe<&2, Catalog.EncounterRegion>,
  +old: State, point: Geometry.Point, distance: U32,
  mode: Encounters.MovementMode) -> SegmentOutcome:
  match found old:
    case None{} State{map_id, prior, meter, pending, identity}:
      SegmentProgress{State{map_id, point, Encounters.leave(meter),
        None{}, identity}}
    case Some{Catalog.EncounterRegion{+region_id, encounter_id, faces}}
         State{map_id, prior, +meter, pending, identity}:
      process_enter(Encounters.enter(meter, region_id), old,
        point, distance, mode, region_id, encounter_id)

def process_segment(travel: Geometry.FaceTravel,
  regions: List<&2, Catalog.EncounterRegion>,
  mode: Encounters.MovementMode, old: State) -> SegmentOutcome:
  match travel:
    case Geometry.FaceTravel{face, distance, point}:
      process_region(Catalog.region_for_face(regions, face), old,
        point, distance, mode)

def segment_steps(segments: List<&2, Geometry.FaceTravel>,
  +regions: List<&2, Catalog.EncounterRegion>,
  +mode: Encounters.MovementMode, outcome: SegmentOutcome) -> StepResult:
  match segments outcome:
    case _ SegmentInvalid{state}: MoveRejected{state}
    case _ SegmentTriggered{state, encounter_id}:
      EncounterReached{state, encounter_id}
    case Nil{} SegmentProgress{state}: Moved{state}
    case travel <> rest SegmentProgress{state}:
      segment_steps(rest, regions, mode,
        process_segment(travel, regions, mode, state))

def moved(result: Geometry.Motion, +old: State,
  regions: List<&2, Catalog.EncounterRegion>,
  mode: Encounters.MovementMode) -> StepResult:
  match result:
    case Geometry.Motion{point, traveled, False{}, segments}:
      MoveRejected{old}
    case Geometry.Motion{point, traveled, True{}, segments}:
      segment_steps(segments, regions, mode, SegmentProgress{old})

def move_map(found: Maybe<&2, Catalog.WorldMap>, +old: State,
  +input: Geometry.Input) -> StepResult:
  match found old:
    case None{} _: MoveRejected{old}
    case Some{Catalog.WorldMap{id, navigation, regions, npcs,
        triggers, transitions}}
         State{map_id, point, meter, pending, identity}:
      moved(Geometry.move_tick(navigation, point, input), old,
        regions, mode_from_geometry(Geometry.input_mode(input)))

def move_ready(catalog: Catalog.Catalog, +old: State,
  input: Geometry.Input) -> StepResult:
  match catalog old:
    case Catalog.Catalog{ruleset, identity, maps, events}
         State{map_id, point, meter, None{}, state_identity}:
      move_map(Catalog.map_by_id(maps, map_id), old, input)
    case _ _: MoveRejected{old}

def move_guard(valid: Bool, catalog: Catalog.Catalog,
  +old: State, input: Geometry.Input) -> StepResult:
  match valid:
    case True{}: move_ready(catalog, old, input)
    case False{}: MoveRejected{old}

# Move one logical 60 Hz tick. A collision rejection preserves state and RNG.
def move(+catalog: Catalog.Catalog, +old: State,
  input: Geometry.Input) -> StepResult:
  match catalog old:
    case Catalog.Catalog{ruleset, +identity, maps, events}
         State{map_id, point, meter, pending, state_identity}:
      move_guard(Bool.and(Nat.is_eq(ruleset, 8n),
        Nat.is_eq(identity, state_identity)), catalog, old, input)
