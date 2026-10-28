import Base
import ../../engine/performance/parallel_workload.bend as Workload
import ./parallel_workload.bend as Fixture
import ./result_wire.bend as Wire

def main() -> List<&2, U32>:
  Wire.encode_batch(Workload.run_batch(Fixture.make_jobs(256n, 11, [])))
