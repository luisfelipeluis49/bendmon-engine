# Data-driven 2.5D Monster RPG Maker

A primarily Bend 2, content-agnostic engine and visual maker in development. M0–M5 are complete locally and in hosted CI: the repository includes the pinned compiler/proof foundation, strict inert content kernel, deterministic headless battle/replay runtime, closed effect/status transaction and typed multi-type damage algebra. The M6 mix, discovery and Harmony core passes its local gate and awaits hosted closeout; [M6 status](docs/architecture/M6-PROGRESS.md) records the verified scope and later host integration boundary. The visual editor is not implemented yet.

Start with [PLAN.md](PLAN.md), [product scope](docs/PRODUCT.md), [architecture](docs/architecture/ARCHITECTURE.md) and [owner decisions](docs/DECISIONS.md).

- [Battle timeline](docs/mechanics/BATTLE.md), [moves/effects](docs/mechanics/MOVES.md), [mixing/Harmony](docs/mechanics/MIXING.md)
- [Content/security boundary](docs/architecture/CONTENT.md), [determinism/save/replay](docs/architecture/DETERMINISM.md)
- [Content-0 contract](docs/schemas/CONTENT-0.md), [M2 status](docs/architecture/M2-STATUS.md), [M5 status](docs/architecture/M5-STATUS.md), [original example](docs/schemas/EXAMPLE.md)
- [Candidate laws and proof boundary](docs/LAW_CATALOG.md), [rule registry](docs/RULES.md)
- [Proposed ADRs](docs/decisions/ADRS.md), [Bend feasibility](docs/architecture/FEASIBILITY.md)
- [First proposed work order](docs/work-orders/M0-FEASIBILITY.md), [work-order template](docs/work-orders/TEMPLATE.md)
- [Independent architecture review](docs/architecture/REVIEW.md)

## Run the foundation

```sh
python3 scripts/setup_toolchain.py
python3 scripts/verify.py
./build/headless -- 1 2 3
# 6
```

Linux x86_64 baseline requires Python 3.12+, Clang and Node.js. Bend is installed only in `.toolchain/`, using the pinned checksums in `toolchain.lock.json`.

The verification command runs `bend PROOF.bend`, negative proof fixtures, native/JS differential tests, CPU parallelism checks and presentation boundary tests. It builds runnable executables and records evidence under `build/evidence/`.

Validate the original inert project after verification:

```sh
python3 scripts/validate_project.py examples/original-demo
```

The command prints the canonical content hash and entity counts. Content-0 intentionally has no executable events or gameplay formulas.

See [build instructions](docs/BUILD.md), [M0 status and limits](docs/architecture/M0-STATUS.md), [M0 implementation review](docs/architecture/M0-REVIEW.md), and the milestone status files under `docs/architecture/`. The decision register records the approved structural and numerical rules currently implemented or scheduled. Proofs cover the named production-linked laws; they do not by themselves prove the entire planned game engine.
