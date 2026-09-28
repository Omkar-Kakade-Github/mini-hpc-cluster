# How the cluster works: a guided walkthrough

Read this after the [measured report](../report/final-report.md). Each section connects a concrete configuration choice to the general HPC idea it teaches. The live quiz should use these ideas to predict a symptom and choose a diagnostic command; memorizing service names alone is insufficient.

## 1. Virtual machines and failure boundaries

KVM gives each guest a separate Linux kernel, process table, boot sequence and cgroup tree. That makes stopping `slurmd` on one compute guest a meaningful node fault while the other two keep running. QEMU supplies the virtual devices; libvirt defines and starts the guests. The four guests still share the laptop's CPU, RAM, disk and bridge. KVM being integrated with a type-1 Linux hypervisor does **not** give a guest exclusive bare-metal hardware or remove host contention. The 4-vCPU guest topology presents four single-threaded virtual cores; it does not reveal which host SMT sibling ran a vCPU.

Why one controller? It makes the dependency graph visible without more VMs. Why three computes? One can fail and the others still demonstrate useful capacity. The price is that the controller and the laptop are large shared failure domains. A second physical host or a replicated control plane would teach different lessons.

## 2. Identity, authentication and trust

LDAP stores the student records and numeric user/group IDs centrally. SSSD asks LDAP for identity and login information and integrates it into each guest's NSS and PAM stack. `/etc/hosts` supplies stable names; the lab CA lets SSSD verify that the LDAPS server claiming `controller.mini-hpc.test` owns the matching certificate. TLS protects and authenticates that network connection. Ansible distributes the public CA; the laptop keeps the CA private key. Passwords and private keys stay outside Git.

SSH host keys answer a different question: is this the VM I intended to contact? SSH user keys or LDAP passwords answer who is logging in. Munge answers yet another question: did a trusted Slurm-side process issue this time-limited credential? Its shared key and close clocks make those credentials verifiable across nodes. A wrong SSH host key blocks Ansible before LDAP or Munge matters; a broken LDAPS certificate can break SSSD while SSH admin access and Slurm service credentials remain intact.

## 3. Files and time

The controller exports `/home/hpc` and all compute nodes mount it. Matching numeric UID 20001 on every node means a file owned by student1 remains student1's file after a job migrates to another VM. NFS itself is not a distributed filesystem with replicated storage here: the controller holds the only copy. `hard` mounting favors eventual correctness of file operations after server recovery but can leave a job waiting during an outage. The systemd automount can show a placeholder until a path is first accessed, which changed how the live verifier checks it.

The controller's Chrony serves time; compute guests poll it. Slurm and especially Munge use timestamps. Clocks continue advancing during a controller time-service outage, but drift can eventually make credentials look expired or premature. The lab configured time sync but did not inject a sustained clock-skew fault.

## 4. Scheduling, accounting and limits

The user submits `sbatch` or `srun` to `slurmctld` on the controller. `slurmctld` chooses a node; `slurmd` starts tasks there. `slurmdbd` persists job and policy data in MariaDB. A Slurm *account* groups users for accounting/fair-share. A *QoS* controls admissible wall time and concurrency. A *partition* selects a set of nodes and a partition wall-time ceiling. Both partition and QoS restrictions can apply to one job.

`select/cons_tres` accounts separately for CPU cores and memory. A request reserves scheduler resources; cgroup v2 turns the request into a kernel boundary for the process. That is why a 128 MiB job attempting 400 MiB was killed, and why one CPU task saw one allowed CPU. `sbatch` returning a job ID only means the request was accepted into the queue; it can remain pending indefinitely under an impossible QoS request. Fair-share weights 1:2 influence priority through historical usage, but they do not promise a fixed per-job dispatch ratio.

## 5. Automation, monitoring and evidence

Ansible describes the desired host state and applies it in dependency order: names/time, identity, storage, Munge, accounting, scheduler, module, monitoring. A second run with zero changes is evidence that the declared state converged on this cluster. A static GitHub workflow checks syntax and secret paths without private VMs. The live verification playbook checks cross-service reality: names, NSS, NFS, daemons, scheduler registration and scrape targets. Neither static syntax nor an Ansible success recap alone proves a student's job will run; the `srun`, `sbatch`, cgroup and fault probes supply that evidence.

Prometheus periodically samples node exporters. An `up` target means the exporter was reachable at the last scrape, not that Slurm can schedule a job or NFS can serve files. This is why diagnosis starts from the user's symptom and follows service boundaries, rather than treating one green dashboard as overall health.

## 6. Reading the results correctly

The 24 tiny jobs completed at 1.48 jobs/s in one observed run. Their total time includes submission, scheduling, process startup and polling; the 24 programs together reported only 0.430 s of compute time. We did not profile the overhead into separate components, so it says little about CPU scaling. A CPU speedup experiment would need comparable serial and parallel workloads, repeat runs, stable host load and explicit thread/core placement. A host SMT comparison would also need the same workload and guest pinning under both host settings. The report records the absence of those controls rather than claiming speedup from a throughput sample.

For a pending job, first ask whether the reason is resource capacity, QoS/account policy, or node availability. For a failed job, first inspect accounting state/exit code and job output, then cgroup or daemon logs. For file stalls, inspect NFS separately. These branches map directly to the fault and queue evidence in the report.
