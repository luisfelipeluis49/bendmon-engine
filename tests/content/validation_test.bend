import Base
import ../../engine/content/model.bend as Model
import ../../engine/content/validation.bend as Content

def main() -> Model.Validation:
  content = {Model.Content{
    1n,
    [Model.Species{Model.AssetId{0n}}],
    [Model.Encounter{[Model.EncounterEntry{Model.SpeciesId{0n}, 1n}]}],
    [Model.MapRecord{1n, 512n, [Model.EncounterId{0n}]}],
    Model.MapId{0n}
  } : Model.Content}
  Content.validate(content)

#| ../../engine/content/model.Valid{}
