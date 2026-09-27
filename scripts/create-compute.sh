#!/usr/bin/env bash
set -euo pipefail

node="${1:-}"
case "$node" in
    compute01) mac="52:54:00:13:00:11" ;;
    compute02) mac="52:54:00:13:00:12" ;;
    compute03) mac="52:54:00:13:00:13" ;;
    *) echo "Usage: $0 compute01|compute02|compute03 [--print-xml]" >&2; exit 2 ;;
esac
shift

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
vm_dir="$project_dir/.local/vms"
"$project_dir/scripts/prepare-compute.sh" "$node" >&2

virsh -c qemu:///system list --all >/dev/null
if virsh -c qemu:///system dominfo "$node" >/dev/null 2>&1; then
    echo "$node VM already exists"
    exit 0
fi

virt-install \
    --connect qemu:///system \
    --name "$node" \
    --memory 3072 \
    --vcpus 4,sockets=1,cores=4,threads=1 \
    --cpu host-passthrough \
    --disk "path=$vm_dir/$node.qcow2,format=qcow2,bus=virtio" \
    --disk "path=$vm_dir/$node-seed.iso,device=cdrom,readonly=on" \
    --network "network=mini-hpc,model=virtio,mac=$mac" \
    --osinfo ubuntu24.04 \
    --import \
    --graphics none \
    --console pty,target_type=serial \
    --noautoconsole \
    "$@"
