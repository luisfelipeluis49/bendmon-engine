import Base
import ../../build/m8_save_snapshot.bend as LoadedSave
import ../../engine/world/save_boundary.bend as Save

def restored(result: Save.RestoreResult) -> Bool:
  match result:
    case Save.Restored{_}: True{}
    case _: False{}

def report(valid: Bool) -> IO(Unit):
  match valid:
    case True{}: IO.print("M8 save restored")
    case False{}: IO.print("M8 save restore failed")

def main() -> IO(Unit):
  do IO<Unit>:
    valid : Bool = restored(Save.restore(LoadedSave.catalog(),
      LoadedSave.snapshot()))
    report(valid)
