import Base
import ../battle/rng.bend as Rng
import ./catalog.bend as Catalog
import ./geometry.bend as Geometry
import ./exploration.bend as Exploration
import ./event_bridge.bend as Bridge
import ./events.bend as Events
import ./world_session.bend as Session

type BootResult is Data:
  Booted{session: Session.WorldSession}
  BootRejected{reason: String}

def opened(result: Exploration.OpenResult) -> BootResult:
  match result:
    case Exploration.OpenRejected{}:
      BootRejected{"entry map, point, RNG, or content identity is invalid"}
    case Exploration.Opened{world}:
      Booted{Session.WorldSession{
        Bridge.State{world, Events.World{Nil{}, Nil{}}, None{}}, None{}}}

# Boot from a validated creator start; Exploration.open rechecks the baked
# surface, exact identity, and nonzero four-word RNG before any session exists.
def boot(catalog: Catalog.Catalog, entry_map: Nat, point: Geometry.Point,
  rng: Rng.RngState, expected_identity: Nat) -> BootResult:
  opened(Exploration.open(catalog, entry_map, point, rng, expected_identity))
