#!/usr/bin/env bash
# Fresh-Mac bootstrap. Sets hostname, installs chezmoi, applies the dotfiles.
# Pass --test to run non-interactively against a VirtioFS-mounted source
# (used by the Tart VM smoke test); default mode is interactive
# `chezmoi init willemneal` against the real GitHub repo.
set -euo pipefail

MODE="${1:-real}"

# ---- 1. sudo upfront, kept alive in the background -------------------------
sudo -v
( while true; do sudo -n true 2>/dev/null; sleep 60; kill -0 $$ 2>/dev/null || exit; done ) &
SUDO_KEEPALIVE=$!
trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null || true' EXIT

# ---- 2. hostname (chezmoi gates AI scripts on this) -----------------------
if [ "$(hostname)" != "mai" ]; then
  sudo scutil --set HostName mai
  sudo scutil --set LocalHostName mai
  sudo scutil --set ComputerName mai
fi

# ---- 3. install chezmoi if missing ----------------------------------------
if ! command -v chezmoi >/dev/null 2>&1; then
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
fi
export PATH="$HOME/.local/bin:$PATH"

# ---- 4. wire up source dir + chezmoi config -------------------------------
case "$MODE" in
  --test)
    MOUNT="/Volumes/My Shared Files/dotfiles"
    [ -d "$MOUNT" ] || { echo "test mode requires VirtioFS mount at $MOUNT" >&2; exit 1; }
    LOCAL="$HOME/.local/share/chezmoi"
    rm -rf "$LOCAL"
    mkdir -p "$(dirname "$LOCAL")"
    cp -R "$MOUNT" "$LOCAL"   # copy not symlink — VirtioFS is unreliable for chezmoi reads
    mkdir -p "$HOME/.config/chezmoi"
    cat > "$HOME/.config/chezmoi/chezmoi.toml" <<'EOF'
[data]
  name = "Test User"
  email = "test@example.com"
  signing_key = ""
EOF
    ;;
  real|"")
    chezmoi init willemneal   # interactive: clones + prompts for name/email/signing_key
    ;;
  *)
    echo "usage: $0 [--test]" >&2
    exit 2
    ;;
esac

# ---- 5. apply -------------------------------------------------------------
chezmoi apply -v

echo
echo "Bootstrap complete. Run \`mai-doctor\` to verify."
