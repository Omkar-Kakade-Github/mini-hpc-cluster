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
python3 - <<'PYLINKS'
from pathlib import Path
import re

paths = [Path('README.md'), *Path('docs').glob('*.md'), *Path('report').rglob('*.md')]
for path in paths:
    for target in re.findall(r'\[[^]]+\]\(([^)]+)\)', path.read_text()):
        if target.startswith(('http://', 'https://', 'mailto:', '#')):
            continue
        relative = target.split('#', 1)[0]
        if not (path.parent / relative).exists():
            raise SystemExit(f'{path}: broken link to {target}')
print(f'Checked relative links in {len(paths)} Markdown files')
PYLINKS
for playbook in ansible/playbooks/*.yml; do
  ansible-playbook --syntax-check "$playbook"
done
if [[ -n $(git ls-files 'secrets/*' '.local/*' '*.key' '*.pem') ]]; then
  printf 'A local secret or generated VM artifact is tracked by Git\n' >&2
  exit 1
fi
