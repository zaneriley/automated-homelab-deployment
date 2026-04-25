#!/usr/bin/env bash
# scripts/bake-rehearse-base.sh
#
# One-time setup for the Tart rehearsal harness.
#
# Pulls cirruslabs's macos-tahoe-vanilla image, clones it into
# `tahoe-clt-base`, boots that, installs Xcode Command Line Tools
# inside, shuts down cleanly. Subsequent rehearsals clone from
# `tahoe-clt-base` so they don't pay the CLT install cost each time.
#
# Why bake CLT? `vanilla` is a clean macOS — no developer tools — so
# `/usr/bin/python3` there is a stub that prompts for CLT install and
# returns no JSON, which crashes Ansible's `setup` module. Baking once
# avoids ~3-5 minutes per rehearsal AND a per-rehearsal sshpass
# multi-line auth dance with `softwareupdate -i`.
#
# Idempotent: if `tahoe-clt-base` already has CLT, this is a no-op.
#
# Run via:  make rehearse-base

set -euo pipefail

VANILLA_OCI="ghcr.io/cirruslabs/macos-tahoe-vanilla:latest"
VANILLA_LOCAL="tahoe-base"
CLT_BASE="tahoe-clt-base"
SSH_USER="admin"
SSH_PASS="admin"
TART="/opt/homebrew/bin/tart"
SSHPASS="/opt/homebrew/bin/sshpass"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m==>\033[0m %s\n' "$*" >&2; exit 1; }

[ -x "$TART" ]    || die "tart not installed (brew bundle)"
[ -x "$SSHPASS" ] || die "sshpass not installed (brew bundle)"

local_has() { "$TART" list 2>/dev/null | awk 'NR>1 {print $2}' | grep -qx "$1"; }

ssh_v() {
  "$SSHPASS" -p "$SSH_PASS" ssh \
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

# 3. If CLT is already baked, nothing to do.
log "Booting $CLT_BASE to check for CLT"
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

if ssh_v 'xcode-select -p >/dev/null 2>&1'; then
  log "CLT already baked into $CLT_BASE — nothing to do"
  ssh_v "echo $SSH_PASS | sudo -S shutdown -h now" 2>&1 | head -1 || true
  sleep 12
  "$TART" stop "$CLT_BASE" 2>/dev/null || true
  log "Done."
  exit 0
fi

# 4. Install CLT inside the VM via softwareupdate.
# The "in-progress" sentinel makes softwareupdate -l include the CLT package.
log "Installing CLT (~3-5 min download + install)"
ssh_v "echo $SSH_PASS | sudo -S touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
LABEL=$(ssh_v 'softwareupdate -l 2>/dev/null | awk "/\\* Label: Command Line Tools/ {sub(/^[* ]*Label: /, \"\"); print; exit}"')
[ -n "$LABEL" ] || die "Could not locate Command Line Tools in softwareupdate -l output"
log "Package: $LABEL"
ssh_v "echo $SSH_PASS | sudo -S softwareupdate -i '$LABEL' --verbose 2>&1 | tail -10"
ssh_v "echo $SSH_PASS | sudo -S rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"

# Verify
ssh_v 'xcode-select -p && /usr/bin/python3 --version && /usr/bin/python3 -c "import json; print(json.dumps({\"ok\": True}))"' \
  || die "CLT install reported success but verification failed"

# 5. Shut down cleanly so the disk image is in a quiescent state.
log "Shutting down $CLT_BASE"
ssh_v "echo $SSH_PASS | sudo -S shutdown -h now" 2>&1 | head -1 || true
sleep 15
"$TART" stop "$CLT_BASE" 2>/dev/null || true

log "Done. $CLT_BASE is ready for rehearsals."
