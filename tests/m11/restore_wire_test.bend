import Base
import ../../engine/world/save_wire_decode.bend as Wire
import ../../engine/world/save_boundary.bend as Save
import ../m8/save_boundary_test.bend as Fixture

def valid_row() -> List<&2, U32>:
  [18, 1, 123, 1, 0, 1000, 0, 0, 0, 1000, 1, 24, 98304, 0,
   1, 2, 3, 4, 0, 0]

def restored(result: Save.RestoreResult) -> Bool:
  match result:
    case Save.Restored{session}:
      Fixture.snapshot_ok(Save.project(session))
    case _: False{}

def restore_is_rejected(result: Save.RestoreResult) -> Bool:
  match result:
    case Save.RestoreRejected{}: True{}
    case _: False{}

def accepted(result: Wire.DecodeResult) -> Bool:
  match result:
    case Wire.DecodeAccepted{snapshot}:
      restored(Save.restore(Fixture.catalog(), snapshot))
    case _: False{}

def restore_rejected(result: Wire.DecodeResult) -> Bool:
  match result:
    case Wire.DecodeRejected{}: False{}
    case Wire.DecodeAccepted{snapshot}:
      restore_is_rejected(Save.restore(Fixture.catalog(), snapshot))

def rejected(result: Wire.DecodeResult) -> Bool:
  match result:
    case Wire.DecodeRejected{}: True{}
    case _: False{}

def main() -> List<&2, Bool>:
  [accepted(Wire.decode_tokens(valid_row())),
   restore_rejected(Wire.decode_tokens([18, 1, 999, 1, 0, 1000, 0, 0, 0, 1000,
     1, 24, 98304, 0, 1, 2, 3, 4, 0, 0])),
   rejected(Wire.decode_tokens([18, 1, 123, 1, 1, 0, 0, 0, 0, 1000,
     1, 24, 98304, 0, 1, 2, 3, 4, 0, 0])),
   rejected(Wire.decode_tokens([18, 1, 123, 1, 0, 1000, 0, 0, 0, 1000,
     1, 24, 98304, 0, 1, 2, 3, 4, 0, 0, 0]))]
