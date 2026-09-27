import Base
import ./battle_bridge_test.bend as BattleFixture
import ../../engine/world/encounter_handoff.bend as Handoff
import ../../engine/world/encounters.bend as Encounters
import ../../engine/world/battle_bridge.bend as Bridge
import ../../engine/m7/playable.bend as Playable
import ../../engine/battle/runtime.bend as Runtime
import ../../engine/battle/model.bend as Battle
import ../m7/session_test.bend as SessionFixture

def after_handoff(result: Handoff.HandoffResult) -> Bool:
  match result:
    case Handoff.HandoffStarted{state, 9n, 1n}:
      BattleFixture.after_submit(Bridge.submit(state, 10n,
        [SessionFixture.lethal_move(),
          Runtime.RuntimeWait{Battle.ActorId{1n}}]))
    case _: False{}

def after_prepare(result: Handoff.PrepareResult,
  battle: Playable.PlayableSession) -> Bool:
  match result:
    case Handoff.EncounterPrepared{prepared}:
      after_handoff(Handoff.start(prepared, battle))
    case _: False{}

def with_battle(battle: Maybe<Playable.PlayableSession>) -> Bool:
  match battle:
    case None{}: False{}
    case Some{session}:
      after_prepare(Handoff.prepare(BattleFixture.world(),
        [Handoff.EncounterTable{7n,
          [Encounters.EncounterEntry{9n, 1n, 1n, 1n}]}]), session)

def main() -> List<&2, Bool>:
  [with_battle(BattleFixture.opened())]
