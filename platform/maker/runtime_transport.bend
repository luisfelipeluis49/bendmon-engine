import Base
import ../../engine/content/model.bend as Model
import ../../engine/content/validation.bend as Validation
import ../../engine/content/wire.bend as Wire

# Transport probe only: Content-0 plus bounded numeric control IDs. M8 catalog
# creation and world transitions remain outside this prototype.
type Action is Data:
  MoveNorth{}
  MoveSouth{}
  MoveEast{}
  MoveWest{}
  Interact{}
  Confirm{}
  Cancel{}

type CommandResult is Data:
  CommandsParsed{actions: List<&2, Action>}
  CommandsFailed{reason: String}

type ContentResult is Data:
  ContentAccepted{}
  ContentRejected{reason: String}

def action_name(action: Action) -> String:
  match action:
    case MoveNorth{}: "MOVE_NORTH"
    case MoveSouth{}: "MOVE_SOUTH"
    case MoveEast{}: "MOVE_EAST"
    case MoveWest{}: "MOVE_WEST"
    case Interact{}: "INTERACT"
    case Confirm{}: "CONFIRM"
    case Cancel{}: "CANCEL"

def parse_codes(fuel: Nat, values: List<&2, Maybe<&2, U32>>,
  acc: List<&2, Action>) -> CommandResult:
  match fuel values:
    case 0n Nil{}:
      CommandsParsed{List.reverse(&2, Action, acc)}
    case 0n _ <> _:
      CommandsFailed{"command count exceeds 4096"}
    case 1n+left Nil{}:
      CommandsParsed{List.reverse(&2, Action, acc)}
    case 1n+left None{} <> rest:
      CommandsFailed{"command token is missing"}
    case 1n+left Some{code} <> rest:
      match code:
        case 0: parse_codes(left, rest, MoveNorth{} <> acc)
        case 1: parse_codes(left, rest, MoveSouth{} <> acc)
        case 2: parse_codes(left, rest, MoveEast{} <> acc)
        case 3: parse_codes(left, rest, MoveWest{} <> acc)
        case 4: parse_codes(left, rest, Interact{} <> acc)
        case 5: parse_codes(left, rest, Confirm{} <> acc)
        case 6: parse_codes(left, rest, Cancel{} <> acc)
        case _: CommandsFailed{"command code is outside 0..6"}

def parse_tokens(result: Wire.TokenResult) -> CommandResult:
  match result:
    case Wire.TokenFail{reason}: CommandsFailed{reason}
    case Wire.TokenDone{values}: parse_codes(4096n, values, Nil{})

def parse_commands(line: String) -> CommandResult:
  parse_tokens(Wire.scan(line, Wire.ScanRun{0n, Nil{}, 0, False{}}))

def validate_content_semantic(result: Model.Validation) -> ContentResult:
  match result:
    case Model.Valid{}: ContentAccepted{}
    case Model.Invalid{code, record, item}:
      ContentRejected{"semantic validation failed"}

def validate_content(result: Wire.WireResult) -> ContentResult:
  match result:
    case Wire.WireFail{reason}: ContentRejected{reason}
    case Wire.WireDone{content}:
      validate_content_semantic(Validation.validate(content))

def format_actions(actions: List<&2, Action>) -> String:
  match actions:
    case Nil{}: ""
    case action <> rest:
      action_name(action) ++ "\n" ++ format_actions(rest)

def report(content: ContentResult, parsed: CommandResult) -> IO(Unit):
  match content:
    case ContentRejected{reason}:
      IO.die(Unit, 2, "M10RT CONTENT " ++ reason)
    case ContentAccepted{}:
      match parsed:
        case CommandsFailed{reason}:
          IO.die(Unit, 2, "M10RT COMMANDS " ++ reason)
        case CommandsParsed{+actions}:
          IO.write("M10RT1 ACCEPTED\nACTIONS " ++
            Nat.show(List.length(&2, Action, actions)) ++ "\n" ++
            format_actions(actions))

def parse_frame(lines: List<&2, String>) -> IO(Unit):
  match lines:
    case content_wire <> command_wire <> Nil{}:
      report(validate_content(Wire.parse(content_wire)),
        parse_commands(command_wire))
    case content_wire <> command_wire <> "" <> Nil{}:
      report(validate_content(Wire.parse(content_wire)),
        parse_commands(command_wire))
    case _: IO.die(Unit, 2, "M10RT frame must have content and command rows")

def parse_request(lines: List<&2, String>) -> IO(Unit):
  match lines:
    case "M10RT1" <> rest: parse_frame(rest)
    case _: IO.die(Unit, 2, "M10RT protocol header must be M10RT1")

def finish_read(pair: File & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match pair:
    case Tuple{file, Fail{Tuple{code, message}}}:
      do IO<Unit>:
        File.close(file)
        IO.die(Unit, code, "M10RT read failed")
    case Tuple{file, Done{+text}}:
      do IO<Unit>:
        File.close(file)
        parse_request(String.lines(text))

def read_sized(file: File, ok: Bool) -> IO(Unit):
  match ok:
    case False{}:
      do IO<Unit>:
        File.close(file)
        IO.die(Unit, 2, "M10RT request exceeds 2097152 bytes")
    case True{}:
      do IO<Unit>:
        pair : File & Result<&1, &1, U32 & String, String> <-
          File.read(file, 2097153)
        finish_read(pair)

def finish_size(pair: File & Result<&1, &1, U32 & String, U32>) -> IO(Unit):
  match pair:
    case Tuple{file, Fail{Tuple{code, message}}}:
      do IO<Unit>:
        File.close(file)
        IO.die(Unit, code, "M10RT size failed")
    case Tuple{file, Done{size}}:
      read_sized(file, U32.is_le(size, 2097152))

def open_request(result: Result<&1, &1, U32 & String, File>) -> IO(Unit):
  match result:
    case Fail{Tuple{code, message}}: IO.die(Unit, code, "M10RT open failed")
    case Done{file}:
      do IO<Unit>:
        pair : File & Result<&1, &1, U32 & String, U32> <- File.size(file)
        finish_size(pair)

def accept_args(args: List<String>) -> IO(Unit):
  match args:
    case path <> Nil{}:
      do IO<Unit>:
        result : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
        open_request(result)
    case _: IO.die(Unit, 64, "M10RT usage: runtime_transport <request-file>")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    accept_args(args)
