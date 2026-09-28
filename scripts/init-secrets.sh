#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
secret_dir="$project_root/secrets"
umask 077
mkdir -p "$secret_dir"

for name in ldap_admin_password student1_password student2_password slurm_db_password; do
  if [[ ! -s "$secret_dir/$name" ]]; then
    openssl rand -hex 24 > "$secret_dir/$name"
  fi
done

if [[ ! -s "$secret_dir/munge.key" ]]; then
  openssl rand -out "$secret_dir/munge.key" 1024
fi

if [[ ! -s "$secret_dir/lab-ca.key" ]]; then
  openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 \
    -out "$secret_dir/lab-ca.key" >/dev/null 2>&1
fi
if [[ ! -s "$secret_dir/lab-ca.crt" ]]; then
  openssl req -x509 -new -sha256 -days 3650 \
    -key "$secret_dir/lab-ca.key" -out "$secret_dir/lab-ca.crt" \
    -subj '/CN=Mini HPC Lab CA' \
    -addext 'basicConstraints=critical,CA:TRUE' \
    -addext 'keyUsage=critical,keyCertSign,cRLSign'
fi

if [[ ! -s "$secret_dir/controller.key" ]]; then
  openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
    -out "$secret_dir/controller.key" >/dev/null 2>&1
fi
if [[ ! -s "$secret_dir/controller.crt" ]]; then
  work_dir=$(mktemp -d "$secret_dir/.cert-work.XXXXXX")
  trap 'rm -rf -- "$work_dir"' EXIT
  cat > "$work_dir/server.ext" <<'EXT'
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:controller.mini-hpc.test,DNS:controller,IP:192.168.130.10
EXT
  openssl req -new -sha256 -key "$secret_dir/controller.key" \
    -out "$work_dir/server.csr" -subj '/CN=controller.mini-hpc.test'
  openssl x509 -req -sha256 -days 825 \
    -in "$work_dir/server.csr" -CA "$secret_dir/lab-ca.crt" \
    -CAkey "$secret_dir/lab-ca.key" -CAcreateserial \
    -extfile "$work_dir/server.ext" -out "$secret_dir/controller.crt" \
    >/dev/null 2>&1
fi

python3 - "$secret_dir" <<'HASHES'
import base64
import hashlib
import os
from pathlib import Path
import sys

root = Path(sys.argv[1])
for name in ("student1", "student2"):
    destination = root / f"{name}_ssha"
    if destination.exists():
        continue
    password = (root / f"{name}_password").read_text().strip().encode()
    salt = os.urandom(16)
    digest = hashlib.sha1(password + salt).digest()
    destination.write_text("{SSHA}" + base64.b64encode(digest + salt).decode() + "\n")
    destination.chmod(0o600)
HASHES

openssl verify -CAfile "$secret_dir/lab-ca.crt" "$secret_dir/controller.crt" >/dev/null
chmod 0600 "$secret_dir"/*
printf 'Lab secrets present; server certificate verifies against lab CA.\n'
