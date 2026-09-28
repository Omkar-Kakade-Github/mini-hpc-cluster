# Reproducible Mini-HPC Cluster: implementation and evaluation

**Observed:** 2026-09-27 to 2026-09-28

**Platform:** one Ubuntu 24.04 laptop, KVM/libvirt, four Ubuntu 24.04 VMs

**Result:** a working three-node Slurm compute pool with central identity, shared homes, accounting, resource enforcement, monitoring, automation, and documented recovery. This is a portfolio lab, not a high-availability cluster.

## Project question and acceptance

Can a single laptop demonstrate the control plane and failure behavior of a small Linux HPC cluster while keeping the configuration reproducible? The acceptance criteria were: distinct VM identities and fixed inventory; usable LDAP/SSSD accounts over verified TLS; NFS homes; Munge-authenticated Slurm with `slurmdbd`/MariaDB, QoS and fair-share; CPU jobs and cgroup limits; monitoring; Ansible replay; a Git-based static pipeline; and observed job, drift and failure behavior. The accompanying [architecture](../docs/architecture.md), [scheduler policy](../docs/scheduler-policy.md), [runbook](../docs/admin-runbook.md), [quick-start](../docs/user-quickstart.md), and [handover](../docs/handover.md) are part of the deliverable.

## Design decisions and why they fit

| Decision | What it buys | Cost or boundary |
| --- | --- | --- |
| One controller plus three compute VMs on KVM | Separate Linux kernels and systemd instances make Slurm daemons, cgroups, node-state faults and NFS mounts real while fitting a laptop. | All guests share one physical host. A laptop outage stops everything. |
| Four vCPUs per VM, 4 GiB controller and 3 GiB per compute | 16 guest vCPUs and 13 GiB assigned RAM fit the 16-core/30-GiB host with room for host activity; identical computes simplify comparisons. | Contention and host SMT can still distort timing. A guest vCPU is not a dedicated physical core. |
| Fixed DHCP leases plus Ansible-managed `/etc/hosts` | Stable names for certificates and Slurm without another DNS daemon. | Changing an address requires coordinated inventory, host-map and certificate updates. |
| OpenLDAP + SSSD + lab CA | One user/group identity source and certificate-checked login across VMs; SSSD can cache credentials. | The controller and CA lifecycle are critical dependencies. Cached credentials are not a general identity outage guarantee. |
| One NFS `/home/hpc` export and numeric IDs | The same input and output files follow jobs to any compute node. | The controller is a storage single point of failure; hard mounts can block I/O while it is unavailable. |
| Shared Munge key; Slurm controller plus `slurmdbd` and MariaDB | Slurm RPCs use a common trust secret, and job/account/QoS records persist in accounting. | The shared key and database need private backups and coordinated rotation. |
| `select/cons_tres` plus cgroup v2 | CPU and memory are separately allocated, then enforced by the guest kernel. | Constraining memory can terminate jobs and adds bookkeeping overhead. |
| Static GitHub Actions plus live local tests | Syntax and tracked-secret checks run without private VMs; live tests establish behavior that static checks cannot. | The hosted workflow passed after the clean runner exposed a missing `ansible.posix` collection in the initial dependency list; the requirement was pinned and the workflow rerun. |

Alternatives considered: containers would be lighter but less direct for guest boot, systemd, and node failure exercises; a single VM would not expose inter-node identity and file behavior; a multi-host or hybrid MPI design would exceed this laptop-only scope. Local MariaDB and NFS deliberately keep the topology small; distributing them would change the failure domains and require more RAM and operational work. The [architecture diagram and IP inventory](../docs/architecture.md) give the concrete deployment.

## Method and observations

The Ubuntu cloud image was verified against a pinned SHA-256 checksum and copied into separate guest disks with distinct cloud-init instance IDs. Fixed libvirt MAC-to-IP leases produced controller `.10` and computes `.11` to `.13` on `192.168.130.0/24`. SSH host fingerprints were recorded and strict checking rejected a deliberately wrong key. The [VM evidence](evidence/01-vm-bootstrap.md) and [SSH evidence](evidence/02-inventory-and-ssh.md) detail those checks. Name resolution survived a compute reboot after Ansible also updated cloud-init's host template; the [name-resolution evidence](evidence/04-name-resolution.md) records the drift found and fixed there.

Ansible applied base naming/time, trust and LDAP, SSSD, NFS, Munge, MariaDB/`slurmdbd`, Slurm, scheduler policy, workload module, and monitoring in that dependency order. `getent` returned UID 20001/20002 and shared GID 20000 on every guest; a real controller password login worked. Cross-node Munge decoding succeeded, NFS file ownership and visibility were verified, and both LDAP students ran `srun` jobs. All three compute nodes registered `idle` with four vCPUs and 2700 MiB scheduled RAM each. Prometheus marked all four exporters `up`. See [service evidence](evidence/05-identity-storage-and-scheduler.md).

### Captured metrics

