import Base

# U07 capture state. All probabilities use the shared 0..10000 scale.
type Status is Data:
  CaptureSleep{}
  CaptureStun{}
  CaptureBurn{}
  CapturePoison{}
  CaptureBlind{}
  CaptureOther{}

type ItemMultiplier is Data:
  ItemMultiplier{numerator: Nat, denominator: Nat}

type ChanceResult is Data:
  ChanceValue{chance: U32}
  ChanceInvalid{}

type Destination is Data:
  PartyDestination{}
  StorageDestination{}

type Wide is Data:
  Wide{high: U32, low: U32}

type WideOrder is Data:
  WideLT{}
  WideEQ{}
  WideGT{}

type QuotientState is Data:
  QuotientSearch{low: U32, high: U32, numerator: Wide, denominator: U32}
  QuotientDone{value: U32}

type CaptureReason is Data:
  TrainerTarget{}
  BossTarget{}
  UncapturableTarget{}
  NoCaptureItem{}
  NoDestination{}
  InvalidCaptureData{}

type CaptureEligibility is Data:
  CaptureRejected{reason: CaptureReason}
  CaptureAccepted{destination: Destination, chance: U32}

def status_multiplier(status: Status) -> ItemMultiplier:
  match status:
    case CaptureSleep{}: ItemMultiplier{2n, 1n}
    case CaptureStun{}: ItemMultiplier{2n, 1n}
    case CaptureBurn{}: ItemMultiplier{3n, 2n}
    case CapturePoison{}: ItemMultiplier{3n, 2n}
    case CaptureBlind{}: ItemMultiplier{3n, 2n}
    case CaptureOther{}: ItemMultiplier{1n, 1n}

def item_multiplier_valid(multiplier: ItemMultiplier) -> Bool:
  match multiplier:
    case ItemMultiplier{+numerator, +denominator}:
      Bool.and(Nat.is_ge(denominator, 1n),
        Bool.and(Nat.is_le(denominator, 10000n),
          Bool.and(Nat.is_ge(numerator, 1n),
            Bool.and(Nat.is_le(numerator, 10000n),
              Bool.and(Nat.is_le(denominator, (2n * numerator : Nat)),
                Nat.is_le(numerator, (4n * denominator : Nat)))))))

def capture_data_valid(+rate: U32, multiplier: ItemMultiplier,
  +max_hp: U32, current_hp: U32) -> Bool:
  Bool.and(Bool.and(U32.is_ge(rate, 500), U32.is_le(rate, 9000)),
    Bool.and(item_multiplier_valid(multiplier),
      Bool.and(Bool.and(U32.is_ge(max_hp, 1), U32.is_le(max_hp, 9999)),
        U32.is_le(current_hp, max_hp))))

def status_parts(status: Status) -> ItemMultiplier:
  status_multiplier(status)

def wide_order_low(left: U32, right: U32, order: Cmp) -> WideOrder:
  match order:
    case LT{}: WideLT{}
    case EQ{}: WideEQ{}
    case GT{}: WideGT{}

def wide_order_high(+left_low: U32, +right_low: U32, order: Cmp) -> WideOrder:
  match order:
    case LT{}: WideLT{}
    case GT{}: WideGT{}
    case EQ{}: wide_order_low(left_low, right_low,
      U32.cmp(left_low, right_low))

def wide_order(left: Wide, right: Wide) -> WideOrder:
  match left right:
    case Wide{left_high, left_low} Wide{right_high, right_low}:
      wide_order_high(left_low, right_low, U32.cmp(left_high, right_high))

def wide_product(+left: U32, +right: U32) -> Wide:
  +left_low = U32.mod(left, 65536)
  +left_high = U32.div(left, 65536)
  +right_low = U32.mod(right, 65536)
  +right_high = U32.div(right, 65536)
  +p0 = U32.mul(left_low, right_low)
  +p1 = U32.mul(left_low, right_high)
  +p2 = U32.mul(left_high, right_low)
  +p3 = U32.mul(left_high, right_high)
  +middle = U32.add(U32.add(U32.div(p0, 65536),
    U32.mod(p1, 65536)), U32.mod(p2, 65536))
  +low = U32.add(U32.shln(U32.mod(middle, 65536), 16n),
    U32.mod(p0, 65536))
  +high = U32.add(U32.add(U32.add(p3, U32.div(p1, 65536)),
    U32.div(p2, 65536)), U32.div(middle, 65536))
  Wide{high, low}

def wide_multiply_result(+high: U32, +factor: U32,
  low_product: Wide) -> Wide:
  match low_product:
    case Wide{carry, result_low}:
      Wide{U32.add(U32.mul(high, factor), carry), result_low}


def wide_multiply(value: Wide, +factor: U32) -> Wide:
  match value:
    case Wide{high, low}:
      +low_product = wide_product(low, factor)
      wide_multiply_result(high, factor, low_product)


