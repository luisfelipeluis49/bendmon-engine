import Base
import ../../engine/m7/persistent_wire_decode.bend as Decoder
import ../../engine/m7/persistent_wire_encode.bend as Encoder
import ./persistent_wire_encode_test.bend as Fixture

def equal_tokens(left: List<&2, Nat>, right: List<&2, Nat>) -> Bool:
  match left right:
    case Nil{} Nil{}: True{}
    case a <> as_ b <> bs:
      Bool.and(Nat.is_eq(a, b), equal_tokens(as_, bs))
    case _ _: False{}

def encoded(result: Encoder.EncodeResult,
  expected: List<&2, Nat>) -> Bool:
  match result:
    case Encoder.EncodeAccepted{tokens}: equal_tokens(tokens, expected)
    case _: False{}

def decoded(result: Decoder.DecodeResult) -> Bool:
  match result:
    case Decoder.DecodeAccepted{state}:
      encoded(Encoder.encode(state), Fixture.expected())
    case _: False{}

def rejected(result: Decoder.DecodeResult) -> Bool:
  match result:
    case Decoder.DecodeRejected{}: True{}
    case _: False{}

def replace_at(index: Nat, replacement: Nat,
  values: List<&2, Nat>) -> List<&2, Nat>:
  match index values:
    case 0n head <> rest: replacement <> rest
    case 1n+remaining head <> rest:
      head <> replace_at(remaining, replacement, rest)
    case _ Nil{}: []

def main() -> List<Bool>:
  [decoded(Decoder.decode(Fixture.expected())),
    rejected(Decoder.decode([2n, 0n])),
    rejected(Decoder.decode([1n, 1n, 0n])),
    rejected(Decoder.decode([1n, 2n, 0n])),
    rejected(Decoder.decode(replace_at(26n, 46n, Fixture.expected()))),
    rejected(Decoder.decode(replace_at(26n, 48n, Fixture.expected()))),
    rejected(Decoder.decode(replace_at(45n, 9n, Fixture.expected()))),
    rejected(Decoder.decode(replace_at(72n, 2n, Fixture.expected())))]
