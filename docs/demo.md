# Five-minute cluster demo

This walkthrough is for a running four-VM lab. It shows one real user job and points to recorded fault tests without changing cluster state. The [administrator runbook](admin-runbook.md) covers VM startup and SSH host-key verification; the [project report](../report/final-report.md) contains the measured results.

## 1. Establish the platform (about one minute)

From the laptop, in the repository root:

```bash
ansible-playbook ansible/playbooks/verify-cluster.yml
```

The expected recap is `failed=0 changed=0` for controller and all three compute nodes. This read-only check crosses several boundaries: NSS resolves the LDAP student, the compute homes reach the NFS export, Slurm sees all three nodes, and Prometheus sees four healthy node exporters. It is more informative than a VM being merely `running` in libvirt.

Show the [architecture diagram](architecture.md). The core design choice is one controller plus three identical compute VMs. Separate guest kernels let one node fail independently; the shared laptop and controller remain single points of failure.

## 2. Follow a student job (about two minutes)

Log in to the controller as an assigned LDAP student, using the privately supplied password. From that login:

```bash
id
source /etc/profile.d/modules.sh
module load mini-hpc/1.0
sinfo -N -h -o '%N %t %c %m' | sort -u
srun -p short -q short -N1 -n1 -c1 --mem=256M --time=00:02:00 \
  cpu-workload --iterations 200000
job_id=$(sbatch --parsable /opt/mini-hpc/examples/cpu-short.sbatch)
echo "submitted job $job_id"
squeue -j "$job_id" -o '%i %T %R %N'
sacct -j "$job_id" --format=JobID,JobName,State,ExitCode,Elapsed,AllocCPUS,ReqMem
```

The batch job may finish before `squeue` runs; in that case its completed record appears in `sacct` shortly afterward. `cpu-workload` prints its compute hostname, Slurm job ID, iteration count, digest, and elapsed program time. The job output file is in the student's shared `/home/hpc` directory.

Explain the path: SSSD resolves the LDAP UID; Munge authenticates Slurm messages; `slurmctld` allocates CPU and memory; `slurmd` starts the task on a compute VM; NFS provides the same home path; `slurmdbd` stores the accounting record. A Slurm account and QoS are separate from the Linux UID.

## 3. Show enforcement and diagnosis (about one minute)

Use the [job evidence](../report/evidence/06-jobs-and-limits.md) for the observed one-CPU affinity, memory OOM, `Resources` queue reason, and QoS limits. An overlong `short` QoS job was accepted by `sbatch` but remained pending with `QOSMaxWallDurationPerJobLimit`. That result illustrates why a job ID is not proof that a job can run.

For any live pending job, start with `squeue -j JOBID -o '%i %T %R %N'`, then `scontrol show job JOBID`. For a finished failure, use `sacct` and its output file. Match the reason to [scheduler policy](scheduler-policy.md) before touching a daemon.

## 4. Close with recovery and limits (about one minute)

The [failure evidence](../report/evidence/07-failure-injection.md) records a drained compute node returning to `idle` in 11.620 s and an NFS write succeeding 7.313 s after service restart. The [drift evidence](../report/evidence/08-drift.md) shows zero changes on a repeat Ansible run and correction of both file and QoS database drift. These are lab observations with polling and SSH overhead, not availability guarantees.

The honest boundary is important: all VMs share one laptop; fresh-image end-to-end provisioning and SMT on/off speedup were not measured. The [report's limits section](../report/final-report.md#limits-and-next-study) says what a larger, controlled experiment would require.
