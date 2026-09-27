#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cache_dir="$project_dir/.local/cache"
image_name="ubuntu-24.04-server-cloudimg-amd64.img"
image_url="https://cloud-images.ubuntu.com/releases/noble/release/$image_name"

install -d -m 0700 "$cache_dir"
if [[ ! -f "$cache_dir/$image_name" ]]; then
    curl --fail --location --retry 3 --output "$cache_dir/$image_name" "$image_url"
fi
(
    cd "$cache_dir"
    sha256sum --check "$project_dir/infrastructure/images/ubuntu-24.04.sha256"
)
