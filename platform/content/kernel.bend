import Base
import ../../engine/content/model.bend as Model
import ../../engine/content/validation.bend as Validation
import ../../engine/content/wire.bend as Wire

def report_validation(result: Model.Validation) -> IO(Unit):
  match result:
    case Model.Valid{}:
      IO.print("OK")
    case Model.Invalid{code, record, item}:
      IO.die(Unit, 2, "ERR " ++ Nat.show(code) ++ " " ++
        Nat.show(record) ++ " " ++ Nat.show(item))

def report_wire(result: Wire.WireResult) -> IO(Unit):
  match result:
    case Wire.WireFail{reason}:
      IO.die(Unit, 2, "WIRE " ++ reason)
    case Wire.WireDone{content}:
      report_validation(Validation.validate(content))

def validate_text(+text: String) -> IO(Unit):
  report_wire(Wire.parse(text))

def finish_read(
  pair: File & Result<&1, &1, U32 & String, String>
) -> IO(Unit):
  match pair:
    case Tuple{file, Fail{Tuple{code, message}}}:
      do IO<Unit>:
        File.close(file)
        IO.die(Unit, code, "WIRE read")
    case Tuple{file, Done{+text}}:
      do IO<Unit>:
        File.close(file)
        validate_text(text)

def read_sized(file: File, ok: Bool) -> IO(Unit):
  match ok:
    case False{}:
      do IO<Unit>:
        File.close(file)
        IO.die(Unit, 2, "WIRE file-size")
    case True{}:
      do IO<Unit>:
        pair : File & Result<&1, &1, U32 & String, String> <- File.read(file, 2097153)
        finish_read(pair)

def finish_size(pair: File & Result<&1, &1, U32 & String, U32>) -> IO(Unit):
  match pair:
    case Tuple{file, Fail{Tuple{code, message}}}:
      do IO<Unit>:
        File.close(file)
        IO.die(Unit, code, "WIRE size")
    case Tuple{file, Done{+size}}:
      read_sized(file, U32.is_le(size, 2097152))

def open_wire(result: Result<&1, &1, U32 & String, File>) -> IO(Unit):
  match result:
    case Fail{Tuple{code, message}}:
      IO.die(Unit, code, "WIRE open")
    case Done{file}:
      do IO<Unit>:
        pair : File & Result<&1, &1, U32 & String, U32> <- File.size(file)
        finish_size(pair)

def read_wire(path: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
    open_wire(result)

def accept_args(args: List<String>) -> IO(Unit):
  match args:
    case Con{path, Nil{}}:
      read_wire(path)
    case _:
      IO.die(Unit, 64, "WIRE usage")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    accept_args(args)
