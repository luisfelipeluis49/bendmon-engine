import Base
import ../../engine/economy/core.bend as Economy
import ../../engine/economy/shop.bend as Shop

def item(value: Nat) -> Economy.ItemId:
  Economy.ItemId{value}

def capacity_equal(left: Economy.Capacity, right: Economy.Capacity) -> Bool:
  match left right:
    case Economy.Capacity{ap, am, ast, ask, ae, ac}
         Economy.Capacity{bp, bm, bst, bsk, be, bc}:
      Bool.and(Nat.is_eq(ap, bp), Bool.and(Nat.is_eq(am, bm),
      Bool.and(Nat.is_eq(ast, bst), Bool.and(Nat.is_eq(ask, bsk),
      Bool.and(Nat.is_eq(ae, be), Nat.is_eq(ac, bc))))))

def inventory_equal(left: List<&2, Economy.ItemStack>,
  right: List<&2, Economy.ItemStack>) -> Bool:
  match left right:
    case Nil{} Nil{}: True{}
    case Economy.ItemStack{Economy.ItemId{item_a}, quantity_a} <> rest_a
         Economy.ItemStack{Economy.ItemId{item_b}, quantity_b} <> rest_b:
      Bool.and(Nat.is_eq(item_a, item_b), Bool.and(Nat.is_eq(quantity_a,
        quantity_b), inventory_equal(rest_a, rest_b)))
    case _ _: False{}

def initial() -> Economy.State:
  Economy.State{Economy.Capacity{6n, 4n, 100n, 999n, 20n, 9999n},
    0n, 6n, 0n, 4n, 100n, []}

def state_equal(left: Economy.State, right: Economy.State) -> Bool:
  match left right:
    case Economy.State{capacity_a, tier_a, party_a, storage_a, moves_a,
        currency_a, items_a}
         Economy.State{capacity_b, tier_b, party_b, storage_b, moves_b,
        currency_b, items_b}:
      Bool.and(capacity_equal(capacity_a, capacity_b),
      Bool.and(Nat.is_eq(tier_a, tier_b), Bool.and(Nat.is_eq(party_a, party_b),
      Bool.and(Nat.is_eq(storage_a, storage_b),
      Bool.and(Nat.is_eq(moves_a, moves_b),
      Bool.and(Nat.is_eq(currency_a, currency_b),
        inventory_equal(items_a, items_b)))))))

def rejection_unchanged(result: Economy.Transaction,
  expected: Economy.State) -> Bool:
  match result:
    case Economy.Rejected{state, reason}: state_equal(state, expected)
    case _: False{}

def invalid_state_rejected(result: Economy.Transaction,
  expected: Economy.State) -> Bool:
  match result:
    case Economy.Rejected{state, Economy.InvalidState{}}:
      state_equal(state, expected)
    case _: False{}

def accepted_state(result: Economy.Transaction) -> Maybe<Economy.State>:
  match result:
    case Economy.Accepted{state}: Some{state}
    case _: None{}

def buy_exact(result: Economy.Transaction) -> Bool:
  match result:
    case Economy.Accepted{Economy.State{capacity, tier, party, storage,
        equipped_moves, 97n, [Economy.ItemStack{Economy.ItemId{7n}, 3n}]}}:
      True{}
    case _: False{}

def shop_catalog_price(result: Economy.Transaction) -> Bool:
  match result:
    case Economy.Accepted{Economy.State{capacity, tier, party, storage,
        equipped_moves, 85n,
        [Economy.ItemStack{Economy.ItemId{7n}, 3n}]}}: True{}
    case _: False{}

def sell_floor(result: Economy.Transaction) -> Bool:
  match result:
    case Economy.Accepted{Economy.State{capacity, tier, party, storage,
        equipped_moves, 102n, [Economy.ItemStack{Economy.ItemId{7n}, 2n}]}}:
      True{}
    case _: False{}

def stack_exact(result: Economy.Transaction) -> Bool:
  match result:
    case Economy.Accepted{Economy.State{capacity, tier, party, storage,
        equipped_moves, 98n, [Economy.ItemStack{Economy.ItemId{7n}, 2n}]}}:
      True{}
    case _: False{}

