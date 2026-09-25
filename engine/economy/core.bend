import Base

# D13/U08 capacity values. Projects may choose at most sixteen monotone rows;
# the engine ceilings and defaults are fixed here.
type Capacity is Data:
  Capacity{party: Nat, moves: Nat, storage: Nat, stack: Nat,
    entries: Nat, currency: Nat}

type CapacityTier is Data:
  CapacityTier{capacity: Capacity}

type ItemId is Data:
  ItemId{value: Nat}

type ItemStack is Data:
  ItemStack{item: ItemId, quantity: Nat}

type State is Data:
  State{capacity: Capacity, tier: Nat, party: Nat, storage: Nat,
    equipped_moves: Nat, currency: Nat, inventory: List<&2, ItemStack>}

type Diagnostic is Data:
  InvalidState{}
  InvalidTierTable{}
  InvalidTierIndex{}
  CapacityOverflow{}
  InvalidQuantity{}
  ItemNotFound{}
  ItemNotOffered{}
  InsufficientCurrency{}
  ItemNotPurchasable{}
  ItemUnsellable{}
  InventoryFull{}
  StackFull{}

type Transaction is Data:
  Accepted{state: State}
  Rejected{state: State, reason: Diagnostic}

def defaults() -> Capacity:
  Capacity{6n, 4n, 1000n, 999n, 512n, 9999999n}

def hard_limits() -> Capacity:
  Capacity{12n, 8n, 10000n, 9999n, 4096n, 999999999n}

def party_cap(value: Capacity) -> Nat:
  match value:
    case Capacity{party, moves, storage, stack, entries, currency}: party

def move_cap(value: Capacity) -> Nat:
  match value:
    case Capacity{party, moves, storage, stack, entries, currency}: moves

def storage_cap(value: Capacity) -> Nat:
  match value:
    case Capacity{party, moves, storage, stack, entries, currency}: storage

def stack_cap(value: Capacity) -> Nat:
  match value:
    case Capacity{party, moves, storage, stack, entries, currency}: stack

def entries_cap(value: Capacity) -> Nat:
  match value:
    case Capacity{party, moves, storage, stack, entries, currency}: entries

def currency_cap(value: Capacity) -> Nat:
  match value:
    case Capacity{party, moves, storage, stack, entries, currency}: currency

def within_hard_limits(value: Capacity) -> Bool:
  match value:
    case Capacity{+party, +moves, +storage, +stack, +entries, +currency}:
      Bool.and(Nat.is_le(1n, party), Bool.and(Nat.is_le(party, 12n),
      Bool.and(Nat.is_le(1n, moves), Bool.and(Nat.is_le(moves, 8n),
      Bool.and(Nat.is_le(1n, storage), Bool.and(Nat.is_le(storage, 10000n),
      Bool.and(Nat.is_le(1n, stack), Bool.and(Nat.is_le(stack, 9999n),
      Bool.and(Nat.is_le(1n, entries), Bool.and(Nat.is_le(entries, 4096n),
      Bool.and(Nat.is_le(1n, currency),
        Nat.is_le(currency, 999999999n))))))))))))

def capacity_le(left: Capacity, right: Capacity) -> Bool:
  match left right:
    case Capacity{ap, am, ast, ak, ae, ac}
         Capacity{bp, bm, bst, bk, be, bc}:
      Bool.and(Nat.is_le(ap, bp), Bool.and(Nat.is_le(am, bm),
      Bool.and(Nat.is_le(ast, bst), Bool.and(Nat.is_le(ak, bk),
      Bool.and(Nat.is_le(ae, be), Nat.is_le(ac, bc))))))

def capacity_eq(+left: Capacity, +right: Capacity) -> Bool:
  Bool.and(capacity_le(left, right), capacity_le(right, left))

def valid_tier_step(previous: Capacity, +current: Capacity) -> Bool:
  Bool.and(within_hard_limits(current), capacity_le(previous, current))

def valid_tiers_from(tiers: List<&2, CapacityTier>, previous: Capacity) -> Bool:
  match tiers:
    case Nil{}: True{}
    case CapacityTier{+capacity} <> rest:
      Bool.and(valid_tier_step(previous, capacity),
        valid_tiers_from(rest, capacity))

