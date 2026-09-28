# Handover

## What is delivered

The repository contains libvirt network and cloud-image bootstrap scripts, fixed Ansible inventory and roles, Slurm policy, example workloads, a static GitHub Actions validation workflow, administrator and user guides, failure notes, and a measured Markdown report. The deployed four-VM cluster was validated on 2026-09-28. `ansible/playbooks/site.yml` is the entry point for desired state; `scripts/check-static.sh` is the offline gate. The live laptop and its untracked local artifacts are required for live tests.

## What the next administrator must preserve

- Keep a private backup of `secrets/`, controller MariaDB/accounting state, `/var/lib/slurm/slurmctld`, and `/home/hpc`. Git does not contain these.
- Keep VM MAC addresses and inventory IPs together. Changing one requires updating libvirt leases, inventory, host mappings, certificate SANs, and possibly the deployed trust material.
- Inspect SSH host-key changes before updating `.local/known_hosts`; a legitimate rebuild and an impersonation attempt otherwise look similar to SSH.
- Reapply the site playbook after intended changes and expect a steady-state `changed=0`. Review diffs and service restarts before changing scheduler or identity policy.
- Keep an eye on host free disk, guest memory, NFS availability, controller time, and Prometheus target health. The 40 GiB guest disks are thin allocated.

## Boundaries and next work

One controller carries LDAP, NFS, time, accounting, scheduling and monitoring, and all VMs share one laptop. No HA, off-host backup automation, production certificate lifecycle, alerting, mail delivery, role-based LDAP administration, or host SMT comparison is implemented. MariaDB's 512 MiB InnoDB pool is deliberately below SchedMD's production minimum because the controller has 4 GiB total RAM; large accounting databases or upgrades need a larger controller and retuning. The Slurm PMIx plugin logs a load warning because no PMIx runtime is installed; CPU and non-MPI jobs were tested, MPI jobs were not. A fresh-from-image end-to-end provisioning clock was not captured; warm boot and idempotent apply were measured instead.

The highest-value next experiments are a host SMT on/off benchmark with controlled host load, a second physical host for real network/failure boundaries, and persistent off-host backups. Do not present the single-laptop measurements as multi-node hardware scaling.
