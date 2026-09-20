import Base
import ../../engine/content/model.bend as Model
import ../../engine/content/wire.bend as Wire

def show(result: Result<&2, &2, String, Model.Content>) -> String:
  match result:
    case Fail{reason}:
      "WIRE " ++ reason
    case Done{content}:
      "OK"

def main() -> String:
  show(Wire.parse("1 1 1 0 1 1 0 1 1 1 1 0 0"))

#| "OK"
