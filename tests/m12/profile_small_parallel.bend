import Base
import ./parallel_workload.bend as Fixture
import ./workload_digest.bend as Digest

def main() -> U32:
  Digest.run_parallel(1n, Fixture.make_jobs(1n, 11, []))
