import Base

# M5's type algebra is deliberately independent of the M4 effect interpreter.
# It resolves the normal damage aggregate for one action; M4 remains the owner
# of the single accuracy/critical draw and applies critical damage once to this
# aggregate.

type TypeId is Data:
  TypeId{value: Nat}

type TypeInteraction is Data:
  TypeNeutral{}
  TypeImmune{}
  TypeMultiplier{numerator: U32, denominator: U32}

type DamageComponent is Data:
  DamageComponent{type_id: TypeId, power: U32}

type ComponentDamage is Data:
  ComponentDamage{type_id: TypeId, power: U32, amount: U32, immune: Bool,
    stab: Bool}

type DamageProfile is Data:
  DamageProfile{level: U32, attack: U32, defense: U32}

type AllocationDiagnostic is Data:
  EmptyComponents{}
  TooManyComponents{count: Nat}
  DuplicateType{type_id: TypeId}
  InvalidPower{power: U32}
  InvalidTypeId{type_id: TypeId}
  NonCanonicalTypes{}

type ResolutionDiagnostic is Data:
  AllocationRejected{reason: AllocationDiagnostic}
  MissingTypeInteraction{type_id: TypeId}
  DuplicateTypeInteraction{type_id: TypeId}
  InvalidTypeInteraction{type_id: TypeId}
  InvalidDamageProfile{}
  InvalidActorTypes{}
  ModifierOverflow{}
  AggregateOverflow{}

type AllocationResult is Data:
  Allocated{components: List<&2, DamageComponent>}
  AllocationRejectedResult{reason: AllocationDiagnostic}

type ComponentResult is Data:
  ComponentResolved{value: ComponentDamage}
  ComponentRejected{reason: ResolutionDiagnostic}

type MultiDamageResult is Data:
  MultiDamageResolved{components: List<&2, ComponentDamage>, total: U32}
  MultiDamageRejected{reason: ResolutionDiagnostic}

type CheckedProduct is Data:
  ProductValue{value: U32}
  ProductOverflow{}

type NatRatio is Data:
  NatRatio{numerator: Nat, denominator: Nat}

def type_eq(left: TypeId, right: TypeId) -> Bool:
  TypeId{left_value} = left
  TypeId{right_value} = right
  Nat.is_eq(left_value, right_value)

def type_le(left: TypeId, right: TypeId) -> Bool:
  TypeId{left_value} = left
  TypeId{right_value} = right
  Nat.is_le(left_value, right_value)

def type_id_in(+wanted: TypeId, values: List<&2, TypeId>) -> Bool:
  match values:
    case Nil{}: False{}
    case value <> rest: Bool.or(type_eq(wanted, value), type_id_in(wanted, rest))

def type_id_valid(type_id: TypeId) -> Bool:
  TypeId{value} = type_id
  Nat.is_le(value, 9n)

def type_registry() -> List<&2, TypeId>:
  [TypeId{0n}, TypeId{1n}, TypeId{2n}, TypeId{3n}, TypeId{4n},
   TypeId{5n}, TypeId{6n}, TypeId{7n}, TypeId{8n}, TypeId{9n}]

def duplicate_values(values: List<&2, TypeId>) -> Bool:
  match values:
    case Nil{}: False{}
    case first <> +rest:
      Bool.or(type_id_in(first, rest), duplicate_values(rest))

def canonical_type_step(found: Bool, type_id: TypeId,
  tail: List<&2, TypeId>) -> List<&2, TypeId>:
  match found:
    case True{}: type_id <> tail
    case False{}: tail

def canonical_types(registry: List<&2, TypeId>,
  +values: List<&2, TypeId>) -> List<&2, TypeId>:
  match registry:
    case Nil{}: Nil{}
    case +type_id <> rest:
      canonical_type_step(type_id_in(type_id, values), type_id,
        canonical_types(rest, values))

def all_type_ids_valid(values: List<&2, TypeId>) -> Bool:
  match values:
    case Nil{}: True{}
    case type_id <> rest: Bool.and(type_id_valid(type_id),
      all_type_ids_valid(rest))

