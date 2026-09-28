# Evidence 05: identity, storage, Slurm and monitoring

Observed on 2026-09-28 on the four Ubuntu 24.04 VMs. The controller ran OpenLDAP over LDAPS and SSSD; each compute used SSSD. `ldapwhoami -x -H ldaps://controller.mini-hpc.test` succeeded from the controller and a compute node using the trusted lab CA. `getent passwd student1` on all four returned UID 20001, GID 20000 and `/home/hpc/student1`; `getent group hpc` returned GID 20000 with both students. A real SSH password login on the controller resolved the same UID/GID. The CA private key and user passwords stayed in Git-ignored `secrets/`.

The controller exported `/home/hpc` over NFSv4. `findmnt` showed all three compute mounts from `controller.mini-hpc.test:/home/hpc`. A file written by `student1` on compute01 was read from compute02; the controller reported numeric owner `20001:20000`. The probe file was removed.

A Munge credential encoded on the controller decoded on all three compute nodes. `slurmd -C` reported `CPUs=4`, one socket, four cores, one thread per core and `RealMemory=2907` MiB on each. The configured Slurm memory is 2700 MiB to leave guest OS headroom. `sinfo -N` reported all compute nodes `idle`. `sacctmgr` showed `team_a` share 1, `team_b` share 2, and both LDAP users associated with `normal,short` QoS. `student1` and `student2` each ran a real `srun` command; the job processes showed their LDAP UIDs and GID 20000.

The controller's Prometheus target API returned `up` for `192.168.130.10:9100` through `.13:9100`. The four node exporters and controller Prometheus were active. This verifies metrics ingestion, not alerting or long-term retention.

A final `verify-cluster.yml` integration run reported zero failures and zero changes on all four hosts. After a reboot, compute03 initially showed `systemd-1` as the `/home/hpc` automount source until a directory access triggered NFS; the verification playbook now triggers the mount before checking its source.
