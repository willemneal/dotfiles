# Alacritty SSH profiles

Each file in this directory is a standalone Alacritty config that SSHes into a
remote host and attaches to (or creates) a named Zellij session.

## Add a host

1. Copy `example.toml` to `<hostname>.toml`.
2. Edit `[terminal.shell].args`:
   - Replace `user@example.com` with your SSH target.
   - Pick a Zellij session name (the argument to `--create`).
3. Run the picker:
   - macOS: `Cmd+Space` from any Alacritty window.
   - Linux: `Ctrl+Shift+Space` from any Alacritty window.
   - Or from a shell: `alacritty-profile`.

## Requirements

- `zellij` must be on the remote host's PATH.
- SSH key or agent auth is recommended — password prompts will interrupt the
  Zellij attach.

## How it works

`alacritty --config-file <profile>.toml` launches a new Alacritty window whose
shell is `ssh -t <host> zellij attach --create <session>`. When Alacritty exits
the SSH session ends; when the SSH session ends the Alacritty window closes.
