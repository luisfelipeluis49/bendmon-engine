import Base
import ../../engine/m7/dynamic_battle_boot.bend as Boot
import ../../engine/m7/dynamic_species.bend as Species
import ../../engine/m7/rewards.bend as Rewards
import ../../engine/progression/core.bend as Progression
import ../../engine/battle/rng.bend as Rng

def species(+id: Nat, hp: U32, speed: U32) -> Species.SpeciesProgressionRecord:
  Species.SpeciesProgressionRecord{id,
    Progression.StatBlock{hp, 50, 40, 35, 45, speed}, 500, 100, 0, [],
    Rewards.SpeciesLearning{id, [Rewards.LevelMove{1, 1},
      Rewards.LevelMove{2, 2}, Rewards.LevelMove{3, 3},
      Rewards.LevelMove{4, 4}, Rewards.LevelMove{5, 5}]}}

def fresh_pair(result: Boot.BootResult) -> Bool:
  match result:
    case Boot.BootReady{Boot.BootPair{
        Progression.Individual{1n, 4n, 1, 0, 12, 12, _, [1], [], [], [], [0]},
        Progression.Individual{2n, 9n, 5, 1900, 19, 19, _, [2, 3, 4, 5], [], [], [], [0]},
        77n, 123, Rng.RngState{1, 2, 3, 4}, 60}}: True{}
    case _: False{}

def invalid_level_rejected(result: Boot.BootResult) -> Bool:
  match result:
    case Boot.BootRejected{}: True{}
    case _: False{}

def main() -> Bool:
  fresh_pair(Boot.build(species(4n, 50, 60), 1, species(9n, 45, 55),
    5, 77n, 123, Rng.RngState{1, 2, 3, 4}, 60))

#| True
