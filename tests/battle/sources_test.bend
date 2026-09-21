import Base
import ../../engine/battle/model.bend as Model
import ../../engine/battle/combat_math.bend as Math
import ../../engine/battle/sources.bend as Sources

def source(deadline: U32, reserved: Bool) -> Sources.MoveSource:
  Sources.MoveSource{Model.ActorId{0n}, Math.MoveId{7n}, deadline, reserved}

def request() -> Sources.SourceRequest:
  Sources.SourceRequest{Model.ActorId{0n}, Math.MoveId{7n}}

def reserved_code(result: Sources.ReserveResult) -> Nat:
  match result:
    case Sources.SourcesReserved{
        Sources.MoveSource{actor, move, 0, True{}} <> Nil{}}:
      1n
    case _:
      0n

def rejected_code(result: Sources.ReserveResult) -> Nat:
  match result:
    case Sources.SourcesRejected{
        Sources.MoveSource{actor, move, 0, False{}} <> Nil{}}:
      1n
    case _:
      0n

def charged_code(result: Sources.ChargeResult) -> Nat:
  match result:
    case Sources.SourceCharged{
        Sources.MoveSource{actor, move, 160, False{}} <> Nil{}}:
      1n
    case _:
      0n

def overflow_code(result: Sources.ChargeResult) -> Nat:
  match result:
    case Sources.SourceChargeRejected{
        Sources.MoveSource{actor, move, 0, True{}} <> Nil{}}:
      1n
    case _:
      0n

def main() -> List<&2, Nat>:
  +sources = {source(0, False{}) <> Nil{} : List<&2, Sources.MoveSource>}
  +requests = {request() <> Nil{} : List<&2, Sources.SourceRequest>}
  +duplicates = {request() <> request() <> Nil{}
    : List<&2, Sources.SourceRequest>}
  [reserved_code(Sources.reserve_batch(0, requests, sources)),
   rejected_code(Sources.reserve_batch(0, duplicates, sources)),
   charged_code(Sources.charge(100, 60, Model.ActorId{0n}, Math.MoveId{7n},
     [source(0, True{})])),
   overflow_code(Sources.charge(216000, 60, Model.ActorId{0n}, Math.MoveId{7n},
     [source(0, True{})]))]

#| [1, 1, 1, 1]
