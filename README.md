# dotfiles

OS-conditional configs for Alacritty and Zellij — plus a macOS AI dev
bootstrap — managed by [chezmoi](https://www.chezmoi.io).

## What's here

- **Alacritty** (primary on macOS): shared keybinds in `common.toml`, an
  OS-templated `alacritty.toml` that picks window decorations and a profile
  picker keybind per OS, and a `profiles/` directory of standalone configs
  that SSH into a remote host and attach to a Zellij session.
- **Zellij** (primary UI target on Linux): the full keybind-heavy config is
  installed on both OSes; Linux gets an extra `layouts/minimal.kdl` and
  `default_layout "minimal"` so the status/help pane is hidden and the tab
  strip becomes a single-line `compact-bar`.
- **`alacritty-profile`** (`~/.local/bin`): an fzf picker over
  `~/.config/alacritty/profiles/*.toml`. Bound to `Cmd+Space` on macOS and
  `Ctrl+Shift+Space` on Linux.
- **macOS AI bootstrap**: Homebrew + a Brewfile of CLI tools and Rust
  replacements, a uv-managed MLX playground at `~/ai/playground`, sane
  macOS defaults, and a `mai-doctor` health check. See below.

## Install

```sh
# 1. Install chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin

# 2. Point chezmoi at this repo in place
chezmoi init --source=~/c/dotfiles

# 3. Preview what will land
chezmoi diff

# 4. Apply
chezmoi apply -v
```

Re-running `chezmoi apply` is idempotent.

## Layout

```
.
├── .chezmoi.toml.tmpl                      one-time prompts (name, email)
├── .chezmoidata.toml                       shared data (ai_machines list)
├── .chezmoiignore.tmpl                     excludes by OS / host
├── .editorconfig                           LF, UTF-8, 2-space sh/tmpl
├── .github/workflows/template-check.yml    renders every .tmpl in CI
├── .chezmoitemplates/
│   ├── zellij-macos.kdl                    full zellij config body
│   └── zellij-linux.kdl                    same + default_layout "minimal"
├── dot_config/
│   ├── alacritty/…                         OS-branched window/keybinds
│   └── zellij/…                            picks macos or linux body
├── dot_local/bin/
│   ├── executable_alacritty-profile        fzf profile picker
│   └── executable_mai-doctor.tmpl          AI env health check (mac, AI hosts)
├── dot_Brewfile.tmpl                       packages (AI bits host-gated)
├── dot_zshenv.tmpl, dot_zshrc.tmpl         shell env + interactive
├── dot_gitconfig.tmpl                      git + delta integration
├── run_once_before_10-install-homebrew.sh.tmpl
├── run_once_after_20-brew-bundle.sh.tmpl
├── run_once_after_30-ai-stack.sh.tmpl      uv + MLX playground (AI hosts)
└── run_once_after_40-macos-defaults.sh.tmpl
```

See `dot_config/alacritty/profiles/README.md` for how to add a host.

## macOS AI bootstrap

On macOS, `chezmoi apply` runs four ordered `run_once_` scripts:

1. **`10-install-homebrew`** — installs Homebrew non-interactively if `brew`
   isn't on PATH. On a truly fresh Mac this triggers the Xcode Command Line
   Tools GUI prompt; that's expected — let it finish, then re-run.
2. **`20-brew-bundle`** — installs everything in `~/.Brewfile`: CLI essentials
   (git, gh, jq, yq, fzf, direnv, zoxide, starship, neovim, tmux), Rust
   replacements (ripgrep, fd, bat, eza), Rust extras (git-delta, dust, tokei,
   hyperfine, bottom, gitui, just), terminal stack (alacritty, zellij), dev
   (uv, mise, node), and productivity casks (raycast, rectangle, 1password).
   On hosts listed in `.chezmoidata.toml` `[hosts] ai_machines`, also
   `llama.cpp`, `ollama`, and the `lm-studio` cask.
3. **`30-ai-stack`** *(host-gated)* — ensures `uv`, creates `~/Models`,
   `~/.cache/huggingface`, `~/ai/playground`; `uv init`s the playground at
   Python 3.12 with `mlx`, `mlx-lm`, `huggingface-hub`, `hf-transfer`,
   `jupyter`, `ipython`, `rich`; writes a `.envrc` that auto-syncs and
   activates the venv on `cd`.
4. **`40-macos-defaults`** — Finder visibility, fast key repeat, screenshots
   to `~/Desktop/Screenshots`, no `.DS_Store` on network/USB.

Day one on a fresh Mac:

```sh
chezmoi init willemneal       # prompts for name + email
chezmoi diff                   # verify!
chezmoi apply -v
mai-doctor                     # confirm everything came up
```

### First model

```sh
huggingface-cli download mlx-community/Llama-3.3-70B-Instruct-4bit
cd ~/ai/playground
uv run python -m mlx_lm.generate \
  --model mlx-community/Llama-3.3-70B-Instruct-4bit \
  --prompt "Explain MoE routing in two sentences." \
  --max-tokens 200
```

### Benchmark MLX vs Ollama

Both ship in the Brewfile, so you can compare apples-to-apples:

```sh
hyperfine --warmup 1 \
  'cd ~/ai/playground && uv run python -m mlx_lm.generate \
     --model mlx-community/Llama-3.3-70B-Instruct-4bit \
     --prompt "Write a haiku about caches." --max-tokens 64' \
  'ollama run llama3.3:70b "Write a haiku about caches."'
```

### Memory for 70B+ models

By default macOS reserves only ~75% of unified memory for GPU-wired
allocations. On the 128 GB M5 Max you can give MLX more headroom for the
session:

```sh
sudo sysctl iogpu.wired_limit_mb=122880    # ~120 GiB of 128 GiB
```

This resets at boot. To make it persistent you'd add a launchd plist —
out of scope for this repo.

### Troubleshooting

Run `mai-doctor`. It reports versions, disk free, HF cache size, and
flags `iogpu.wired_limit_mb` if it's below ~95% of physical memory.

### CLI replacements

These aliases land via `dot_zshrc.tmpl`; the binaries come from the Brewfile.

| Old      | New                  | Notes                              |
|----------|----------------------|------------------------------------|
| `ls`     | `eza`                | `ll` adds `-lah --git`, `lt` tree  |
| `cat`    | `bat --paged=never`  | syntax-highlighted, page off       |
| `find`   | `fd`                 | (no alias — different syntax)      |
| `grep`   | `ripgrep` (`rg`)     | (no alias — different syntax)      |
| `du`     | `dust`               | tree-shaped disk usage             |
| `top`    | `btm` (bottom)       | shows GPU/Metal on Apple Silicon   |
| `diff`   | `delta`              | wired into git via `core.pager`    |

## Requirements

- `alacritty`, `zellij`, `fzf` on the local machine.
- `zellij` on any remote host you define a profile for.
- For macOS AI work: a host listed under `[hosts] ai_machines` in
  `.chezmoidata.toml` (default: `mai`).
