import Base
import ./parallel_workload.bend as Fixture
import ../../engine/performance/parallel_workload.bend as Workload
import ./result_wire.bend as Wire

def main() -> List<&2, U32>:
  +jobs = Fixture.make_jobs(9n, 11, [])
  Wire.encode_batch(Workload.BatchAccepted{Workload.serial(jobs)})