def valid_tiers(tiers: List<&2, CapacityTier>) -> Bool:
  match tiers:
    case Nil{}: False{}
    case CapacityTier{+capacity} <> +rest:
      Bool.and(Nat.is_le(Nat.add(1n,
          List.length(&2, CapacityTier, rest)), 16n),
        Bool.and(within_hard_limits(capacity),
          valid_tiers_from(rest, capacity)))

def item_eq(left: ItemId, right: ItemId) -> Bool:
  match left right:
    case ItemId{a} ItemId{b}: Nat.is_eq(a, b)

def inventory_count(items: List<&2, ItemStack>) -> Nat:
  match items:
    case Nil{}: 0n
    case _ <> rest: Nat.add(1n, inventory_count(rest))

def find_quantity_step(rest: List<&2, ItemStack>, found: Bool,
  +wanted: ItemId, item: ItemId, quantity: Nat) -> Maybe<Nat>:
  match rest found:
    case Nil{} True{}: Some{quantity}
    case Nil{} False{}: None{}
    case next <> tail True{}: Some{quantity}
    case ItemStack{+next_item, next_quantity} <> tail False{}:
      find_quantity_step(tail, item_eq(next_item, wanted), wanted, next_item,
        next_quantity)

def find_quantity(items: List<&2, ItemStack>, +wanted: ItemId) -> Maybe<Nat>:
  match items:
    case Nil{}: None{}
    case ItemStack{+item, quantity} <> rest:
      find_quantity_step(rest, item_eq(item, wanted), wanted, item, quantity)

def put_item_step(rest: List<&2, ItemStack>, found: Bool,
  +wanted: ItemId, quantity: Nat, item: ItemId, old_quantity: Nat) ->
  List<&2, ItemStack>:
  match rest found:
    case Nil{} True{}: [ItemStack{item, quantity}]
    case Nil{} False{}: [ItemStack{item, old_quantity}, ItemStack{wanted, quantity}]
    case tail_item <> tail True{}: ItemStack{item, quantity} <> rest
    case ItemStack{+next_item, next_quantity} <> tail False{}:
      ItemStack{item, old_quantity} <> put_item_step(tail,
        item_eq(next_item, wanted), wanted, quantity, next_item, next_quantity)

def put_item(items: List<&2, ItemStack>, +wanted: ItemId,
  quantity: Nat) -> List<&2, ItemStack>:
  match items:
    case Nil{}: [ItemStack{wanted, quantity}]
    case ItemStack{+item, old_quantity} <> rest:
      put_item_step(rest, item_eq(item, wanted), wanted, quantity, item,
        old_quantity)

def remove_item_step(rest: List<&2, ItemStack>, found: Bool,
  +wanted: ItemId, item: ItemId, quantity: Nat) -> List<&2, ItemStack>:
  match rest found:
    case Nil{} True{}: []
    case Nil{} False{}: [ItemStack{item, quantity}]
    case tail_item <> tail True{}: rest
    case ItemStack{+next_item, next_quantity} <> tail False{}:
      ItemStack{item, quantity} <> remove_item_step(tail,
        item_eq(next_item, wanted), wanted, next_item, next_quantity)

def remove_item(items: List<&2, ItemStack>, +wanted: ItemId) ->
  List<&2, ItemStack>:
  match items:
    case Nil{}: []
    case ItemStack{+item, quantity} <> rest:
      remove_item_step(rest, item_eq(item, wanted), wanted, item, quantity)

def adjust_new_result(ok: Bool, wanted: ItemId, delta: Nat,
  items: List<&2, ItemStack>) -> Maybe<List<&2, ItemStack>>:
  match ok:
    case False{}: None{}
    case True{}: Some{put_item(items, wanted, delta)}

def adjust_new(add: Bool, +wanted: ItemId, +delta: Nat,
  +items: List<&2, ItemStack>, +caps: Capacity) -> Maybe<List<&2, ItemStack>>:
  match add:
    case False{}: None{}
    case True{}:
      adjust_new_result(Bool.and(Nat.is_le(1n, delta),
        Bool.and(Nat.is_le(delta, stack_cap(caps)),
          Nat.is_lt(inventory_count(items), entries_cap(caps)))), wanted, delta,
        items)

