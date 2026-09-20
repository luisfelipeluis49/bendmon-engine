import Base
import ./engine/core/bootstrap.bend as Boot
import ./engine/content/validation.bend as Content

# BOOT-1: adding zero preserves the headless accumulator for every Nat state.
# This is a toolchain/bootstrap law, not a battle or progression specification.
# Initial adoption follows the owner's implementation request. Semantic changes
# require human approval; implementations/proofs must satisfy this statement.
law bootstrap_zero:
  for n: Nat
  {Boot.transition(n, 0n) == n : Nat}


# REF-EMPTY: no typed reference can point into an empty catalog.
# Additive fixed content-validity requirement; BOOT-1 above is unchanged.
law content_empty_reference:
  for id: Nat
  {Content.ref_ok(id, 0n) == False{} : Bool}