def first_invalid_type(values: List<&2, TypeId>) -> TypeId:
  match values:
    case Nil{}: TypeId{0n}
    case TypeId{0n} <> rest: first_invalid_type(rest)
    case TypeId{1n} <> rest: first_invalid_type(rest)
    case TypeId{2n} <> rest: first_invalid_type(rest)
    case TypeId{3n} <> rest: first_invalid_type(rest)
    case TypeId{4n} <> rest: first_invalid_type(rest)
    case TypeId{5n} <> rest: first_invalid_type(rest)
    case TypeId{6n} <> rest: first_invalid_type(rest)
    case TypeId{7n} <> rest: first_invalid_type(rest)
    case TypeId{8n} <> rest: first_invalid_type(rest)
    case TypeId{9n} <> rest: first_invalid_type(rest)
    case TypeId{invalid} <> rest: TypeId{invalid}

def select_type(selected: Bool, candidate: TypeId,
  fallback: TypeId) -> TypeId:
  match selected:
    case True{}: candidate
    case False{}: fallback

def duplicate_identity(values: List<&2, TypeId>) -> TypeId:
  match values:
    case +a <> +b <> +c <> +d <> Nil{}:
      select_type(type_eq(a, b), a,
        select_type(type_eq(a, c), a,
          select_type(type_eq(a, d), a,
            select_type(type_eq(b, c), b,
              select_type(type_eq(b, d), b, c)))))
    case +a <> +b <> +c <> Nil{}:
      select_type(type_eq(a, b), a,
        select_type(type_eq(a, c), a, b))
    case a <> b <> Nil{}: a
    case a <> Nil{}: a
    case Nil{}: TypeId{0n}
    case first <> rest: first

def allocation_type_ids_valid(valid: Bool, invalid: TypeId) -> AllocationResult:
  match valid:
    case False{}: AllocationRejectedResult{InvalidTypeId{invalid}}
    case True{}: Allocated{[]}

def allocation_types_duplicate(duplicate: Bool,
  +values: List<&2, TypeId>) -> AllocationResult:
  match duplicate:
    case True{}: AllocationRejectedResult{DuplicateType{
      duplicate_identity(values)}}
    case False{}: allocation_type_ids_valid(all_type_ids_valid(values),
      first_invalid_type(values))

def allocation_types_limit(too_many: Bool, +count: Nat,
  +values: List<&2, TypeId>) -> AllocationResult:
  match too_many:
    case True{}: AllocationRejectedResult{TooManyComponents{count}}
    case False{}: allocation_types_duplicate(duplicate_values(values), values)

def allocation_types_zero(zero: Bool, +count: Nat,
  +values: List<&2, TypeId>) -> AllocationResult:
  match zero:
    case True{}: AllocationRejectedResult{EmptyComponents{}}
    case False{}: allocation_types_limit(Nat.is_gt(count, 4n), count, values)

def allocation_types(+values: List<&2, TypeId>) -> AllocationResult:
  +count = List.length(&2, TypeId, values)
  allocation_types_zero(Nat.is_eq(count, 0n), count, values)

def type_rank(+wanted: TypeId, values: List<&2, TypeId>) -> Nat:
  TypeId{wanted_value} = wanted
  match values:
    case Nil{}: 0n
    case TypeId{value} <> rest:
      Nat.add(U32.to_nat(Bool.to_u32(Nat.is_lt(value, wanted_value))),
        type_rank(TypeId{wanted_value}, rest))

def allocation_components(+q: U32, +remainder: U32,
  +canonical: List<&2, TypeId>, values: List<&2, TypeId>) ->
  List<&2, DamageComponent>:
  match values:
    case Nil{}: Nil{}
    case +type_id <> rest:
      +extra = Bool.to_u32(Nat.is_lt(type_rank(type_id, canonical),
        U32.to_nat(remainder)))
      DamageComponent{type_id, U32.add(q, extra)} <>
        allocation_components(q, remainder, canonical, rest)

def allocate_power_shape(result: AllocationResult, +power: U32, +count: Nat,
  +values: List<&2, TypeId>) -> AllocationResult:
  match result:
    case AllocationRejectedResult{reason}: AllocationRejectedResult{reason}
    case Allocated{components}:
      +q = U32.div(power, U32.from_nat(count))
      +remainder = U32.mod(power, U32.from_nat(count))
      Allocated{allocation_components(q, remainder,
        canonical_types(type_registry(), values), values)}

def allocate_power_valid(valid: Bool, +power: U32, +count: Nat,
  +values: List<&2, TypeId>) -> AllocationResult:
  match valid:
    case False{}: AllocationRejectedResult{InvalidPower{power}}
    case True{}: allocate_power_shape(allocation_types(values), power, count, values)

def allocate_power(+power: U32, +values: List<&2, TypeId>) -> AllocationResult:
  +count = List.length(&2, TypeId, values)
  allocate_power_valid(U32.is_ge(power, 1), power, count, values)

