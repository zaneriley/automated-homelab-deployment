#!/usr/bin/env bash
# scripts/bake-rehearse-base.sh
#
# One-time setup for the Tart rehearsal harness.
#
# Pulls cirruslabs's macos-tahoe-vanilla image, clones it into
# `tahoe-clt-base`, boots that, configures NOPASSWD sudo on `admin`,
# installs Xcode Command Line Tools inside, shuts down cleanly.
# Subsequent rehearsals clone from `tahoe-clt-base` and inherit:
#   - working /usr/bin/python3 (CLT-baked)
#   - passwordless sudo for `admin` (so the rehearsal harness doesn't
#     leak the password through `sudo -S` on every task)
#
# Why bake CLT? `vanilla` is a clean macOS — no developer tools — so
# `/usr/bin/python3` there is a stub that prompts for CLT install and
# returns no JSON, which crashes Ansible's `setup` module.
#
# Why NOPASSWD? `cirruslabs/macos-*-vanilla` ships with the public
# default credentials `admin / admin`. Throwaway VM, well-documented.
# By baking NOPASSWD into the image we eliminate every `echo PASS |
# sudo -S` in the rehearsal path — the password no longer appears on
# any subsequent process command line.
#
# Idempotent: if `tahoe-clt-base` already has CLT + NOPASSWD, this is
# a no-op.
#
# Run via:  make rehearse-base

set -euo pipefail

VANILLA_OCI="ghcr.io/cirruslabs/macos-tahoe-vanilla:latest"
VANILLA_LOCAL="tahoe-base"
CLT_BASE="tahoe-clt-base"
SSH_USER="admin"
# Public default password for cirruslabs vanilla images
# (https://tart.run/quick-start/). Throwaway VM only — never use
# this pattern against a real host.
SSH_PASS="admin"
TART="/opt/homebrew/bin/tart"
SSHPASS="/opt/homebrew/bin/sshpass"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m==>\033[0m %s\n' "$*" >&2; exit 1; }

[ -x "$TART" ]    || die "tart not installed (brew bundle)"
[ -x "$SSHPASS" ] || die "sshpass not installed (brew bundle)"

local_has() { "$TART" list 2>/dev/null | awk 'NR>1 {print $2}' | grep -qx "$1"; }
vm_running() { "$TART" list 2>/dev/null | awk 'NR>1 && $4 == "running" {print $2}' | grep -qx "$1"; }

# Trap: on any exit (success, error, ^C, kill), make sure the VM is
# stopped so the disk image is in a quiescent state. Don't delete —
# the bake's job is to leave $CLT_BASE persistent.
cleanup_bake() {
  local rc=$?
  if vm_running "$CLT_BASE"; then
    log "Cleanup: stopping $CLT_BASE"
    "$TART" stop "$CLT_BASE" 2>/dev/null || true
  fi
  exit "$rc"
}
trap cleanup_bake INT TERM EXIT

# sshpass -e reads SSHPASS from the environment instead of -p $SSH_PASS,
# which keeps the password out of `ps -ef` on the host.
ssh_v() {
  SSHPASS="$SSH_PASS" "$SSHPASS" -e ssh \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o PreferredAuthentications=password -o PubkeyAuthentication=no -o IdentityAgent=none \
    -o ConnectTimeout=15 -o ServerAliveInterval=30 \
    "$SSH_USER@$VM_IP" "$@"
}

# 1. Make sure the vanilla local exists (clone from registry if not)
if ! local_has "$VANILLA_LOCAL"; then
  log "Cloning $VANILLA_OCI → $VANILLA_LOCAL (one-time, ~25 GB)"
  "$TART" clone "$VANILLA_OCI" "$VANILLA_LOCAL"
fi

# 2. Make sure the CLT-baked clone exists (clone from vanilla if not)
if ! local_has "$CLT_BASE"; then
  log "Cloning $VANILLA_LOCAL → $CLT_BASE (CoW; near-instant)"
  "$TART" clone "$VANILLA_LOCAL" "$CLT_BASE"
fi

log "Booting $CLT_BASE for inspection"
"$TART" run --no-graphics "$CLT_BASE" >/dev/null 2>&1 &
disown

# Wait for IP
VM_IP=""
sleep 25
for _ in $(seq 1 30); do
  VM_IP="$("$TART" ip "$CLT_BASE" 2>/dev/null || true)"
  [ -n "$VM_IP" ] && break
  sleep 2
done
[ -n "$VM_IP" ] || die "VM never got an IP"
log "VM IP: $VM_IP"

# Wait for SSH
sleep 8
for _ in $(seq 1 30); do
  ssh_v true 2>/dev/null && break
  sleep 2
done
ssh_v true || die "SSH never came up"

# 3. Bake NOPASSWD sudo for the admin user. Done FIRST so the rest of
# the bake doesn't leak the password through `sudo -S`. The single
# `echo PASS | sudo -S` here is the last password-on-command-line
# moment in the entire harness lifecycle.
SUDOERS_LINE='admin ALL=(ALL) NOPASSWD: ALL'
if ssh_v 'sudo -n true' 2>/dev/null; then
  log "NOPASSWD sudo already configured"
else
  log "Configuring NOPASSWD sudo for $SSH_USER (one-time, only password leak in the bake)"
  ssh_v "echo $SSH_PASS | sudo -S sh -c 'echo \"$SUDOERS_LINE\" > /etc/sudoers.d/admin-nopasswd && chmod 0440 /etc/sudoers.d/admin-nopasswd'"
  ssh_v 'sudo -n true' || die "NOPASSWD sudo install reported success but sudo -n still requires a password"
fi

# 4. If CLT is already baked, we're done.
if ssh_v 'xcode-select -p >/dev/null 2>&1'; then
  log "CLT already baked into $CLT_BASE"
  log "Shutting down cleanly"
  ssh_v 'sudo shutdown -h now' 2>&1 | head -1 || true
  sleep 12
  log "Done — $CLT_BASE is ready"
  exit 0
fi

# 5. Install CLT inside the VM via softwareupdate.
# The "in-progress" sentinel makes softwareupdate -l include the CLT package.
log "Installing CLT (~3-5 min download + install)"
ssh_v 'sudo touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress'
LABEL=$(ssh_v 'softwareupdate -l 2>/dev/null | awk "/\\* Label: Command Line Tools/ {sub(/^[* ]*Label: /, \"\"); print; exit}"')
if [ -z "$LABEL" ]; then
  # Capture full softwareupdate output for postmortem before dying.
  ssh_v 'softwareupdate -l 2>&1' > /tmp/softwareupdate.log || true
  die "Could not locate Command Line Tools in softwareupdate -l output (full output saved to /tmp/softwareupdate.log)"
fi
log "Package: $LABEL"
ssh_v "sudo softwareupdate -i '$LABEL' --verbose 2>&1 | tail -10"
ssh_v 'sudo rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress'

# 6. Verify
ssh_v 'xcode-select -p && /usr/bin/python3 --version && /usr/bin/python3 -c "import json; print(json.dumps({\"ok\": True}))"' \
  || die "CLT install reported success but verification failed"

# 7. Shut down cleanly so the disk image is in a quiescent state.
log "Shutting down $CLT_BASE"
ssh_v 'sudo shutdown -h now' 2>&1 | head -1 || true
sleep 15

log "Done. $CLT_BASE is ready for rehearsals."
