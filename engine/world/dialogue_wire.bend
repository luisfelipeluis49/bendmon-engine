import Base
import ./dialogue.bend as Dialogue

type DecodeResult is Data:
  DecodeAccepted{identity: U32, records: List<&2, Dialogue.Record>,
    associations: List<&2, Association>}
  DecodeRejected{reason: String}

type Association is Data:
  Association{map_id: Nat, npc_id: Nat, dialogue_id: Nat}

type Codes is Data:
  CodesBad{}
  CodesDone{values: List<&2, U32>, rest: List<&2, U32>}

type Lines is Data:
  LinesBad{}
  LinesDone{values: List<&2, Dialogue.Line>, rest: List<&2, U32>}

type Records is Data:
  RecordsBad{}
  RecordsDone{values: List<&2, Dialogue.Record>, rest: List<&2, U32>}

type Associations is Data:
  AssociationsBad{}
  AssociationsDone{values: List<&2, Association>, rest: List<&2, U32>}

def scalar(+value: U32) -> Bool:
  Bool.and(U32.is_le(value, 1114111),
    Bool.not(Bool.and(U32.is_le(55296, value), U32.is_le(value, 57343))))

@unsafe def codes_read(count: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, U32>) -> Codes:
  match count:
    case 0n: CodesDone{List.reverse(&2, U32, acc), tokens}
    case 1n+remaining:
      match tokens:
        case value <> rest:
          codes_checked(scalar(value), remaining, rest, acc, value)
        case _: CodesBad{}

@unsafe def codes_checked(ok: Bool, remaining: Nat,
  +tokens: List<&2, U32>, +acc: List<&2, U32>, value: U32) -> Codes:
  match ok:
    case True{}: codes_read(remaining, tokens, value <> acc)
    case False{}: CodesBad{}

def code_count_valid(+count: U32, +maximum: U32) -> Bool:
  Bool.and(U32.is_le(1, count), U32.is_le(count, maximum))

def text_codes_result(result: Codes, speaker: List<&2, U32>) -> Lines:
  match result:
    case CodesBad{}: LinesBad{}
    case CodesDone{text, tail}:
      LinesDone{[Dialogue.Line{speaker, text}], tail}

def text_codes_read(text_count: U32, speaker: List<&2, U32>,
  +text_tokens: List<&2, U32>) -> Lines:
  text_codes_result(codes_read(U32.to_nat(text_count), text_tokens, Nil{}),
    speaker)

def text_count_checked(ok: Bool, text_count: U32,
  speaker: List<&2, U32>, +text_tokens: List<&2, U32>) -> Lines:
  match ok:
    case False{}: LinesBad{}
    case True{}: text_codes_read(text_count, speaker, text_tokens)

def text_pair(speaker: List<&2, U32>, +rest: List<&2, U32>) -> Lines:
  match rest:
    case text_count <> text_tokens:
      text_count_checked(code_count_valid(text_count, 512), text_count,
        speaker, text_tokens)
    case _: LinesBad{}

def speaker_codes_result(result: Codes) -> Lines:
  match result:
    case CodesBad{}: LinesBad{}
    case CodesDone{speaker, rest}: text_pair(speaker, rest)

def speaker_count_checked(ok: Bool, count: U32,
  +tokens: List<&2, U32>) -> Lines:
  match ok:
    case False{}: LinesBad{}
    case True{}: speaker_codes_result(codes_read(U32.to_nat(count),
      tokens, Nil{}))

def speaker_read(+count: U32, +tokens: List<&2, U32>) -> Lines:
  speaker_count_checked(code_count_valid(count, 128), count, tokens)

@unsafe def lines_read(count: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, Dialogue.Line>) -> Lines:
  match count:
    case 0n: LinesDone{List.reverse(&2, Dialogue.Line, acc), tokens}
    case 1n+remaining:
      match tokens:
        case speaker_count <> rest:
          line_read_result(remaining, acc,
            speaker_read(speaker_count, rest))
        case _: LinesBad{}

@unsafe def line_read_result(remaining: Nat,
  +acc: List<&2, Dialogue.Line>, result: Lines) -> Lines:
  match result:
    case LinesBad{}: LinesBad{}
    case LinesDone{[line], tail}:
      lines_read(remaining, tail, line <> acc)
    case _: LinesBad{}

def line_count_valid(count: U32) -> Bool:
  code_count_valid(count, 64)

@unsafe def records_read(count: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, Dialogue.Record>) -> Records:
  match count:
    case 0n: RecordsDone{List.reverse(&2, Dialogue.Record, acc), tokens}
    case 1n+remaining:
      match tokens:
        case id <> line_count <> rest:
          records_header(remaining, rest, acc, id, line_count)
        case _: RecordsBad{}

@unsafe def records_header(remaining: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, Dialogue.Record>, +id: U32, +line_count: U32) -> Records:
  records_header_valid(Bool.and(U32.is_le(1, id),
    Bool.and(U32.is_le(id, 256), line_count_valid(line_count))),
    remaining, tokens, acc, id, line_count)

