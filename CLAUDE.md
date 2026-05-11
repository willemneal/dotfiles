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
- `run_after_NNN-name.sh.tmpl` (no `_once`) runs every apply, in numeric order alongside the `run_once_after_*` scripts. Used for invariants that drift, not one-time setup.
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

## Script run order (macOS)

1. `010-install-homebrew` — bootstraps brew if missing.
2. `020-brew-bundle` — `brew bundle --file=~/.Brewfile`.
3. `022-fpath-perms` *(every apply)* — `chmod g-w,o-w` any compaudit-flagged dir. Homebrew leaves `/opt/homebrew/share` 775; trips zsh's `compinit` on a fresh shell.
4. `025-typewhisper` — install TypeWhisper.app from GitHub releases (not on Homebrew/MAS); idempotent via `CFBundleShortVersionString` vs `tag_name`. Relies on `jq` from step 2.
5. `030-ai-stack` *(host-gated)* — uv playground at `~/ai/playground` with mlx/mlx-lm/mlx-vlm.
6. `035-iogpu-limit` *(host-gated)* — LaunchDaemon to persist `iogpu.wired_limit_mb` to ~95% of physical.
7. `040-macos-defaults` — Finder visibility, key repeat, screenshot dir, etc.
8. `045-time-machine` *(host-gated)* — exclude `~/Models`, HF cache, uv cache, playground venv.
9. `050-sudo-touchid` — Touch ID for sudo via `/etc/pam.d/sudo_local`.
10. `055-models-repo` *(host-gated)* — `git init`s `~/Models/` as its own repo (separate history from dotfiles), seeds `.gitignore` (excludes `*.gguf`/`*.safetensors`/etc), a `README.md`, and one example model dir. Pairs with the `mai-model` CLI in `dot_local/bin/`. Weights stay in `~/.cache/huggingface/hub`.

## Local models (`mai-model`)

`~/Models/<name>/` is one model per folder, each with a `model.toml` (HF repo, runner, generation params) and `runs/` for bench logs. Weights live in the HF cache; the per-model dir owns metadata only. The CLI dispatches to one of three runners based on `runner =`:

- `mlx-lm` (default) — fast path on Apple Silicon; requires an `mlx-community` repo.
- `ollama` — uses `ollama_model = "<tag>"` from TOML.
- `llama.cpp` — uses `hf_repo` + `gguf_file` from TOML.

TOML parsing is done via the playground venv's Python 3.12 `tomllib` (`$HOME/ai/playground/.venv/bin/python`). Override with `MAI_MODEL_PYTHON` if you want a different interpreter; override `MAI_MODELS_DIR` to point at a non-default models dir (useful for testing).

`run-all` and `serve` delegate to a stdlib-only Python helper at `~/.local/share/mai-model/helper.py` (sibling template `dot_local/share/mai-model/executable_helper.py.tmpl`). The bash CLI re-execs the helper with `MAI_MODELS_DIR` forwarded; the helper parses each `model.toml`, runs each model via `mai-model run <name>` as a subprocess (so runner selection logic stays in one place), parses mlx-lm's stdout for tokens/sec + peak memory + token counts, and writes `~/Models/.runs/<utc-stamp>/results.json`. `serve` is `http.server.ThreadingHTTPServer` bound to `127.0.0.1` with two routes: `/` (run-set list) and `/runs/<stamp>` (side-by-side viewer). No external Python deps; everything works against the playground venv's Python.

## Secret handling

Never inline secrets in templates. Two patterns are in use:

- **`op://` references** read at runtime by `*-login` zsh functions in `dot_zshenv.tmpl` (`hf-login`, `gh-login`, `tailscale-up`, `openrouter-login`). The functions export the env var only when invoked — nothing runs at shell startup.
- **`op-cred <title>` / `op-creds-bootstrap`** create credentials in 1Password without exposing them in argv. Secret transits via stdin pipe through `jq -Rn ... | op item create --template -` — kernel pipe, never visible in `ps`. The credential inventory lives at `dot_config/op-creds` (one item title per line, `#` comments). **Adding a credential is a one-line config edit, not a code edit** — do not edit the function.

Defense-in-depth: `dot_config/atuin/config.toml` has a `history_filter` regex list that drops common secret-leaking patterns (op/login/--token=/--password=/api_key/HF_TOKEN/TS_AUTHKEY) before they hit the SQLite history.

## Brewfile organization

`dot_Brewfile.tmpl` is sectioned by purpose (CLI essentials, Rust replacements, Terminal stack, Editors, Dev, Productivity, Browsers, Communication, Media, Creative/GPU, Games, Security, Mac App Store, Containers). Each cask has a trailing `# comment` aligned to roughly column 28; comments call out something distinguishing rather than restating the name. AI-only packages sit inside the host-gating block.

`mas` (Mac App Store CLI) lives in CLI essentials so it's installed before any `mas "Name", id: NNN` lines are reached. Order matters in a Brewfile.

## When to update README.md

The README's `020-brew-bundle` section inventories specific packages by category. **When adding/removing packages, update that list** — it's the canonical user-facing reference. The Layout section also lists every top-level file/dir; add new ones (especially under `dot_config/`) so readers don't have to grep.

`mai-doctor` counts Brewfile entries via the regex `^(brew|cask|tap|mas) "`. If you add a new top-level Brewfile keyword, extend that regex too.

## Gotchas

- **VirtioFS reads are unreliable** for chezmoi sources — `bootstrap.sh --test` copies the source into the VM's local filesystem before chezmoi reads it, rather than reading from the mount directly.
- **`uv pip show` not `uv run pip show`** — uv-managed venvs don't include `pip`, so `uv run pip show` silently fails. `mai-doctor` uses the former.
- **`op` CLI scopes auth to the parent process** when integrated with the 1Password desktop app. Auth in one terminal does not carry to others; "Allow in background" must be enabled in 1Password's macOS Login Items settings.
- **Forgetting to set hostname before apply** is harmless — AI-gated scripts render to empty and don't run. Fix the hostname, re-apply, scripts fire on the next pass.
