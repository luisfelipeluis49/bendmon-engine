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


# Approved future proof obligations (2026-09-21 decision packet):
#
# MIX-CD: ceil(3*c/2) strictly exceeds every legal ordinary cooldown c and
# charging both source deadlines is atomic.
# ESCAPE-ATOMIC: a rejected escape changes nothing; an attempted escape consumes
# exactly its specified draw/action cost and successful escape commits no reward.
# REINFORCE: queued reinforcements count as viable and fill vacant active slots
# in canonical order before terminal victory is evaluated.
# SWITCH-ATOMIC: voluntary and forced replacement either commit one legal active
# identity transition or leave battle state unchanged; locked targets never retarget.
# HARM-TIER: the six mastery thresholds and accuracy/critical packages are
# monotone and remain within the ordinary probability caps.
# MIX-ALLOC: quotient/remainder allocation over 1..4 distinct TypeIds preserves
# the complete base power budget before component modifiers.
# CAP-ATOMIC: capture, inventory, shop and capacity-tier transitions either
# commit their entire validated result or leave state unchanged.
# WORLD-DET: equal accepted fixed-point movement inputs and RNG state produce
# equal swept positions and encounter thresholds independent of rendered frames.
# EVENT-TERM: one immediate event activation is acyclic and bounded by cumulative
# fuel; persistent repetition crosses an activation boundary.
# SAVE-ID: a save/replay loads only under exact ruleset and project-content
# identity unless an explicit version-specific schema migration succeeds.
#
# These owner-approved obligations are recorded here before their M4–M11 domain
# functions exist. Replace each comment with a checked law and proof alongside
# its implementation; do not weaken the obligation to make a proof pass.
