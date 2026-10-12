import Base

# Text is kept as validated Unicode code points so runtime progression remains
# deterministic and independent of host font or localization services.
type Line is Data:
  Line{speaker: List<&2, U32>, text: List<&2, U32>}

type Record is Data:
  Record{id: Nat, lines: List<&2, Line>}

type Cursor is Data:
  Closed{}
  Showing{id: Nat, remaining: List<&2, Line>}
  Finished{id: Nat}

type Action is Data:
  Started{cursor: Cursor, line: Line}
  Advanced{cursor: Cursor, line: Line}
  Completed{cursor: Cursor}
  Rejected{}

def start(record: Record) -> Action:
  match record:
    case Record{0n, _}: Rejected{}
    case Record{id, Nil{}}: Rejected{}
    case Record{id, first <> rest}:
      Started{Showing{id, rest}, first}

# Advancing consumes exactly one authored line; a completed cursor cannot be
# restarted accidentally by another button press.
def advance(cursor: Cursor) -> Action:
  match cursor:
    case Closed{}: Rejected{}
    case Finished{id}: Rejected{}
    case Showing{id, Nil{}}:
      Completed{Finished{id}}
    case Showing{id, next <> rest}:
      Advanced{Showing{id, rest}, next}
