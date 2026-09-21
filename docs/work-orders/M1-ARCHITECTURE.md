# M1 architecture and formal-domain closure

Authorization: the owner approved all remaining recommended decisions on
2026-09-21 and requested formal M0/M1 completion. This order records and checks
the already accepted architecture without expanding later milestone scope.

TASK: close M1 architecture and formal-domain definition.
OWNER MODEL: architecture-capable primary agent; independent semantic review.
DEPENDENCIES: M0 toolchain feasibility; accepted owner decisions D01–D19 and
U01–U13.
FILES ALLOWED TO CHANGE: architecture, decision, rule, law-catalog and milestone
documents; architecture consistency tests; additive proof wiring for already
implemented production laws.
FILES FORBIDDEN TO CHANGE: approved mechanics merely to satisfy a check;
later-milestone production implementations.
GOAL: one accepted domain architecture, explicit trust and ownership
boundaries, closed owner decisions, a versioned rules identity, a candidate-law
inventory and an honest checked-proof boundary.
NON-GOALS: proving every future mechanic before its production function exists;
implementing M4–M13; claiming host behavior is mathematically proved.
ENGINE INVARIANTS AFFECTED: deterministic authority, typed identity, no creator
code, exact save/replay identity and renderer/editor separation.
LAWS AFFECTED: catalog only for unimplemented domains; checked laws must call
production functions and have matching entries in `PROOF.bend`.
INPUT CONTRACT: accepted product brief, decision register, ADRs, rules registry,
architecture documents and implemented M0–M3 evidence.
OUTPUT CONTRACT: `docs/architecture/M1-STATUS.md` plus machine checks that fail
on reopened decisions, missing ADR selections, unresolved local links,
unversioned rules or a checked law without its proof.
TESTS REQUIRED: M1 architecture contract suite, canonical proof gate and full
repository verifier.
PROOF OBLIGATIONS: BOOT-1 and implemented-domain additive laws only. Remaining
catalog entries become checked alongside their production milestones.
ACCEPTANCE CRITERIA: all D01–D19 and U01–U13 groups are approved; ADR-01–15 have
selected outcomes; architecture and trust boundaries are accepted; ruleset and
RNG identities are assigned; every current Bend law has a proof; local links
resolve; separate review finds no planning inconsistency; repository verification
passes.
