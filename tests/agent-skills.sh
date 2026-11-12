#!/bin/bash
# Personal agent skills and plugins: skills are portable and Claude-linked; the
# modify_ templates add plugin entries without disturbing app-written config.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
printf '[data]\nfixture = true\n' > "$WORK/none.toml"
render() { # render <template-file> < input
    chezmoi --source "$HERE" --config "$WORK/none.toml" execute-template --with-stdin "$(cat "$1")"
}

skills="$HERE/dot_agents/skills"
links="$HERE/dot_claude/skills"
[[ -d "$skills" ]] || fail "no dot_agents/skills"

# Every personal skill is linked for Claude, and every link has a skill.
for d in "$skills"/*/; do
    n="$(basename "$d")"
    [[ -f "$d/SKILL.md" ]] || fail "$n has no SKILL.md"
    [[ "$(cat "$links/symlink_$n" 2>/dev/null)" == "../../.agents/skills/$n" ]] \
        || fail "$n is not linked into ~/.claude/skills"
done
for l in "$links"/symlink_*; do
    [[ -d "$skills/$(basename "$l" | sed 's/^symlink_//')" ]] || fail "dangling Claude link $l"
done

# Portable and publishable: no home paths, no project mappings in the skills.
if grep -rnE '/Users/|/home/' "$skills"; then fail "home path in a skill"; fi
[[ ! -d "$skills/personal-beads/references" ]] || fail "project mappings belong in tracker workspaces"
grep -q 'TRACKER.md' "$skills/personal-beads/SKILL.md" || fail "personal-beads must discover TRACKER.md"

# Third-party skills come from upstream for both agents.
installer="$HERE/run_onchange_after_install-agent-skills.sh.tmpl"
render "$installer" < /dev/null > "$WORK/install.sh"
bash -n "$WORK/install.sh"
for repo in t3dotgg/tstack vercel-labs/skills mwunsch/termscope mattpocock/skills DietrichGebert/ponytail; do
    grep -q "$repo" "$WORK/install.sh" || fail "installer misses $repo"
done

# Claude settings: entries added, other keys kept, already-correct input untouched.
claude="$HERE/dot_claude/modify_private_settings.json"
render "$claude" < /dev/null > "$WORK/empty.json"
printf '{"model":"opus","enabledPlugins":{"x@y":false},"permissions":{"allow":["Bash(ls)"]}}' > "$WORK/in.json"
render "$claude" < "$WORK/in.json" > "$WORK/merged.json"
render "$claude" < "$WORK/merged.json" > "$WORK/again.json"
cmp -s "$WORK/merged.json" "$WORK/again.json" || fail "Claude settings modify is not idempotent"
python3 - "$WORK" <<'PY'
import json, pathlib, sys
w = pathlib.Path(sys.argv[1])
for name in ('empty.json', 'merged.json'):
    d = json.loads((w / name).read_text())
    assert d['enabledPlugins']['ponytail@ponytail'] is True, name
    assert d['extraKnownMarketplaces']['ponytail']['source'] == {'source': 'github', 'repo': 'DietrichGebert/ponytail'}, name
d = json.loads((w / 'merged.json').read_text())
assert d['model'] == 'opus' and d['permissions'] == {'allow': ['Bash(ls)']}
assert d['enabledPlugins']['x@y'] is False, 'must not touch other plugins'
PY

# Codex config: tables appended once, existing text byte-for-byte preserved.
codex="$HERE/dot_codex/modify_private_config.toml"
render "$codex" < /dev/null > "$WORK/empty.toml"
[[ "$(head -c1 "$WORK/empty.toml")" == "[" ]] || fail "new Codex config starts with a blank line"
printf '# mine\nmodel = "gpt-5"\n\n[projects."/x"]\ntrust_level = "trusted"' > "$WORK/in.toml"
render "$codex" < "$WORK/in.toml" > "$WORK/merged.toml"
render "$codex" < "$WORK/merged.toml" > "$WORK/again.toml"
cmp -s "$WORK/merged.toml" "$WORK/again.toml" || fail "Codex config modify is not idempotent"
[[ "$(head -c "$(wc -c < "$WORK/in.toml")" "$WORK/merged.toml")" == "$(cat "$WORK/in.toml")" ]] \
    || fail "Codex config modify rewrote existing text"
printf '[plugins."ponytail@ponytail"]\nenabled = false\n' > "$WORK/off.toml"
render "$codex" < "$WORK/off.toml" > "$WORK/off-out.toml"
python3 - "$WORK" <<'PY'
import pathlib, sys, tomllib
w = pathlib.Path(sys.argv[1])
for name in ('empty.toml', 'merged.toml'):
    d = tomllib.loads((w / name).read_text())
    assert d['plugins']['ponytail@ponytail']['enabled'] is True, name
    assert d['marketplaces']['ponytail'] == {'source_type': 'git', 'source': 'https://github.com/DietrichGebert/ponytail.git'}, name
d = tomllib.loads((w / 'merged.toml').read_text())
assert d['model'] == 'gpt-5' and d['projects']['/x']['trust_level'] == 'trusted'
off = tomllib.loads((w / 'off-out.toml').read_text())
assert off['plugins']['ponytail@ponytail']['enabled'] is False, 'a deliberate disable must stick'
PY

# chezmoi must manage settings.json despite the .claude/*.json ignore, and keep
# both config files private (the apps write them 0600).
managed="$(chezmoi --source "$HERE" --config "$WORK/none.toml" managed --path-style source-relative)"
grep -qx 'dot_claude/modify_private_settings.json' <<<"$managed" || fail "Claude settings.json not managed as private"
grep -qx 'dot_codex/modify_private_config.toml' <<<"$managed" || fail "Codex config.toml not managed as private"

echo "PASS: skills portable and Claude-linked; plugin config merges idempotently"
