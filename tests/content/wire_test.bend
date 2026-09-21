import Base
import ../../engine/content/model.bend as Model
import ../../engine/content/wire.bend as Wire

def show(result: Wire.WireResult) -> String:
  match result:
    case Wire.WireFail{reason}:
      "WIRE " ++ reason
    case Wire.WireDone{content}:
      "OK"

def main() -> String:
  show(Wire.parse("1 1 1 0 1 1 0 1 1 1 1 0 0"))

#| "OK"
