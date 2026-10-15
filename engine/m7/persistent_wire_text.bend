import Base
import ./persistent_state.bend as Persistent
import ./persistent_wire_encode.bend as Wire

def tokens_tail(rows: List<&2, Nat>) -> String:
  match rows:
    case Nil{}: ""
    case value <> rest: "," ++ Nat.show(value) ++ tokens_tail(rest)

def tokens(rows: List<&2, Nat>) -> String:
  match rows:
    case Nil{}: "0"
    case value <> rest: Nat.show(value) ++ tokens_tail(rest)

def encoded(result: Wire.EncodeResult) -> String:
  match result:
    case Wire.EncodeRejected{}: "0"
    case Wire.EncodeAccepted{values}: "1," ++ tokens(values)

# The host receives no durable party row if a transient or invalid M7 state
# cannot pass the stable projection and full numeric-wire validation.
def serialize(value: Maybe<&2, Persistent.PersistentState>) -> String:
  match value:
    case None{}: "0"
    case Some{state}: encoded(Wire.encode(state))