def quotient_by_order(order: WideOrder, +low: U32, +middle: U32,
  +high: U32, numerator: Wide, denominator: U32) -> QuotientState:
  match order:
    case WideGT{}:
      QuotientSearch{low, middle, numerator, denominator}
    case _:
      QuotientSearch{middle, high, numerator, denominator}

def quotient_step(done: Bool, +low: U32, +high: U32,
  +numerator: Wide, +denominator: U32) -> QuotientState:
  match done:
    case True{}:
      QuotientDone{low}
    case False{}:
      +middle = U32.add(low, U32.div(U32.sub(high, low), 2))
      +candidate = wide_product(denominator, middle)
      quotient_by_order(wide_order(candidate, numerator), low, middle,
        high, numerator, denominator)

def quotient_search(fuel: Nat, state: QuotientState) -> U32:
  match fuel state:
    case _ QuotientDone{value}:
      value
    case 0n QuotientSearch{low, high, numerator, denominator}:
      low
    case 1n+rest QuotientSearch{+low, +high, numerator, denominator}:
      quotient_search(rest, quotient_step(
        U32.is_le(U32.sub(high, low), 1), low, high, numerator, denominator))

def finish_chance(numerator: Wide, denominator: U32) -> ChanceResult:
  +raw = quotient_search(14n, QuotientSearch{0, 9501, numerator, denominator})
  ChanceValue{U32.max(100, U32.min(raw, 9500))}


# Products are represented as checked 64-bit pairs. The validated formula
# bounds numerator below 5.4e12, denominator below 599,940,000 and quotient below
# 72,001; quotient search therefore performs one final exact floor.
def checked_products(valid: Bool, +rate: U32, item: ItemMultiplier,
  status: ItemMultiplier, +max_hp: U32, +current_hp: U32) -> ChanceResult:
  match valid item status:
    case False{} _ _:
      ChanceInvalid{}
    case True{} ItemMultiplier{item_num, item_den}
        ItemMultiplier{status_num, status_den}:
      +hp3 = U32.mul(3, max_hp)
      +hp2 = U32.mul(2, current_hp)
      +health_factor = U32.sub(hp3, hp2)
      +item_n = U32.from_nat(item_num)
      +item_d = U32.from_nat(item_den)
      +status_n = U32.from_nat(status_num)
      +status_d = U32.from_nat(status_den)
      +item_rate = wide_product(rate, item_n)
      +status_scaled = wide_multiply(item_rate, status_n)
      +numerator = wide_multiply(status_scaled, health_factor)
      +denominator = U32.mul(U32.mul(item_d, status_d), hp3)
      finish_chance(numerator, denominator)


def chance_with_status(valid: Bool, +rate: U32, item: ItemMultiplier,
  status: Status, +max_hp: U32, +current_hp: U32) -> ChanceResult:
  +status_ratio = status_parts(status)
  checked_products(valid, rate, item, status_ratio, max_hp, current_hp)

def capture_chance(+rate: U32, +item: ItemMultiplier, status: Status,
  +max_hp: U32, +current_hp: U32) -> ChanceResult:
  chance_with_status(capture_data_valid(rate, item, max_hp, current_hp),
    rate, item, status, max_hp, current_hp)

def destination(party_room: Bool, storage_room: Bool) -> Maybe<Destination>:
  match party_room storage_room:
    case True{} _:
      Some{PartyDestination{}}
    case False{} True{}:
      Some{StorageDestination{}}
    case False{} False{}:
      None{}

def reject_restrictions(trainer_owned: Bool, boss: Bool,
  uncapturable: Bool, item_available: Bool, room: Maybe<Destination>,
  chance: ChanceResult) -> CaptureEligibility:
  match trainer_owned boss uncapturable item_available room chance:
    case True{} _ _ _ _ _:
      CaptureRejected{TrainerTarget{}}
    case False{} True{} _ _ _ _:
      CaptureRejected{BossTarget{}}
    case False{} False{} True{} _ _ _:
      CaptureRejected{UncapturableTarget{}}
    case False{} False{} False{} False{} _ _:
      CaptureRejected{NoCaptureItem{}}
    case False{} False{} False{} True{} None{} _:
      CaptureRejected{NoDestination{}}
    case False{} False{} False{} True{} Some{_} ChanceInvalid{}:
      CaptureRejected{InvalidCaptureData{}}
    case False{} False{} False{} True{} Some{chosen} ChanceValue{chance_value}:
      CaptureAccepted{chosen, chance_value}

def plan_capture(trainer_owned: Bool, boss: Bool, uncapturable: Bool,
  item_available: Bool, party_room: Bool, storage_room: Bool,
  +rate: U32, item: ItemMultiplier, status: Status,
  +max_hp: U32, +current_hp: U32) -> CaptureEligibility:
  reject_restrictions(trainer_owned, boss, uncapturable, item_available,
    destination(party_room, storage_room),
    capture_chance(rate, item, status, max_hp, current_hp))
