import Base
import ./capture_submit_test.bend as Submit
import ../../engine/m7/battle.bend as M7
import ../../engine/battle/model.bend as Battle
import ../../engine/capture/core.bend as Capture

def main() -> List<&2, Bool>:
  [Submit.committed_destination_accounts_for_prior_capture(),
   Submit.reserved_capture_key_exact(),
   Submit.reserved_capture_key_rejects_tamper(),
   Submit.reserved_capture_due_uses_acceptance_time()]