| Metric | Procedure | Observation | Interpretation and limit |
| --- | --- | --- | --- |
| Provisioning / restoration time | Controlled warm reboot of existing compute03, SSH poll, limited site replay, node-state poll | SSH ready at 10.002 s; playbook finished at 24.138 s; `idle` at 24.645 s from VM start | Measures restart and reconciliation, **not** first creation from a cloud image. A fresh-image end-to-end timer was not captured during incremental development. |
| Full idempotent apply | Re-run `site.yml` on running four-VM cluster | 35.76 s in the final replay (`32.66 s` in an earlier steady-state replay), `changed=0 failed=0` on all hosts | Desired files, services, and policy were already converged. This is the full repeat-run elapsed time. |
| CPU/memory enforcement | One-CPU `srun`; 400 MiB allocation under a 128 MiB request | Allowed CPU list `0`; memory step exited 1 with one OOM kill | Guest kernel cgroups applied the requested limits. |
| Queue behavior | Four exclusive node jobs on three nodes | Three running, fourth pending `(Resources)` | The queue reflected physical VM capacity. |
| QoS behavior | Overlong `short` job; three simultaneous `short` jobs | Overlong job pending `QOSMaxWallDurationPerJobLimit`; third concurrent job pending `QOSMaxJobsPerUserLimit` | Accounting-backed limits enforced; `sbatch` may still return an ID for a job that cannot dispatch. |
| Job throughput | Submit 24 tiny CPU jobs, wait until queue empty, inspect accounting | 24/24 completed in 16.230 s = **1.48 jobs/s** | The workload outputs report median 0.018 s program time (sum 0.430 s across 24 jobs); submission, scheduling, process launch and polling together dominate this wall time. It is not a compute speedup result. |
| Controller daemon recovery | Stop/start `slurmctld`; poll `sinfo` | `sinfo` failed while stopped; first response 7.062 s after start, initially `unk` nodes | Full return of all nodes to `idle` was observed later but not timed precisely. |
| Compute node recovery | Stop compute03 `slurmd`, drain, restart/resume, poll idle | 11.620 s to observed `idle`; node-pinned job had been `ReqNodeNotAvail` and later completed | Measures this fault procedure plus command/polling latency. |
| NFS recovery | Stop export, bounded client write, restore, retry synchronized write | Client write timed out after four seconds; success 7.313 s after server start | Hard-mount I/O blocked during loss and resumed after restore. |
| File drift | Append comment to compute02 `slurm.conf`, check, apply, check | Check showed one file diff; apply restored it; final check zero changes | Demonstrates desired-state reconciliation, including `slurmd` restart. |
| Database policy drift | Change `short` QoS max jobs 2→3, rerun policy | One Ansible change restored it to 2 | Policy tasks reconcile this tested database value. |

The [job evidence](evidence/06-jobs-and-limits.md), [failure evidence](evidence/07-failure-injection.md), and [drift evidence](evidence/08-drift.md) preserve commands, states and timing caveats. Timings include SSH/Ansible orchestration and one-second polling. The shared laptop had no controlled CPU isolation, so these values are demonstrations and reproducible procedures rather than cross-platform performance estimates.

## Failure interpretation and operating method

A pending job should be diagnosed at the scheduler boundary first: `squeue` gives the reason; `scontrol show job` gives requested resources, QoS and selected nodes; `sinfo` and `scontrol show node` explain node state; `sacct` and the batch output explain a completed or failed step. That sequence avoids treating every pending job as a daemon fault. In this lab, `Resources`, `QOSMaxWallDurationPerJobLimit`, `QOSMaxJobsPerUserLimit`, and `ReqNodeNotAvail` were all observed with different causes. The [runbook](../docs/admin-runbook.md) gives commands for each branch.

The controller combines scheduling, directory, shared storage, accounting, time and monitoring. A single controller failure is therefore wider than the isolated `slurmctld` test. The node test preserved capacity on compute01/02; the storage test showed why a job can have CPUs available yet wait on file I/O. Host failure remains outside VM recovery. These are failure-domain observations, not a promise of job continuity.

## Automation and operational quality

`site.yml` gave a zero-change second apply on all four VMs. A live read-only health playbook passed across all four VMs after handling the lazy NFS automount correctly. A static check repaired a previously unnoticed syntax typo in `prepare-controller.sh`; `scripts/check-static.sh` then passed Bash parsing, Python AST parsing, Ansible site syntax, and a tracked-secret path check. The GitHub Actions workflow installs pinned Ansible and collection versions and passed on a clean hosted runner after the missing `ansible.posix` dependency was added. It runs the same script on push/PR. It does not pretend to run KVM or access ignored local credentials on a hosted runner. The repository's `secrets/` and `.local/` are untracked; a separate private backup is required to reproduce an existing deployed cluster rather than build a new identity domain.

## Limits and next study

The 4 GiB controller cannot follow [SchedMD's production recommendation](https://slurm.schedmd.com/accounting.html) of at least 4 GiB for the database buffer pool while also running LDAP, NFS, Slurm and monitoring. MariaDB is set to a 512 MiB pool and 900-second lock wait in this lab. This is adequate for the tiny observed job history but is not a scale claim. Slurm logged PMIx plugin load warnings; this project tested CPU and non-MPI work, not MPI. No host SMT on/off benchmark, NUMA study, multi-host scaling, load-isolated throughput, backup restore drill, or fresh-image end-to-end provisioning timing was performed.

For deeper study, read [SchedMD's cgroup v2 guide](https://slurm.schedmd.com/cgroup_v2.html) alongside this lab's CPU and OOM checks, and [SchedMD's fair-share explanation](https://slurm.schedmd.com/fair_tree.html) before interpreting the 1:2 account weights as long-term allocation behavior. The most useful next experiment is a controlled host SMT on/off comparison with identical jobs, host load and thermal conditions recorded.
