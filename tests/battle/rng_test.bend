import Base
import ../../engine/battle/rng.bend as Rng

def step_code(step: Rng.RngStep) -> Nat:
  match step:
    case Rng.RngStep{Rng.RngState{7, 0, 1026, 12288}, 11520}:
      1n
    case _:
      0n

def bounded_code(ok: Bool) -> Nat:
  match ok:
    case True{}:
      1n
    case False{}:
      0n

def sample_code(result: Rng.RngSampleResult) -> Nat:
  match result:
    case Rng.RngSampled{state, value, 1n}:
      bounded_code(U32.is_lt(value, 10000))
    case _:
      0n

def invalid_code(result: Rng.RngSampleResult) -> Nat:
  match result:
    case Rng.RngInvalidBound{Rng.RngState{1, 2, 3, 4}}:
      1n
    case _:
      0n

def invalid_state_code(result: Rng.RngSampleResult) -> Nat:
  match result:
    case Rng.RngInvalidState{Rng.RngState{0, 0, 0, 0}}:
      1n
    case _:
      0n

def exhausted_code(result: Rng.RngSampleResult) -> Nat:
  match result:
    case Rng.RngSamplingExhausted{Rng.RngState{1, 2, 3, 4}, 64n}:
      1n
    case _:
      0n

def main() -> List<&2, Nat>:
  +seed = {Rng.RngState{1, 2, 3, 4} : Rng.RngState}
  [step_code(Rng.next(seed)), sample_code(Rng.sample(seed, 10000)),
    invalid_code(Rng.sample(seed, 0)),
    invalid_state_code(Rng.sample(Rng.RngState{0, 0, 0, 0}, 10000)),
    exhausted_code(Rng.sample_machine(0n, Rng.SampleNeed{seed}, seed,
      10000, 7296, 64n))]

#| [1, 1, 1, 1, 1]
