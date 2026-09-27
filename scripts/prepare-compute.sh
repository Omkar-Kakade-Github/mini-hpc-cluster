#!/usr/bin/env bash
set -euo pipefail
umask 077

node="${1:-}"
case "$node" in
    compute01|compute02|compute03) ;;
    *) echo "Usage: $0 compute01|compute02|compute03" >&2; exit 2 ;;
esac

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
vm_dir="$project_dir/.local/vms"
base_image="$project_dir/.local/cache/ubuntu-24.04-server-cloudimg-amd64.img"
disk_path="$vm_dir/$node.qcow2"
seed_path="$vm_dir/$node-seed.iso"
key_path="$project_dir/secrets/lab_admin_ed25519"

grant_qemu_access() {
    local user_home
    user_home="$(getent passwd "$(id -un)" | cut -d: -f6)"
    setfacl -m u:libvirt-qemu:--x "$user_home"
    setfacl -m u:libvirt-qemu:--x "$project_dir/.local"
    setfacl -m u:libvirt-qemu:--x,m::--x "$vm_dir"
    setfacl -m u:libvirt-qemu:rw-,m::rw- "$disk_path"
    setfacl -m u:libvirt-qemu:r--,m::r-- "$seed_path"
}

"$project_dir/scripts/fetch-image.sh"
[[ -f "$key_path" && -f "$key_path.pub" ]] || {
    echo "Controller lab SSH key is required: $key_path" >&2
    exit 1
}
install -d -m 0700 "$vm_dir"

if [[ -e "$disk_path" ]]; then
    [[ -f "$seed_path" ]] || { echo "$node disk exists without seed ISO" >&2; exit 1; }
    grant_qemu_access
    echo "$node boot files already prepared"
    exit 0
fi

public_key="$(cat "$key_path.pub")"
cat > "$vm_dir/$node-user-data" <<USER_DATA
#cloud-config
hostname: $node
manage_etc_hosts: true
ssh_pwauth: false
disable_root: true
users:
  - name: ubuntu
    groups: [sudo]
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - "$public_key"
USER_DATA
cat > "$vm_dir/$node-meta-data" <<META_DATA
instance-id: mini-hpc-$node-001
local-hostname: $node
META_DATA

cloud-localds "$seed_path" "$vm_dir/$node-user-data" "$vm_dir/$node-meta-data"
cp "$base_image" "$disk_path"
qemu-img resize -f qcow2 "$disk_path" 40G
grant_qemu_access

echo "$node disk and first-boot seed prepared"
