# Phase 3 evidence: time synchronization, controller stage

**Observed:** 2026-09-28. All four VMs were running. The controller and
three compute time clients were configured in separate Ansible chunks.

## Before the change

`timedatectl show` reported `NTP=yes` and `NTPSynchronized=yes` on all four
VMs. `timedatectl timesync-status` showed each VM using `ntp.ubuntu.com`.
Reported offsets ranged from about 1.5 to 6.1 ms in magnitude at that moment.
This showed that the clocks were synchronized then; it does not prove that they
would remain so during an outage. Ansible's ad-hoc `command` task printed
`CHANGED` for these read-only checks because that module reports execution as a
change by default. No guest configuration was modified by those checks.

## Controller change and verification

`ansible-playbook ansible/playbooks/base-controller.yml` installed Chrony,
added `allow 192.168.130.0/24` to `/etc/chrony/chrony.conf`, enabled the
service, and restarted it after the configuration change. The first run
reported `ok=5 changed=3 failed=0`. A second run reported
`ok=4 changed=0 failed=0`, confirming idempotency for this playbook on the
controller at this point.

`chronyc tracking` on the controller reported an upstream Canonical time
source, stratum 3, `Leap status: Normal`, and system time approximately
0.000000219 seconds slow at the instant checked. `ss -lun` showed a UDP
listener on `0.0.0.0:123`. The `allow` directive restricts which clients
Chrony serves; a listening socket alone does not prove that the compute VMs
are using this source.

## Compute change and verification

`ansible-playbook ansible/playbooks/base-compute.yml` added a timesyncd drop-in
with `NTP=192.168.130.10` and an empty `FallbackNTP=`. The IP is read from
the controller's Ansible inventory entry. The first run reported
`ok=5 changed=3 failed=0` on each compute node. A second run reported
`ok=4 changed=0 failed=0` on each node.

After the change, `timedatectl timesync-status` on compute01, compute02 and
compute03 selected `192.168.130.10` and reported offsets of approximately
+4.510 ms, -4.250 ms and +6.010 ms respectively. Each reported
`NTPSynchronized=yes`. `chronyc clients` on the controller recorded one NTP
request from each compute node and zero dropped requests at the time checked.
This verifies a successful initial exchange; it does not establish long-term
clock stability.

## Remaining checks

The controller-outage experiment has not been run, so free-run drift, fallback
behavior and recovery time are still predictions. No failure recovery time or
provisioning duration was measured in this stage. Munge and Slurm are not yet
installed, so their authentication behavior has not been tested.