def sell_currency_exact(result: Economy.Transaction) -> Bool:
  match result:
    case Economy.Accepted{Economy.State{capacity, tier, party, storage,
        equipped_moves, 100n, [Economy.ItemStack{Economy.ItemId{7n}, 2n}]}}:
      True{}
    case _: False{}

def capture_storage_fallback(result: Economy.Transaction) -> Bool:
  match result:
    case Economy.Accepted{Economy.State{capacity, tier, 6n, 1n,
        equipped_moves, currency, inventory}}: True{}
    case _: False{}

def capture_party_first(result: Economy.Transaction) -> Bool:
  match result:
    case Economy.Accepted{Economy.State{capacity, tier, 7n, 0n,
        equipped_moves, currency, inventory}}: True{}
    case _: False{}

def reward_unchanged(+state: Economy.State) -> Bool:
  rejection_unchanged(Economy.reward(state, 10n, item(7n), 1n), state)

def storage_is_full(+state: Economy.State) -> Bool:
  rejection_unchanged(Economy.transfer_to_storage(state, 1n), state)

def shop_rejection_unchanged(+state: Economy.State) -> Bool:
  rejection_unchanged(Shop.buy_from_shop(state, item(7n), 1n,
    [item(8n)], [Shop.ItemDescriptor{item(7n), 1n, False{}}]), state)

def tier_downgrade_unchanged(+state: Economy.State,
  tiers: List<&2, Economy.CapacityTier>) -> Bool:
  rejection_unchanged(Economy.change_tier(0n, tiers, state), state)

def selected_tier_is_retained(result: Economy.Transaction) -> Bool:
  match result:
    case Economy.Accepted{Economy.State{capacity, 1n, party, storage,
        equipped_moves, currency, inventory}}: True{}
    case _: False{}

def invalid_downgrade_unchanged(+state: Economy.State,
  +tiers: List<&2, Economy.CapacityTier>) -> Bool:
  rejection_unchanged(Economy.change_tier(0n, tiers, state), state)

def unsellable_rejected_unchanged(+state: Economy.State) -> Bool:
  rejection_unchanged(Economy.sell(state, item(7n), 5n, True{}, 1n), state)

