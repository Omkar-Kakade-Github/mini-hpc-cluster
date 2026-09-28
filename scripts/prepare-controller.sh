#!/usr/bin/env bash
set -euo pipefail
umask 077

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
vm_dir="$project_dir/.local/vms"
secret_dir="$project_dir/secrets"
image_name="ubuntu-24.04-server-cloudimg-amd64.img"
base_image="$project_dir/.local/cache/$image_name"
disk_path="$vm_dir/controller.qcow2"
seed_path="$vm_dir/controller-seed.iso"
key_path="$secret_dir/lab_admin_ed25519"

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
install -d -m 0700 "$vm_dir" "$secret_dir"

if [[ -e "$disk_path" && ! -f "$key_path" ]]; then
    echo "Existing controller disk needs its original lab SSH key: $key_path" >&2
    exit 1
fi
if [[ ! -f "$key_path" ]]; then
    ssh-keygen -q -t ed25519 -N '' -C mini-hpc-lab -f "$key_path"
fi
if [[ -e "$disk_path" ]]; then
    [[ -f "$seed_path" ]] || { echo "Controller disk exists without its seed ISO" >&2; exit 1; }
    grant_qemu_access
    echo "Controller boot files already prepared"
    exit 0
fi

public_key="$(cat "$key_path.pub")"
cat > "$vm_dir/controller-user-data" <<USER_DATA
#cloud-config
hostname: controller
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
cat > "$vm_dir/controller-meta-data" <<'META_DATA'
instance-id: mini-hpc-controller-001
local-hostname: controller
META_DATA

cloud-localds "$seed_path" "$vm_dir/controller-user-data" "$vm_dir/controller-meta-data"
cp "$base_image" "$disk_path"
qemu-img resize -f qcow2 "$disk_path" 40G

grant_qemu_access

echo "Controller disk and first-boot seed prepared"
