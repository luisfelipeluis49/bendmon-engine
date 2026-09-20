# Data-driven 2.5D Monster RPG Maker

A primarily Bend 2, content-agnostic engine and visual maker in early development. The M0 foundation now runs: pinned compiler, checked bootstrap proof, headless native/JavaScript probes and a native presentation artifact bridge. The RPG runtime and editor are not implemented yet.

Start with [PLAN.md](PLAN.md), [product scope](docs/PRODUCT.md), [architecture](docs/architecture/ARCHITECTURE.md) and [owner decisions](docs/DECISIONS.md).

- [Battle timeline](docs/mechanics/BATTLE.md), [moves/effects](docs/mechanics/MOVES.md), [mixing/Harmony](docs/mechanics/MIXING.md)
- [Content/security boundary](docs/architecture/CONTENT.md), [determinism/save/replay](docs/architecture/DETERMINISM.md)
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

See [build instructions](docs/BUILD.md) and [M0 status and limits](docs/architecture/M0-STATUS.md), and [implementation review](docs/architecture/M0-REVIEW.md). Approved nonnumerical decisions are recorded in the decision register; numerical gameplay rules remain unapproved. The bootstrap proof does not prove the planned game engine.
