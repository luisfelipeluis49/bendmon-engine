import Base
import ../../engine/economy/core.bend as Economy
import ../../engine/economy/shop.bend as Shop
import ../../engine/economy/validated.bend as Validated

def item(value: Nat) -> Economy.ItemId:
  Economy.ItemId{value}

def first_capacity() -> Economy.Capacity:
  Economy.Capacity{6n, 4n, 10n, 10n, 8n, 200n}

def second_capacity() -> Economy.Capacity:
  Economy.Capacity{8n, 4n, 20n, 20n, 12n, 400n}

def tiers() -> List<&2, Economy.CapacityTier>:
  [Economy.CapacityTier{first_capacity()},
   Economy.CapacityTier{second_capacity()}]

def account() -> Validated.Account:
  Validated.Account{tiers(), Economy.State{first_capacity(), 0n, 1n, 1n,
    2n, 100n, []}}

def account_with_items() -> Validated.Account:
  Validated.Account{tiers(), Economy.State{first_capacity(), 0n, 1n, 1n,
    2n, 100n, [Economy.ItemStack{item(7n), 5n}]}}

def high_tier_account() -> Validated.Account:
  Validated.Account{tiers(), Economy.State{second_capacity(), 1n, 7n, 0n,
    2n, 100n, []}}

def mismatched_account() -> Validated.Account:
  Validated.Account{tiers(), Economy.State{second_capacity(), 0n, 1n, 1n,
    2n, 100n, []}}

def catalog() -> List<&2, Shop.ItemDescriptor>:
  [Shop.ItemDescriptor{item(7n), 5n, False{}}]

def offers() -> List<&2, Economy.ItemId>:
  [item(7n)]

def state_is_initial(state: Economy.State) -> Bool:
  match state:
    case Economy.State{Economy.Capacity{6n, 4n, 10n, 10n, 8n, 200n},
        0n, 1n, 1n, 2n, 100n, []}: True{}
    case _: False{}

def state_is_mismatched_original(state: Economy.State) -> Bool:
  match state:
    case Economy.State{Economy.Capacity{8n, 4n, 20n, 20n, 12n, 400n},
        0n, 1n, 1n, 2n, 100n, []}: True{}
    case _: False{}

def state_mismatch_rejected(result: Validated.EconomyResult) -> Bool:
  match result:
    case Validated.Rejected{Validated.Account{tier_rows, state},
        Economy.InvalidState{}}:
      Bool.and(Economy.valid_tiers(tier_rows),
        state_is_mismatched_original(state))
    case _: False{}

def invalid_table_rejected(result: Validated.EconomyResult) -> Bool:
  match result:
    case Validated.Rejected{account, Economy.InvalidTierTable{}}: True{}
    case _: False{}

def purchase_price_matches_catalog(result: Validated.EconomyResult) -> Bool:
  match result:
    case Validated.Committed{Validated.Account{tier_rows,
        Economy.State{capacity, 0n, 1n, 1n, 2n, 90n,
          [Economy.ItemStack{Economy.ItemId{7n}, 2n}]}}}:
      True{}
    case _: False{}

def sale_price_matches_catalog(result: Validated.EconomyResult) -> Bool:
  match result:
    case Validated.Committed{Validated.Account{tier_rows,
        Economy.State{capacity, 0n, 1n, 1n, 2n, 104n,
          [Economy.ItemStack{Economy.ItemId{7n}, 3n}]}}}:
      True{}
    case _: False{}

def tier_upgrade_succeeded(result: Validated.EconomyResult) -> Bool:
  match result:
    case Validated.Committed{Validated.Account{tier_rows,
        Economy.State{Economy.Capacity{8n, 4n, 20n, 20n, 12n, 400n},
          1n, 1n, 1n, 2n, 100n, []}}}:
      True{}
    case _: False{}

def downgrade_rejected_unchanged(result: Validated.EconomyResult) -> Bool:
  match result:
    case Validated.Rejected{Validated.Account{tier_rows,
        Economy.State{Economy.Capacity{8n, 4n, 20n, 20n, 12n, 400n},
          1n, 7n, 0n, 2n, 100n, []}}, Economy.CapacityOverflow{}}:
      True{}
    case _: False{}

def mismatch_all_public_ops() -> Bool:
  Bool.and(state_mismatch_rejected(Validated.buy(mismatched_account(), item(7n),
      1n, catalog())),
  Bool.and(state_mismatch_rejected(Validated.sell(mismatched_account(), item(7n),
      1n, catalog())),
  Bool.and(state_mismatch_rejected(Validated.adjust_item(mismatched_account(),
      item(7n), 1n, True{}, Economy.StackFull{})),
  Bool.and(state_mismatch_rejected(Validated.reward(mismatched_account(), 1n,
      item(7n), 0n)),
  Bool.and(state_mismatch_rejected(Validated.transfer_to_storage(
      mismatched_account(), 1n)),
  Bool.and(state_mismatch_rejected(Validated.transfer_to_party(
      mismatched_account(), 1n)),
  Bool.and(state_mismatch_rejected(Validated.route_captured(
      mismatched_account())),
  Bool.and(state_mismatch_rejected(Validated.buy_from_shop(
      mismatched_account(), item(7n), 1n, offers(), catalog())),
      state_mismatch_rejected(Validated.sell_to_shop(mismatched_account(),
        item(7n), 1n, catalog()))))))))))

def main() -> List<Bool>:
  [Economy.valid_tiers(tiers()),
   state_mismatch_rejected(Validated.buy(mismatched_account(), item(7n),
     1n, catalog())),
   invalid_table_rejected(Validated.buy(
     Validated.Account{[Economy.CapacityTier{second_capacity()},
       Economy.CapacityTier{first_capacity()}],
       Economy.State{second_capacity(), 0n, 1n, 1n, 2n, 100n, []}},
     item(7n), 1n, catalog())),
   purchase_price_matches_catalog(Validated.buy(account(), item(7n), 2n,
     catalog())),
   purchase_price_matches_catalog(Validated.buy_from_shop(account(), item(7n),
     2n, offers(), catalog())),
   sale_price_matches_catalog(Validated.sell(account_with_items(), item(7n), 2n,
     [Shop.ItemDescriptor{item(7n), 5n, False{}}])),
   sale_price_matches_catalog(Validated.sell_to_shop(
     account_with_items(), item(7n), 2n,
       catalog())),
   tier_upgrade_succeeded(Validated.change_tier(account(), 1n)),
   downgrade_rejected_unchanged(Validated.change_tier(high_tier_account(), 0n)),
   mismatch_all_public_ops()]

#| [True{}, True{}, True{}, True{}, True{}, True{}, True{}, True{}, True{}, True{}]
