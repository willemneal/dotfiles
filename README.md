# dotfiles

OS-conditional configs for Alacritty and Zellij — plus a macOS AI dev
bootstrap — managed by [chezmoi](https://www.chezmoi.io).

- [Install](#install)
- [Layout](#layout)
- [macOS AI bootstrap](#macos-ai-bootstrap)
- [Zellij walkthrough](#zellij-walkthrough) — the long one
- [Window management: AeroSpace + Karabiner](#window-management-aerospace--karabiner)
- [Alacritty walkthrough](#alacritty-walkthrough)
- [Neovim (LazyVim)](#neovim-lazyvim)
- [Shell, git, and 1Password integrations](#shell-git-and-1password-integrations)
- [Shell history (Atuin)](#shell-history-atuin)
- [Prompt and runtime managers (starship, mise)](#prompt-and-runtime-managers-starship-mise)
- [CLI replacements](#cli-replacements)
- [Troubleshooting](#troubleshooting)

## Install

```sh
# 1. (AI hosts only) Set hostname *first* — chezmoi reads `.chezmoi.hostname`
#    and gates AI-only scripts on `.hosts.ai_machines = ["mai"]`. Skip on a
#    non-AI Mac; the AI bits will simply not fire.
sudo scutil --set HostName mai
sudo scutil --set LocalHostName mai
sudo scutil --set ComputerName mai

# 2. Install chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin

# 3. Initialise (prompts for name, email, and signing_key once)
chezmoi init willemneal

# 4. Preview what will land — *always* read this on a fresh machine
chezmoi diff

# 5. Apply
chezmoi apply -v

# 6. Confirm everything came up
mai-doctor
```

Re-running `chezmoi apply` is idempotent. The `run_once_*` scripts only re-fire
when their content hash changes.

**Forgot to set the hostname before applying?** Harmless — the AI-gated
scripts render to empty and chezmoi doesn't run them. Fix the hostname,
then `chezmoi apply -v` again; the scripts now render with content and
fire on the next pass.

## Layout

```
.
├── .chezmoi.toml.tmpl                          one-time prompts (name, email)
├── .chezmoidata.toml                           shared data (ai_machines list)
├── .chezmoiignore.tmpl                         excludes by OS / host
├── .editorconfig                               LF, UTF-8, 2-space sh/tmpl
├── .github/workflows/template-check.yml        renders + shellchecks every .tmpl
├── .chezmoitemplates/
│   ├── brew-shellenv.sh                        shared `eval $(brew shellenv)`
│   ├── zellij-base.kdl                         shared zellij body (theme, plugins, keybinds)
│   ├── zellij-macos.kdl                        thin wrapper → base
│   └── zellij-linux.kdl                        adds default_layout "minimal" → base
├── dot_config/
│   ├── aerospace/aerospace.toml                tiling WM bindings (Hyper prefix)
│   ├── alacritty/
│   │   ├── alacritty.toml.tmpl                 OS-branched window/keybinds + theme imports
│   │   ├── common.toml                         shared keybinds
│   │   ├── colors/catppuccin-mocha.toml        palette (matches zellij theme)
│   │   └── profiles/                           SSH-launch profile fragments
│   ├── atuin/config.toml                       SQLite history config + secret filter
│   ├── karabiner/karabiner.json                Caps Lock → Esc/Hyper remap
│   ├── mise/config.toml                        global runtime versions (node/go/bun/deno)
│   ├── nvim/                                   LazyVim bootstrap (init.lua + lua/)
│   ├── starship.toml                           Catppuccin Mocha prompt
│   └── zellij/
│       ├── config.kdl.tmpl                     picks macos or linux body
│       └── layouts/minimal.kdl                 compact-bar only, Linux default
├── dot_local/bin/
│   ├── executable_alacritty-profile            fzf profile picker
│   └── executable_mai-doctor.tmpl              AI env health check (mac, AI hosts)
├── dot_Brewfile.tmpl                           packages (AI bits host-gated)
├── dot_zshenv.tmpl, dot_zshrc.tmpl             shell env + interactive
├── dot_gitconfig.tmpl                          git + delta + optional 1Password signing
├── run_once_before_010-install-homebrew.sh.tmpl
├── run_once_after_020-brew-bundle.sh.tmpl
├── run_once_after_030-ai-stack.sh.tmpl         uv + MLX playground (AI hosts)
├── run_once_after_035-iogpu-limit.sh.tmpl      LaunchDaemon: persist iogpu.wired_limit_mb
├── run_once_after_040-macos-defaults.sh.tmpl
├── run_once_after_045-time-machine.sh.tmpl    exclude AI artifacts (AI hosts)
└── run_once_after_050-sudo-touchid.sh.tmpl    enable Touch ID for sudo
```

See `dot_config/alacritty/profiles/README.md` for how to add an SSH profile.

## macOS AI bootstrap

On macOS, `chezmoi apply` runs seven ordered `run_once_` scripts:

1. **`010-install-homebrew`** — installs Homebrew non-interactively if `brew`
   isn't on PATH. On a truly fresh Mac this triggers the Xcode Command Line
   Tools GUI prompt; that's expected — let it finish, then re-run.
2. **`020-brew-bundle`** — installs everything in `~/.Brewfile`:
   - CLI essentials: git, gh, jq, yq, fzf, direnv, zoxide, starship, neovim,
     tmux, **repomix**.
   - Rust replacements: ripgrep, fd, bat, eza.
   - Rust extras: git-delta, dust, tokei, hyperfine, bottom, gitui, just.
   - Zsh enhancements: **zsh-autosuggestions**, **zsh-fast-syntax-highlighting**,
     **atuin**.
   - Terminal stack: alacritty, zellij.
   - Dev: uv, mise, node.
   - Rust toolchain: rustup, cargo-binstall.
   - Productivity casks: raycast, **aerospace**, **karabiner-elements**,
     1password, 1password-cli, tailscale-app.
   - On hosts in `.chezmoidata.toml` `[hosts] ai_machines`: also llama.cpp,
     ollama, whisper-cpp, asitop, **mactop**, and the lm-studio cask.
3. **`030-ai-stack`** *(host-gated)* — ensures `uv`, creates `~/Models`,
   `~/.cache/huggingface`, `~/ai/playground`. `uv init`s the playground at
   Python 3.12 with `mlx`, `mlx-lm`, `mlx-vlm`, `huggingface-hub`,
   `hf-transfer`, `jupyter`, `ipython`, `rich`. Writes a `.envrc` that
   auto-syncs and activates the venv on `cd`.
4. **`035-iogpu-limit`** *(host-gated)* — installs a LaunchDaemon plist at
   `/Library/LaunchDaemons/local.iogpu.wired-limit.plist` that re-applies
   `iogpu.wired_limit_mb` to ~95 % of physical memory at every boot. Without
   this, macOS resets the limit to ~75 %, eating into the headroom you need
   for 70B+ models. **Needs sudo on first run.**
5. **`040-macos-defaults`** — Finder visibility, fast key repeat, screenshots
   to `~/Desktop/Screenshots`, no `.DS_Store` on network/USB.
6. **`045-time-machine`** *(host-gated)* — `tmutil addexclusion` for `~/Models`,
   `~/.cache/huggingface`, `~/.cache/uv`, and `~/ai/playground/.venv`. These
   are large and re-downloadable; backing them up wastes snapshots.
7. **`050-sudo-touchid`** — enables Touch ID for `sudo` via
   `/etc/pam.d/sudo_local`. Survives macOS updates. **Needs sudo on first run.**

After bootstrap you'll want a few one-time setup steps:

```sh
rustup default stable        # install the actual Rust compiler/cargo
atuin import auto            # ingest existing ~/.zsh_history into atuin
nvim                         # first launch downloads LazyVim plugins (~10s)
```

In Karabiner-Elements and AeroSpace, accept the macOS permission prompts on
first launch (Input Monitoring, Accessibility). They both auto-start on login
afterwards.

Then run `mai-doctor` to confirm everything came up. It reports versions,
playground state, ollama daemon reachability, HF auth, network reach to
`huggingface.co`, disk usage, and the current `iogpu.wired_limit_mb`
relative to physical memory.

### First model

```sh
hf-login                                                 # exports HF_TOKEN
hfd mlx-community/Llama-3.3-70B-Instruct-4bit            # ~40 GB download
play                                                      # cd to playground + open repl
# or
cd ~/ai/playground && uv run python -m mlx_lm.generate \
  --model mlx-community/Llama-3.3-70B-Instruct-4bit \
  --prompt "Explain MoE routing in two sentences." \
  --max-tokens 200
```

### Benchmark MLX vs Ollama

```sh
hyperfine --warmup 1 \
  'cd ~/ai/playground && uv run python -m mlx_lm.generate \
     --model mlx-community/Llama-3.3-70B-Instruct-4bit \
     --prompt "Write a haiku about caches." --max-tokens 64' \
  'ollama run llama3.3:70b "Write a haiku about caches."'
```

`asitop` (in the AI Brewfile block) is the cleanest way to watch GPU/memory
during runs.

### Memory for 70B+ models

The `035-iogpu-limit` script handles this for you on AI hosts. Confirm
with `sysctl iogpu.wired_limit_mb` after a reboot — it should report a
value near 95 % of physical (e.g. ~124 GiB on a 128 GB box).

## Zellij walkthrough

Zellij is a terminal multiplexer (think tmux, but modal). The config is a
single shared body in `.chezmoitemplates/zellij-base.kdl` — the macOS and
Linux variants are thin wrappers; Linux additionally sets
`default_layout "minimal"` to hide the help/status pane.

### Modes

Zellij is **modal**. Every binding hangs off a mode. The mode you start in is
**Normal** (or **Locked**, if you've configured it that way — this repo does
not). The active mode shows in the bottom-right of the status bar.

| Mode         | Enter via         | What it's for                                           |
|--------------|-------------------|---------------------------------------------------------|
| **Normal**   | `Esc` from any mode | Pass-through — everything goes to the focused pane     |
| **Locked**   | `Ctrl+G`          | Suspends ALL Zellij keybinds. Use inside nvim/lazygit/fzf |
| **Pane**     | `Ctrl+P`          | Manage panes (split, focus, close, fullscreen, float)   |
| **Tab**      | `Ctrl+T`          | Manage tabs (new, navigate, rename, sync, close)        |
| **Resize**   | `Ctrl+N`          | Resize the focused pane                                 |
| **Move**     | `Ctrl+H`          | Reorder panes within the layout                         |
| **Scroll**   | `Ctrl+S`          | Scrollback (vim-style: `j/k/u/d/g/G`)                   |
| **Search**   | inside Scroll: `s` | Find in scrollback                                      |
| **Session**  | `Ctrl+O`          | Session manager, plugin manager, about                  |
| **Tmux**     | `Ctrl+B`          | tmux-compat keys (`%`, `"`, `c`, `n`, `p`, etc.)        |

Inside any mode, **`Enter`** or **`Esc`** returns you to Normal.

### Day-one survival kit (Normal mode shortcuts that work everywhere)

These are bound in `shared_except "locked"` so they fire from any mode except
Locked:

| Key             | What it does                              |
|-----------------|-------------------------------------------|
| `Ctrl+G`        | Toggle Locked mode                        |
| `Ctrl+Q`        | Quit the session                          |
| `Alt+←/→`       | Move focus left/right (or to prev/next tab if at the edge) |
| `Alt+↑/↓`       | Move focus up/down                        |
| `Alt+h/j/k/l`   | Same, vim-style                           |
| `Alt+n`         | New pane (split direction auto-chosen)    |
| `Alt+f`         | Toggle floating panes                     |
| `Alt+i` / `Alt+o` | Move current tab left / right           |
| `Alt+[` / `Alt+]` | Cycle swap layouts                      |
| `Alt+=` / `Alt+-` | Resize ± (in 5 % increments)            |
| `Alt+Shift+L`   | Toggle the auto-lock plugin (see below)   |

### Pane mode (`Ctrl+P …`)

Most of the day-to-day pane verbs:

- `n` new pane, `d` new below, `r` new right, `s` new stacked
- `h/j/k/l` or arrows: move focus
- `x` close pane (also: `shared_among pane,tmux`)
- `f` toggle fullscreen, `z` toggle pane frames
- `w` toggle floating, `e` embed/float toggle, `i` pin floating pane
- `c` rename pane (drops you into Renamepane mode; `Esc` undoes)
- `p` cycle focus

### Tab mode (`Ctrl+T …`)

- `n` new tab, `x` close tab, `r` rename
- `1..9` jump to tab N
- `h/j/k/l` or arrows: prev/next
- `[` / `]` break the focused pane out into the tab to the left / right
- `b` break the focused pane into a new tab
- `s` toggle sync — every keystroke is broadcast to all panes in the tab
- `tab` jump back to the previously-focused tab

### Resize mode (`Ctrl+N …`)

- `h/j/k/l` or arrows: increase that side
- `H/J/K/L`: decrease that side
- `+ -` (and `=`): grow / shrink uniformly

### Scroll mode (`Ctrl+S …`)

vim-flavoured scrollback navigation:

- `j/k`: line down/up, `u/d`: half page, `Ctrl+f / Ctrl+b`: full page
- `s`: enter Search mode (then type, `Enter` to confirm, `n/N` for next/prev)
- `e`: open the scrollback in `$EDITOR` (nvim)
- `Ctrl+c`: jump to bottom and exit Scroll

### Session mode (`Ctrl+O …`)

- `w`: session manager (switch / create / detach)
- `d`: detach from this session (also bound in Tmux mode)
- `p`: plugin manager
- `a`: about, `c`: configuration UI, `s`: web-share

### Plugins shipped here

Three things are on top of the stock Zellij config:

#### 1. Catppuccin Mocha theme

`theme "catppuccin-mocha"` — built-in. The same palette is also imported from
`alacritty/colors/catppuccin-mocha.toml` so the terminal chrome and pane
content don't drift. To change theme: edit one line in
`.chezmoitemplates/zellij-base.kdl` and (optionally) drop a different
`colors/<name>.toml` into the alacritty config and update the import in
`alacritty.toml.tmpl`.

#### 2. zellij-autolock

[fresh2dev/zellij-autolock](https://github.com/fresh2dev/zellij-autolock) —
auto-flips Zellij into Locked mode whenever the focused pane is running
nvim, vim, hx, fzf, lazygit, zoxide, atuin, or claude. Eliminates the manual
`Ctrl+G` dance every time you open an editor. Auto-unlocks when the
foreground process exits.

- Triggers/list: edit the `triggers "..."` line in `zellij-base.kdl`.
- Manual override: `Alt+Shift+L` toggles auto-lock for the current session
  (useful when an unlisted command is collisions with Zellij keybinds).
- Plugin downloads on first session start; if it ever fails, `chezmoi apply`
  doesn't reinstall it — clear the cached wasm under
  `~/Library/Caches/org.Zellij-Contributors.Zellij/` and restart Zellij.

#### 3. zellij-attention

[KiryuuLight/zellij-attention](https://github.com/KiryuuLight/zellij-attention)
— shows an icon next to a tab name when a pane wants attention. Built
explicitly for Claude Code. To wire it up, edit `~/.claude/settings.json`:

```jsonc
{
  "hooks": {
    "Stop": [
      { "hooks": [{ "type": "command", "command": "zellij action write-chars 'attention'" }] }
    ],
    "Notification": [
      { "hooks": [{ "type": "command", "command": "zellij action write-chars 'attention'" }] }
    ]
  }
}
```

(Exact action varies by plugin version — check the repo for the current
recipe; the placeholder above shows the shape.)

### Layouts

A *layout* is a saved pane arrangement loaded with `zellij --layout <name>`
(or referenced by `default_layout` in the config). This repo ships one:

- `dot_config/zellij/layouts/minimal.kdl` — a single pane with the compact
  status bar, no help bar. Used as `default_layout` on Linux.

To add more, drop `*.kdl` files alongside it and either reference them with
`zellij --layout dev` or set `default_layout "dev"`. See
<https://zellij.dev/documentation/creating-a-layout.html>.

### Sessions

```sh
zellij                    # start unnamed session
zellij -s work            # start (or attach to) named session "work"
zellij list-sessions      # all sessions on this machine
zellij attach work        # attach to "work"
zellij delete-session old # remove
```

Sessions persist after detach (`Ctrl+O d`); attach again to find the same
panes/cwds intact (Zellij serializes session state to disk by default since
v0.40).

### Remote Zellij via Alacritty profiles

The `dot_config/alacritty/profiles/` directory holds standalone Alacritty
configs that SSH into a host and `zellij attach -c <session>`. Pick one with
`Cmd+Shift+P` (macOS) — fzf picker over the directory, opens a new Alacritty
window pinned `AlwaysOnTop`. See `profiles/README.md` for adding hosts.

## Window management: AeroSpace + Karabiner

The productivity stack ditches Rectangle for a tiling setup that's
fully keyboard-driven and conflict-free with Zellij.

### Karabiner-Elements: the Hyper key

`dot_config/karabiner/karabiner.json` remaps **Caps Lock**:

- **Tap and release** → `Esc` (cheap thrill for vim users).
- **Hold and press another key** → Hyper, which is `Cmd+Ctrl+Opt+Shift`
  pressed simultaneously. Nothing in macOS, Alacritty, or Zellij binds
  to Hyper, so it's a clean modifier you can use without collisions.

First time: open Karabiner-Elements, grant the input-monitoring
permission macOS prompts for, and it'll pick up `~/.config/karabiner/`
automatically.

### AeroSpace: i3 for macOS

`dot_config/aerospace/aerospace.toml` defines an i3-style tiling
window manager. Every binding uses Hyper as the prefix.

| Binding                        | Action                                      |
|--------------------------------|---------------------------------------------|
| `Hyper+1..6`                   | Focus workspace N                           |
| `Hyper+h/j/k/l`                | Focus pane left / down / up / right         |
| `Hyper+-` / `Hyper+=`          | Resize focused pane (smart, ±50)            |
| `Hyper+/`                      | Toggle tiling layout (horizontal/vertical)  |
| `Hyper+,`                      | Toggle accordion layout                     |
| `Hyper+f`                      | Float the focused window                    |
| `Hyper+r`                      | Reload AeroSpace config                     |
| `Hyper+;`                      | Enter "service" mode (see below)            |

Service mode (`Hyper+;` then…):

| Key            | Action                                              |
|----------------|-----------------------------------------------------|
| `1..6`         | Move focused window to workspace N                  |
| `h/j/k/l`      | Move focused window in direction                    |
| `r`            | Flatten the workspace tree                          |
| `Backspace`    | Close every window in the workspace except current  |
| `Esc`          | Reload config and return to main mode               |

Apps that don't tile well (System Preferences, 1Password, Raycast,
Calculator) are declared `floating` in the config — add more as needed.

AeroSpace runs fully in user-space (no SIP changes), so the only
permission grant is "Accessibility access" on first launch. To start
on login, the config sets `start-at-login = true`.

## Alacritty walkthrough

Alacritty is the local terminal emulator (cask `alacritty`). The config is
split into:

- `alacritty.toml.tmpl` — OS-templated entry point. Imports `common.toml` and
  `colors/catppuccin-mocha.toml`. macOS sets `decorations="buttonless"` and
  `option_as_alt="Both"` (caveat noted inline if input ever breaks). Binds
  `Cmd+Shift+P` to the profile picker.
- `common.toml` — currently just one binding: `Shift+Enter` sends a literal
  `Esc CR`, which is the convention many shells/editors use for "real"
  newlines vs. submit.
- `colors/catppuccin-mocha.toml` — the palette. Drop another file in this
  directory and swap the import to switch themes.
- `profiles/*.toml` — per-host SSH-then-attach configs (see
  `profiles/README.md`).

### Profile picker

`Cmd+Shift+P` (macOS) / `Ctrl+Shift+P` (Linux) launches a tiny pinned
Alacritty window running `~/.local/bin/alacritty-profile`, an fzf picker
over `profiles/*.toml`. Pick one and a new Alacritty window opens that
SSH-launches you into a remote Zellij session.

## Neovim (LazyVim)

`dot_config/nvim/` ships a thin LazyVim bootstrap:

```
dot_config/nvim/
├── init.lua                       # one-line: require("config.lazy")
└── lua/
    ├── config/lazy.lua             # clones folke/lazy.nvim, configures distro
    └── plugins/colorscheme.lua     # pins catppuccin-mocha
```

First `nvim` launch clones `lazy.nvim` and downloads the plugin set
(~10 seconds). LazyVim's defaults give you Treesitter, LSP-zero-equivalent,
telescope, which-key, gitsigns, oil.nvim, conform.nvim, and nvim-cmp out of
the box.

To enable language extras, uncomment lines in `lua/config/lazy.lua`:

```lua
-- { import = "lazyvim.plugins.extras.lang.python" },
-- { import = "lazyvim.plugins.extras.lang.rust" },
-- { import = "lazyvim.plugins.extras.lang.typescript" },
```

After the first launch, **commit `dot_config/nvim/lazy-lock.json`** so a fresh
machine pins to the same plugin commits. Run `:Lazy sync` periodically to
update; review and commit the lockfile diff.

Pairs with `zellij-autolock`: opening nvim auto-locks Zellij's keybinds, so
nothing collides.

## Shell, git, and 1Password integrations

### `dot_zshenv` (sourced for every shell)

- Loads brew shellenv via the shared `.chezmoitemplates/brew-shellenv.sh`.
- Prepends `~/.local/bin` to PATH.
- `EDITOR=nvim`, `VISUAL=$EDITOR`.
- AI env: `HF_HUB_ENABLE_HF_TRANSFER=1`, `MODELS_DIR=$HOME/Models`.
  `HF_HOME` is commented out — uncomment to point at an external drive.
- Two lazy 1Password helpers (only run on demand, never at shell startup):
  - **`hf-login`** → exports `HF_TOKEN` from
    `op://Personal/HuggingFace/credential`. Walkthrough below.
  - **`tailscale-up`** → reads `op://Personal/Tailscale/credential` and runs
    `tailscale up` with the key passed via `TS_AUTHKEY` env (no `ps` leak).
    Forwards extra flags, e.g. `tailscale-up --accept-routes`.
- Sources `~/.zshenv.local` if present (machine-specific overrides, untracked).

### `dot_zshrc` (interactive shells)

History (50 k entries, dedup, shared — supplemented by Atuin's SQLite store),
`compinit`, conditional init for starship/zoxide/direnv/mise/atuin, fzf
bindings, **zsh-autosuggestions + fast-syntax-highlighting** sourced after
fzf (order matters), the CLI replacement aliases, and AI shortcuts (`hfd`,
`play`, `jlab`).

### Hugging Face token

```
1. Mint at https://huggingface.co/settings/tokens (Read scope is enough).
2. Accept any gated-model licenses on the model pages.
3. Store in 1Password:
     New item → API Credential
     Vault: Personal
     Title: HuggingFace
     credential: hf_…
4. Run `hf-login` once per shell. `hfd <repo>` works after.
```

### Tailscale

```
1. Mint a reusable auth key at
   https://login.tailscale.com/admin/settings/keys (90-day expiry max).
2. Store in 1Password:
     New item → API Credential
     Vault: Personal
     Title: Tailscale
     credential: tskey-auth-…
3. Install the cask: `tailscale-app` (lands via brew bundle).
4. Run `tailscale-up` (extra flags forward, e.g. `--accept-routes`).
```

### GitHub CLI (`gh`)

`gh-login` exports `GH_TOKEN` from 1Password — `gh` reads that env var
automatically, so there's no `gh auth login` step.

```
1. Mint a Personal Access Token at
   https://github.com/settings/tokens?type=beta (Fine-grained, scoped to
   the repos and permissions you actually need).
2. Store in 1Password:
     New item → API Credential
     Vault: Personal
     Title: GitHub CLI
     credential: github_pat_…
3. Run `gh-login` once per shell, then `gh repo view`, `gh pr list`, etc.
```

### Git + delta

`dot_gitconfig.tmpl` injects `name`/`email` from the chezmoi prompt cache,
sets `defaultBranch=main`, `pull.rebase=true`, `push.autoSetupRemote=true`,
and routes diffs through delta side-by-side with `merge.conflictstyle=zdiff3`.
Aliases: `git s` (status -sb), `co`, `br`, `ci`, and `lg` (graph + relative
date).

### Git commit signing via 1Password SSH (optional)

If you set `signing_key` during `chezmoi init` (the SSH public-key
fingerprint, e.g. `SHA256:abc...`), the gitconfig adds `commit.gpgsign=true`
and points `gpg.ssh.program` at 1Password's `op-ssh-sign` helper. Every
commit gets cryptographically signed by the 1Password-managed SSH key.

One-time setup on a fresh machine:

1. In 1Password → Settings → Developer: enable the SSH agent and
   "Use SSH key for git commit signing".
2. Add the matching public key to GitHub → Settings → SSH and GPG keys
   → **New signing key** (separate from any auth key).
3. Create `~/.ssh/allowed_signers` with one line:
   `<your-email> ssh-ed25519 AAAA…` (so `git log --show-signature` works).
4. Skip with a blank `signing_key` value during init if you don't want
   this — gitconfig falls back to unsigned commits.

## Shell history (Atuin)

Atuin replaces zsh's text-file `~/.zsh_history` with a SQLite store, plus a
fuzzy-search UI on demand. Wired into `dot_zshrc.tmpl` via:

```sh
command -v atuin >/dev/null && eval "$(atuin init zsh --disable-up-arrow --disable-ctrl-r)"
```

`--disable-up-arrow` keeps Up arrow as zsh's native per-session sequential
recall, and `--disable-ctrl-r` keeps Ctrl+R as zsh's built-in inline
backward-search. Both standard zsh history bindings stay untouched —
Atuin records to its SQLite store in the background but doesn't take
over either keybind. To open Atuin's fuzzy UI explicitly, run `atuin
search` (or bind it to a key of your choice in a `~/.zshrc.local`).

`dot_config/atuin/config.toml` configures the UI (compact, single-Enter
accept, no help line) and a `history_filter` regex list that drops these
patterns *before* they're written to the database:

- `op read…`, `op signin…`
- `hf-login`, `tailscale-up`
- `--token=…`, `--password=…`, `*api_key*`
- `HF_TOKEN=…`, `TS_AUTHKEY=…`

Defense-in-depth: secrets that flow through your shell never land on disk.

One-time setup after `brew bundle`:

```sh
atuin import auto      # ingest existing ~/.zsh_history
# Optional: enable sync
# atuin register -u <username> -e <email>
# atuin sync
```

## Prompt and runtime managers (starship, mise)

**Starship** — `dot_config/starship.toml` defines a one-line Catppuccin Mocha
prompt with directory (truncated to 3 levels), git branch + status, python
(uv venv detection), rust, nodejs, and `cmd_duration` for any command longer
than 2 s. `command_timeout = 1000` caps slow `git_status` calls so big
monorepos don't hang the prompt. The palette matches Alacritty + Zellij so
colors don't drift between the prompt and pane content.

**Mise** — `dot_config/mise/config.toml` pins polyglot runtimes:

```toml
[tools]
node = "lts"
go = "latest"
bun = "latest"
deno = "latest"
```

Python is *deliberately not* under mise — it's owned by `uv` per-project
(see `~/ai/playground/pyproject.toml`). Rust is owned by `rustup`. Mise
covers the rest, so any project with a `mise.toml` or `.tool-versions`
resolves automatically when you `cd` in.

## CLI replacements

These aliases land via `dot_zshrc.tmpl`; the binaries come from the Brewfile.

| Old      | New                  | Notes                                        |
|----------|----------------------|----------------------------------------------|
| `ls`     | `eza`                | `ll` adds `-lah --git`, `lt` is `--tree -L 2` |
| `cat`    | `bat --paging=never` | syntax-highlighted, page off                 |
| `find`   | `fd`                 | (no alias — different syntax)                |
| `grep`   | `ripgrep` (`rg`)     | (no alias — different syntax)                |
| `du`     | `dust`               | tree-shaped disk usage                       |
| `top`    | `btm` (bottom)       | system monitor; `asitop` on AI hosts for GPU |
| `diff`   | `delta`              | wired into git via `core.pager`              |

## Troubleshooting

- Run **`mai-doctor`** first — it covers ~90 % of "is X set up correctly?"
  questions.
- `chezmoi diff` before any `chezmoi apply -v`. Especially on shared
  machines.
- A `run_once_*` script you want to re-fire: bump a comment in the file
  (chezmoi content-hashes scripts; any change re-runs them).
- Plugin wasm download failed: clear
  `~/Library/Caches/org.Zellij-Contributors.Zellij/` and restart Zellij.
- `option_as_alt = "Both"` ever breaks input: switch to `"OnlyLeft"` in
  `alacritty.toml.tmpl` (alacritty/alacritty#7077).

## Requirements

- `alacritty`, `zellij`, `fzf` on the local machine.
- `zellij` on any remote host you define a profile for.
- For macOS AI work: a host listed under `[hosts] ai_machines` in
  `.chezmoidata.toml` (default: `mai`).
