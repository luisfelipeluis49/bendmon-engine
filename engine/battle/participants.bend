import Base
import ./model.bend as Model

def same_side(left: Model.Side, right: Model.Side) -> Bool:
  match left right:
    case Model.Player{} Model.Player{}:
      True{}
    case Model.Enemy{} Model.Enemy{}:
      True{}
    case _ _:
      False{}

def phase_active(phase: Model.Phase) -> Bool:
  match phase:
    case Model.Benched{}:
      False{}
    case Model.Defeated{}:
      False{}
    case _:
      True{}

def active_on_side(actor: Model.Actor, side: Model.Side) -> Bool:
  match actor:
    case Model.Actor{id, actor_side, 0n, speed, phase, cooldown}:
      False{}
    case Model.Actor{id, actor_side, 1n+hp, speed, phase, cooldown}:
      Bool.and(same_side(actor_side, side), phase_active(phase))

def active_count(+side: Model.Side, actors: List<&2, Model.Actor>) -> Nat:
  match actors:
    case Nil{}:
      0n
    case actor <> rest:
      Nat.add(U32.to_nat(Bool.to_u32(active_on_side(actor, side))),
        active_count(side, rest))

def side_count(+side: Model.Side, actors: List<&2, Model.Actor>) -> Nat:
  match actors:
    case Nil{}:
      0n
    case Model.Actor{id, actor_side, hp, speed, phase, cooldown} <> rest:
      Nat.add(U32.to_nat(Bool.to_u32(same_side(side, actor_side))),
        side_count(side, rest))

def roster_valid(+actors: List<&2, Model.Actor>) -> Bool:
  Bool.and(Bool.and(Nat.is_le(side_count(Model.Player{}, actors), 12n),
      Nat.is_le(side_count(Model.Enemy{}, actors), 12n)),
    Bool.and(Nat.is_le(active_count(Model.Player{}, actors), 4n),
      Nat.is_le(active_count(Model.Enemy{}, actors), 4n)))

def activate_phase(
  eligible: Bool, phase: Model.Phase, +spaces: Nat
) -> Model.Phase:
  match eligible phase spaces:
    case True{} Model.Benched{} 1n+remaining:
      Model.Ready{}
    case _ +other +remaining:
      other

def remaining_spaces(eligible: Bool, phase: Model.Phase, +spaces: Nat) -> Nat:
  match eligible phase spaces:
    case True{} Model.Benched{} 1n+remaining:
      remaining
    case _ other +remaining:
      remaining

def queued_on_side(+side: Model.Side, actor_side: Model.Side, +hp: Nat) -> Bool:
  match hp:
    case 0n:
      False{}
    case 1n+rest:
      same_side(side, actor_side)

def fill_side(
  +side: Model.Side, actors: List<&2, Model.Actor>, +spaces: Nat
) -> List<&2, Model.Actor>:
  match actors:
    case Nil{}:
      Nil{}
    case Model.Actor{id, +actor_side, +hp, speed, +phase, cooldown} <> rest:
      +eligible = queued_on_side(side, actor_side, hp)
      Model.Actor{id, actor_side, hp,
        speed, activate_phase(eligible, phase, spaces), cooldown} <>
        fill_side(side, rest, remaining_spaces(eligible, phase, spaces))

def fill_one_side(
  +side: Model.Side, +actors: List<&2, Model.Actor>
) -> List<&2, Model.Actor>:
  fill_side(side, actors,
    Nat.sub(4n, Nat.min(active_count(side, actors), 4n)))

def fill_reinforcements(
  +actors: List<&2, Model.Actor>
) -> List<&2, Model.Actor>:
  fill_one_side(Model.Enemy{}, fill_one_side(Model.Player{}, actors))

def switch_phase_flags(
  outgoing: Bool, incoming: Bool, phase: Model.Phase
) -> Model.Phase:
  match outgoing incoming:
    case True{} False{}:
      Model.Benched{}
    case False{} True{}:
      Model.Ready{}
    case _ _:
      phase

def switch_phase(
  +id: Model.ActorId, +outgoing: Model.ActorId, +incoming: Model.ActorId,
  phase: Model.Phase
) -> Model.Phase:
  switch_phase_flags(Model.ActorId.eq(id, outgoing),
    Model.ActorId.eq(id, incoming), phase)

def apply_switch(
  +outgoing: Model.ActorId, +incoming: Model.ActorId,
  actors: List<&2, Model.Actor>
) -> List<&2, Model.Actor>:
  match actors:
    case Nil{}:
      Nil{}
    case Model.Actor{+id, side, hp, speed, phase, cooldown} <> rest:
      Model.Actor{id, side, hp, speed,
        switch_phase(id, outgoing, incoming, phase), cooldown} <>
        apply_switch(outgoing, incoming, rest)
