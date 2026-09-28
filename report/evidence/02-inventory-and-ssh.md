# Phase 2 evidence: Ansible reachability and SSH identity

**Observed:** 2026-09-27. The four VMs were running on the private
`mini-hpc` libvirt network.

## Inventory reachability

`ansible-inventory --graph` showed one host in `controllers` and three in
`compute`. `ansible all -m ansible.builtin.ping` returned `pong` and
`changed: false` for controller, compute01, compute02 and compute03.
This proves SSH login and remote Python execution through the chosen inventory;
it does not prove that any cluster service is configured.

## Stale host-key experiment

A temporary `known_hosts` file associated compute01's IP with the
controller's SSH host public key. SSH to compute01 with strict host-key
checking returned `REMOTE HOST IDENTIFICATION HAS CHANGED` and exit status
`255`. A subsequent `virsh domstate compute01` returned `running`.
The real `.local/known_hosts` file was not changed.

The failure was at server identity verification on the laptop, before user
authentication against `authorized_keys` inside compute01. An unexpected
host-key change must be investigated before replacing the saved key. A VM
rebuild at the same IP is one legitimate cause.
