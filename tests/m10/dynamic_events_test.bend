import Base
import ../../engine/world/dynamic_events.bend as Dynamic
import ../../engine/world/events.bend as Events
import ../../engine/world/encounters.bend as Encounters
import ../../engine/world/encounter_handoff.bend as Handoff

def good_wire() -> List<&2, U32>:
  [12, 1, 123, 1,
   1, 0, 7,
   0, 0, 7, 9, 1,
   1, 1, 3, 5, 2,
   2, 2, 4, 8, 3,
   3, 3, 6, 4,
   4, 4, 7, 5, 6,
   5, 5,
   6, 5,
   1,
   9, 1, 3, 4, 2, 4]

def accepted(result: Dynamic.DecodeResult) -> Bool:
  match result:
    case Dynamic.DecodeAccepted{Dynamic.DynamicEvents{123,
        [Dynamic.EventsGraph{1n, 0n,
          [Events.Node{0n, Events.SetValue{7n, 9n}, [1n]},
           Events.Node{1n, Events.AddEntity{3n, 5n}, [2n]},
           Events.Node{2n, Events.EmitSignal{4n, 8n}, [3n]},
           Events.Node{3n, Events.Wait{6n}, [4n]},
           Events.Node{4n, Events.Choice{7n}, [5n, 6n]},
           Events.Node{5n, Events.Stop{}, []},
           Events.Node{6n, Events.Stop{}, []}]}],
        [Handoff.EncounterTable{9n,
          [Encounters.EncounterEntry{3n, 4n, 2n, 4n}]}]}}:
      True{}
    case _: False{}

def rejected_result(result: Dynamic.DecodeResult) -> Bool:
  match result:
    case Dynamic.DecodeRejected{reason}: True{}
    case _: False{}

def rejected(tokens: List<&2, U32>) -> Bool:
  rejected_result(Dynamic.decode_tokens(tokens))

def main() -> Bool:
  Bool.and(accepted(Dynamic.decode_tokens(good_wire())),
    Bool.and(rejected([12, 1, 123, 1, 1, 0, 1, 0, 3, 1, 0, 0]),
    Bool.and(rejected([12, 1, 123, 1, 1, 0, 1, 0, 0, 1, 1, 0]),
      Bool.and(rejected([12, 1, 123, 1, 1, 0, 1, 0, 99, 7, 9, 0, 0]),
        Bool.and(rejected([12, 1, 123, 1, 1, 1, 1, 0, 5, 0, 0]),
          rejected([12, 1, 123, 0, 1, 4, 9, 1, 3, 4, 0, 4]))))))

#| True
