import Base
import ../battle/effects.bend as Effects

# Numeric wire data is converted here into the closed M4 effect algebra. No
# authored names or executable values cross this boundary.
type MoveRecord is Data:
  MoveRecord{id: U32, power: U32, always_hit: Bool, accuracy: U32,
    windup: U32, recovery: U32, cooldown: U32,
    components: List<&2, U32>, category: U32, priority_bias: U32,
    effects: Effects.EffectProgram}

type Catalog is Data:
  Catalog{identity: U32, moves: List<&2, MoveRecord>}

type DecodeResult is Data:
  DecodeRejected{reason: String}
  DecodeAccepted{catalog: Catalog}

type Rows is Data:
  RowsBad{}
  RowsDone{moves: List<&2, MoveRecord>, rest: List<&2, U32>}

type Node is Data:
  NodeBad{}
  NodeDone{effect: Effects.Effect, rest: List<&2, U32>, records: U32}

type LeafRows is Data:
  LeafRowsBad{}
  LeafRowsDone{effects: List<&2, Effects.LeafEffect>, rest: List<&2, U32>}

type ProgramRows is Data:
  ProgramBad{}
  ProgramDone{program: Effects.EffectProgram, rest: List<&2, U32>}

def components_valid(+power: U32, +count: U32, +a: U32, +b: U32, +c: U32,
  +d: U32) -> Bool:
  Bool.and(U32.is_le(count, 4),
  Bool.and(U32.is_le(a, 9), Bool.and(U32.is_le(b, 9),
  Bool.and(U32.is_le(c, 9), Bool.and(U32.is_le(d, 9),
  Bool.and(Bool.or(U32.is_eq(power, 0), U32.is_le(1, count)),
  Bool.and(Bool.or(U32.is_le(2, count), U32.is_eq(b, 0)),
  Bool.and(Bool.or(U32.is_le(3, count), U32.is_eq(c, 0)),
    Bool.or(U32.is_eq(count, 4), U32.is_eq(d, 0))))))))))

def hit_valid(+always: U32, +accuracy: U32) -> Bool:
  Bool.or(Bool.and(U32.is_eq(always, 1), U32.is_eq(accuracy, 0)),
    Bool.and(U32.is_eq(always, 0), Bool.and(U32.is_le(500, accuracy),
      U32.is_le(accuracy, 10000))))

def category_valid(category: U32) -> Bool:
  U32.is_le(category, 1)

def timing_valid(+windup: U32, +recovery: U32, +cooldown: U32) -> Bool:
  Bool.and(U32.is_le(windup, 600), Bool.and(U32.is_le(30, recovery),
  Bool.and(U32.is_le(recovery, 600), Bool.and(U32.is_le(60, cooldown),
    U32.is_le(cooldown, 3600)))))

def unique_components(+count: U32, +a: U32, +b: U32, +c: U32, +d: U32) -> Bool:
  Bool.and(Bool.or(U32.is_le(count, 1), Bool.not(U32.is_eq(a, b))),
  Bool.and(Bool.or(U32.is_le(count, 2), Bool.not(U32.is_eq(a, c))),
  Bool.and(Bool.or(U32.is_le(count, 2), Bool.not(U32.is_eq(b, c))),
  Bool.and(Bool.or(U32.is_le(count, 3), Bool.not(U32.is_eq(a, d))),
  Bool.and(Bool.or(U32.is_le(count, 3), Bool.not(U32.is_eq(b, d))),
    Bool.or(U32.is_le(count, 3), Bool.not(U32.is_eq(c, d))))))))

def keep_components(+count: U32, +a: U32, +b: U32, +c: U32, +d: U32) ->
  List<&2, U32>:
  match count:
    case 0: []
    case 1: [a]
    case 2: [a, b]
    case 3: [a, b, c]
    case _: [a, b, c, d]

def target(value: U32) -> Effects.EffectTarget:
  match value:
    case 0: Effects.Source{}
    case _: Effects.Target{}

def status(value: U32) -> Effects.StatusId:
  match value:
    case 0: Effects.Burn{}
    case 1: Effects.Poison{}
    case 2: Effects.Sleep{}
    case 3: Effects.Stun{}
    case _: Effects.Blind{}

