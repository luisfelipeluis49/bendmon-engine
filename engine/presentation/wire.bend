import Base
import ./projection.bend as Projection
import ../world/geometry.bend as Geometry
import ../battle/model.bend as Battle
import ../world/presentation_cues.bend as Cues
import ../world/events.bend as Events

def concat(left: List<&2, Nat>, right: List<&2, Nat>) -> List<&2, Nat>:
  match left:
    case Nil{}: right
    case value <> rest: value <> concat(rest, right)

# Version 1 is a bounded, line-oriented numeric CSV record. Scene fields are
# version, identity, map, position xyz, facing, camera-anchor xyz, NPC count and
# NPC tuples, then battle presence and optional battle fields. It contains no
# renderer handles or authored media bytes; hosts resolve IDs via validated
# content. Coordinates are Q10 sign/magnitude pairs.
def facing_code(facing: Projection.Facing) -> Nat:
  match facing:
    case Projection.North{}: 0n
    case Projection.East{}: 1n
    case Projection.South{}: 2n
    case Projection.West{}: 3n

def sign_code(negative: Bool) -> Nat:
  match negative:
    case False{}: 0n
    case True{}: 1n

def coord_fields(coord: Geometry.Coord) -> List<&2, Nat>:
  match coord:
    case Geometry.Coord{negative, magnitude}:
      [sign_code(negative), U32.to_nat(magnitude)]

def point_fields(point: Geometry.Point) -> List<&2, Nat>:
  match point:
    case Geometry.Point{x, y, z}:
      concat(coord_fields(x), concat(coord_fields(y), coord_fields(z)))

def optional_id_fields(id: Maybe<&2, Nat>) -> List<&2, Nat>:
  match id:
    case None{}: [0n, 0n]
    case Some{value}: [1n, value]

def npc_fields(npcs: List<&2, Projection.VisibleNpc>) ->
  List<&2, Nat>:
  match npcs:
    case Nil{}: []
    case Projection.VisibleNpc{id, point, event_id} <> rest:
      concat([id], concat(point_fields(point), concat(
        optional_id_fields(event_id), npc_fields(rest))))

def side_code(side: Battle.Side) -> Nat:
  match side:
    case Battle.Player{}: 0n
    case Battle.Enemy{}: 1n

def phase_code(phase: Battle.Phase) -> Nat:
  match phase:
    case Battle.Ready{}: 0n
    case Battle.Windup{execution_tick}: 1n
    case Battle.Recovery{ready_tick}: 2n
    case Battle.Benched{}: 3n
    case Battle.Defeated{}: 4n

def status_code(status: Battle.BattleStatus) -> Nat:
  match status:
    case Battle.AwaitingCommands{}: 0n
    case Battle.Advancing{}: 1n
    case Battle.Victory{}: 2n
    case Battle.Defeat{}: 3n
    case Battle.Draw{}: 4n
    case Battle.Timeout{}: 5n
    case Battle.Escaped{}: 6n
    case Battle.SchedulerStalled{}: 7n

def battle_actor_fields(actors: List<&2, Projection.BattleActor>) ->
  List<&2, Nat>:
  match actors:
    case Nil{}: []
    case Projection.BattleActor{Battle.ActorId{value}, side, hp, phase} <>
        rest:
      concat([value, side_code(side), hp, phase_code(phase)],
        battle_actor_fields(rest))

def battle_fields(battle: Maybe<&2, Projection.BattleScene>) ->
  List<&2, Nat>:
  match battle:
    case None{}: [0n]
    case Some{Projection.BattleScene{tick, status, +actors}}:
      concat([1n, U32.to_nat(tick), status_code(status),
        List.length(&2, Projection.BattleActor, actors)],
        battle_actor_fields(actors))

def fields(scene: Projection.Scene) -> List<&2, Nat>:
  match scene:
    case Projection.Scene{Projection.WorldScene{identity, map_id, position,
        elevation, facing, camera_anchor, +visible_npcs, battle}}:
      concat([1n, identity, map_id], concat(point_fields(position),
        concat([facing_code(facing)], concat(point_fields(camera_anchor),
          concat([List.length(&2, Projection.VisibleNpc,
            visible_npcs)], concat(npc_fields(visible_npcs),
            battle_fields(battle)))))))

def csv_tail(values: List<&2, Nat>) -> String:
  match values:
    case Nil{}: ""
    case value <> rest: "," ++ Nat.show(value) ++ csv_tail(rest)

def csv(values: List<&2, Nat>) -> String:
  match values:
    case Nil{}: ""
    case value <> rest: Nat.show(value) ++ csv_tail(rest)

# Serialize one projected scene as a deterministic numeric CSV line.
def serialize(scene: Projection.Scene) -> String:
  csv(fields(scene))

def cue_kind_fields(kind: Cues.CueKind) -> List<&2, Nat>:
  match kind:
    case Cues.Signal{kind}: [0n, kind, 0n]
    case Cues.Waited{ticks}: [1n, ticks, 0n]
    case Cues.Asked{prompt}: [2n, prompt, 0n]
    case Cues.Yielded{opcode}:
      match opcode:
        case Events.Wait{ticks}: [3n, 0n, ticks]
        case Events.Choice{prompt}: [3n, 1n, prompt]
        case _: [3n, 2n, 0n]

def cue_fields(cues: List<&2, Cues.Cue>) -> List<&2, Nat>:
  match cues:
    case Nil{}: []
    case Cues.Cue{Cues.OccurrenceId{ordinal, index}, kind} <> rest:
      concat([ordinal, index], concat(cue_kind_fields(kind),
        cue_fields(rest)))

# Serialize one ordered cue batch as `version,count,(ordinal,index,kind,payload,aux)*`.
def serialize_cues(+cues: List<&2, Cues.Cue>) -> String:
  concat_fields = concat([1n, List.length(&2, Cues.Cue, cues)],
    cue_fields(cues))
  csv(concat_fields)
