import Base
import ../../engine/world/dynamic_battle_content.bend as BattleContent
import ../../engine/world/dynamic_content.bend as Content
import ../../engine/world/dynamic_catalog.bend as World
import ../../engine/world/dynamic_events.bend as Events
import ../../engine/m7/dynamic_species.bend as Species
import ./dynamic_catalog_test.bend as WorldFixture
import ./dynamic_content_test.bend as ContentFixture

def species_tokens(id: U32, identity: U32) -> List<&2, U32>:
  [13, 2, identity, 1, 2, id, 50, 51, 52, 53, 54, 55,
    500, 100, 0, 1, 1, 0, 1, 2, 1]

def accepted(result: BattleContent.JoinResult) -> Bool:
  match result:
    case BattleContent.JoinAccepted{content}: True{}
    case _: False{}

def rejected(result: BattleContent.JoinResult) -> Bool:
  match result:
    case BattleContent.JoinRejected{reason}: True{}
    case _: False{}

def joined(species_id: U32, identity: U32) -> BattleContent.JoinResult:
  BattleContent.join(Content.join(
    World.decode_tokens(WorldFixture.world_tokens()),
    Events.decode_tokens(ContentFixture.event_tokens())),
    Species.decode_tokens(species_tokens(species_id, identity)))

def main() -> Bool:
  Bool.and(accepted(joined(1, 123)),
    Bool.and(rejected(joined(1, 124)),
      rejected(joined(2, 123))))

#| True
