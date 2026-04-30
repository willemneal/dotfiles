# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A chezmoi-managed dotfiles repo. Primary target: macOS (specifically a host named `mai` for AI dev work). Linux support is partial — only terminal/zellij configs render. There is no build step; the "code" is configuration that chezmoi renders + applies into `$HOME`.

The README is comprehensive (~32 KB) — read it for user-facing walkthroughs. This file covers the non-obvious operational conventions.

## Common commands

```sh
chezmoi diff                  # preview pending changes — do this before apply on any shared box
chezmoi apply -v              # render + apply to $HOME
chezmoi cd                    # jump to source dir (~/.local/share/chezmoi)
mai-doctor                    # health check for the AI dev environment (status only, never gates)
./bootstrap.sh                # fresh-Mac one-shot (hostname + chezmoi init + apply)
./bootstrap.sh --test         # uses VirtioFS-mounted source for Tart VM testing
```

To re-fire a `run_once_*` script on the next apply: edit anything in it (chezmoi content-hashes scripts; any change re-runs).

## Local template testing

CI renders every `.tmpl` across a darwin/linux × mai/other matrix. To match locally for a single file:

```sh
printf 'name="T"\nemail="t@e"\nsigning_key=""\n[chezmoi]\nos="darwin"\nhostname="mai"\n' > /tmp/o.toml
chezmoi execute-template --source="$PWD" --override-data-file=/tmp/o.toml < dot_Brewfile.tmpl
```

For shell scripts: pipe the rendered output through `shellcheck -s bash`. CI does this automatically for any rendered file with a `#!/usr/bin/env bash` shebang.

End-to-end integration test is `./bootstrap.sh --test` against a fresh Tart macOS VM with the source mounted via VirtioFS. There is no automated test suite beyond CI rendering + shellcheck.

## chezmoi conventions used here

- `dot_X` → `.X` in `$HOME` (e.g., `dot_zshrc.tmpl` → `~/.zshrc`).
- `executable_X` → `+x` on the result.
- `private_X` → `chmod 600`.
- `*.tmpl` → Go-template-rendered, suffix stripped after rendering.
- `run_once_before_NNN-name.sh.tmpl` and `run_once_after_NNN-name.sh.tmpl` run in numeric order; before init / after apply respectively. Re-run only when content hash changes.
- `.chezmoitemplates/` holds reusable partials called via `{{ template "name" . }}`. They are NOT applied directly.

## Two gating mechanisms

**OS gate** — every macOS-only file wraps its body in:

```
{{- if eq .chezmoi.os "darwin" -}}
...body...
{{ end -}}
```

On Linux this renders to empty and chezmoi skips the file.

**Host gate (AI machines)** — `.chezmoidata.toml` declares `[hosts] ai_machines = ["mai"]`. AI-specific blocks (mlx packages in the Brewfile, `030-ai-stack`, `035-iogpu-limit`, `045-time-machine`) wrap themselves in:

```
{{ if has .chezmoi.hostname .hosts.ai_machines }}
...AI-only stuff...
{{ end }}
```

The hostname must be set *before* `chezmoi apply` for these blocks to fire. `bootstrap.sh` handles this; manual installs require `sudo scutil --set HostName mai` first or a re-apply afterward.

## Run_once script order (macOS)

1. `010-install-homebrew` — bootstraps brew if missing.
2. `020-brew-bundle` — `brew bundle --file=~/.Brewfile`.
3. `025-typewhisper` — install TypeWhisper.app from GitHub releases (not on Homebrew/MAS); idempotent via `CFBundleShortVersionString` vs `tag_name`. Relies on `jq` from step 2.
4. `030-ai-stack` *(host-gated)* — uv playground at `~/ai/playground` with mlx/mlx-lm/mlx-vlm.
5. `035-iogpu-limit` *(host-gated)* — LaunchDaemon to persist `iogpu.wired_limit_mb` to ~95% of physical.
6. `040-macos-defaults` — Finder visibility, key repeat, screenshot dir, etc.
7. `045-time-machine` *(host-gated)* — exclude `~/Models`, HF cache, uv cache, playground venv.
8. `050-sudo-touchid` — Touch ID for sudo via `/etc/pam.d/sudo_local`.

## Secret handling

Never inline secrets in templates. Two patterns are in use:

- **`op://` references** read at runtime by `*-login` zsh functions in `dot_zshenv.tmpl` (`hf-login`, `gh-login`, `tailscale-up`, `openrouter-login`). The functions export the env var only when invoked — nothing runs at shell startup.
- **`op-cred <title>` / `op-creds-bootstrap`** create credentials in 1Password without exposing them in argv. Secret transits via stdin pipe through `jq -Rn ... | op item create --template -` — kernel pipe, never visible in `ps`. The credential inventory lives at `dot_config/op-creds` (one item title per line, `#` comments). **Adding a credential is a one-line config edit, not a code edit** — do not edit the function.

Defense-in-depth: `dot_config/atuin/config.toml` has a `history_filter` regex list that drops common secret-leaking patterns (op/login/--token=/--password=/api_key/HF_TOKEN/TS_AUTHKEY) before they hit the SQLite history.

## Brewfile organization

`dot_Brewfile.tmpl` is sectioned by purpose (CLI essentials, Rust replacements, Terminal stack, Editors, Dev, Productivity, Communication, Media, Creative/GPU, Games, Security, Mac App Store, Containers). Each cask has a trailing `# comment` aligned to roughly column 28; comments call out something distinguishing rather than restating the name. AI-only packages sit inside the host-gating block.

`mas` (Mac App Store CLI) lives in CLI essentials so it's installed before any `mas "Name", id: NNN` lines are reached. Order matters in a Brewfile.

## When to update README.md

The README's `020-brew-bundle` section inventories specific packages by category. **When adding/removing packages, update that list** — it's the canonical user-facing reference. The Layout section also lists every top-level file/dir; add new ones (especially under `dot_config/`) so readers don't have to grep.

`mai-doctor` counts Brewfile entries via the regex `^(brew|cask|tap|mas) "`. If you add a new top-level Brewfile keyword, extend that regex too.

## Gotchas

- **VirtioFS reads are unreliable** for chezmoi sources — `bootstrap.sh --test` copies the source into the VM's local filesystem before chezmoi reads it, rather than reading from the mount directly.
- **`uv pip show` not `uv run pip show`** — uv-managed venvs don't include `pip`, so `uv run pip show` silently fails. `mai-doctor` uses the former.
- **`op` CLI scopes auth to the parent process** when integrated with the 1Password desktop app. Auth in one terminal does not carry to others; "Allow in background" must be enabled in 1Password's macOS Login Items settings.
- **Forgetting to set hostname before apply** is harmless — AI-gated scripts render to empty and don't run. Fix the hostname, re-apply, scripts fire on the next pass.
