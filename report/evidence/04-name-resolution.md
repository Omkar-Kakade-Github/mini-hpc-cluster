# Phase 4 evidence: cluster name resolution

**Observed:** 2026-09-28. All four VMs were running on the private libvirt
network. The user selected Ansible-managed host mappings for the four fixed
addresses.

## Baseline

`getent hosts controller` failed on all three compute nodes. On the controller,
it returned `127.0.1.1 controller`. `getent hosts compute01` failed on the
controller. The compute resolver used `192.168.130.1` as its DNS server, but
had no search domain. The guest `/etc/hosts` files contained only loopback and
self-name entries.

Cloud-init's generated `/etc/hosts` header said `manage_etc_hosts` was true.
Both VM bootstrap scripts explicitly set this in user-data. Cloud-init would
rewrite `/etc/hosts` at boot from `/etc/cloud/templates/hosts.debian.tmpl`, so
changing only the live file would not be persistent. The base role now renders
the same inventory-derived map to the live file and the cloud-init template.
It removes the old `127.0.1.1` self-name mapping so each cluster name resolves
to its routable private address.

## Observed after applying the base role

`ansible-playbook ansible/playbooks/base-all.yml` changed the host map on all
four VMs and left the existing time services unchanged. On each VM, lookup of
`controller`, `compute01`, `compute02` and `compute03` returned respectively
`192.168.130.10`, `.11`, `.12` and `.13`. Lookup of
`controller.mini-hpc.test` returned `192.168.130.10` everywhere. `hostname -f`
returned the expected fully qualified name on every VM. A second base
playbook run reported `changed=0 failed=0` for all four VMs.

## Reboot and drift check

A first reboot of compute03 left name resolution working, but a subsequent
Ansible run reported `changed=1` for `/etc/hosts`. A dry-run diff showed that
cloud-init strips the `## template:jinja` marker from its source template,
while Ansible had written the marker into the live file. The shared template
contained no cloud-init substitutions, so the marker was removed. Running
cloud-init's `update_etc_hosts` module again then left the file identical to
Ansible's desired state (`changed=0` in check mode).

After applying the corrected template to all VMs, compute03 was rebooted a
second time. `cloud-init status --wait` returned `status: done`, and
`getent hosts controller` still returned `192.168.130.10`. A post-reboot
Ansible check on compute03 reported `changed=0`. A final full base-role run
reported `changed=0 failed=0` on all four VMs. This verifies persistence on
one rebooted compute VM and idempotency across the running cluster.

Slurm, Munge and LDAP are not yet installed, so their use of these names
remains to be verified.
