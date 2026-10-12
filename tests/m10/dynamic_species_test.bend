import Base
import ../../engine/m7/dynamic_species.bend as Species

def accepted(result: Species.DecodeResult) -> Bool:
  match result:
    case Species.DecodeAccepted{catalog}: True{}
    case _: False{}

def rejected(result: Species.DecodeResult) -> Bool:
  match result:
    case Species.DecodeRejected{reason}: True{}
    case _: False{}

def main() -> Bool:
  Bool.and(accepted(Species.decode_tokens(
    [13, 2, 17, 1, 2, 1, 50, 51, 52, 53, 54, 55, 500, 100, 0, 1, 2, 0, 1, 1, 2])),
  Bool.and(accepted(Species.decode_tokens(
    [13, 2, 17, 1, 0, 1, 50, 51, 52, 53, 54, 55, 500, 100, 0, 1, 0, 0, 0])),
  Bool.and(rejected(Species.decode_tokens(
    [13, 2, 17, 1, 2, 1, 50, 51, 52, 53, 54, 55, 500, 100, 0, 1, 2, 0, 1, 1, 3])),
  Bool.and(rejected(Species.decode_tokens(
    [13, 2, 17, 1, 2, 1, 0, 51, 52, 53, 54, 55, 500, 100, 0, 1, 2, 0, 1, 1, 2])),
  Bool.and(rejected(Species.decode_tokens(
    [13, 2, 17, 2, 2, 2, 50, 51, 52, 53, 54, 55, 500, 100, 0, 1, 0, 0, 0,
      1, 50, 51, 52, 53, 54, 55, 500, 100, 0, 1, 0, 0, 0])),
    rejected(Species.decode_tokens(
      [13, 2, 17, 1, 2, 1, 50, 51, 52, 53, 54, 55, 500, 100, 0, 1, 2, 0, 1, 1, 2, 99])))))))

#| True
