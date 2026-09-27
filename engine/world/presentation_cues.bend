import Base
import ./events.bend as Events

# Presentation occurrence labels are replay metadata, never gameplay clocks.
type OccurrenceId is Data:
  OccurrenceId{accepted_ordinal: Nat, cue_index: Nat}

type CueKind is Data:
  Signal{kind: Nat}
  Waited{ticks: Nat}
  Asked{prompt: Nat}
  Yielded{opcode: Events.Opcode}

type Cue is Data:
  Cue{id: OccurrenceId, kind: CueKind}

def outputs(events: List<&2, Events.OutputEvent>, +ordinal: Nat,
  +index: Nat) -> List<&2, Cue>:
  match events:
    case Nil{}: []
    case Events.Signal{kind} <> rest:
      Cue{OccurrenceId{ordinal, index}, Signal{kind}} <>
        outputs(rest, ordinal, (index + 1n : Nat))
    case Events.Waited{ticks} <> rest:
      Cue{OccurrenceId{ordinal, index}, Waited{ticks}} <>
        outputs(rest, ordinal, (index + 1n : Nat))
    case Events.Asked{prompt} <> rest:
      Cue{OccurrenceId{ordinal, index}, Asked{prompt}} <>
        outputs(rest, ordinal, (index + 1n : Nat))

def reverse_outputs(events: List<&2, Events.OutputEvent>,
  reversed: List<&2, Events.OutputEvent>) -> List<&2, Events.OutputEvent>:
  match events:
    case Nil{}: reversed
    case event <> rest: reverse_outputs(rest, event <> reversed)

def ordered_outputs(events: List<&2, Events.OutputEvent>, ordinal: Nat) ->
  List<&2, Cue>:
  outputs(reverse_outputs(events, []), ordinal, 0n)

def yield_cues(kind: Events.Opcode, +ordinal: Nat, +index: Nat) ->
  List<&2, Cue>:
  [Cue{OccurrenceId{ordinal, index}, Yielded{kind}}]
