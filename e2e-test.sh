#!/usr/bin/env bash
# Host-side driver for the bootstrap.sh --test e2e smoke test.
#
# Spins up a fresh Tart macOS VM from cirruslabs/macos-sequoia-base, mounts
# the dotfiles repo over VirtioFS read-only, enables passwordless sudo for
# the admin user (so the bootstrap's many sudo calls don't each need a
# password), then runs `./bootstrap.sh --test` inside the guest via
# `tart exec` (no SSH/sshpass needed — uses the Tart Guest Agent).
#
# The VM is left stopped on exit so failures can be inspected. Pass --clean
# to also `tart delete` it on success.
#
# Requires: tart (brew install cirruslabs/cli/tart). macOS only.

set -euo pipefail

VM=mai-test
IMAGE="ghcr.io/cirruslabs/macos-sequoia-base:latest"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEAN_ON_SUCCESS=0

for arg in "$@"; do
  case "$arg" in
    --clean) CLEAN_ON_SUCCESS=1 ;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

command -v tart >/dev/null || { echo "tart not installed (brew install cirruslabs/cli/tart)" >&2; exit 1; }

RUN_PID=""
cleanup() {
  local rc=$?
  if [ -n "$RUN_PID" ] && kill -0 "$RUN_PID" 2>/dev/null; then
    tart stop "$VM" 2>/dev/null || true
    wait "$RUN_PID" 2>/dev/null || true
  fi
  if [ $rc -eq 0 ] && [ "$CLEAN_ON_SUCCESS" -eq 1 ]; then
    tart delete "$VM" 2>/dev/null || true
    echo "[e2e] deleted $VM"
  elif [ $rc -ne 0 ]; then
    echo "[e2e] FAILED (exit $rc); VM left as-is for inspection: tart list" >&2
  fi
}
trap cleanup EXIT

step() { printf '\n[e2e] %s\n' "$*"; }

# ---- 1. fresh VM ----------------------------------------------------------
step "stop+delete any prior $VM"
tart stop "$VM" 2>/dev/null || true
tart delete "$VM" 2>/dev/null || true

step "clone fresh $VM from $IMAGE"
tart clone "$IMAGE" "$VM"

# ---- 2. boot with the repo VirtioFS-mounted -------------------------------
step "boot $VM (no graphics) with $REPO_ROOT mounted as 'dotfiles' (ro)"
tart run --dir="dotfiles:${REPO_ROOT}:ro" --no-graphics "$VM" >/tmp/tart-run.log 2>&1 &
RUN_PID=$!

step "wait for guest agent"
SECONDS=0
until tart exec "$VM" hostname >/dev/null 2>&1; do
  if [ "$SECONDS" -gt 180 ]; then
    echo "guest agent never came up; tart run log:" >&2
    tail -50 /tmp/tart-run.log >&2
    exit 1
  fi
  sleep 5
done
echo "  guest ready after ${SECONDS}s"

# ---- 3. passwordless sudo for admin (so bootstrap.sh's sudo -v works) -----
# Two-line sudoers entry:
#   1. `Defaults:admin !authenticate` — needed because bootstrap.sh starts with
#      `sudo -v`, which validates credentials. With plain NOPASSWD, sudo -v
#      still fails under tart exec (no TTY). !authenticate bypasses validation.
#   2. `admin ALL=(ALL) NOPASSWD: ALL` — actual passwordless command exec.
step "enable passwordless sudo for admin (with !authenticate for sudo -v)"
echo admin | tart exec -i "$VM" sudo -S sh -c \
  'cat > /etc/sudoers.d/admin-nopass <<EOF
Defaults:admin !authenticate
admin ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/admin-nopass
visudo -cf /etc/sudoers.d/admin-nopass'

step "verify NOPASSWD is in effect"
echo "  whoami: $(tart exec "$VM" whoami)"
echo "  sudoers.d listing:"; tart exec "$VM" ls -la /etc/sudoers.d/ | sed 's/^/    /'
if tart exec "$VM" sudo -n true 2>&1; then
  echo "  sudo -n true: PASS"
else
  echo "  sudo -n true: FAIL — NOPASSWD did not take effect" >&2
  exit 1
fi
# bootstrap.sh starts with `sudo -v`. With NOPASSWD set, sudo -v should also
# succeed. Verify before launching the long-running bootstrap.
if tart exec "$VM" sudo -n -v 2>&1; then
  echo "  sudo -n -v: PASS"
else
  echo "  sudo -n -v: FAIL — bootstrap.sh's 'sudo -v' would block" >&2
  exit 1
fi

# ---- 4. run bootstrap.sh --test from the VirtioFS mount -------------------
step "run bootstrap.sh --test inside VM (this takes ~15-30 min: brew bundle + AI stack)"
tart exec "$VM" bash "/Volumes/My Shared Files/dotfiles/bootstrap.sh" --test

# ---- 5. post-bootstrap sanity --------------------------------------------
step "post-apply checks (hostname, mai-doctor)"
tart exec "$VM" hostname
tart exec "$VM" "/Users/admin/.local/bin/mai-doctor" || true

step "DONE — bootstrap.sh --test completed cleanly"
