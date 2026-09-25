import Base
import ./session_test.bend as Fixture

def main() -> List<Bool>:
  [Fixture.invalid_snapshot_is_unchanged(),
    Fixture.submit_ok(Fixture.submission())]