def adjust_existing_add(ok: Bool, item: ItemId, old_quantity: Nat,
  delta: Nat, items: List<&2, ItemStack>) -> Maybe<List<&2, ItemStack>>:
  match ok:
    case False{}: None{}
    case True{}: Some{put_item(items, item, Nat.add(old_quantity, delta))}

def remove_or_reduce(remove_all: Bool, item: ItemId, old_quantity: Nat,
  delta: Nat, items: List<&2, ItemStack>) -> Maybe<List<&2, ItemStack>>:
  match remove_all:
    case True{}: Some{remove_item(items, item)}
    case False{}: Some{put_item(items, item, Nat.sub(old_quantity, delta))}

def adjust_existing_remove(enough: Bool, item: ItemId, +old_quantity: Nat,
  +delta: Nat, items: List<&2, ItemStack>) -> Maybe<List<&2, ItemStack>>:
  match enough:
    case False{}: None{}
    case True{}:
      choose = Nat.is_eq(delta, old_quantity)
      remove_or_reduce(choose, item, old_quantity, delta, items)

def adjust_existing(add: Bool, item: ItemId, +old_quantity: Nat, +delta: Nat,
  items: List<&2, ItemStack>, caps: Capacity) -> Maybe<List<&2, ItemStack>>:
  match add:
    case True{}: adjust_existing_add(
      Nat.is_le(Nat.add(old_quantity, delta), stack_cap(caps)), item, old_quantity,
      delta, items)
    case False{}: adjust_existing_remove(Nat.is_le(delta, old_quantity), item,
      old_quantity, delta, items)

def adjust_item_found(found: Maybe<Nat>, items: List<&2, ItemStack>,
  wanted: ItemId, delta: Nat, add: Bool, caps: Capacity) ->
  Maybe<List<&2, ItemStack>>:
  match found:
    case None{}:
      adjust_new(add, wanted, delta, items, caps)
    case Some{old_quantity}: adjust_existing(add, wanted, old_quantity,
      delta, items, caps)

def adjust_item(+items: List<&2, ItemStack>, +wanted: ItemId, delta: Nat,
  add: Bool, caps: Capacity) -> Maybe<List<&2, ItemStack>>:
  adjust_item_found(find_quantity(items, wanted), items, wanted, delta, add,
    caps)

def rejected(state: State, reason: Diagnostic) -> Transaction:
  Rejected{state, reason}

def accepted(state: State) -> Transaction:
  Accepted{state}

def stacks_fit(items: List<&2, ItemStack>, +limit: Nat) -> Bool:
  match items:
    case Nil{}: True{}
    case ItemStack{item, +quantity} <> rest:
      Bool.and(Nat.is_le(1n, quantity),
        Bool.and(Nat.is_le(quantity, limit), stacks_fit(rest, limit)))

def item_in_stacks(+wanted: ItemId, items: List<&2, ItemStack>) -> Bool:
  match items:
    case Nil{}: False{}
    case ItemStack{item, quantity} <> rest:
      Bool.or(item_eq(wanted, item), item_in_stacks(wanted, rest))

def stack_ids_unique(items: List<&2, ItemStack>) -> Bool:
  match items:
    case Nil{}: True{}
    case ItemStack{+item, quantity} <> +rest:
      Bool.and(Bool.not(item_in_stacks(item, rest)), stack_ids_unique(rest))

def state_valid(state: State) -> Bool:
  match state:
    case State{+capacity, tier, +party, +storage, +equipped_moves,
        +currency, +inventory}:
      Bool.and(Nat.is_lt(tier, 16n),
      Bool.and(within_hard_limits(capacity),
      Bool.and(Nat.is_le(party, party_cap(capacity)),
      Bool.and(Nat.is_le(storage, storage_cap(capacity)),
      Bool.and(Nat.is_le(equipped_moves, move_cap(capacity)),
      Bool.and(Nat.is_le(currency, currency_cap(capacity)),
      Bool.and(Nat.is_le(inventory_count(inventory), entries_cap(capacity)),
      Bool.and(stacks_fit(inventory, stack_cap(capacity)),
        stack_ids_unique(inventory)))))))))

