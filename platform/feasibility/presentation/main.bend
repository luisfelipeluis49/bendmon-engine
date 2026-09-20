import Base
import ./projection.bend as Scene

def Artifact.emit(
  out_dir: String, x: U32, y: U32, depth: U32, palette: U32, tone_hz: U32,
  state_tag: U32
) -> IO(Result<&1, &1, U32 & String, String>):
  import "./artifact.c"
  import "./artifact.js"

def emit(out_dir: String, p: Scene.Projection) -> IO(Unit):
  Scene.Projection{x, y, depth, palette, tone_hz, state_tag} = p
  do IO<Unit>:
    report : String <- IO.try(String,
      Artifact.emit(out_dir, x, y, depth, palette, tone_hz, state_tag))
    IO.print(report)

def accept_args(args: List<String>) -> IO(Unit):
  match args:
    case Con{out_dir, Nil{}}:
      emit(out_dir, Scene.project(Scene.original_snapshot()))
    case _:
      IO.die(Unit, 64, "usage: presentation <existing-output-directory>")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    accept_args(args)
