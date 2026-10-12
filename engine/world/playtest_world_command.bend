import Base
import ./catalog.bend as Catalog
import ./commands.bend as Commands
import ./events.bend as Events
import ./geometry.bend as Geometry
import ./world_session.bend as Session

type WorldCommand is Data:
  PlayMove{input: Geometry.Input}
  PlayInteract{npc_id: Nat, facing_x: Geometry.Coord,
    facing_z: Geometry.Coord}
  PlayActivate{trigger_id: Nat}
  PlayTraverse{transition_id: Nat}
  PlayFastTravel{transition_id: Nat}
  PlayContinueEvent{}
  PlayChooseEvent{yes: Bool}
  PlayAdvanceDialogue{}
  PlayBattleWait{actor_id: Nat}
  PlayBattleEscape{actor_id: Nat}
  PlayBattleMove{actor_id: Nat, target_id: Nat, move_id: Nat}
  PlayAdvanceBattle{}

def move_presented(result: Session.SessionResult) -> Session.PresentedResult:
  Session.PresentedResult{result, Nil{}}

# This adapter maps closed playtest commands to the existing M8 transition
# entry points. The caller supplies accepted-input ordinals for cue identity.
def run(catalog: Catalog.Catalog, session: Session.WorldSession,
  input: WorldCommand, ordinal: Nat) -> Session.PresentedResult:
  match input:
    case PlayMove{motion}:
      move_presented(Session.move(catalog, session, motion))
    case PlayInteract{npc_id, facing_x, facing_z}:
      Session.command_presented(catalog, session,
        Commands.Interact{npc_id, facing_x, facing_z}, ordinal)
    case PlayActivate{trigger_id}:
      Session.command_presented(catalog, session,
        Commands.Activate{trigger_id}, ordinal)
    case PlayTraverse{transition_id}:
      Session.command_presented(catalog, session,
        Commands.Traverse{transition_id}, ordinal)
    case PlayFastTravel{transition_id}:
      Session.command_presented(catalog, session,
        Commands.FastTravel{transition_id}, ordinal)
    case PlayContinueEvent{}:
      Session.event_step_presented(session, Events.NoInput{}, ordinal)
    case PlayChooseEvent{yes}:
      Session.event_step_presented(session, Events.Choose{yes}, ordinal)
    case PlayAdvanceDialogue{}:
      Session.PresentedResult{Session.Rejected{session}, []}
    case PlayBattleWait{actor_id}:
      Session.PresentedResult{Session.Rejected{session}, []}
    case PlayBattleEscape{actor_id}:
      Session.PresentedResult{Session.Rejected{session}, []}
    case PlayBattleMove{actor_id, target_id, move_id}:
      Session.PresentedResult{Session.Rejected{session}, []}
    case PlayAdvanceBattle{}:
      Session.PresentedResult{Session.Rejected{session}, []}
