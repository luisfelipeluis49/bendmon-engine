import Base
import ../../engine/world/dialogue.bend as Dialogue
import ../../engine/world/dialogue_wire.bend as Wire

def wire_tokens() -> List<&2, U32>:
  [16, 1, 88, 1, 1, 1, 4, 77, 105, 114, 97, 4, 79, 105, 32, 127793, 0]

def decoded_result(result: Wire.DecodeResult) -> Bool:
  match result:
    case Wire.DecodeAccepted{88, [Dialogue.Record{1n,
        [Dialogue.Line{speaker, text}]}], []}:
      Bool.and(Nat.is_eq(List.length(&2, U32, speaker), 4n),
        Nat.is_eq(List.length(&2, U32, text), 4n))
    case _: False{}

def decoded() -> Bool:
  decoded_result(Wire.decode_tokens(88, wire_tokens()))

def sample() -> Dialogue.Record:
  Dialogue.Record{4n, [
    Dialogue.Line{[65], [72, 105]},
    Dialogue.Line{[66], [66, 121, 101]}
  ]}

def final_result(result: Dialogue.Action, speaker: List<&2, U32>,
  text: List<&2, U32>) -> Bool:
  match result:
    case Dialogue.Completed{finished}:
      Bool.and(Nat.is_eq(List.length(&2, U32, speaker), 1n),
        Nat.is_eq(List.length(&2, U32, text), 3n))
    case _: False{}

def final_line(cursor: Dialogue.Cursor, speaker: List<&2, U32>,
  text: List<&2, U32>) -> Bool:
  final_result(Dialogue.advance(cursor), speaker, text)

def second_result(result: Dialogue.Action, speaker: List<&2, U32>,
  text: List<&2, U32>) -> Bool:
  match result:
    case Dialogue.Advanced{next_cursor, Dialogue.Line{next_speaker, next_text}}:
      Bool.and(Nat.is_eq(List.length(&2, U32, speaker), 1n),
        Bool.and(Nat.is_eq(List.length(&2, U32, text), 2n),
          final_line(next_cursor, next_speaker, next_text)))
    case _: False{}

def second_line(cursor: Dialogue.Cursor, speaker: List<&2, U32>,
  text: List<&2, U32>) -> Bool:
  second_result(Dialogue.advance(cursor), speaker, text)

def start_result(result: Dialogue.Action) -> Bool:
  match result:
    case Dialogue.Started{cursor, Dialogue.Line{speaker, text}}:
      second_line(cursor, speaker, text)
    case _: False{}

def progression() -> Bool:
  start_result(Dialogue.start(sample()))

def rejected_result(result: Dialogue.Action) -> Bool:
  match result:
    case Dialogue.Rejected{}: True{}
    case _: False{}

def rejected_after_finish() -> Bool:
  rejected_result(Dialogue.advance(Dialogue.Finished{4n}))

def main() -> Bool:
  Bool.and(decoded(), Bool.and(progression(), rejected_after_finish()))

#| True
