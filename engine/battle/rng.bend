import Base

type RngState is Data:
  RngState{a: U32, b: U32, c: U32, d: U32}

type RngStep is Data:
  RngStep{state: RngState, value: U32}

type RngSampleResult is Data:
  RngSampled{state: RngState, value: U32, candidates: Nat}
  RngInvalidState{state: RngState}
  RngInvalidBound{state: RngState}
  RngSamplingExhausted{state: RngState}

def rotl(+value: U32, +amount: Nat, +inverse: Nat) -> U32:
  U32.or(U32.shln(value, amount), U32.shrn(value, inverse))

# xoshiro128** 1.1, with fixed-width U32 wraparound owned by the type.
def next(+state: RngState) -> RngStep:
  RngState{+a, +b, +c, +d} = state
  +value = U32.mul(rotl(U32.mul(b, 5), 7n, 25n), 9)
  +shifted = U32.shln(b, 9n)
  +next_c0 = U32.xor(c, a)
  +next_d0 = U32.xor(d, b)
  +next_b = U32.xor(b, next_c0)
  +next_a = U32.xor(a, next_d0)
  +next_c = U32.xor(next_c0, shifted)
  +next_d = rotl(next_d0, 11n, 21n)
  RngStep{RngState{next_a, next_b, next_c, next_d}, value}

def valid_state(state: RngState) -> Bool:
  match state:
    case RngState{a, b, c, d}:
      Bool.not(Bool.and(U32.is_eq(a, 0), Bool.and(U32.is_eq(b, 0),
        Bool.and(U32.is_eq(c, 0), U32.is_eq(d, 0)))))

type SampleMachine is Data:
  SampleNeed{current: RngState}
  SampleHave{next_state: RngState, raw: U32}
  SampleDecide{next_state: RngState, raw: U32, accepted: Bool}

def step_machine(step: RngStep) -> SampleMachine:
  match step:
    case RngStep{next_state, +raw}:
      SampleHave{next_state, raw}

def sample_machine(
  fuel: Nat, machine: SampleMachine, +original: RngState, +bound: U32,
  +threshold: U32, candidates: Nat
) -> RngSampleResult:
  match fuel machine:
    case 0n _:
      RngSamplingExhausted{original}
    case 1n+rest SampleNeed{current}:
      sample_machine(rest, step_machine(next(current)), original, bound,
        threshold, 1n+candidates)
    case 1n+rest SampleHave{next_state, +raw}:
      sample_machine(rest,
        SampleDecide{next_state, raw, U32.is_ge(raw, threshold)}, original,
        bound, threshold, candidates)
    case 1n+rest SampleDecide{next_state, +raw, True{}}:
      RngSampled{next_state, U32.mod(raw, bound), candidates}
    case 1n+rest SampleDecide{next_state, raw, False{}}:
      sample_machine(rest, SampleNeed{next_state}, original, bound, threshold,
        candidates)

def sample_bound(
  valid: Bool, +state: RngState, +bound: U32
) -> RngSampleResult:
  match valid:
    case False{}:
      RngInvalidBound{state}
    case True{}:
      +threshold = U32.mod(U32.sub(0, bound), bound)
      sample_machine(192n, SampleNeed{state}, state, bound, threshold, 0n)

def sample_state_valid(
  valid: Bool, +state: RngState, +bound: U32
) -> RngSampleResult:
  match valid:
    case False{}:
      RngInvalidState{state}
    case True{}:
      sample_bound(U32.is_ne(bound, 0), state, bound)

def sample(+state: RngState, +bound: U32) -> RngSampleResult:
  sample_state_valid(valid_state(state), state, bound)
