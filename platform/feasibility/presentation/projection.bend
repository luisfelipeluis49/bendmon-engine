import Base

# A developer-owned presentation snapshot. These fields describe only this
# feasibility scene; they are not game state or game rules.
type Snapshot is Data:
  Snapshot{x: U32, y: U32, depth: U32, palette: U32, tone_hz: U32}

type Projection is Data:
  Projection{x: U32, y: U32, depth: U32, palette: U32, tone_hz: U32,
    state_tag: U32}

# The tag makes preservation observable at the host boundary without granting
# the presentation shell any way to mutate the input snapshot.
def Snapshot.tag(+s: Snapshot) -> U32:
  Snapshot{+x, +y, +depth, +palette, +tone_hz} = s
  (x + y * 3 + depth * 5 + palette * 7 + tone_hz * 11 : U32)

def project(+s: Snapshot) -> Projection:
  Snapshot{+x, +y, +depth, +palette, +tone_hz} = s
  Projection{x, y, depth, palette, tone_hz, Snapshot.tag(s)}

def original_snapshot() -> Snapshot:
  Snapshot{42, 31, 2, 1, 523}