def allocate_upper(valid: Bool, +power: U32,
  values: List<&2, TypeId>) -> AllocationResult:
  match valid:
    case False{}: AllocationRejectedResult{InvalidPower{power}}
    case True{}: allocate_power(power, values)

def allocate(+power: U32, values: List<&2, TypeId>) -> AllocationResult:
  allocate_upper(U32.is_le(power, 200), power, values)

def type_interaction_valid(interaction: TypeInteraction) -> Bool:
  match interaction:
    case TypeNeutral{}: True{}
    case TypeImmune{}: True{}
    case TypeMultiplier{numerator, +denominator}:
      Bool.and(U32.is_le(numerator, 16), Bool.and(U32.is_ge(denominator, 1),
        U32.is_le(denominator, 16)))

def has_stab(+wanted: TypeId, actor_types: List<&2, TypeId>) -> Bool:
  type_id_in(wanted, actor_types)

def checked_product_limit(overflow: Bool, +left: U32,
  +right: U32) -> CheckedProduct:
  match overflow:
    case True{}: ProductOverflow{}
    case False{}: ProductValue{U32.mul(left, right)}

def checked_product_zero(zero: Bool, +left: U32, +right: U32) -> CheckedProduct:
  match zero:
    case True{}: ProductValue{0}
    case False{}:
      +limit = U32.div(4294967295, right)
      checked_product_limit(U32.is_gt(left, limit), left, right)

def checked_product(+left: U32, +right: U32) -> CheckedProduct:
  checked_product_zero(U32.is_zero(right), left, right)

def product_value(result: CheckedProduct) -> U32:
  match result:
    case ProductValue{value}: value
    case ProductOverflow{}: 0

def profile_valid(profile: DamageProfile) -> Bool:
  match profile:
    case DamageProfile{+level, +attack, +defense}:
      Bool.and(Bool.and(U32.is_ge(level, 1), U32.is_le(level, 200)),
        Bool.and(Bool.and(U32.is_ge(attack, 1), U32.is_le(attack, 9999)),
          Bool.and(U32.is_ge(defense, 1), U32.is_le(defense, 9999))))

def final_ratio(stab: Bool, +numerator: Nat, +denominator: Nat) -> NatRatio:
  match stab:
    case False{}: NatRatio{numerator, denominator}
    case True{}: NatRatio{Nat.mul(numerator, 3n), Nat.mul(denominator, 2n)}

def component_amount_bound(valid: Bool, +power: U32, +amount: Nat,
  +stab: Bool) -> ComponentResult:
  match valid:
    case False{}: ComponentRejected{ModifierOverflow{}}
    case True{}: ComponentResolved{ComponentDamage{TypeId{0n}, power,
      U32.from_nat(amount), False{}, stab}}

def component_amount_ratio_final(ratio: NatRatio, +power: U32,
  stab: Bool) -> ComponentResult:
  match ratio:
    case NatRatio{final_numerator, final_denominator}:
      +amount = Nat.div(final_numerator, final_denominator)
      component_amount_bound(Nat.is_le(amount, 4294967295n), power, amount, stab)

def component_amount_ratio(+power: U32, +level: U32, +attack: U32,
  +defense: U32, +type_numerator: U32, +type_denominator: U32,
  +stab: Bool) -> ComponentResult:
  +raw_numerator = Nat.mul(Nat.mul(U32.to_nat(power),
    Nat.add(Nat.mul(2n, U32.to_nat(level)), 50n)), U32.to_nat(attack))
  +raw_denominator = Nat.mul(300n, U32.to_nat(defense))
  +typed_numerator = Nat.mul(raw_numerator, U32.to_nat(type_numerator))
  +typed_denominator = Nat.mul(raw_denominator, U32.to_nat(type_denominator))
  component_amount_ratio_final(final_ratio(stab, typed_numerator,
    typed_denominator), power, stab)

def component_damage_ratio_result(result: ComponentResult, type_id: TypeId,
  +power: U32) -> ComponentResult:
  match result:
    case ComponentRejected{reason}: ComponentRejected{reason}
    case ComponentResolved{ComponentDamage{ignored, ignored_power, amount,
        immune, matched}}: ComponentResolved{ComponentDamage{type_id, power,
      amount, immune, matched}}

