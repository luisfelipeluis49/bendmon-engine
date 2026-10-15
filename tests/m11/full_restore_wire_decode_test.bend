import Base
import ../../engine/world/full_restore_wire_decode.bend as Wire
import ../../engine/world/save_boundary.bend as Save
import ../../engine/m7/persistent_state.bend as Persistent
import ./persistent_wire_encode_test.bend as ProgressionFixture

def base_row() -> List<&2, U32>:
  [18, 2, 123, 1, 0, 1000, 0, 0, 0, 1000, 1, 24, 98304, 0,
   1, 2, 3, 4, 0, 0, 0, 0]

def accepted_absent(result: Wire.DecodeResult) -> Bool:
  match result:
    case Wire.DecodeAccepted{snapshot, progression}:
      match progression:
        case None{}: Nat.is_eq(Save.snapshot_identity(snapshot), 123n)
        case _: False{}
    case _: False{}

def append(left: List<&2, U32>, right: List<&2, U32>) -> List<&2, U32>:
  match left:
    case Nil{}: right
    case head <> tail: head <> append(tail, right)

def u32_tokens(values: List<&2, Nat>) -> List<&2, U32>:
  match values:
    case Nil{}: []
    case head <> tail: U32.from_nat(head) <> u32_tokens(tail)

def replace_last(values: List<&2, Nat>, value: Nat) -> List<&2, Nat>:
  match values:
    case Nil{}: [value]
    case head <> Nil{}: head <> [value]
    case head <> tail: head <> replace_last(tail, value)

def replace_first(values: List<&2, Nat>, value: Nat) -> List<&2, Nat>:
  match values:
    case Nil{}: []
    case _ <> tail: value <> tail

def present_row() -> List<&2, U32>:
  append([18, 2, 123, 1, 0, 1000, 0, 0, 0, 1000, 1, 24, 98304, 0,
    1, 2, 3, 4, 0, 0, 1, 79],
    u32_tokens(ProgressionFixture.expected()))

def mismatched_identity_row() -> List<&2, U32>:
  append([18, 2, 123, 1, 0, 1000, 0, 0, 0, 1000, 1, 24, 98304, 0,
    1, 2, 3, 4, 0, 0, 1, 79],
    u32_tokens(replace_last(ProgressionFixture.expected(), 124n)))

def wrong_progression_tag_row() -> List<&2, U32>:
  append([18, 2, 123, 1, 0, 1000, 0, 0, 0, 1000, 1, 24, 98304, 0,
    1, 2, 3, 4, 0, 0, 1, 79],
    u32_tokens(replace_first(ProgressionFixture.expected(), 2n)))

def accepted_present(result: Wire.DecodeResult) -> Bool:
  match result:
    case Wire.DecodeAccepted{snapshot, progression}:
      match progression:
        case Some{state}:
          match state:
            case Persistent.PersistentState{economy, roster, owned, ledger,
                ruleset, content_identity}:
              Bool.and(Nat.is_eq(Save.snapshot_identity(snapshot), 123n),
                Nat.is_eq(content_identity, 123n))
        case _: False{}
    case _: False{}

def rejected(result: Wire.DecodeResult) -> Bool:
  match result:
    case Wire.DecodeRejected{}: True{}
    case _: False{}

def main() -> List<Bool>:
  [accepted_absent(Wire.decode_tokens(base_row())),
   accepted_present(Wire.decode_tokens(present_row())),
   rejected(Wire.decode_tokens(mismatched_identity_row())),
   rejected(Wire.decode_tokens(wrong_progression_tag_row())),
   rejected(Wire.decode_tokens([18, 2, 123, 1, 0, 1000, 0, 0, 0, 1000,
     1, 24, 98304, 0, 1, 2, 3, 4, 0, 1])),
   rejected(Wire.decode_tokens([18, 2, 123, 1, 0, 1000, 0, 0, 0, 1000,
     1, 24, 98304, 0, 1, 2, 3, 4, 0, 2, 1, 0])),
   rejected(Wire.decode_tokens([18, 2, 123, 1, 0, 1000, 0, 0, 0, 1000,
     1, 24, 98304, 0, 1, 2, 3, 4, 0, 0, 0, 9])),
   rejected(Wire.decode_tokens([18, 2, 123, 1, 0, 1000, 0, 0, 0, 1000,
     1, 24, 98304, 0, 1, 2, 3, 4, 0, 1, 4097])),
   rejected(Wire.decode_tokens(append([18, 2, 123, 1, 0, 1000, 0, 0, 0,
     1000, 1, 24, 98304, 0, 1, 2, 3, 4, 0, 0, 1, 78],
     u32_tokens(ProgressionFixture.expected())))),
   rejected(Wire.decode_tokens([18, 2, 123, 1, 0, 1000, 0, 0, 0, 1000,
     1, 24, 98304, 0, 1, 2, 3, 4, 4097])),
   rejected(Wire.decode_tokens([18, 2, 123, 1, 0, 1000, 0, 0, 0, 1000,
     1, 24, 98304, 0, 1, 2, 3, 4, 1, 0]))]
