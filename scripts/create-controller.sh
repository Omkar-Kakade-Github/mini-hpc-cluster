#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
vm_dir="$project_dir/.local/vms"
"$project_dir/scripts/prepare-controller.sh" >&2

virsh -c qemu:///system list --all >/dev/null
if virsh -c qemu:///system dominfo controller >/dev/null 2>&1; then
    echo "Controller VM already exists"
    exit 0
fi

virt-install \
    --connect qemu:///system \
    --name controller \
    --memory 4096 \
    --vcpus 4,sockets=1,cores=4,threads=1 \
    --cpu host-passthrough \
    --disk "path=$vm_dir/controller.qcow2,format=qcow2,bus=virtio" \
    --disk "path=$vm_dir/controller-seed.iso,device=cdrom,readonly=on" \
    --network "network=mini-hpc,model=virtio,mac=52:54:00:13:00:10" \
    --osinfo ubuntu24.04 \
    --import \
    --graphics none \
    --console pty,target_type=serial \
    --noautoconsole \
    "$@"
