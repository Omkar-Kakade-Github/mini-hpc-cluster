# Phase 1 evidence: virtual machine bootstrap

**Observed:** 2026-09-27, on one Ubuntu 24.04 laptop. This is a VM-layer
verification record, not a Slurm performance result.

## Method

Each VM was created from a separate copy of the Ubuntu 24.04 cloud image whose
SHA-256 digest is pinned in `infrastructure/images/ubuntu-24.04.sha256`.
Cloud-init received a unique hostname and instance ID. The libvirt network
assigned addresses from fixed MAC-to-IP reservations. Checks included
`virsh list --all`, `virsh net-dhcp-leases mini-hpc`, SSH using the lab key,
`cloud-init status --wait`, `hostnamectl --static`, `nproc`,
`sudo -n true`, and the guest's SSH host-key fingerprint and machine ID.

| VM | Reserved IP | vCPUs | Assigned RAM | Cloud-init | SSH host-key fingerprint |
| --- | --- | ---: | ---: | --- | --- |
| controller | 192.168.130.10 | 4 | 4 GiB | done | `SHA256:YUs/DkOv9NYGmcaAHG84QIClzwOwHx+mhpdH0vDj6qY` |
| compute01 | 192.168.130.11 | 4 | 3 GiB | done | `SHA256:Fnc/Cdui0Esia3ZORDd0pmSHTbo3yFPTTph1Rl5OwCQ` |
| compute02 | 192.168.130.12 | 4 | 3 GiB | done | `SHA256:X8TU4Wk5XzN9o+daANOx5tvGPjC41oYJQE37HxHCg6A` |
| compute03 | 192.168.130.13 | 4 | 3 GiB | done | `SHA256:7j3YW4bTn5Y7L6aFgOL4UTTH7yhdfqQSzTDWDPoxVKI` |

All four VMs appeared as running in libvirt. Their hostnames matched their
reserved leases; SSH and passwordless lab administration worked. The four
machine IDs were distinct. This supports that the compute nodes were
initialized as separate guests rather than copied from the already booted
controller.

## Scope of this observation

The 40 GiB disks are virtual capacities; their host allocations grow with
writes. VMs are peers on one KVM host, so this test does not establish
multi-host availability or network performance. LDAP, NFS, Munge, Slurm,
monitoring and resource enforcement have not yet been configured. Provisioning
time, idempotency, throughput, queue behaviour, recovery time and drift have
not yet been measured under a defined procedure.