def main() -> List<Bool>:
  [buy_exact(Economy.buy(initial(), item(7n), 1n, 3n)),
   sell_floor(Economy.sell(Economy.State{
     Economy.Capacity{6n, 4n, 100n, 999n, 20n, 9999n}, 0n, 6n, 0n, 4n,
     100n, [Economy.ItemStack{item(7n), 3n}]}, item(7n), 5n, False{}, 1n)),
   rejection_unchanged(Economy.buy(initial(), item(7n), 0n, 1n), initial()),
   shop_rejection_unchanged(initial()),
   buy_exact(Shop.buy_from_shop(initial(), item(7n), 3n, [item(7n)],
     [Shop.ItemDescriptor{item(7n), 1n, False{}}])),
   shop_catalog_price(Shop.buy_from_shop(initial(), item(7n), 3n,
     [item(7n)], [Shop.ItemDescriptor{item(7n), 5n, False{}}])),
   sell_floor(Shop.sell_to_shop(Economy.State{
     Economy.Capacity{6n, 4n, 100n, 999n, 20n, 9999n}, 0n, 6n, 0n,
     4n, 100n, [Economy.ItemStack{item(7n), 3n}]}, item(7n), 1n,
     [Shop.ItemDescriptor{item(7n), 5n, False{}}])),
   reward_unchanged(Economy.State{Economy.Capacity{6n, 4n, 100n, 2n, 20n,
     9999n}, 0n, 6n, 0n, 4n, 100n,
     [Economy.ItemStack{item(7n), 2n}]}),
   storage_is_full(Economy.State{Economy.Capacity{6n, 4n, 1n, 999n, 20n,
     9999n}, 0n, 6n, 1n, 4n, 100n, []}),
   stack_exact(Economy.buy(initial(), item(7n), 1n, 2n)),
   rejection_unchanged(Economy.buy(initial(), item(7n), 1n, 1000n), initial()),
   sell_currency_exact(Economy.sell(Economy.State{
     Economy.Capacity{6n, 4n, 100n, 999n, 20n, 100n}, 0n, 6n, 0n, 4n,
     98n, [Economy.ItemStack{item(7n), 3n}]}, item(7n), 5n, False{}, 1n)),
   rejection_unchanged(Economy.sell(Economy.State{
     Economy.Capacity{6n, 4n, 100n, 999n, 20n, 100n}, 0n, 6n, 0n, 4n,
     99n, [Economy.ItemStack{item(7n), 3n}]}, item(7n), 5n, False{}, 1n),
     Economy.State{Economy.Capacity{6n, 4n, 100n, 999n, 20n, 100n}, 0n, 6n,
       0n, 4n, 99n, [Economy.ItemStack{item(7n), 3n}]}),
   unsellable_rejected_unchanged(Economy.State{
     Economy.Capacity{6n, 4n, 100n, 999n, 20n, 100n}, 0n, 6n, 0n, 4n,
     99n, [Economy.ItemStack{item(7n), 3n}]}),
   capture_storage_fallback(Economy.route_captured(initial())),
   capture_party_first(Economy.route_captured(Economy.State{
     Economy.Capacity{8n, 4n, 100n, 999n, 20n, 9999n}, 0n, 6n, 0n, 4n,
     100n, []})),
   Economy.valid_tiers([Economy.CapacityTier{Economy.Capacity{
     6n, 4n, 100n, 10n, 20n, 100n}}, Economy.CapacityTier{
     Economy.Capacity{8n, 4n, 100n, 12n, 22n, 120n}}]),
   Bool.not(Economy.valid_tiers([Economy.CapacityTier{Economy.Capacity{
     6n, 4n, 100n, 10n, 20n, 100n}}, Economy.CapacityTier{
     Economy.Capacity{5n, 4n, 100n, 12n, 22n, 120n}}])),
   selected_tier_is_retained(Economy.change_tier(1n,
     [Economy.CapacityTier{Economy.Capacity{6n, 4n, 100n, 10n, 20n, 100n}},
      Economy.CapacityTier{Economy.Capacity{8n, 4n, 100n, 12n, 22n, 120n}}],
     Economy.State{Economy.Capacity{8n, 4n, 100n, 12n, 22n, 120n}, 1n,
       7n, 0n, 4n, 100n, []})),
   invalid_downgrade_unchanged(Economy.State{
     Economy.Capacity{8n, 4n, 100n, 12n, 22n, 120n}, 1n, 7n, 0n, 4n,
     100n, []}, [Economy.CapacityTier{Economy.Capacity{
       6n, 4n, 100n, 10n, 20n, 100n}}, Economy.CapacityTier{
       Economy.Capacity{8n, 4n, 100n, 12n, 22n, 120n}}]),
   invalid_state_rejected(Economy.buy(Economy.State{
     Economy.Capacity{6n, 4n, 100n, 999n, 20n, 9999n}, 0n, 6n, 0n,
     4n, 100n, [Economy.ItemStack{item(7n), 1n},
       Economy.ItemStack{item(7n), 2n}]}, item(7n), 1n, 1n),
     Economy.State{Economy.Capacity{6n, 4n, 100n, 999n, 20n, 9999n},
       0n, 6n, 0n, 4n, 100n, [Economy.ItemStack{item(7n), 1n},
         Economy.ItemStack{item(7n), 2n}]}),
   invalid_state_rejected(Economy.buy(Economy.State{
     Economy.Capacity{6n, 4n, 100n, 999n, 20n, 9999n}, 999n, 6n,
     0n, 4n, 100n, []}, item(7n), 1n, 1n),
     Economy.State{Economy.Capacity{6n, 4n, 100n, 999n, 20n, 9999n},
       999n, 6n, 0n, 4n, 100n, []}),
   invalid_state_rejected(Economy.change_tier(1n,
     [Economy.CapacityTier{Economy.Capacity{6n, 4n, 100n, 10n, 20n, 100n}},
      Economy.CapacityTier{Economy.Capacity{8n, 4n, 100n, 12n, 22n, 120n}}],
     Economy.State{Economy.Capacity{7n, 4n, 100n, 10n, 20n, 100n},
       0n, 6n, 0n, 4n, 100n, []}),
     Economy.State{Economy.Capacity{7n, 4n, 100n, 10n, 20n, 100n},
       0n, 6n, 0n, 4n, 100n, []})]
