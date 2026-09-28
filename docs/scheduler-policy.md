# Scheduler policy

| Setting | Lab value | Why |
| --- | --- | --- |
| Nodes | Three four-vCPU compute VMs, 2700 MiB schedulable RAM each | Leave roughly 207 MiB per guest for the OS and daemons; physical RAM reported by `slurmd -C` was 2907 MiB. |
| `short` partition | Default; five-minute maximum | Fast feedback for learning and short tests. |
| `batch` partition | One-hour maximum | Longer CPU examples on the same nodes. |
| `short` QoS | Five-minute wall limit; two running jobs per user | Demonstrate accounting-backed admission and concurrency limits. |
| `normal` QoS | One-hour wall limit; four running jobs per user | Permit a bounded batch workload. |
| Accounts | `team_a` share 1 for `student1`; `team_b` share 2 for `student2` | Teach fair-share weighting under contention. A 2:1 share is a target for accumulated usage, not a guarantee that every two jobs of team B run for each team A job. |
| Priority | Multifactor: fair-share weight 1000, age weight 100; one-day usage half-life | Favor lower historical usage while allowing waiting time to matter. |
| Memory and CPU | `CR_Core_Memory`, one CPU default memory 512 MiB; cgroup v2 core, RAM, swap constraints | The allocation made by Slurm has a kernel-enforced boundary. |
| Enforcement | `associations,limits,qos` | Users must have a cluster association and authorized QoS; accounting limits can hold jobs pending. |

An overlong `short` QoS job can be **accepted into the queue** and remain pending with `QOSMaxWallDurationPerJobLimit`; acceptance of `sbatch` is not proof it can ever run. Use `squeue -j JOBID -o '%i %T %R'`, then `scontrol show job JOBID` to inspect the reason and requested limits. A job with `ReqNodeNotAvail` needs a node-state or node-selection fix; a job with `Resources` waits for free capacity. Inspect completed or failed jobs with `sacct -j JOBID --format=JobID,JobName,State,ExitCode,Elapsed,AllocCPUS,MaxRSS` and the `slurm-JOBID.out` file.

Fair-share weights were checked in `sacctmgr` but their long-run allocation effect was not isolated in this small, shared-host experiment. The [report](../report/final-report.md) separates configured policy from measured scheduler behavior.