@unsafe def records_header_valid(ok: Bool, remaining: Nat,
  +tokens: List<&2, U32>, +acc: List<&2, Dialogue.Record>, id: U32,
  line_count: U32) -> Records:
  match ok:
    case False{}: RecordsBad{}
    case True{}: records_lines_read(remaining, tokens, acc, id, line_count)

@unsafe def records_lines_read(remaining: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, Dialogue.Record>, id: U32, line_count: U32) -> Records:
  records_lines_result(remaining, acc, id,
    lines_read(U32.to_nat(line_count), tokens, Nil{}))

@unsafe def records_lines_result(remaining: Nat,
  +acc: List<&2, Dialogue.Record>, id: U32, result: Lines) -> Records:
  match result:
    case LinesBad{}: RecordsBad{}
    case LinesDone{lines, rest}:
      records_read(remaining, rest,
        Dialogue.Record{U32.to_nat(id), lines} <> acc)

# Verify identity at the decode boundary and reject missing or trailing data.
@unsafe def associations_read(count: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, Association>) -> Associations:
  match count:
    case 0n: AssociationsDone{List.reverse(&2, Association, acc), tokens}
    case 1n+remaining:
      match tokens:
        case map_id <> npc_id <> dialogue_id <> rest:
          association_valid(remaining, rest, acc, map_id, npc_id, dialogue_id)
        case _: AssociationsBad{}

@unsafe def association_valid(remaining: Nat, +tokens: List<&2, U32>,
  +acc: List<&2, Association>, +map_id: U32, +npc_id: U32,
  +dialogue_id: U32) -> Associations:
  association_checked(association_ids_valid(map_id, npc_id, dialogue_id),
    remaining, tokens, acc, map_id, npc_id, dialogue_id)

def association_ids_valid(+map_id: U32, +npc_id: U32,
  +dialogue_id: U32) -> Bool:
  Bool.and(U32.is_le(1, map_id), Bool.and(U32.is_le(map_id, 256),
    Bool.and(U32.is_le(1, npc_id), Bool.and(U32.is_le(npc_id, 256),
      Bool.and(U32.is_le(1, dialogue_id), U32.is_le(dialogue_id, 256))))))

@unsafe def association_checked(ok: Bool, remaining: Nat,
  +tokens: List<&2, U32>, +acc: List<&2, Association>, +map_id: U32,
  +npc_id: U32, +dialogue_id: U32) -> Associations:
  match ok:
    case False{}: AssociationsBad{}
    case True{}: associations_read(remaining, tokens,
      Association{U32.to_nat(map_id), U32.to_nat(npc_id),
        U32.to_nat(dialogue_id)} <> acc)

def association_result(identity: U32, records: List<&2, Dialogue.Record>,
  result: Associations) -> DecodeResult:
  match result:
    case AssociationsBad{}: DecodeRejected{"malformed NPC dialogue association"}
    case AssociationsDone{values, Nil{}}:
      DecodeAccepted{identity, records, values}
    case _: DecodeRejected{"trailing dialogue wire tokens"}

def association_count_valid(ok: Bool, identity: U32,
  records: List<&2, Dialogue.Record>, count: U32,
  +tokens: List<&2, U32>) -> DecodeResult:
  match ok:
    case False{}: DecodeRejected{"NPC dialogue association count exceeds bounds"}
    case True{}:
      association_result(identity, records,
        associations_read(U32.to_nat(count), tokens, Nil{}))

def association_count(identity: U32, records: List<&2, Dialogue.Record>,
  +count: U32, +tokens: List<&2, U32>) -> DecodeResult:
  association_count_valid(U32.is_le(count, 4096), identity, records,
    count, tokens)

def association_tail(identity: U32, records: List<&2, Dialogue.Record>,
  +rest: List<&2, U32>) -> DecodeResult:
  match rest:
    case count <> tokens:
      association_count(identity, records, count, tokens)
    case _: DecodeRejected{"missing NPC dialogue association count"}

def records_result(identity: U32, result: Records) -> DecodeResult:
  match result:
    case RecordsBad{}: DecodeRejected{"malformed dialogue records"}
    case RecordsDone{records, rest}: association_tail(identity, records, rest)

def records_count_check(ok: Bool, identity: U32, count: U32,
  +tokens: List<&2, U32>) -> DecodeResult:
  match ok:
    case False{}: DecodeRejected{"dialogue count exceeds 256"}
    case True{}:
      records_result(identity,
        records_read(U32.to_nat(count), tokens, Nil{}))

def identity_check(ok: Bool, identity: U32, +count: U32,
  +tokens: List<&2, U32>) -> DecodeResult:
  match ok:
    case False{}: DecodeRejected{"dialogue identity mismatch"}
    case True{}:
      records_count_check(U32.is_le(count, 256), identity, count, tokens)

def decode_tokens(expected_identity: U32,
  tokens: List<&2, U32>) -> DecodeResult:
  match tokens:
    case 16 <> 1 <> +identity <> +count <> rest:
      identity_check(U32.is_eq(expected_identity, identity), identity,
        count, rest)
    case _: DecodeRejected{"dialogue wire must be M10DIALOGUE v1"}
