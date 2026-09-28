# User quick-start

The administrator gives you the controller address and your LDAP password through a private channel. First verify the controller SSH fingerprint against the administrator's record; do not accept an unexpected changed key. Log in with `ssh student1@192.168.130.10` (or the assigned account). User login is on the controller; Slurm starts the job on compute nodes. Your home directory `/home/hpc/student1` is shared across them.

```bash
id
pwd
source /etc/profile.d/modules.sh
module avail mini-hpc
module load mini-hpc/1.0
which cpu-workload
srun -p short -q short -N1 -n1 -c1 --mem=256M --time=00:02:00 cpu-workload --iterations 200000
sbatch /opt/mini-hpc/examples/cpu-short.sbatch
sbatch /opt/mini-hpc/examples/cpu-array.sbatch
```

`srun` waits for an interactive job step; `sbatch` returns a job ID for work that runs later. The example scripts write `slurm-JOBID.out` and `slurm-ARRAYID_TASKID.out` in the directory from which you submit. Each job declares partition, QoS, time, CPU and memory so its resource request is explicit and can be enforced.

```bash
squeue -u "$USER" -o '%i %T %R %N'
scontrol show job JOBID
sacct -j JOBID --format=JobID,JobName,State,ExitCode,Elapsed,AllocCPUS,ReqMem,MaxRSS
cat slurm-JOBID.out
scancel JOBID
```

A pending job has a reason in `squeue` or `scontrol`: `Resources` means the requested capacity is busy; `QOSMaxJobsPerUserLimit` means your QoS concurrency limit is reached; `QOSMaxWallDurationPerJobLimit` means shorten the requested time or choose an authorized QoS/partition. `ReqNodeNotAvail` means a requested node is unavailable; contact the administrator if it persists. An out-of-memory job needs a larger `--mem` request or a smaller working set. The `short` partition and QoS each cap wall time at five minutes; the `batch` partition and `normal` QoS allow up to one hour. Your `short` QoS runs at most two jobs concurrently and `normal` at most four.
