# Evidence 07: controlled failure injection

Observed on 2026-09-28 with no user production jobs. Each stopped service was restarted in the same test. Timings include Ansible/SSH command latency and one-second polling; they are recovery observations for this lab, not service-level guarantees.

| Fault | During fault | Restore and observed time |
| --- | --- | --- |
| Stop `slurmctld` | `sinfo` failed with `Unable to contact slurm controller (connect failure)` | After `systemctl start slurmctld`, `sinfo` first returned in 7.062 s but showed `unk` node state. All three nodes were later observed `idle`; the exact full-idle time was not captured. |
| Stop `slurmd` on compute03 and drain node | A job pinned to compute03 was `PENDING (ReqNodeNotAvail, UnavailableNodes:compute03)`; other nodes remained idle | Restarted `slurmd`, set `State=RESUME`; compute03 was observed `idle` after 11.620 s and the pinned job later completed. A redundant second `RESUME` returned `Invalid node state specified` because the node was already idle. |
| Stop controller NFS export | A bounded `dd ... conv=fsync` from compute02 exited 124 after a four-second timeout | After starting NFS, a fresh synchronized write succeeded 7.313 s later. Test files were removed. |

The NFS test demonstrates a hard mount's blocked I/O during an export outage. It does not prove that all running jobs survive such an outage. The controller experiment illustrates the combined single-controller failure domain; only the scheduler daemon was stopped, so LDAP and NFS were still available in that particular test.
