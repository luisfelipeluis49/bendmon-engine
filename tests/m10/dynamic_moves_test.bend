import Base
import ../../engine/m7/dynamic_moves.bend as Moves
import ../../engine/battle/effects.bend as Effects

def accepted(result: Moves.DecodeResult) -> Bool:
  match result:
    case Moves.DecodeAccepted{catalog}: True{}
    case _: False{}

def rejected(result: Moves.DecodeResult) -> Bool:
  match result:
    case Moves.DecodeRejected{reason}: True{}
    case _: False{}

def legacy_damage(result: Moves.DecodeResult) -> Bool:
  match result:
    case Moves.DecodeAccepted{Moves.Catalog{identity, moves}}:
      match moves:
        case Moves.MoveRecord{id, power, always_hit, accuracy, windup, recovery,
             cooldown, components, category, priority_bias,
             Effects.EffectProgram{[Effects.Leaf{Effects.Damage{0n,
               Effects.Target{}, Effects.Special{}, 75}}]}} <> Nil{}:
          Bool.and(U32.is_eq(power, 75), U32.is_eq(category, 1))
        case _: False{}
    case _: False{}

def status_only(result: Moves.DecodeResult) -> Bool:
  match result:
    case Moves.DecodeAccepted{Moves.Catalog{identity, moves}}:
      match moves:
        case Moves.MoveRecord{id, power, always_hit, accuracy, windup, recovery,
             cooldown, components, category, priority_bias,
             Effects.EffectProgram{[Effects.Leaf{Effects.ApplyStatus{
               Effects.Target{}, Effects.Burn{}}}]}} <> Nil{}:
          Bool.and(U32.is_eq(power, 0), U32.is_eq(priority_bias, 8))
        case _: False{}
    case _: False{}

def conditional_decodes(result: Moves.DecodeResult) -> Bool:
  match result:
    case Moves.DecodeAccepted{Moves.Catalog{identity, moves}}:
      match moves:
        case Moves.MoveRecord{id, power, always_hit, accuracy, windup, recovery,
             cooldown, components, category, priority_bias,
             Effects.EffectProgram{[Effects.Conditional{
               Effects.HpBelowHalf{Effects.Source{}},
               [Effects.Heal{Effects.Target{}, 20}], []}]}} <> Nil{}: True{}
        case _: False{}
    case _: False{}

def main() -> Bool:
  Bool.and(legacy_damage(Moves.decode_tokens([15, 3, 17, 1,
    1, 75, 0, 9000, 1, 30, 60, 1, 2, 0, 0, 0, 1, 8, 0])),
  Bool.and(status_only(Moves.decode_tokens([15, 3, 17, 1,
    1, 0, 1, 0, 0, 30, 60, 0, 0, 0, 0, 0, 0, 8, 1,
    4, 1, 0, 0, 0, 0, 0])),
  Bool.and(conditional_decodes(Moves.decode_tokens([15, 3, 17, 1,
    1, 0, 1, 0, 0, 30, 60, 0, 0, 0, 0, 0, 0, 8, 2,
    8, 0, 0, 0, 0, 1, 0,
    1, 1, 20, 0, 0, 0, 0])),
  Bool.and(rejected(Moves.decode_tokens([15, 3, 17, 1,
    1, 75, 0, 9000, 1, 30, 60, 0, 0, 0, 0, 0, 1, 8, 1,
    4, 1, 0, 0, 0, 0, 0])),
  Bool.and(rejected(Moves.decode_tokens([15, 3, 17, 1,
    1, 0, 1, 0, 0, 30, 60, 0, 0, 0, 0, 0, 0, 8, 1,
    4, 1, 5, 0, 0, 0, 0])),
    rejected(Moves.decode_tokens([15, 3, 17, 1,
      1, 0, 1, 0, 0, 30, 60, 0, 0, 0, 0, 0, 0, 17, 0])))))))

#| True
