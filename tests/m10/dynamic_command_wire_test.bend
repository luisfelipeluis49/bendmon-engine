import Base
import ../../engine/world/geometry.bend as Geometry
import ../../engine/world/playtest_world_command.bend as Commands
import ../../engine/world/playtest_command_wire.bend as Wire

def good_tokens() -> List<&2, U32>:
  [14, 1, 12,
   0, 1, 0, 256, 1, 512, 1, 0,
   1, 2, 9, 1, 12, 0, 20,
   2, 3, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 7, 1, 7, 8,
   8, 9, 0, 9, 10, 0, 10, 11, 11, 12, 0, 1, 7]

def accepted(result: Wire.DecodeResult) -> Bool:
  match result:
    case Wire.DecodeAccepted{[
        Commands.PlayMove{Geometry.Input{Geometry.Coord{False{}, 256},
          Geometry.Coord{True{}, 512}, True{}, False{}}},
        Commands.PlayInteract{9n, Geometry.Coord{True{}, 12},
          Geometry.Coord{False{}, 20}},
        Commands.PlayActivate{3n}, Commands.PlayTraverse{4n},
        Commands.PlayFastTravel{5n}, Commands.PlayContinueEvent{},
        Commands.PlayChooseEvent{True{}},
        Commands.PlayAdvanceDialogue{}, Commands.PlayBattleWait{0n},
        Commands.PlayBattleEscape{0n}, Commands.PlayAdvanceBattle{},
        Commands.PlayBattleMove{0n, 1n, 7n}]}:
      True{}
    case _: False{}

def rejected_result(result: Wire.DecodeResult) -> Bool:
  match result:
    case Wire.DecodeRejected{reason}: True{}
    case _: False{}

def rejected(tokens: List<&2, U32>) -> Bool:
  rejected_result(Wire.decode_tokens(tokens))

def main() -> Bool:
  Bool.and(accepted(Wire.decode_tokens(good_tokens())),
    Bool.and(rejected([14, 2, 0]),
    Bool.and(rejected([14, 1, 4097]),
    Bool.and(rejected([14, 1, 1, 1, 6]),
    Bool.and(rejected([14, 1, 1, 0, 99]),
    Bool.and(rejected([14, 1, 1, 0, 9, 1]),
    Bool.and(rejected([14, 1, 1, 0, 1, 2, 0, 0, 0, 0, 2, 0]),
    Bool.and(rejected([14, 1, 1, 0, 3, 0]),
    Bool.and(rejected([14, 1, 1, 0, 12, 0, 0, 7]),
    Bool.and(rejected([14, 1, 1, 0, 12, 0, 1, 0]),
      rejected([14, 1, 0, 99])))))))))))

#| True

#| True
