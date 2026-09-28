#!/usr/bin/env bash
set -euo pipefail
for script in scripts/*.sh; do
  bash -n "$script"
done
python3 - <<'PY'
import ast
from pathlib import Path
for path in Path('workloads').glob('*.py'):
    ast.parse(path.read_text(), filename=str(path))
PY
for playbook in ansible/playbooks/*.yml; do
  ansible-playbook --syntax-check "$playbook"
done
if [[ -n $(git ls-files 'secrets/*' '.local/*' '*.key' '*.pem') ]]; then
  printf 'A local secret or generated VM artifact is tracked by Git\n' >&2
  exit 1
fi