def stat(value: U32) -> Effects.StatId:
  match value:
    case 0: Effects.Attack{}
    case 1: Effects.Defense{}
    case 2: Effects.SpecialAttack{}
    case 3: Effects.SpecialDefense{}
    case 4: Effects.Speed{}
    case 5: Effects.Accuracy{}
    case _: Effects.Evasion{}

def damage_category(value: U32) -> Effects.DamageCategory:
  match value:
    case 0: Effects.Physical{}
    case _: Effects.Special{}

def stage_delta(direction: U32, magnitude: U32) -> Effects.StageDelta:
  match direction:
    case 0: Effects.Raise{magnitude}
    case _: Effects.Lower{magnitude}

def leaf_fields_valid(kind: U32, a: U32, b: U32, c: U32) -> Bool:
  match kind:
    case 0: Bool.and(U32.is_le(a, 1), Bool.and(U32.is_le(b, 200), U32.is_le(c, 15)))
    case 1: U32.is_le(a, 9999)
    case 2: Bool.and(U32.is_le(a, 15), Bool.and(U32.is_le(b, 100), U32.is_le(c, 100)))
    case 3: Bool.and(U32.is_le(a, 15), Bool.and(U32.is_le(b, 100), U32.is_le(c, 100)))
    case 4: U32.is_le(a, 4)
    case 5: U32.is_le(a, 4)
    case 6: Bool.and(U32.is_eq(a, 0), Bool.and(U32.is_eq(b, 0), U32.is_eq(c, 0)))
    case _: Bool.and(U32.is_le(a, 6), Bool.and(U32.is_le(b, 1), U32.is_le(c, 3)))

def leaf_valid(+kind: U32, +target_id: U32, +a: U32, +b: U32, +c: U32,
  then_count: U32, else_count: U32) -> Bool:
  Bool.and(U32.is_le(kind, 7), Bool.and(U32.is_le(target_id, 1),
  Bool.and(U32.is_eq(then_count, 0), Bool.and(U32.is_eq(else_count, 0),
    leaf_fields_valid(kind, a, b, c)))))

def leaf_value(kind: U32, target_id: U32, a: U32, b: U32, c: U32) -> Effects.LeafEffect:
  match kind:
    case 0:
      Effects.Damage{U32.to_nat(c), target(target_id), damage_category(a), b}
    case 1: Effects.Heal{target(target_id), a}
    case 2: Effects.Drain{target(target_id), U32.to_nat(a), b, c}
    case 3: Effects.Recoil{target(target_id), U32.to_nat(a), b, c}
    case 4: Effects.ApplyStatus{target(target_id), status(a)}
    case 5: Effects.RemoveStatus{target(target_id), status(a)}
    case 6: Effects.ClearStatuses{target(target_id)}
    case _:
      Effects.ModifyStat{target(target_id), stat(a), stage_delta(b, c)}

def parse_leaf_valid(valid: Bool, kind: U32, target_id: U32, a: U32,
  b: U32, c: U32) -> Maybe<&2, Effects.LeafEffect>:
  match valid:
    case True{}: Some{leaf_value(kind, target_id, a, b, c)}
    case False{}: None{}

def parse_leaf(tokens: List<&2, U32>) -> Maybe<&2, Effects.LeafEffect>:
  match tokens:
    case +kind <> +target_id <> +a <> +b <> +c <> +then_count <> +else_count <> rest:
      parse_leaf_valid(leaf_valid(kind, target_id, a, b, c, then_count, else_count),
        kind, target_id, a, b, c)
    case _: None{}

@unsafe def leaf_rows(count: Nat, tokens: List<&2, U32>,
  acc: List<&2, Effects.LeafEffect>) -> LeafRows:
  match count:
    case 0n: LeafRowsDone{List.reverse(&2, Effects.LeafEffect, acc), tokens}
    case 1n+rest:
      match tokens:
        case +kind <> +target_id <> +a <> +b <> +c <> +then_count <> +else_count <> tail:
          leaf_row_valid(leaf_valid(kind, target_id, a, b, c, then_count, else_count),
            rest, kind, target_id, a, b, c, tail, acc)
        case _: LeafRowsBad{}

