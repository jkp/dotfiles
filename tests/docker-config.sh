#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
printf '[data]\nfixture = true\n' > "$WORK/none.toml"
source_file="$HERE/dot_docker/config.json.tmpl"
[[ -f "$source_file" ]] || source_file="$HERE/dot_docker/config.json"
for platform in darwin linux; do
    chezmoi --source "$HERE" --config "$WORK/none.toml" execute-template \
        --override-data "{\"chezmoi\":{\"os\":\"$platform\"}}" < "$source_file" > "$WORK/$platform.json"
done
python3 - "$WORK" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
mac = json.loads((root / 'darwin.json').read_text())
linux = json.loads((root / 'linux.json').read_text())
assert mac['currentContext'] == 'colima'
assert mac['cliPluginsExtraDirs'] == ['/opt/homebrew/lib/docker/cli-plugins']
assert linux.get('currentContext', 'default') == 'default', 'Linux must use Docker Engine default context'
assert 'cliPluginsExtraDirs' not in linux, 'Linux must use standard plugin discovery'
assert 'osxkeychain' not in json.dumps(linux), 'Linux cannot use macOS credential helpers'
assert {k: v for k, v in mac.items() if k not in ('currentContext', 'cliPluginsExtraDirs')} == linux
assert set(linux['credHelpers'].values()) == {'gcloud'}
print('PASS: macOS keeps Colima/Homebrew; Linux uses default context and portable settings')
PY
