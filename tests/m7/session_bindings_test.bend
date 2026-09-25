import Base
import ../../engine/m7/session.bend as Session
import ../../engine/battle/model.bend as Battle
import ../../engine/progression/core.bend as Progression
import ../../engine/economy/roster.bend as Roster
import ./session_test.bend as Fixture

def replace_bindings(state: Session.State,
  enemies: List<&2, Session.Enemy>,
  owners: List<&2, Session.OwnerActor>) -> Session.State:
  match state:
    case Session.State{battle, rewards, old_enemies, old_owners}:
      Session.State{battle, rewards, enemies, owners}

def state_with(enemies: List<&2, Session.Enemy>,
  owners: List<&2, Session.OwnerActor>) -> Session.State:
  replace_bindings(Fixture.session_state(), enemies, owners)

def valid_with(enemies: List<&2, Session.Enemy>,
  owners: List<&2, Session.OwnerActor>) -> Bool:
  Session.session_valid(state_with(enemies, owners))

def duplicate_enemy_binding_rejected() -> Bool:
  Bool.not(valid_with([Fixture.enemy_binding(), Fixture.enemy_binding()],
    [Fixture.owner_binding()]))

def missing_enemy_binding_rejected() -> Bool:
  Bool.not(valid_with([], [Fixture.owner_binding()]))

def missing_owner_binding_rejected() -> Bool:
  Bool.not(valid_with([Fixture.enemy_binding()], []))

def wrong_enemy_side_rejected() -> Bool:
  Bool.not(valid_with([Session.Enemy{Battle.ActorId{0n},
      Fixture.enemy_individual(), Fixture.base_stats(),
      Progression.DefeatedReward{1, 100, 5}}], [Fixture.owner_binding()]))

def wrong_enemy_specimen_stats_rejected() -> Bool:
  Bool.not(valid_with([Session.Enemy{Battle.ActorId{1n},
      Progression.Individual{88n, 9n, 1, 0, 1, 13, Fixture.zero_ivs(), [],
        [], [], [], [0]}, Fixture.base_stats(),
      Progression.DefeatedReward{1, 100, 5}}], [Fixture.owner_binding()]))

def storage_owner_id_rejected() -> Bool:
  Bool.not(Session.owner_in_party(77n,
    Roster.Roster{Fixture.capacity(), [Roster.IndividualId{78n}],
      [Roster.IndividualId{77n}]}))

def flags_preserved(flags: List<&2, Bool>) -> Bool:
  match flags:
    case [True{}, True{}]: True{}
    case _: False{}

def unbound_party_liveness_preserved() -> Bool:
  flags_preserved(Session.unbound_flags(Fixture.owner_input(),
    Roster.Roster{Fixture.capacity(), [Roster.IndividualId{77n}], []}))

def main() -> List<Bool>:
  [Session.session_valid(Fixture.session_state()),
    duplicate_enemy_binding_rejected(),
    missing_enemy_binding_rejected(),
    missing_owner_binding_rejected(),
    wrong_enemy_side_rejected(),
    wrong_enemy_specimen_stats_rejected(),
    storage_owner_id_rejected(),
    unbound_party_liveness_preserved()]