def tier_capacity_matches(tiers: List<&2, CapacityTier>, position: Nat,
  +expected: Capacity) -> Bool:
  match tiers position:
    case Nil{} _: False{}
    case CapacityTier{capacity} <> rest 0n: capacity_eq(capacity, expected)
    case CapacityTier{capacity} <> rest 1n+p:
      tier_capacity_matches(rest, p, expected)

def state_matches_tiers(+state: State,
  +tiers: List<&2, CapacityTier>) -> Bool:
  match state:
    case State{capacity, tier, party, storage, equipped_moves, currency,
        inventory}:
      Bool.and(valid_tiers(tiers), Bool.and(state_valid(state),
        tier_capacity_matches(tiers, tier, capacity)))

def change_tier_commit(ok: Bool, capacity: Capacity, index: Nat,
  state: State) -> Transaction:
  match ok:
    case False{}: rejected(state, CapacityOverflow{})
    case True{}:
      match state:
        case State{old_capacity, old_tier, party, storage, equipped_moves,
            currency, inventory}:
          accepted(State{capacity, index, party, storage, equipped_moves,
            currency, inventory})

def change_tier_capacity(+capacity: Capacity, index: Nat, state: State) ->
  Transaction:
  match state:
    case State{old_capacity, old_tier, +party, +storage, +equipped_moves,
        +currency, +inventory}:
      change_tier_commit(Bool.and(within_hard_limits(capacity),
        Bool.and(Nat.is_le(party, party_cap(capacity)),
        Bool.and(Nat.is_le(storage, storage_cap(capacity)),
        Bool.and(Nat.is_le(equipped_moves, move_cap(capacity)),
        Bool.and(Nat.is_le(currency, currency_cap(capacity)),
        Bool.and(Nat.is_le(inventory_count(inventory), entries_cap(capacity)),
          stacks_fit(inventory, stack_cap(capacity)))))))), capacity, index,
        state)

def change_tier_at(tiers: List<&2, CapacityTier>, position: Nat,
  +selected: Nat, state: State) -> Transaction:
  match tiers position:
    case Nil{} _: rejected(state, InvalidTierIndex{})
    case CapacityTier{capacity} <> rest 0n:
      change_tier_capacity(capacity, selected, state)
    case CapacityTier{capacity} <> rest 1n+p:
      change_tier_at(rest, p, selected, state)

def change_tier_index(in_range: Bool, +index: Nat,
  tiers: List<&2, CapacityTier>, state: State) -> Transaction:
  match in_range:
    case False{}: rejected(state, InvalidTierIndex{})
    case True{}: change_tier_at(tiers, index, index, state)

def change_tier_valid(valid: Bool, in_range: Bool, +index: Nat,
  tiers: List<&2, CapacityTier>, state: State) -> Transaction:
  match valid:
    case False{}: rejected(state, InvalidTierTable{})
    case True{}: change_tier_index(in_range, index, tiers, state)

def change_tier_state_valid(valid: Bool, +index: Nat,
  +tiers: List<&2, CapacityTier>, state: State) -> Transaction:
  match valid:
    case False{}: rejected(state, InvalidState{})
    case True{}: change_tier_valid(valid_tiers(tiers), Nat.is_lt(index,
      List.length(&2, CapacityTier, tiers)), index, tiers, state)

def change_tier_from_valid_table(valid: Bool, +index: Nat,
  +tiers: List<&2, CapacityTier>, +state: State) -> Transaction:
  match valid:
    case False{}: rejected(state, InvalidTierTable{})
    case True{}:
      change_tier_state_valid(state_matches_tiers(state, tiers), index,
        tiers, state)

def change_tier_from_valid_state(valid: Bool, +index: Nat,
  +tiers: List<&2, CapacityTier>, +state: State) -> Transaction:
  match valid:
    case False{}: rejected(state, InvalidState{})
    case True{}:
      change_tier_from_valid_table(valid_tiers(tiers), index, tiers, state)

def change_tier(+index: Nat, +tiers: List<&2, CapacityTier>, +state: State) ->
  Transaction:
  change_tier_from_valid_state(state_valid(state), index, tiers, state)