@unsafe def leaf_row_valid(valid: Bool, count: Nat, kind: U32, target_id: U32,
  a: U32, b: U32, c: U32, tail: List<&2, U32>,
  acc: List<&2, Effects.LeafEffect>) -> LeafRows:
  match valid:
    case True{}: leaf_rows(count, tail, leaf_value(kind, target_id, a, b, c) <> acc)
    case False{}: LeafRowsBad{}

def predicate_target(valid: Bool, kind: U32, target_id: U32, c: U32) -> Maybe<&2, Effects.Predicate>:
  match valid:
    case False{}: None{}
    case True{}:
      match kind:
        case 0: Some{Effects.HpBelowHalf{target(target_id)}}
        case _: Some{Effects.HasStatus{target(target_id), status(c)}}

def predicate_node(valid: Bool, node_id: U32) -> Maybe<&2, Effects.Predicate>:
  match valid:
    case True{}: Some{Effects.PriorDamagePositive{U32.to_nat(node_id)}}
    case False{}: None{}

def predicate_value(+kind: U32, +predicate_arg: U32, +status_arg: U32) -> Maybe<&2, Effects.Predicate>:
  match kind:
    case 0:
      predicate_target(U32.is_le(predicate_arg, 1), kind, predicate_arg, status_arg)
    case 1:
      predicate_target(Bool.and(U32.is_le(predicate_arg, 1), U32.is_le(status_arg, 4)), kind, predicate_arg, status_arg)
    case 2:
      predicate_node(U32.is_le(predicate_arg, 15), predicate_arg)
    case _: None{}


@unsafe def node(tokens: List<&2, U32>) -> Node:
  match tokens:
    case +node_kind <> +target_id <> +a <> +b <> +c <> +then_count <> +else_count <> tail:
      node_kind_dispatch(node_kind, target_id, a, b, c, then_count, else_count, tail)
    case _: NodeBad{}

@unsafe def node_kind_dispatch(node_kind: U32, target_id: U32, a: U32, b: U32,
  c: U32, then_count: U32, else_count: U32, tail: List<&2, U32>) -> Node:
  match node_kind:
    case 8:
      node_predicate(predicate_value(a, b, c), then_count,
        else_count, tail)
    case _:
      node_leaf(parse_leaf([node_kind, target_id, a, b, c, then_count, else_count]), tail)

def node_leaf(parsed: Maybe<&2, Effects.LeafEffect>, tail: List<&2, U32>) -> Node:
  match parsed:
    case None{}: NodeBad{}
    case Some{effect}: NodeDone{Effects.Leaf{effect}, tail, 1}

@unsafe def node_predicate(parsed: Maybe<&2, Effects.Predicate>, +then_count: U32,
  +else_count: U32, tail: List<&2, U32>) -> Node:
  match parsed:
    case None{}: NodeBad{}
    case Some{predicate}:
      node_then(leaf_rows(U32.to_nat(then_count), tail, Nil{}), predicate,
        then_count, else_count)

@unsafe def node_then(parsed: LeafRows, predicate: Effects.Predicate,
  +then_count: U32, +else_count: U32) -> Node:
  match parsed:
    case LeafRowsBad{}: NodeBad{}
    case LeafRowsDone{then_effects, after_then}:
      node_else(leaf_rows(U32.to_nat(else_count), after_then, Nil{}), predicate,
        then_effects, then_count, else_count)

def node_else(parsed: LeafRows, predicate: Effects.Predicate,
  then_effects: List<&2, Effects.LeafEffect>, then_count: U32,
  else_count: U32) -> Node:
  match parsed:
    case LeafRowsBad{}: NodeBad{}
    case LeafRowsDone{else_effects, rest}:
      NodeDone{Effects.Conditional{predicate, then_effects, else_effects},
        rest, U32.add(1, U32.add(then_count, else_count))}