def component_profile_valid(valid: Bool, +level: U32, +attack: U32,
  +defense: U32, +type_id: TypeId, +power: U32,
  interaction: TypeInteraction, +stab: Bool) -> ComponentResult:
  match valid:
    case False{}: ComponentRejected{InvalidDamageProfile{}}
    case True{}:
      match interaction:
        case TypeImmune{}: ComponentResolved{ComponentDamage{type_id,
          power, 0, True{}, stab}}
        case TypeNeutral{}:
          component_damage_ratio_result(component_amount_ratio(power, level,
            attack, defense, 1, 1, stab), type_id, power)
        case TypeMultiplier{numerator, denominator}:
          component_damage_ratio_result(component_amount_ratio(power, level,
            attack, defense, numerator, denominator, stab), type_id, power)

def component_interaction_valid(valid: Bool, +profile_valid_value: Bool,
  +level: U32, +attack: U32, +defense: U32, +type_id: TypeId, +power: U32,
  interaction: TypeInteraction, stab: Bool) -> ComponentResult:
  match valid:
    case False{}: ComponentRejected{InvalidTypeInteraction{type_id}}
    case True{}: component_profile_valid(profile_valid_value, level, attack,
      defense, type_id, power, interaction, stab)

def component_damage(+profile: DamageProfile, component: DamageComponent,
  +interaction: TypeInteraction, stab: Bool) -> ComponentResult:
  match profile component:
    case DamageProfile{level, attack, defense}
        DamageComponent{type_id, power}:
      component_interaction_valid(type_interaction_valid(interaction),
        profile_valid(profile), level, attack, defense, type_id, power,
        interaction, stab)

def add_component_bound(overflow: Bool, +total: U32,
  +amount: U32) -> Maybe<&2, U32>:
  match overflow:
    case True{}: None{}
    case False{}: Some{U32.add(total, amount)}

def add_component_checked(+total: U32, +amount: U32) -> Maybe<&2, U32>:
  add_component_bound(U32.is_gt(total, U32.sub(4294967295, amount)), total,
    amount)

def component_amount_value(value: ComponentDamage) -> U32:
  match value:
    case ComponentDamage{type_id, power, amount, immune, stab}: amount

def component_power_sum(values: List<&2, DamageComponent>) -> U32:
  match values:
    case Nil{}: 0
    case DamageComponent{type_id, power} <> rest:
      U32.add(power, component_power_sum(rest))

def allocation_total(result: AllocationResult) -> U32:
  match result:
    case AllocationRejectedResult{reason}: 0
    case Allocated{components}: component_power_sum(components)

# U04 owns the ten-type registry and ordered chart.  The numeric identities are
# stable serialization identities: 0 neutral, 1 ember, 2 tide, 3 verdant,
# 4 stone, 5 gale, 6 spark, 7 frost, 8 radiant and 9 umbral.
def pair_match(+a: Nat, +d: Nat, +attacker: Nat, +defender: Nat) -> Bool:
  Bool.and(Nat.is_eq(a, attacker), Nat.is_eq(d, defender))

def strong_pair(attacker: TypeId, defender: TypeId) -> Bool:
  TypeId{+a} = attacker
  TypeId{+d} = defender
  Bool.or(pair_match(a, d, 1n, 3n), Bool.or(pair_match(a, d, 1n, 7n),
    Bool.or(pair_match(a, d, 2n, 1n), Bool.or(pair_match(a, d, 2n, 4n),
      Bool.or(pair_match(a, d, 3n, 2n), Bool.or(pair_match(a, d, 3n, 4n),
        Bool.or(pair_match(a, d, 4n, 1n), Bool.or(pair_match(a, d, 4n, 6n),
          Bool.or(pair_match(a, d, 5n, 3n), Bool.or(pair_match(a, d, 5n, 9n),
            Bool.or(pair_match(a, d, 6n, 2n), Bool.or(pair_match(a, d, 6n, 5n),
              Bool.or(pair_match(a, d, 7n, 3n), Bool.or(pair_match(a, d, 7n, 5n),
                Bool.or(pair_match(a, d, 8n, 7n), Bool.or(pair_match(a, d, 8n, 9n),
                  Bool.or(pair_match(a, d, 9n, 8n), pair_match(a, d, 9n, 6n))))))))))))))))))

def chart_interaction_reverse(reverse: Bool) -> TypeInteraction:
  match reverse:
    case True{}: TypeMultiplier{1, 2}
    case False{}: TypeNeutral{}

