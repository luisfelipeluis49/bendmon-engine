import Base
import ../../engine/capture/core.bend as Capture

def chance_is(result: Capture.ChanceResult, expected: U32) -> Bool:
  match result:
    case Capture.ChanceValue{chance}:
      U32.is_eq(chance, expected)
    case _:
      False{}

def chance_invalid(result: Capture.ChanceResult) -> Bool:
  match result:
    case Capture.ChanceInvalid{}: True{}
    case _ : False{}

def party_selected(result: Capture.CaptureEligibility) -> Bool:
  match result:
    case Capture.CaptureAccepted{Capture.PartyDestination{}, chance}:
      True{}
    case _:
      False{}

def storage_selected(result: Capture.CaptureEligibility) -> Bool:
  match result:
    case Capture.CaptureAccepted{Capture.StorageDestination{}, chance}:
      True{}
    case _:
      False{}

def rejected(result: Capture.CaptureEligibility) -> Bool:
  match result:
    case Capture.CaptureRejected{reason}:
      True{}
    case _:
      False{}

def main() -> List<&2, Bool>:
  [chance_is(Capture.capture_chance(500, Capture.ItemMultiplier{1n, 1n},
      Capture.CaptureOther{}, 100, 100), 166),
   chance_is(Capture.capture_chance(9000, Capture.ItemMultiplier{4n, 1n},
      Capture.CaptureSleep{}, 100, 0), 9500),
   chance_is(Capture.capture_chance(500, Capture.ItemMultiplier{1n, 2n},
      Capture.CaptureOther{}, 100, 100), 100),
   chance_is(Capture.capture_chance(500, Capture.ItemMultiplier{4n, 3n},
      Capture.CaptureOther{}, 100, 100), 222),
   chance_is(Capture.capture_chance(500,
      Capture.ItemMultiplier{9999n, 2500n}, Capture.CaptureOther{},
      100, 100), 666),
   chance_is(Capture.capture_chance(9000,
      Capture.ItemMultiplier{10000n, 2500n}, Capture.CaptureOther{},
      100, 100), 9500),
   chance_invalid(Capture.capture_chance(500,
      Capture.ItemMultiplier{1n, 3n}, Capture.CaptureOther{}, 100, 100)),
   chance_is(Capture.capture_chance(500, Capture.ItemMultiplier{1n, 1n},
      Capture.CaptureBurn{}, 100, 0), 750),
   party_selected(Capture.plan_capture(False{}, False{}, False{}, True{},
      True{}, True{}, 500, Capture.ItemMultiplier{1n, 1n},
      Capture.CaptureOther{}, 100, 0)),
   storage_selected(Capture.plan_capture(False{}, False{}, False{}, True{},
      False{}, True{}, 500, Capture.ItemMultiplier{1n, 1n},
      Capture.CaptureOther{}, 100, 0)),
   rejected(Capture.plan_capture(True{}, False{}, False{}, True{}, True{},
      True{}, 500, Capture.ItemMultiplier{1n, 1n}, Capture.CaptureOther{},
      100, 0)),
   rejected(Capture.plan_capture(False{}, True{}, False{}, True{}, True{},
      True{}, 500, Capture.ItemMultiplier{1n, 1n}, Capture.CaptureOther{},
      100, 0)),
   rejected(Capture.plan_capture(False{}, False{}, True{}, True{}, True{},
      True{}, 500, Capture.ItemMultiplier{1n, 1n}, Capture.CaptureOther{},
      100, 0)),
   rejected(Capture.plan_capture(False{}, False{}, False{}, False{}, True{},
      True{}, 500, Capture.ItemMultiplier{1n, 1n}, Capture.CaptureOther{},
      100, 0)),
   rejected(Capture.plan_capture(False{}, False{}, False{}, True{}, False{},
      False{}, 500, Capture.ItemMultiplier{1n, 1n}, Capture.CaptureOther{},
      100, 0)),
   rejected(Capture.plan_capture(False{}, False{}, False{}, True{}, True{},
      True{}, 499, Capture.ItemMultiplier{1n, 1n}, Capture.CaptureOther{},
      100, 0))]

#| [True, True, True, True, True, True, True, True, True, True, True, True,
#|  True, True, True, True]
