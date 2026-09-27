import Base
import ../../engine/world/presentation_cues.bend as Cues
import ../../engine/presentation/wire.bend as Wire
import ../../engine/world/events.bend as Events

def main() -> String:
  committed = Wire.serialize_cues(Cues.ordered_outputs(
    [Events.Asked{8n}, Events.Waited{3n}, Events.Signal{4n}], 42n))
  yielded = Wire.serialize_cues(Cues.yield_cues(Events.Choice{9n}, 7n, 0n))
  committed ++ "\n" ++ yielded
