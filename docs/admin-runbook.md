# Administrator runbook

Run host commands from the repository root on the Ubuntu laptop. Guest commands in examples use `ansible` and become root when needed. The VM scripts and inventory assume the fixed address and MAC plan in [architecture.md](architecture.md).

## Host preparation and first deployment

1. Install KVM/libvirt, `virt-install`, `cloud-localds`, `qemu-img`, `setfacl`, OpenSSH, Ansible Core 2.16, and the collections in `ansible/collections/requirements.yml`. Confirm `/dev/kvm` exists and your login can use `qemu:///system`. Install collections with `ansible-galaxy collection install -r ansible/collections/requirements.yml`.
2. Define and start `infrastructure/libvirt/network.xml` in system libvirt: `virsh -c qemu:///system net-define infrastructure/libvirt/network.xml`, `virsh -c qemu:///system net-start mini-hpc`, and `virsh -c qemu:///system net-autostart mini-hpc`. Skip `net-define` when the network already exists. On this laptop, `sg libvirt -c 'virsh -c qemu:///system net-list --all'` works if the current shell has not refreshed group membership.
3. Run `scripts/init-secrets.sh` once and back up `secrets/` privately. Run `scripts/create-controller.sh`, then `scripts/create-compute.sh compute01`, `compute02`, and `compute03`. Each `prepare-*` script verifies the pinned Ubuntu image SHA-256 before making a distinct guest disk and cloud-init seed. Existing disks are preserved by the scripts.
4. Before adding SSH host keys, compare each guest's Ed25519 fingerprint from its libvirt console with the fingerprints in [VM bootstrap evidence](../report/evidence/01-vm-bootstrap.md). Only after matching, save each guest key in `.local/known_hosts`. For a first enrollment, `mkdir -p .local; ssh-keyscan -t ed25519 192.168.130.10 192.168.130.11 192.168.130.12 192.168.130.13 > .local/known_hosts.candidate; ssh-keygen -lf .local/known_hosts.candidate` produces fingerprints to compare with the guest consoles before `mv .local/known_hosts.candidate .local/known_hosts`. An unexpected key change is an investigation, not an automatic update. Check `ansible all -m ping` with strict host checking.
5. Apply `ansible-playbook ansible/playbooks/site.yml`. Run it again and inspect `PLAY RECAP`: the expected steady state is `changed=0 failed=0` on every VM. `scripts/check-static.sh` checks repository syntax without contacting guests.

Never commit `secrets/` or `.local/`; `.gitignore` excludes them. A fresh `secrets/` directory on an already configured cluster changes its trust roots and will break authentication. Restore the original backup instead.

## Start, stop, and health

Start the NAT network if needed, then `virsh -c qemu:///system start controller` and `virsh -c qemu:///system start compute01` through `compute03`. Wait for `ansible all -m ping`. To stop cleanly, ensure `squeue` is empty and shut down compute guests before the controller. `scripts/measure-warm-start.sh compute03` is a deliberate existing-VM reboot measurement; it refuses to run while jobs are queued or running.

The read-only `ansible-playbook ansible/playbooks/verify-cluster.yml` checks identity, service state, lazy NFS mounts, scheduler registration, and all four Prometheus targets. It accesses a shared home path before asking `findmnt` for the NFS source because an idle systemd automount initially appears as `systemd-1`.

From the laptop:

```bash
ansible all -m ping
ansible controller -b -m shell -a 'systemctl is-active slapd nfs-kernel-server munge mariadb slurmdbd slurmctld prometheus; sinfo -N -h -o "%N %t %E" | sort -u'
ansible compute -b -m shell -a 'systemctl is-active sssd munge slurmd prometheus-node-exporter; findmnt -n /home/hpc'
ansible controller -b -m shell -a 'sacctmgr -n -P show assoc format=Cluster,Account,User,Share,QOS; sacct -n -P -X -S now-1day -o JobID,User,State,ExitCode'
```

Prometheus listens on controller port 9090 and scrapes each node exporter on port 9100 every 15 seconds. Check target health through `http://192.168.130.10:9090/targets` from the laptop or its JSON API. The lab network is private; no external access control or alerting is configured for this dashboard.

## Diagnose a pending or failed job

1. `squeue -j JOBID -o '%i %T %R %N'` gives the live state and reason; `scontrol show job JOBID` gives requested account, QoS, nodes, memory, CPU and time. `Resources` means capacity is occupied; `ReqNodeNotAvail` points to a requested down/drained node; `QOSMaxWallDurationPerJobLimit` or `QOSMaxJobsPerUserLimit` points to accounting policy.
2. `sinfo -N -o '%N %t %E'` and `scontrol show node compute03` reveal node state and drain reason. Inspect `journalctl -u slurmd` on that node and `journalctl -u slurmctld` on the controller. Only resume after the underlying fault is fixed: `scontrol update NodeName=compute03 State=RESUME`.
3. For an exited job, `sacct -j JOBID --format=JobID,JobName,State,ExitCode,Elapsed,AllocCPUS,ReqMem,MaxRSS` and the user's `slurm-JOBID.out` separate an application error from a scheduler failure. An `OUT_OF_MEMORY` step plus `slurmstepd` OOM log means its requested memory was exceeded. Use `scontrol show job` while the job is live; some detail disappears from the controller after completion.
4. If identity or files look wrong, use `getent passwd student1`, `id student1`, `systemctl status sssd`, and `findmnt /home/hpc`. Check `systemctl status slapd nfs-kernel-server` on the controller, certificate validity with `openssl s_client -connect controller.mini-hpc.test:636 -CAfile /etc/ssl/certs/ca-certificates.crt`, and clock state with `chronyc tracking` or `timedatectl`.
5. If `sinfo` cannot contact the controller, check `systemctl status slurmctld munge slurmdbd mariadb`, then `journalctl -u slurmctld -u slurmdbd -n 100 --no-pager`. A valid Munge credential from the controller should decode on every compute node; `ansible-playbook ansible/playbooks/verify-munge.yml` performs that cross-node test.

## Safe failure exercises and drift

Run only when no user jobs matter. For controller daemon loss, stop `slurmctld`, verify `sinfo` fails, start it and wait for `sinfo` plus all node states. For node loss, stop `slurmd` on `compute03`, set it `DRAIN` with a reason, observe a node-pinned job pending, restart `slurmd`, then `RESUME` and wait for `idle`. For NFS loss, stop `nfs-kernel-server`, use `timeout -k 2s 4s` around a write on one compute node, start NFS immediately, and retry. A hard NFS mount can block I/O until the server returns; do not leave it stopped. See [failure evidence](../report/evidence/07-failure-injection.md) for measured outcomes.

Detect configuration drift with `ansible-playbook ansible/playbooks/site.yml --check --diff`; apply the same playbook to reconcile. `--check` reports proposed handler changes as well as file changes; a real apply followed by another check verifies that drift is gone. The [drift evidence](../report/evidence/08-drift.md) shows a harmless `slurm.conf` comment inserted and removed.

## Backup and handover

Back up `secrets/`, the controller's MariaDB database (`mariadb-dump slurm_acct_db`), `/var/lib/slurm/slurmctld`, and `/home/hpc` to a private location. Keep the repository and image checksum alongside the backup. Restore the same Munge key, CA and LDAP credentials before reapplying Ansible. Rotating a student password requires replacing both its local password file and SSHA hash, updating LDAP, and considering SSSD's cached credentials; `scripts/init-secrets.sh` intentionally does not rewrite existing hashes. The database and controller state are not recreated from Git alone. See [handover.md](handover.md) for ownership and unresolved limitations.