def transfer_storage_fit(fits: Bool, capacity: Capacity, tier: Nat,
  party: Nat, storage: Nat, equipped_moves: Nat, currency: Nat,
  inventory: List<&2, ItemStack>, +quantity: Nat, state: State) -> Transaction:
  match fits:
            case False{}: rejected(state, CapacityOverflow{})
            case True{}: accepted(State{capacity, tier, Nat.sub(party, quantity),
              Nat.add(storage, quantity), equipped_moves, currency, inventory})

def transfer_storage_quantity(zero: Bool, state: State, +quantity: Nat) ->
  Transaction:
  match zero:
    case True{}: rejected(state, InvalidQuantity{})
    case False{}:
      match state:
        case State{+capacity, +tier, +party, +storage, +equipped_moves,
            +currency, +inventory}:
          transfer_storage_fit(Bool.and(Nat.is_le(quantity, party),
              Nat.is_le(Nat.add(storage, quantity), storage_cap(capacity))),
              capacity, tier, party, storage, equipped_moves, currency,
              inventory, quantity, state)

def transfer_storage_state_valid(valid: Bool, state: State,
  +quantity: Nat) -> Transaction:
  match valid:
    case False{}: rejected(state, InvalidState{})
    case True{}: transfer_storage_quantity(Nat.is_eq(quantity, 0n), state, quantity)

def transfer_to_storage(+state: State, +quantity: Nat) -> Transaction:
  transfer_storage_state_valid(state_valid(state), state, quantity)

def transfer_party_fit(fits: Bool, capacity: Capacity, tier: Nat,
  party: Nat, storage: Nat, equipped_moves: Nat, currency: Nat,
  inventory: List<&2, ItemStack>, +quantity: Nat, state: State) -> Transaction:
  match fits:
            case False{}: rejected(state, CapacityOverflow{})
            case True{}: accepted(State{capacity, tier, Nat.add(party, quantity),
              Nat.sub(storage, quantity), equipped_moves, currency, inventory})

def transfer_party_quantity(zero: Bool, state: State, +quantity: Nat) ->
  Transaction:
  match zero:
    case True{}: rejected(state, InvalidQuantity{})
    case False{}:
      match state:
        case State{+capacity, +tier, +party, +storage, +equipped_moves,
            +currency, +inventory}:
          transfer_party_fit(Bool.and(Nat.is_le(quantity, storage),
              Nat.is_le(Nat.add(party, quantity), party_cap(capacity))),
              capacity, tier, party, storage, equipped_moves, currency,
              inventory, quantity, state)

def transfer_party_state_valid(valid: Bool, state: State,
  +quantity: Nat) -> Transaction:
  match valid:
    case False{}: rejected(state, InvalidState{})
    case True{}: transfer_party_quantity(Nat.is_eq(quantity, 0n), state, quantity)

def transfer_to_party(+state: State, +quantity: Nat) -> Transaction:
  transfer_party_state_valid(state_valid(state), state, quantity)

def route_capture_capacity(party_fits: Bool, storage_fits: Bool,
  capacity: Capacity, tier: Nat, party: Nat, storage: Nat,
  equipped_moves: Nat, currency: Nat, inventory: List<&2, ItemStack>,
  state: State) -> Transaction:
  match party_fits storage_fits:
    case True{} _:
      accepted(State{capacity, tier, Nat.add(party, 1n), storage,
        equipped_moves, currency, inventory})
    case False{} True{}:
      accepted(State{capacity, tier, party, Nat.add(storage, 1n),
        equipped_moves, currency, inventory})
    case False{} False{}: rejected(state, CapacityOverflow{})

# Route one newly captured individual to party first, then storage.
def route_captured_valid(valid: Bool, state: State) -> Transaction:
  match valid:
    case False{}: rejected(state, InvalidState{})
    case True{}:
      match state:
        case State{+capacity, +tier, +party, +storage, +equipped_moves,
            +currency, +inventory}:
          route_capture_capacity(Nat.is_lt(party, party_cap(capacity)),
            Nat.is_lt(storage, storage_cap(capacity)), capacity, tier, party,
            storage, equipped_moves, currency, inventory, state)

