# dotfiles

OS-conditional configs for Alacritty and Zellij, managed by
[chezmoi](https://www.chezmoi.io).

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
├── .chezmoiignore.tmpl                     excludes linux-only files on mac
├── .chezmoitemplates/
│   ├── zellij-macos.kdl                    full zellij config body
│   └── zellij-linux.kdl                    same + default_layout "minimal"
├── dot_config/
│   ├── alacritty/
│   │   ├── alacritty.toml.tmpl             OS-branched window/keybinds
│   │   ├── common.toml                     shared keybinds
│   │   └── profiles/
│   │       ├── README.md                   how to add a host
│   │       └── example.toml                template profile
│   └── zellij/
│       ├── config.kdl.tmpl                 picks macos or linux body
│       └── layouts/
│           └── minimal.kdl                 compact-bar only, no status-bar
└── dot_local/bin/
    └── executable_alacritty-profile        fzf picker
```

See `dot_config/alacritty/profiles/README.md` for how to add a host.

## Requirements

- `alacritty`, `zellij`, `fzf` on the local machine.
- `zellij` on any remote host you define a profile for.
