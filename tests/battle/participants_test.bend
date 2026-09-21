import Base
import ../../engine/battle/model.bend as Model
import ../../engine/battle/participants.bend as Participants

def actor(id: Nat, side: Model.Side, hp: Nat, phase: Model.Phase) -> Model.Actor:
  Model.Actor{Model.ActorId{id}, side, hp, 100n, phase, 0}

def fill_code(actors: List<&2, Model.Actor>) -> Nat:
  match actors:
    case Model.Actor{a, s0, hp0, sp0, Model.Ready{}, c0} <>
        Model.Actor{b, s1, hp1, sp1, Model.Defeated{}, c1} <>
        Model.Actor{c, s2, hp2, sp2, Model.Ready{}, c2} <>
        Model.Actor{d, s3, hp3, sp3, Model.Ready{}, c3} <>
        Model.Actor{e, s4, hp4, sp4, Model.Ready{}, c4} <>
        Model.Actor{f, s5, hp5, sp5, Model.Benched{}, c5} <> Nil{}:
      1n
    case _:
      0n

def switch_code(actors: List<&2, Model.Actor>) -> Nat:
  match actors:
    case Model.Actor{a, s0, hp0, sp0, Model.Benched{}, c0} <>
        Model.Actor{b, s1, hp1, sp1, Model.Defeated{}, c1} <>
        Model.Actor{c, s2, hp2, sp2, Model.Ready{}, c2} <> rest:
      1n
    case _:
      0n

def base() -> List<&2, Model.Actor>:
  [actor(0n, Model.Player{}, 10n, Model.Ready{}),
   actor(1n, Model.Player{}, 0n, Model.Defeated{}),
   actor(2n, Model.Player{}, 10n, Model.Benched{}),
   actor(3n, Model.Player{}, 10n, Model.Benched{}),
   actor(4n, Model.Player{}, 10n, Model.Benched{}),
   actor(5n, Model.Player{}, 10n, Model.Benched{})]

def main() -> List<&2, Nat>:
  [fill_code(Participants.fill_reinforcements(base())),
   switch_code(Participants.apply_switch(Model.ActorId{0n},
     Model.ActorId{2n}, base())),
   U32.to_nat(Bool.to_u32(Participants.roster_valid(base())))]

#| [1, 1, 1]
