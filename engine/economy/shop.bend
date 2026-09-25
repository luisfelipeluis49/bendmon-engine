import Base
import ./core.bend as Economy

# The host builds these descriptors from its validated content catalog. Player
# commands select only an item identity and quantity, never a price.
type ItemDescriptor is Data:
  ItemDescriptor{item: Economy.ItemId, buy_price: Nat, unsellable: Bool}

def find_descriptor_step(rest: List<&2, ItemDescriptor>, found: Bool,
  +wanted: Economy.ItemId, item: Economy.ItemId, buy_price: Nat,
  unsellable: Bool) -> Maybe<ItemDescriptor>:
  match rest found:
    case Nil{} True{}: Some{ItemDescriptor{item, buy_price, unsellable}}
    case Nil{} False{}: None{}
    case next <> tail True{}:
      Some{ItemDescriptor{item, buy_price, unsellable}}
    case ItemDescriptor{+next_item, next_price, next_unsellable} <> tail
         False{}:
      find_descriptor_step(tail, Economy.item_eq(next_item, wanted),
        wanted, next_item, next_price, next_unsellable)

def find_descriptor(items: List<&2, ItemDescriptor>,
  +wanted: Economy.ItemId) -> Maybe<ItemDescriptor>:
  match items:
    case Nil{}: None{}
    case ItemDescriptor{+item, buy_price, unsellable} <> rest:
      find_descriptor_step(rest, Economy.item_eq(item, wanted), wanted,
        item, buy_price, unsellable)

def offered(offers: List<&2, Economy.ItemId>, +wanted: Economy.ItemId) -> Bool:
  match offers:
    case Nil{}: False{}
    case item <> rest:
      Bool.or(Economy.item_eq(item, wanted), offered(rest, wanted))

def buy_selected(descriptor: Maybe<ItemDescriptor>, state: Economy.State,
  quantity: Nat) -> Economy.Transaction:
  match descriptor:
    case None{}: Economy.Rejected{state, Economy.ItemNotFound{}}
    case Some{ItemDescriptor{item, buy_price, unsellable}}:
      Economy.buy(state, item, buy_price, quantity)

def purchase_decision(is_offered: Bool, state: Economy.State,
  item: Economy.ItemId, quantity: Nat,
  catalog: List<&2, ItemDescriptor>) -> Economy.Transaction:
  match is_offered:
    case False{}: Economy.Rejected{state, Economy.ItemNotOffered{}}
    case True{}: buy_selected(find_descriptor(catalog, item), state, quantity)

def buy_from_shop(state: Economy.State, +item: Economy.ItemId,
  quantity: Nat, offers: List<&2, Economy.ItemId>,
  catalog: List<&2, ItemDescriptor>) -> Economy.Transaction:
  purchase_decision(offered(offers, item), state, item, quantity, catalog)

def sell_selected(descriptor: Maybe<ItemDescriptor>, state: Economy.State,
  quantity: Nat) -> Economy.Transaction:
  match descriptor:
    case None{}: Economy.Rejected{state, Economy.ItemNotFound{}}
    case Some{ItemDescriptor{item, buy_price, unsellable}}:
      Economy.sell(state, item, buy_price, unsellable, quantity)

def sell_to_shop(state: Economy.State, +item: Economy.ItemId,
  quantity: Nat, catalog: List<&2, ItemDescriptor>) -> Economy.Transaction:
  sell_selected(find_descriptor(catalog, item), state, quantity)