def route_captured(+state: State) -> Transaction:
  route_captured_valid(state_valid(state), state)

def apply_item_adjusted(adjusted: Maybe<List<&2, ItemStack>>, state: State,
  failure: Diagnostic) -> Transaction:
  match adjusted:
    case None{}: rejected(state, failure)
    case Some{next_inventory}:
      match state:
        case State{capacity, tier, party, storage, equipped_moves, currency,
            inventory}:
          accepted(State{capacity, tier, party, storage, equipped_moves,
            currency, next_inventory})

def apply_item_state(state: State, item: ItemId, quantity: Nat, add: Bool,
  failure: Diagnostic) -> Transaction:
  match state:
    case State{+capacity, +tier, +party, +storage, +equipped_moves, +currency,
        +inventory}:
      apply_item_adjusted(adjust_item(inventory, item, quantity, add, capacity),
        state, failure)

def apply_item_quantity(zero: Bool, state: State, item: ItemId, quantity: Nat,
  add: Bool, failure: Diagnostic) -> Transaction:
  match zero:
    case True{}: rejected(state, InvalidQuantity{})
    case False{}: apply_item_state(state, item, quantity, add, failure)

def apply_item_valid(valid: Bool, state: State, item: ItemId,
  +quantity: Nat, add: Bool, failure: Diagnostic) -> Transaction:
  match valid:
    case False{}: rejected(state, InvalidState{})
    case True{}: apply_item_quantity(Nat.is_eq(quantity, 0n), state, item,
      quantity, add, failure)

def apply_item(+state: State, item: ItemId, +quantity: Nat, add: Bool,
  failure: Diagnostic) -> Transaction:
  apply_item_valid(state_valid(state), state, item, quantity, add, failure)

def buy_deduct(state: State, cost: Nat) -> Transaction:
  match state:
    case State{capacity, tier, party, storage, equipped_moves, stock, inventory}:
      accepted(State{capacity, tier, party, storage, equipped_moves,
        Nat.sub(stock, cost), inventory})
def buy_inventory(result: Transaction, cost: Nat) -> Transaction:
  match result:
    case Rejected{state, reason}: rejected(state, reason)
    case Accepted{next_state}: buy_deduct(next_state, cost)
def buy_funds_valid(has_funds: Bool, state: State, item: ItemId,
  quantity: Nat, cost: Nat) -> Transaction:
  match has_funds:
    case False{}: rejected(state, InsufficientCurrency{})
    case True{}: buy_inventory(apply_item(state, item, quantity, True{},
      StackFull{}), cost)
def buy_funds(state: State, item: ItemId, buy_price: Nat,
  +quantity: Nat) -> Transaction:
  match state:
    case State{capacity, tier, party, storage, equipped_moves, +currency,
        inventory}:
      +cost = Nat.mul(buy_price, quantity)
      buy_funds_valid(Nat.is_le(cost, currency), state, item, quantity, cost)
def buy_price_valid(valid: Bool, state: State, item: ItemId,
  buy_price: Nat, quantity: Nat) -> Transaction:
  match valid:
    case False{}: rejected(state, ItemNotPurchasable{})
    case True{}: buy_funds(state, item, buy_price, quantity)
def buy_zero(zero: Bool, state: State, item: ItemId, +buy_price: Nat,
  +quantity: Nat) -> Transaction:
  match zero:
    case True{}: rejected(state, ItemNotPurchasable{})
    case False{}: buy_price_valid(Nat.is_le(buy_price, 1000000n), state,
      item, buy_price, quantity)
def buy_state_valid(valid: Bool, state: State, item: ItemId,
  +buy_price: Nat, +quantity: Nat) -> Transaction:
  match valid:
    case False{}: rejected(state, InvalidState{})
    case True{}:
      buy_zero(Nat.is_eq(buy_price, 0n), state, item, buy_price, quantity)

def buy(+state: State, item: ItemId, +buy_price: Nat, +quantity: Nat) -> Transaction:
  buy_state_valid(state_valid(state), state, item, buy_price, quantity)
def sell_add(state: State, proceeds: Nat) -> Transaction:
  match state:
    case State{+capacity, tier, party, storage, equipped_moves, +currency,
        inventory}:
      accepted(State{capacity, tier, party, storage, equipped_moves,
        Nat.add(currency, proceeds), inventory})
