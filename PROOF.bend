import Base
import LAWS.bend as Laws

def Laws.bootstrap_zero(n):
  match n:
    case 0n:
      {==}
    case 1n+p:
      %Laws.bootstrap_zero(p) : {1n+Nat.add(p, 0n) == 1n+_ : Nat}
      {==}

def Laws.content_empty_reference(id):
  {==}
