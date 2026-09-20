import Base
import ../../../platform/feasibility/presentation/main.bend as Presentation

def reject(out_dir: String) -> IO(Unit):
  do IO<Unit>:
    # x=96 is one pixel past the fixed host frame and must be rejected by the
    # foreign boundary even though the value is well-typed as U32.
    _ : String <- IO.try(String,
      Presentation.Artifact.emit(out_dir, 96, 31, 2, 1, 523, 5905))
    IO.print("invalid projection was accepted")

def accept_args(args: List<String>) -> IO(Unit):
  match args:
    case Con{out_dir, Nil{}}:
      reject(out_dir)
    case _:
      IO.die(Unit, 64, "usage: invalid_projection <existing-output-directory>")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    accept_args(args)