def chart_interaction_first(first: Bool, attacker: TypeId,
  defender: TypeId) -> TypeInteraction:
  match first:
    case True{}: TypeMultiplier{2, 1}
    case False{}: chart_interaction_reverse(strong_pair(defender, attacker))

def chart_interaction(+attacker: TypeId, +defender: TypeId) -> TypeInteraction:
  chart_interaction_first(strong_pair(attacker, defender), attacker, defender)

def combine_multiplier_denominator(denominator_result: CheckedProduct,
  +numerator: U32) -> Maybe<&2, TypeInteraction>:
  match denominator_result:
    case ProductOverflow{}: None{}
    case ProductValue{denominator}: Some{TypeMultiplier{numerator,
      denominator}}

def combine_multiplier_products(numerator_result: CheckedProduct,
  +left_den: U32, +right_den: U32) -> Maybe<&2, TypeInteraction>:
  match numerator_result:
    case ProductOverflow{}: None{}
    case ProductValue{numerator}:
      combine_multiplier_denominator(checked_product(left_den, right_den),
        numerator)

def combine_interaction(left: TypeInteraction,
  right: TypeInteraction) -> Maybe<&2, TypeInteraction>:
  match left right:
    case TypeImmune{} _: Some{TypeImmune{}}
    case _ TypeImmune{}: Some{TypeImmune{}}
    case TypeNeutral{} other: Some{other}
    case other TypeNeutral{}: Some{other}
    case TypeMultiplier{+left_num, +left_den}
        TypeMultiplier{+right_num, +right_den}:
      combine_multiplier_products(checked_product(left_num, right_num),
        left_den, right_den)

def combine_defenders(+attacker: TypeId,
  defenders: List<&2, TypeId>) -> Maybe<&2, TypeInteraction>:
  match defenders:
    case Nil{}: None{}
    case defender <> Nil{}: Some{chart_interaction(attacker, defender)}
    case first <> second <> rest:
      combine_interaction(chart_interaction(attacker, first),
        chart_interaction(attacker, second))

def no_duplicate_types(values: List<&2, TypeId>) -> Bool:
  Bool.not(duplicate_values(values))

def type_snapshot_valid(+values: List<&2, TypeId>) -> Bool:
  +count = List.length(&2, TypeId, values)
  Bool.and(Bool.and(Nat.is_ge(count, 1n), Nat.is_le(count, 2n)),
    Bool.and(no_duplicate_types(values), all_type_ids_valid(values)))

def finish_components(valid: Bool, components: List<&2, ComponentDamage>,
  +total: Nat) -> MultiDamageResult:
  match valid:
    case False{}: MultiDamageRejected{AggregateOverflow{}}
    case True{}: MultiDamageResolved{components, U32.from_nat(total)}

def resolve_result_1(result: ComponentResult) -> MultiDamageResult:
  match result:
    case ComponentRejected{reason}: MultiDamageRejected{reason}
    case ComponentResolved{+value}:
      +total = U32.to_nat(component_amount_value(value))
      finish_components(Nat.is_le(total, 4294967295n), [value], total)

def resolve_result_2(left: ComponentResult,
  right: ComponentResult) -> MultiDamageResult:
  match left right:
    case ComponentRejected{reason} _: MultiDamageRejected{reason}
    case _ ComponentRejected{reason}: MultiDamageRejected{reason}
    case ComponentResolved{+a} ComponentResolved{+b}:
      +total = Nat.add(U32.to_nat(component_amount_value(a)),
        U32.to_nat(component_amount_value(b)))
      finish_components(Nat.is_le(total, 4294967295n), [a, b], total)

def resolve_result_3(one: ComponentResult, two: ComponentResult,
  three: ComponentResult) -> MultiDamageResult:
  match one two three:
    case ComponentRejected{reason} _ _: MultiDamageRejected{reason}
    case _ ComponentRejected{reason} _: MultiDamageRejected{reason}
    case _ _ ComponentRejected{reason}: MultiDamageRejected{reason}
    case ComponentResolved{+a} ComponentResolved{+b} ComponentResolved{+c}:
      +total = Nat.add(U32.to_nat(component_amount_value(a)), Nat.add(
        U32.to_nat(component_amount_value(b)),
        U32.to_nat(component_amount_value(c))))
      finish_components(Nat.is_le(total, 4294967295n), [a, b, c], total)