def sell_remove(result: Transaction, proceeds: Nat) -> Transaction:
  match result:
    case Rejected{state, reason}: rejected(state, reason)
    case Accepted{next_state}: sell_add(next_state, proceeds)
def sell_balance_valid(valid: Bool, state: State, item: ItemId,
  quantity: Nat, proceeds: Nat) -> Transaction:
  match valid:
    case False{}: rejected(state, CapacityOverflow{})
    case True{}: sell_remove(apply_item(state, item, quantity, False{},
      ItemNotFound{}), proceeds)
def sell_checked(state: State, item: ItemId, buy_price: Nat,
  +quantity: Nat) -> Transaction:
  match state:
    case State{+capacity, tier, party, storage, equipped_moves, +currency,
        inventory}:
      +proceeds = Nat.mul(Nat.div(buy_price, 2n), quantity)
      available = Nat.sub(currency_cap(capacity),
        Nat.min(currency, currency_cap(capacity)))
      sell_balance_valid(Nat.is_le(proceeds, available), state, item, quantity,
        proceeds)
def sell_price_valid(valid: Bool, state: State, item: ItemId,
  +buy_price: Nat, quantity: Nat) -> Transaction:
  match valid:
    case False{}: rejected(state, ItemUnsellable{})
    case True{}: sell_checked(state, item, buy_price, quantity)
def sell_state_valid(valid: Bool, state: State, item: ItemId,
  +buy_price: Nat, unsellable: Bool, quantity: Nat) -> Transaction:
  match valid:
    case False{}: rejected(state, InvalidState{})
    case True{}:
      match unsellable:
        case True{}: rejected(state, ItemUnsellable{})
        case False{}: sell_price_valid(Nat.is_le(buy_price, 1000000n), state,
          item, buy_price, quantity)

def sell(+state: State, item: ItemId, +buy_price: Nat, unsellable: Bool,
  quantity: Nat) -> Transaction:
  sell_state_valid(state_valid(state), state, item, buy_price, unsellable,
    quantity)
def inventory_of(state: State) -> List<&2, ItemStack>:
  match state:
    case State{capacity, tier, party, storage, equipped_moves, currency,
        inventory}: inventory
def reward_add_currency(state: State, currency_reward: Nat) -> Transaction:
  match state:
    case State{capacity, tier, party, storage, equipped_moves, currency,
        inventory}:
      accepted(State{capacity, tier, party, storage, equipped_moves,
        Nat.add(currency, currency_reward), inventory})
def reward_commit(result: Transaction, currency_reward: Nat) -> Transaction:
  match result:
    case Rejected{state, reason}: rejected(state, reason)
    case Accepted{next_state}: reward_add_currency(next_state, currency_reward)
def reward_item(zero: Nat, state: State, currency_reward: Nat,
  item: ItemId, item_quantity: Nat) -> Transaction:
  match zero:
    case 0n: reward_add_currency(state, currency_reward)
    case 1n+p: reward_commit(apply_item(state, item, item_quantity, True{},
      StackFull{}), currency_reward)
def reward_balance(ok: Bool, state: State, currency_reward: Nat,
  item: ItemId, +item_quantity: Nat) -> Transaction:
  match ok:
    case False{}: rejected(state, CapacityOverflow{})
    case True{}: reward_item(item_quantity, state, currency_reward, item,
      item_quantity)
def reward_state_valid(valid: Bool, state: State, +currency_reward: Nat,
  item: ItemId, item_quantity: Nat) -> Transaction:
  match valid:
    case False{}: rejected(state, InvalidState{})
    case True{}:
      match state:
        case State{+capacity, tier, party, storage, equipped_moves, +currency,
            inventory}:
          reward_balance(Nat.is_le(currency_reward,
            Nat.sub(currency_cap(capacity), currency)), state,
            currency_reward, item, item_quantity)

def reward(+state: State, +currency_reward: Nat, item: ItemId,
  item_quantity: Nat) -> Transaction:
  reward_state_valid(state_valid(state), state, currency_reward, item,
    item_quantity)
