---
name: 1password-cli
description: Working with the 1Password CLI (`op`) on macOS — service accounts, storing tokens an agent can actually read, and `op run` env files. READ THIS FIRST if `op` hangs / times out / produces no output in a Claude session (known issue, known fix — do not debug from scratch), if the macOS keychain returns exit 36 "user interaction is not allowed", or before setting up unattended access to secrets.
---

# 1Password CLI (`op`)

## `op` hangs forever in agent/daemon sessions on macOS — run it in a container

**Symptom:** any `op` command needing the network or its daemon (`op whoami`,
`op vault list`, `op read`, `op run`, `op item ...`) hangs indefinitely when run
from a Claude Code Bash session, producing **no output at all** — not even with
`--debug`. `op --version` returns instantly. Each attempt leaves an
`op daemon --background` process blocked in `_pthread_cond_wait`. The same
commands work fine from an interactive SSH session on the same machine.

**Do not debug this from scratch. The fix:**

```bash
docker run --rm -i -e OP_SERVICE_ACCOUNT_TOKEN="$TOKEN" 1password/op:2 op vault list
```

A Linux container has no macOS keychain and no GUI session, and a service-account
token authenticates over plain HTTPS. Note the image entrypoint is **not** `op`,
so the binary must be named explicitly (`... 1password/op:2 op vault list`).

To resolve a whole env file in one pass (a drop-in for `op run --env-file`), feed
`NAME={{ op://... }}` lines to `op inject` inside the container and export the
`NAME=value` lines it returns. A working implementation lives at
`network-config/scripts/op-run-compat.sh` — it probes the native CLI first and
falls back automatically, so it is safe to use interactively too.

**Already ruled out — do not re-test:**
- an invalid token hangs identically, so it blocks *before* authentication
- op version (2.32.0 and 2.35.0 both hang; pinning a version does not help)
- `OP_BIOMETRIC_UNLOCK_ENABLED=false`, `OP_CACHE=false`, isolated `OP_CONFIG_DIR`
- disabling the Bash sandbox
- quitting the 1Password desktop app entirely
- killing stale `op daemon` processes first
- a minimal environment (`env -i`), or a pty (`script`)
- `launchctl managername` reports "Background" in both the working SSH session
  and the hanging agent session, so session type is not the discriminator

**Likely cause** (unconfirmed): agent sessions cannot reach the login keychain —
`security find-generic-password -w` returns exit **36**
(`errSecInteractionNotAllowed`) — and a SecItem call during op's early init
blocks waiting for a UI authorisation prompt that can never appear.

### Consequences for storing secrets

- **The macOS keychain is unusable from agent sessions** (exit 36), including
  after a `security set-generic-password-partition-list` stamp. Store tokens an
  agent must read in a file with mode `600` (e.g.
  `~/.local/state/<name>-token`), not the keychain. Prefer `~/.local/state` over
  `~/.config` so the secret is not swept into dotfile-sync or backups.
- **`security add-generic-password -w` truncates the interactive prompt at 128
  characters.** Service-account tokens are far longer, and the truncation is
  silent — the token only fails later, looking like an auth problem. Pass the
  value as an argument read from a file instead.

### Service accounts

- Create in the web console under **Developer → Service Accounts**; vault access
  is granted at creation time and cannot include Personal/Private vaults.
- The token is shown **once**. It cannot be retrieved later — rotation means
  create-new then delete-old.
- Verify scope with `op vault list`: whatever that prints is everything the
  token can ever read. That one command is the whole security review.
- Service accounts have **no REST API** (that is 1Password Connect, a separate
  self-hosted server). Hitting `my.1password.com/api/...` with a service-account
  token returns 401. Use the CLI.

### `op run` resolves the entire env file up front

One unresolvable `op://` reference fails the whole command, not just the line
that needs it — so a dangling reference breaks every deploy that shares the
file. Two consequences:

- Add the 1Password item **before** adding the reference; keep references to
  not-yet-created items commented out.
- Under a service account, **every** reference in the file must live in a vault
  that account can read. Mixing vaults silently breaks unattended runs.
