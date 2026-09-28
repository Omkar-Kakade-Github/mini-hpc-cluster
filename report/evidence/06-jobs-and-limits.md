# Evidence 06: jobs, queue behavior, and resource enforcement

Observed on 2026-09-28 using `student1` and `scripts/measure-jobs.sh` on the controller. Each tiny job ran on the three four-vCPU KVM compute guests; the laptop was not isolated from its own workload.

| Probe | Observation | Interpretation |
| --- | --- | --- |
| One-CPU `srun` | `/proc/self/status` reported `Cpus_allowed_list: 0` | The task was pinned to one guest CPU. |
| 128 MiB request, 400 MiB allocation | `srun` exit 1; `slurmstepd` reported one `oom_kill` event and `Out Of Memory` | The kernel cgroup memory limit was active. |
| Four exclusive one-node jobs | Three `RUNNING` on compute01/02/03; fourth `PENDING (Resources)` | Capacity, rather than a daemon error, held the fourth job. |
| 24 short CPU jobs | 24 `COMPLETED` in 16.230 s = 1.48 jobs/s | This measures this lab's submission-to-completion throughput for tiny work. The 24 output files reported 0.015-0.020 s of CPU-program time each (median 0.018 s; sum 0.430 s), so submission, scheduling, launching and polling together dominate the 16.230 s wall time. This is not CPU scaling. |
| Ten-minute request with `short` QoS and `batch` partition | `sbatch` returned job 35; it remained `PENDING (QOSMaxWallDurationPerJobLimit)` | Submission acceptance does not imply dispatch. Job was cancelled. |
| Three 20-second `short` QoS jobs | Two ran, third `PENDING (QOSMaxJobsPerUserLimit)` | Per-user QoS concurrency limit of two was enforced. Jobs were cancelled. |

The sample batch job `cpu-short.sbatch` completed as job 3; its output was written to the shared student home. Slurm accounting stored state, requested memory and allocated CPUs. The deterministic CPU program prints host, job ID, iteration count, digest, and elapsed time. No speedup or host SMT conclusion was drawn from these tiny jobs.

The benchmark script submits jobs serially and polls once per second. The available measurements do not separate client submission time from scheduler, daemon startup, or polling delay; attributing the full gap to any one component would require tracing or profiling.
