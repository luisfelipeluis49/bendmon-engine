import Base
import ../../../platform/feasibility/presentation/main.bend as Presentation

def reject(out_dir: String) -> IO(Unit):
  do IO<Unit>:
    _ : String <- IO.try(String,
      Presentation.Artifact.emit(out_dir, 42, 31, 2, 1, 523, 5906))
    IO.print("mismatched state tag was accepted")

def accept_args(args: List<String>) -> IO(Unit):
  match args:
    case Con{out_dir, Nil{}}:
      reject(out_dir)
    case _:
      IO.die(Unit, 64, "usage: mismatched_tag <existing-output-directory>")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    accept_args(args)