def resolve_result_4(one: ComponentResult, two: ComponentResult,
  three: ComponentResult, four: ComponentResult) -> MultiDamageResult:
  match one two three four:
    case ComponentRejected{reason} _ _ _: MultiDamageRejected{reason}
    case _ ComponentRejected{reason} _ _: MultiDamageRejected{reason}
    case _ _ ComponentRejected{reason} _: MultiDamageRejected{reason}
    case _ _ _ ComponentRejected{reason}: MultiDamageRejected{reason}
    case ComponentResolved{+a} ComponentResolved{+b} ComponentResolved{+c}
        ComponentResolved{+d}:
      +total = Nat.add(U32.to_nat(component_amount_value(a)), Nat.add(
        U32.to_nat(component_amount_value(b)), Nat.add(
        U32.to_nat(component_amount_value(c)),
        U32.to_nat(component_amount_value(d)))))
      finish_components(Nat.is_le(total, 4294967295n), [a, b, c, d], total)

def resolve_one_interaction(result: Maybe<&2, TypeInteraction>,
  +profile: DamageProfile, +component: DamageComponent,
  +actor_types: List<&2, TypeId>) -> ComponentResult:
  match result:
    case None{}: ComponentRejected{InvalidActorTypes{}}
    case Some{interaction}:
      DamageComponent{type_id, power} = component
      component_damage(profile, component, interaction,
        has_stab(type_id, actor_types))

def resolve_one(+profile: DamageProfile, +component: DamageComponent,
  +actor_types: List<&2, TypeId>, defender_types: List<&2, TypeId>) ->
  ComponentResult:
  DamageComponent{type_id, power} = component
  resolve_one_interaction(combine_defenders(type_id, defender_types), profile,
    component, actor_types)

def resolve_allocated(result: AllocationResult, +profile: DamageProfile,
  +actor_types: List<&2, TypeId>, +defender_types: List<&2, TypeId>) ->
  MultiDamageResult:
  match result:
    case AllocationRejectedResult{reason}: MultiDamageRejected{
      AllocationRejected{reason}}
    case Allocated{components}:
      match components:
        case a <> Nil{}: resolve_result_1(resolve_one(profile, a, actor_types,
          defender_types))
        case a <> b <> Nil{}: resolve_result_2(
          resolve_one(profile, a, actor_types, defender_types),
          resolve_one(profile, b, actor_types, defender_types))
        case a <> b <> c <> Nil{}: resolve_result_3(
          resolve_one(profile, a, actor_types, defender_types),
          resolve_one(profile, b, actor_types, defender_types),
          resolve_one(profile, c, actor_types, defender_types))
        case a <> b <> c <> d <> Nil{}: resolve_result_4(
          resolve_one(profile, a, actor_types, defender_types),
          resolve_one(profile, b, actor_types, defender_types),
          resolve_one(profile, c, actor_types, defender_types),
          resolve_one(profile, d, actor_types, defender_types))
        case _: MultiDamageRejected{AllocationRejected{EmptyComponents{}}}

def resolve_defender_snapshot(valid: Bool, +profile: DamageProfile,
  +power: U32, types: List<&2, TypeId>, +actor_types: List<&2, TypeId>,
  defender_types: List<&2, TypeId>) -> MultiDamageResult:
  match valid:
    case False{}: MultiDamageRejected{InvalidActorTypes{}}
    case True{}: resolve_allocated(allocate(power, types), profile, actor_types,
      defender_types)

def resolve_actor_snapshot(valid: Bool, +profile: DamageProfile, +power: U32,
  types: List<&2, TypeId>, actor_types: List<&2, TypeId>,
  +defender_types: List<&2, TypeId>) -> MultiDamageResult:
  match valid:
    case False{}: MultiDamageRejected{InvalidActorTypes{}}
    case True{}: resolve_defender_snapshot(type_snapshot_valid(defender_types),
      profile, power, types, actor_types, defender_types)

def resolve_chart(+profile: DamageProfile, +power: U32,
  types: List<&2, TypeId>, +actor_types: List<&2, TypeId>,
  defender_types: List<&2, TypeId>) -> MultiDamageResult:
  resolve_actor_snapshot(type_snapshot_valid(actor_types), profile, power, types,
    actor_types, defender_types)

# Compatibility aliases used by tests and later runtime integration.
def allocate_components(power: U32,
  types: List<&2, TypeId>) -> AllocationResult:
  allocate(power, types)

def resolve_multi_type(profile: DamageProfile, power: U32,
  types: List<&2, TypeId>, actor_types: List<&2, TypeId>,
  defender_types: List<&2, TypeId>) -> MultiDamageResult:
  resolve_chart(profile, power, types, actor_types, defender_types)
