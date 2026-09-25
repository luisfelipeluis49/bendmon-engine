import Base
import ./core.bend as Economy
import ./shop.bend as Shop

# A validated account keeps the capacity rows beside the selected runtime
# state, so public transactions can check their relationship every time.
type Account is Data:
  Account{tiers: List<&2, Economy.CapacityTier>, state: Economy.State}

type EconomyResult is Data:
  Committed{account: Account}
  Rejected{account: Account, reason: Economy.Diagnostic}

type Command is Data:
  Buy{item: Economy.ItemId, quantity: Nat,
    catalog: List<&2, Shop.ItemDescriptor>}
  Sell{item: Economy.ItemId, quantity: Nat,
    catalog: List<&2, Shop.ItemDescriptor>}
  Item{item: Economy.ItemId, quantity: Nat, add: Bool,
    failure: Economy.Diagnostic}
  Reward{currency: Nat, item: Economy.ItemId, quantity: Nat}
  TransferToStorage{quantity: Nat}
  TransferToParty{quantity: Nat}
  ChangeTier{index: Nat}
  Capture{}
  ShopBuy{item: Economy.ItemId, quantity: Nat,
    offers: List<&2, Economy.ItemId>, catalog: List<&2, Shop.ItemDescriptor>}
  ShopSell{item: Economy.ItemId, quantity: Nat,
    catalog: List<&2, Shop.ItemDescriptor>}

def execute(command: Command, tiers: List<&2, Economy.CapacityTier>,
  state: Economy.State) -> Economy.Transaction:
  match command:
    case Buy{item, quantity, catalog}:
      Shop.buy_selected(Shop.find_descriptor(catalog, item), state, quantity)
    case Sell{item, quantity, catalog}:
      Shop.sell_selected(Shop.find_descriptor(catalog, item), state, quantity)
    case Item{item, quantity, add, failure}:
      Economy.apply_item(state, item, quantity, add, failure)
    case Reward{currency, item, quantity}:
      Economy.reward(state, currency, item, quantity)
    case TransferToStorage{quantity}:
      Economy.transfer_to_storage(state, quantity)
    case TransferToParty{quantity}:
      Economy.transfer_to_party(state, quantity)
    case ChangeTier{index}: Economy.change_tier(index, tiers, state)
    case Capture{}: Economy.route_captured(state)
    case ShopBuy{item, quantity, offers, catalog}:
      Shop.buy_from_shop(state, item, quantity, offers, catalog)
    case ShopSell{item, quantity, catalog}:
      Shop.sell_to_shop(state, item, quantity, catalog)

def preserve_account(account: Account,
  transaction: Economy.Transaction) -> EconomyResult:
  match account transaction:
    case Account{tiers, old_state} Economy.Accepted{state}:
      Committed{Account{tiers, state}}
    case Account{tiers, old_state} Economy.Rejected{state, reason}:
      Rejected{Account{tiers, state}, reason}

def transact_valid(table_valid: Bool, state_valid: Bool, +account: Account,
  command: Command) -> EconomyResult:
  match table_valid state_valid:
    case False{} _: Rejected{account, Economy.InvalidTierTable{}}
    case True{} False{}: Rejected{account, Economy.InvalidState{}}
    case True{} True{}:
      match account:
        case Account{tiers, +state}:
          preserve_account(account, execute(command, tiers, state))

def transact(+account: Account, command: Command) -> EconomyResult:
  match account:
    case Account{+tiers, +state}:
      transact_valid(Economy.valid_tiers(tiers),
        Economy.state_matches_tiers(state, tiers), account, command)

def buy(+account: Account, item: Economy.ItemId, quantity: Nat,
  catalog: List<&2, Shop.ItemDescriptor>) -> EconomyResult:
  transact(account, Buy{item, quantity, catalog})

def sell(+account: Account, item: Economy.ItemId, quantity: Nat,
  catalog: List<&2, Shop.ItemDescriptor>) -> EconomyResult:
  transact(account, Sell{item, quantity, catalog})

def adjust_item(+account: Account, item: Economy.ItemId, quantity: Nat,
  add: Bool, failure: Economy.Diagnostic) -> EconomyResult:
  transact(account, Item{item, quantity, add, failure})

def reward(+account: Account, currency: Nat, item: Economy.ItemId,
  quantity: Nat) -> EconomyResult:
  transact(account, Reward{currency, item, quantity})

def transfer_to_storage(+account: Account, quantity: Nat) -> EconomyResult:
  transact(account, TransferToStorage{quantity})

def transfer_to_party(+account: Account, quantity: Nat) -> EconomyResult:
  transact(account, TransferToParty{quantity})

def change_tier(+account: Account, index: Nat) -> EconomyResult:
  transact(account, ChangeTier{index})

def route_captured(+account: Account) -> EconomyResult:
  transact(account, Capture{})

def buy_from_shop(+account: Account, item: Economy.ItemId, quantity: Nat,
  offers: List<&2, Economy.ItemId>,
  catalog: List<&2, Shop.ItemDescriptor>) -> EconomyResult:
  transact(account, ShopBuy{item, quantity, offers, catalog})

def sell_to_shop(+account: Account, item: Economy.ItemId, quantity: Nat,
  catalog: List<&2, Shop.ItemDescriptor>) -> EconomyResult:
  transact(account, ShopSell{item, quantity, catalog})
