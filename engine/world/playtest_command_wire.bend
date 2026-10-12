import Base
import ./geometry.bend as Geometry
import ./playtest_world_command.bend as Commands

type OneRead is Data:
  OneBad{reason: String}
  OneDone{value: Commands.WorldCommand, rest: List<&2, U32>}

type LogRead is Data:
  LogBad{reason: String}
  LogDone{values: List<&2, Commands.WorldCommand>,
    rest: List<&2, U32>}

type DecodeResult is Data:
  DecodeRejected{reason: String}
  DecodeAccepted{commands: List<&2, Commands.WorldCommand>}

def coord_option(ok: Bool, +sign: U32, +magnitude: U32) ->
  Maybe<&2, Geometry.Coord>:
  match ok:
    case True{}: Some{Geometry.Coord{U32.is_eq(sign, 1), magnitude}}
    case False{}: None{}

def coord_read(+sign: U32, +magnitude: U32) -> Maybe<&2, Geometry.Coord>:
  coord_option(Bool.and(U32.is_le(sign, 1),
    Geometry.valid_coord(Geometry.Coord{U32.is_eq(sign, 1), magnitude})),
    sign, magnitude)

def bool_option_after(ok: Bool, value: U32) -> Maybe<&2, Bool>:
  match ok:
    case True{}: Some{U32.is_eq(value, 1)}
    case False{}: None{}

def bool_option(+value: U32) -> Maybe<&2, Bool>:
  bool_option_after(U32.is_le(value, 1), value)

def move_checked(sequence_ok: Bool,
  x_result: Maybe<&2, Geometry.Coord>, z_result: Maybe<&2, Geometry.Coord>,
  analog_result: Maybe<&2, Bool>, sprint_result: Maybe<&2, Bool>,
  rest: List<&2, U32>) -> OneRead:
  match sequence_ok x_result z_result analog_result sprint_result:
    case True{} Some{x} Some{z} Some{a} Some{s}:
      OneDone{Commands.PlayMove{Geometry.Input{x, z, a, s}}, rest}
    case _ _ _ _ _: OneBad{"move-argument"}

def move_read(sequence_ok: Bool, sx: U32, mx: U32, sz: U32, mz: U32,
  analog: U32, sprint: U32, rest: List<&2, U32>) -> OneRead:
  move_checked(sequence_ok, coord_read(sx, mx), coord_read(sz, mz),
    bool_option(analog), bool_option(sprint), rest)

def interact_checked(sequence_ok: Bool, +id: U32,
  x_result: Maybe<&2, Geometry.Coord>, z_result: Maybe<&2, Geometry.Coord>,
  rest: List<&2, U32>) -> OneRead:
  match sequence_ok x_result z_result:
    case True{} Some{x} Some{z}:
      Bool.pick(OneRead, U32.is_le(1, id),
        OneDone{Commands.PlayInteract{U32.to_nat(id), x, z}, rest},
        OneBad{"interaction-id"})
    case _ _ _: OneBad{"interaction-argument"}

def interact_read(sequence_ok: Bool, id: U32, sx: U32, mx: U32,
  sz: U32, mz: U32, rest: List<&2, U32>) -> OneRead:
  interact_checked(sequence_ok, id, coord_read(sx, mx), coord_read(sz, mz), rest)

def activate_read(sequence_ok: Bool, +id: U32,
  rest: List<&2, U32>) -> OneRead:
  Bool.pick(OneRead, Bool.and(sequence_ok, U32.is_le(1, id)),
    OneDone{Commands.PlayActivate{U32.to_nat(id)}, rest},
    OneBad{"trigger-id"})

def traverse_read(sequence_ok: Bool, +id: U32,
  rest: List<&2, U32>) -> OneRead:
  Bool.pick(OneRead, Bool.and(sequence_ok, U32.is_le(1, id)),
    OneDone{Commands.PlayTraverse{U32.to_nat(id)}, rest},
    OneBad{"transition-id"})

def fast_travel_read(sequence_ok: Bool, +id: U32,
  rest: List<&2, U32>) -> OneRead:
  Bool.pick(OneRead, Bool.and(sequence_ok, U32.is_le(1, id)),
    OneDone{Commands.PlayFastTravel{U32.to_nat(id)}, rest},
    OneBad{"transition-id"})

def continue_read(sequence_ok: Bool, rest: List<&2, U32>) -> OneRead:
  match sequence_ok:
    case True{}: OneDone{Commands.PlayContinueEvent{}, rest}
    case False{}: OneBad{"sequence"}

def choose_checked(sequence_ok: Bool, result: Maybe<&2, Bool>,
  rest: List<&2, U32>) -> OneRead:
  match sequence_ok result:
    case True{} Some{yes}:
      OneDone{Commands.PlayChooseEvent{yes}, rest}
    case _ _: OneBad{"choice-argument"}

def choose_read(sequence_ok: Bool, value: U32,
  rest: List<&2, U32>) -> OneRead:
  choose_checked(sequence_ok, bool_option(value), rest)

