#!/usr/bin/env bash
# Reboot an existing compute VM and measure restoration; no image re-creation.
set -euo pipefail
node="${1:-compute03}"
case "$node" in compute01|compute02|compute03) ;; *) exit 2 ;; esac
if [[ -n $(ansible controller -m shell -a 'squeue -h' | tail -n +2) ]]; then
  echo 'Refusing to reboot while jobs are queued or running' >&2
  exit 1
fi
vm() { sg libvirt -c "virsh -c qemu:///system $*"; }
vm shutdown "$node"
for i in $(seq 1 60); do
  [[ $(vm domstate "$node" | tr -d '\r') == 'shut off' ]] && break
  sleep 1
done
[[ $(vm domstate "$node" | tr -d '\r') == 'shut off' ]]
start_ns=$(date +%s%N)
vm start "$node" >/dev/null
for i in $(seq 1 60); do
  if ansible "$node" -m ping -e ansible_ssh_timeout=2 >/dev/null 2>&1; then break; fi
  sleep 1
done
ansible "$node" -m ping >/dev/null
ssh_ns=$(date +%s%N)
ansible-playbook ansible/playbooks/site.yml --limit "$node" > /tmp/mini-hpc-warm-site.log
site_ns=$(date +%s%N)
for i in $(seq 1 30); do
  if ansible controller -m shell -a "sinfo -N -h -o '%N|%t' | sort -u" | grep -q "$node|idle"; then break; fi
  sleep 1
done
idle_ns=$(date +%s%N)
awk -v s="$start_ns" -v h="$ssh_ns" -v c="$site_ns" -v i="$idle_ns" 'BEGIN {printf "boot_to_ssh=%.3f boot_to_site=%.3f boot_to_idle=%.3f\n", (h-s)/1e9, (c-s)/1e9, (i-s)/1e9}'
tail -n 6 /tmp/mini-hpc-warm-site.log