@unsafe def program_rows(count: Nat, tokens: List<&2, U32>,
  acc: List<&2, Effects.Effect>) -> ProgramRows:
  match count:
    case 0n: ProgramDone{Effects.EffectProgram{List.reverse(&2, Effects.Effect, acc)}, tokens}
    case 1n+rest:
      program_node(node(tokens), count, acc)

@unsafe def program_node(parsed: Node, +count: Nat,
  acc: List<&2, Effects.Effect>) -> ProgramRows:
  match parsed:
    case NodeBad{}: ProgramBad{}
    case NodeDone{effect, tail, +records}:
      program_fit(node_records_fit(U32.to_nat(records), count), records,
        count, tail, effect, acc)

@unsafe def program_fit(fits: Bool, records: U32, count: Nat,
  tail: List<&2, U32>, effect: Effects.Effect,
  acc: List<&2, Effects.Effect>) -> ProgramRows:
  match fits:
    case False{}: ProgramBad{}
    case True{}: program_rows(Nat.sub(count, U32.to_nat(records)),
      tail, effect <> acc)

def node_records_fit(records: Nat, count: Nat) -> Bool:
  Nat.is_le(records, count)

@unsafe def rows(count: Nat, +expected: U32, tokens: List<&2, U32>,
  acc: List<&2, MoveRecord>) -> Rows:
  match count:
    case 0n: RowsDone{List.reverse(&2, MoveRecord, acc), tokens}
    case 1n+rest:
      match tokens:
        case +id <> +power <> +always <> +accuracy <> +windup <> +recovery <>
             +cooldown <> +component_count <> +a <> +b <> +c <> +d <>
             +category <> +priority_bias <> +effect_count <> tail:
          row_v3(Bool.and(U32.is_eq(id, expected), Bool.and(U32.is_le(power, 200),
            Bool.and(hit_valid(always, accuracy),
            Bool.and(timing_valid(windup, recovery, cooldown),
            Bool.and(components_valid(power, component_count, a, b, c, d),
            Bool.and(unique_components(component_count, a, b, c, d),
            Bool.and(category_valid(category), U32.is_le(priority_bias, 16)))))))),
            rest, expected, id, power, always, accuracy, windup, recovery, cooldown,
            component_count, a, b, c, d, category, priority_bias, effect_count, tail, acc)
        case _: RowsBad{}

@unsafe def row_v3(valid: Bool, count: Nat, expected: U32, id: U32, power: U32,
  always: U32, accuracy: U32, windup: U32, recovery: U32, cooldown: U32,
  component_count: U32, a: U32, b: U32, c: U32, d: U32, category: U32,
  priority_bias: U32, +effect_count: U32, tokens: List<&2, U32>,
  acc: List<&2, MoveRecord>) -> Rows:
  match valid:
    case False{}: RowsBad{}
    case True{}:
      row_effect_count(U32.is_le(effect_count, 16), count, expected, id, power,
        always, accuracy, windup, recovery, cooldown, component_count, a, b, c,
        d, category, priority_bias, effect_count, tokens, acc)

@unsafe def row_effect_count(valid: Bool, count: Nat, expected: U32, id: U32,
  power: U32, always: U32, accuracy: U32, windup: U32, recovery: U32,
  cooldown: U32, component_count: U32, a: U32, b: U32, c: U32, d: U32,
  category: U32, priority_bias: U32, +effect_count: U32,
  tokens: List<&2, U32>, acc: List<&2, MoveRecord>) -> Rows:
  match valid:
    case False{}: RowsBad{}
    case True{}:
      row_program(program_rows(U32.to_nat(effect_count), tokens, Nil{}), count,
        expected, id, power, always, accuracy, windup, recovery, cooldown,
        component_count, a, b, c, d, category, priority_bias, effect_count, acc)

@unsafe def row_program(parsed: ProgramRows, count: Nat, expected: U32,
  id: U32, +power: U32, always: U32, accuracy: U32, windup: U32,
  recovery: U32, cooldown: U32, component_count: U32, a: U32, b: U32,
  c: U32, d: U32, category: U32, priority_bias: U32, +effect_count: U32,
  acc: List<&2, MoveRecord>) -> Rows:
  match parsed:
    case ProgramBad{}: RowsBad{}
    case ProgramDone{program, rest}:
      row_program_valid(Bool.or(U32.is_eq(effect_count, 0), U32.is_eq(power, 0)),
        count, expected, id, power, always, accuracy, windup, recovery, cooldown,
        component_count, a, b, c, d, category, priority_bias, effect_count,
        program, rest, acc)

