# Evidence 08: idempotency and drift

Observed on 2026-09-28. A complete `ansible-playbook ansible/playbooks/site.yml` steady-state run took 32.66 s and reported `changed=0 failed=0` on controller and all three compute nodes. A final full replay after MariaDB tuning and policy reconciliation took 35.76 s, again with `changed=0 failed=0` on all four. A later existing-VM restart of compute03 reached SSH in 10.002 s, completed its limited site replay in 24.138 s from start, and was observed `idle` at 24.645 s; that replay also reported `changed=0 failed=0`. These are repeat and warm-start times, not fresh-image provisioning times.

For file drift, a harmless `# lab drift probe` comment was appended to compute02's `/etc/slurm/slurm.conf`. A check-mode `--diff` run showed exactly that line's removal and `changed=2` on compute02 (template plus simulated restart handler), zero on other hosts. An apply removed it and restarted `slurmd`; a final check showed zero changes on all four nodes.

For database policy drift, the `short` QoS `MaxJobsPU` was changed from 2 to 3. `sacctmgr` confirmed `short|3`. The Slurm policy playbook reported one change and restored `short|2`. Another policy run was already observed at `changed=0`. The role now checks and restores QoS values, parent account shares, user default accounts, and user QoS associations rather than merely creating missing rows.

`scripts/check-static.sh` passed locally after it exposed and prompted repair of a pre-existing syntax typo in `scripts/prepare-controller.sh`. The GitHub Actions workflow contains the same static checks but had not run remotely when this evidence was recorded.