def continue_dialogue_read(sequence_ok: Bool,
  rest: List<&2, U32>) -> OneRead:
  match sequence_ok:
    case True{}: OneDone{Commands.PlayAdvanceDialogue{}, rest}
    case False{}: OneBad{"sequence"}

def advance_battle_read(sequence_ok: Bool,
  rest: List<&2, U32>) -> OneRead:
  match sequence_ok:
    case True{}: OneDone{Commands.PlayAdvanceBattle{}, rest}
    case False{}: OneBad{"sequence"}

def read_tag(sequence_ok: Bool, tag: U32,
  rest: List<&2, U32>) -> OneRead:
  match tag:
    case 1:
      match rest:
        case sx <> mx <> sz <> mz <> analog <> sprint <> tail:
          move_read(sequence_ok, sx, mx, sz, mz, analog, sprint, tail)
        case _: OneBad{"move-arity"}
    case 2:
      match rest:
        case id <> sx <> mx <> sz <> mz <> tail:
          interact_read(sequence_ok, id, sx, mx, sz, mz, tail)
        case _: OneBad{"interaction-arity"}
    case 3:
      match rest:
        case id <> tail: activate_read(sequence_ok, id, tail)
        case _: OneBad{"activation-arity"}
    case 4:
      match rest:
        case id <> tail: traverse_read(sequence_ok, id, tail)
        case _: OneBad{"traverse-arity"}
    case 5:
      match rest:
        case id <> tail: fast_travel_read(sequence_ok, id, tail)
        case _: OneBad{"fast-travel-arity"}
    case 6: continue_read(sequence_ok, rest)
    case 7:
      match rest:
        case value <> tail: choose_read(sequence_ok, value, tail)
        case _: OneBad{"choice-arity"}
    case 8: continue_dialogue_read(sequence_ok, rest)
    case 9:
      match rest:
        case actor <> tail:
          Bool.pick(OneRead, Bool.and(sequence_ok, U32.is_zero(actor)),
            OneDone{Commands.PlayBattleWait{0n}, tail},
            OneBad{"battle-wait-actor"})
        case _: OneBad{"battle-wait-arity"}
    case 10:
      match rest:
        case actor <> tail:
          Bool.pick(OneRead, Bool.and(sequence_ok, U32.is_zero(actor)),
            OneDone{Commands.PlayBattleEscape{0n}, tail},
            OneBad{"battle-escape-actor"})
        case _: OneBad{"battle-escape-arity"}
    case 11: advance_battle_read(sequence_ok, rest)
    case 12:
      match rest:
        case actor <> target <> +move_id <> tail:
          Bool.pick(OneRead, Bool.and(sequence_ok,
            Bool.and(U32.is_zero(actor),
              Bool.and(U32.is_eq(target, 1), U32.is_le(1, move_id)))),
            OneDone{Commands.PlayBattleMove{0n, 1n,
              U32.to_nat(move_id)}, tail},
            OneBad{"battle-move-argument"})
        case _: OneBad{"battle-move-arity"}
    case _: OneBad{"command-tag"}

def read_one(expected: U32, tokens: List<&2, U32>) -> OneRead:
  match tokens:
    case sequence <> tag <> rest:
      read_tag(U32.is_eq(sequence, expected), tag, rest)
    case _: OneBad{"command-header"}

@unsafe def read_log(count: Nat, +expected: U32,
  +tokens: List<&2, U32>, +acc: List<&2, Commands.WorldCommand>) -> LogRead:
  match count:
    case 0n: LogDone{List.reverse(&2, Commands.WorldCommand, acc), tokens}
    case 1n+remaining:
      one_after(remaining, expected, acc, read_one(expected, tokens))

@unsafe def one_after(remaining: Nat, expected: U32,
  +acc: List<&2, Commands.WorldCommand>, result: OneRead) -> LogRead:
  match result:
    case OneBad{reason}: LogBad{reason}
    case OneDone{command, rest}:
      read_log(remaining, U32.inc(expected), rest, command <> acc)

def finish_log(result: LogRead) -> DecodeResult:
  match result:
    case LogBad{reason}: DecodeRejected{reason}
    case LogDone{commands, Nil{}}: DecodeAccepted{commands}
    case LogDone{commands, rest}: DecodeRejected{"trailing"}

def decode_count(ok: Bool, count: U32, rest: List<&2, U32>) -> DecodeResult:
  match ok:
    case False{}: DecodeRejected{"command-count"}
    case True{}:
      finish_log(read_log(U32.to_nat(count), 0, rest, Nil{}))

def decode_header(tokens: List<&2, U32>) -> DecodeResult:
  match tokens:
    case 14 <> 1 <> +count <> rest:
      decode_count(U32.is_le(count, 4096), count, rest)
    case _: DecodeRejected{"version-or-header"}

def decode_tokens(+tokens: List<&2, U32>) -> DecodeResult:
  Bool.pick(DecodeResult, Nat.is_le(List.length(&2, U32, tokens),
    32771n), decode_header(tokens), DecodeRejected{"token-limit"})
