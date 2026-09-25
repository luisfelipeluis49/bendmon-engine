# M7 progression, capture and economy status

Status: implemented and verified locally; hosted Ubuntu verification pending.
M6 is the verified baseline at master commit `41a4744`. The controlling M7
contract is `docs/work-orders/M7-PROGRESSION-CAPTURE-ECONOMY.md`, using the
approved D11–D13 and U06–U08 decisions.

The Bend engine now has the exact 200-level XP table, bounded stats and growth,
checked learning and evolution, bounded economy/roster/shop transactions, and
the exact checked capture formula. The M7 battle wrapper executes queued
captures with the shared RNG and routes one newly owned identity to party or
storage. `engine/m7/session.bend` binds validated enemy records and saved
individuals to that battle path. It preserves the complete captured individual,
records defeated/captured encounter yields once, carries participation through
switches, and commits XP, HP changes, currency, items and the encounter ledger
only on eligible terminal completion. A late reward rejection restores the
original queued battle, RNG, roster, inventory, ownership and ledger.
The encounter-scoped playable entry retains one bound content catalog through
command, learning-choice and evolution-choice retries. A full move list pauses
before terminal rewards commit; a choice identifies its level and move, and an
ordered evolution can then apply to the same projected owner. Rejection
preserves the original queued state.

The host content boundary validates and hashes optional M7 species growth,
capture rates, reward yields, move/evolution entries, items, shops and capacity
tiers as inert data. Its deterministic binder assigns numeric runtime IDs. The
content suite has 58 passing tests. The playable content binder requires the
saved `m7-1` ruleset and exact content digest before producing immutable
numeric runtime rows; the Bend entry checks the catalog against the expected
encounter identity. Save and replay identities now default to
exact `m7-1`; historical `m6-1` requires explicit selection and is preserved.
The persistence suite has 22 passing tests. Seven production-linked M7 proof
claims compile in `PROOF.bend`.

The workspace toolchain was advanced from the historical M0 v2.0.19 pin to
verified v2.0.27 during M7. Its official upstream tag, release archive and
executable hashes are recorded in `toolchain.lock.json` and
`docs/architecture/toolchain-evidence.md`. The staged compiler passed the
proof gate and a native/JavaScript session rollback golden before the pin
changed. The complete repository gate passed 305 checks under v2.0.27,
including native/JavaScript parity for every M7 Bend fixture.

Focused M7 fixtures cover progression and capacity boundaries, capture action
timing and RNG, ownership, reward bridge and atomic rollback, terminal battle
session rewards, nonterminal capture persistence, learning/evolution choice
barriers, and invalid binding rejection. Independent Luna reviews found and
rechecked activity history, binding, owner-to-party mapping, stale evolution
source species and catalog identity defects; those are fixed under the trusted
host binder contract. Host-to-Bend process wiring and visual play remain later
integration work; M7's production path is the headless Bend playable entry.

The remaining M7 exit tasks are: run `PROOF.bend` again immediately before
commit; push the verified commit to master; and confirm the hosted Ubuntu run.
Visual editing, world UI and save installation remain later milestones outside
M7.
