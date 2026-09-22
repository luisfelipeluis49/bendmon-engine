import Base
import ../../engine/battle/model.bend as Model
import ../../engine/battle/combat_math.bend as Math
import ../../engine/battle/sources.bend as Sources

def source(move: Nat, deadline: U32, reserved: Bool) -> Sources.MoveSource:
  Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{move}, deadline, reserved}

def exact_pair(result: Sources.MixedChargeResult) -> Nat:
  match result:
    case Sources.MixedSourcesCharged{
        Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{7n}, 190, False{}} <>
        Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{8n}, 192, False{}} <>
        Nil{}}:
      1n
    case _:
      0n

def rejection_unchanged(result: Sources.MixedChargeResult) -> Nat:
  match result:
    case Sources.MixedSourcesRejected{
        Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{7n}, 0, True{}} <>
        Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{8n}, 0, True{}} <>
        Nil{}}:
      1n
    case _:
      0n

def unavailable_unchanged(result: Sources.MixedChargeResult) -> Nat:
  match result:
    case Sources.MixedSourcesRejected{
        Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{7n}, 0, True{}} <>
        Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{8n}, 0, False{}} <>
        Nil{}}:
      1n
    case _:
      0n

def ceiling_pair(result: Sources.MixedChargeResult) -> Nat:
  match result:
    case Sources.MixedSourcesCharged{
        Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{7n}, 5400, False{}} <>
        Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{8n}, 90, False{}} <>
        Nil{}}:
      1n
    case _:
      0n

def duplicate_key_unchanged(result: Sources.MixedChargeResult) -> Nat:
  match result:
    case Sources.MixedSourcesRejected{
        Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{7n}, 0, True{}} <>
        Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{7n}, 0, False{}} <>
        Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{8n}, 0, True{}} <>
        Nil{}}:
      1n
    case _:
      0n

def main() -> List<&2, Nat>:
  +owner = {Model.ActorId{0n} : Model.ActorId}
  +a = {Math.MoveId{7n} : Math.MoveId}
  +b = {Math.MoveId{8n} : Math.MoveId}
  [exact_pair(Sources.charge_mixed_pair(100, owner, a, b, 60, 61,
      [source(7n, 0, True{}), source(8n, 0, True{})])),
   rejection_unchanged(Sources.charge_mixed_pair(215950, owner, a, b,
      60, 60, [source(7n, 0, True{}), source(8n, 0, True{})])),
   unavailable_unchanged(Sources.charge_mixed_pair(100, owner, a, b,
      60, 60, [source(7n, 0, True{}), source(8n, 0, False{})])),
   rejection_unchanged(Sources.charge_mixed_pair(100, owner, a, a,
      60, 60, [source(7n, 0, True{}), source(8n, 0, True{})])),
   ceiling_pair(Sources.charge_mixed_pair(0, owner, a, b,
      3600, 60, [source(7n, 0, True{}), source(8n, 0, True{})])),
   duplicate_key_unchanged(Sources.charge_mixed_pair(0, owner, a, b,
      60, 60, [source(7n, 0, True{}), source(7n, 0, False{}),
        source(8n, 0, True{})]))]

#| [1, 1, 1, 1, 1, 1]