@unsafe def row_program_valid(valid: Bool, count: Nat, expected: U32,
  id: U32, power: U32, always: U32, accuracy: U32, windup: U32,
  recovery: U32, cooldown: U32, component_count: U32, a: U32, b: U32,
  c: U32, d: U32, category: U32, priority_bias: U32, effect_count: U32,
  program: Effects.EffectProgram, rest: List<&2, U32>,
  acc: List<&2, MoveRecord>) -> Rows:
  match valid:
    case False{}: RowsBad{}
    case True{}:
      row_program_value(U32.is_eq(effect_count, 0), count, expected, id, power,
        always, accuracy, windup, recovery, cooldown, component_count, a, b, c,
        d, category, priority_bias, program, rest, acc)

@unsafe def row_program_value(legacy: Bool, count: Nat, expected: U32,
  id: U32, +power: U32, always: U32, accuracy: U32, windup: U32,
  recovery: U32, cooldown: U32, component_count: U32, a: U32, b: U32,
  c: U32, d: U32, category: U32, priority_bias: U32,
  program: Effects.EffectProgram, rest: List<&2, U32>,
  acc: List<&2, MoveRecord>) -> Rows:
  match legacy:
    case True{}:
      row_legacy(U32.is_eq(power, 0), count, expected, id, power, always,
        accuracy, windup, recovery, cooldown, component_count, a, b, c, d,
        category, priority_bias, rest, acc)
    case False{}:
      rows(count, U32.add(expected, 1), rest,
        MoveRecord{id, power, U32.is_eq(always, 1), accuracy, windup,
          recovery, cooldown, keep_components(component_count, a, b, c, d),
          category, priority_bias, program} <> acc)

@unsafe def row_legacy(is_empty: Bool, count: Nat, expected: U32, id: U32,
  +power: U32, always: U32, accuracy: U32, windup: U32, recovery: U32,
  cooldown: U32, component_count: U32, a: U32, b: U32, c: U32, d: U32,
  +category: U32, priority_bias: U32, rest: List<&2, U32>,
  acc: List<&2, MoveRecord>) -> Rows:
  match is_empty:
    case True{}:
      rows(count, U32.add(expected, 1), rest,
        MoveRecord{id, power, U32.is_eq(always, 1), accuracy, windup,
          recovery, cooldown, keep_components(component_count, a, b, c, d),
          category, priority_bias, Effects.EffectProgram{[]}} <> acc)
    case False{}:
      rows(count, U32.add(expected, 1), rest,
        MoveRecord{id, power, U32.is_eq(always, 1), accuracy, windup,
          recovery, cooldown, keep_components(component_count, a, b, c, d),
          category, priority_bias, Effects.EffectProgram{[
            Effects.Leaf{Effects.Damage{0n, Effects.Target{},
              damage_category(category), power}}]}} <> acc)

def decoded(result: Rows, identity: U32) -> DecodeResult:
  match result:
    case RowsBad{}: DecodeRejected{"move-record"}
    case RowsDone{moves, Nil{}}: DecodeAccepted{Catalog{identity, moves}}
    case RowsDone{moves, rest}: DecodeRejected{"move-trailing-data"}

def count_valid(valid: Bool, count: U32, identity: U32,
  rest: List<&2, U32>) -> DecodeResult:
  match valid:
    case True{}: decoded(rows(U32.to_nat(count), 1, rest, Nil{}), identity)
    case False{}: DecodeRejected{"move-count"}

def decode_tokens(tokens: List<&2, U32>) -> DecodeResult:
  match tokens:
    case 15 <> 3 <> identity <> +count <> rest:
      count_valid(U32.is_le(count, 256), count, identity, rest)
    case _: DecodeRejected{"move-wire-header"}
