#!/usr/bin/env bash
# scripts/rehearse-tart.sh
#
# Rehearse destructive Ansible plays against a throwaway macOS VM via Tart.
# Each invocation is fresh: clone the base image, boot, plant fixtures,
# run the play with the destructive flag enabled, verify the change,
# prove idempotency, tear the VM down.
#
# Per ADR-0003: layers 2 and 3 of `harden` MUST clear this rehearsal
# before being enabled on the real machine.
#
# Credentials: cirruslabs's `macos-*-vanilla` images ship with the
# public-default `admin / admin` (https://tart.run/quick-start/). The
# bake step (`make rehearse-base`) configures NOPASSWD sudo so this
# script never sends the password over the wire after initial login.
# `sshpass -e` (env-var) is used instead of `-p` so the password never
# appears in `ps -ef` on the host either.
#
# Prereqs (installed via Brewfile):
#   - cirruslabs/cli/tart
#   - hudochenkov/sshpass/sshpass
#
# Base image must be present (one-time setup):
#   make rehearse-base
#
# Usage:
#   scripts/rehearse-tart.sh [layer2|layer3]
#
# Default: layer2.

set -euo pipefail

LAYER="${1:-layer2}"
# CLT-baked image — vanilla doesn't have Xcode Command Line Tools, so
# /usr/bin/python3 there is a stub that prompts for a CLT install and
# crashes Ansible's setup module. We bake CLT once into tahoe-clt-base
# and clone from it for each rehearsal.
BASE_VM="tahoe-clt-base"
VM_NAME="rehearsal-$$"
SSH_USER="admin"
SSH_PASS="admin"
TART="/opt/homebrew/bin/tart"
SSHPASS="/opt/homebrew/bin/sshpass"

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
INV_FILE="$(mktemp -t rehearsal-inv).yml"
APPLY1_LOG="$(mktemp -t rehearsal-apply1).log"
CHECK_LOG="$(mktemp -t rehearsal-check).log"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==>\033[0m %s\n' "$*" >&2; exit 1; }

cleanup() {
  local rc=$?
  for f in "$INV_FILE" "$APPLY1_LOG" "$CHECK_LOG"; do
    [ -f "$f" ] && rm -f "$f"
  done
  if [ -n "${VM_NAME:-}" ] && "$TART" list 2>/dev/null | awk 'NR>1 {print $2}' | grep -qx "$VM_NAME"; then
    log "Cleanup: stopping + deleting $VM_NAME"
    "$TART" stop "$VM_NAME" 2>/dev/null || true
    "$TART" delete "$VM_NAME" 2>/dev/null || true
  fi
  exit "$rc"
}
trap cleanup INT TERM EXIT

# -- Pre-flight: tools and base image --
[ -x "$TART" ]    || die "tart not installed (brew install cirruslabs/cli/tart)"
[ -x "$SSHPASS" ] || die "sshpass not installed (brew install hudochenkov/sshpass/sshpass)"
"$TART" list 2>/dev/null | awk 'NR>1 {print $2}' | grep -qx "$BASE_VM" || \
  die "base image $BASE_VM missing — run 'make rehearse-base' to bake it (one-time, ~10 min)"

# Pre-flight: a stale rehearsal-vm from a crashed prior run would
# collide on `tart clone`. Reap it before cloning.
"$TART" delete "$VM_NAME" 2>/dev/null || true

# -- Clone + boot --
log "Cloning $BASE_VM → $VM_NAME"
"$TART" clone "$BASE_VM" "$VM_NAME"

log "Booting $VM_NAME (headless)"
"$TART" run --no-graphics "$VM_NAME" >/dev/null 2>&1 &

# -- Wait for IP, then SSH --
log "Waiting for VM IP"
VM_IP=""
for _ in $(seq 1 60); do
  VM_IP="$("$TART" ip "$VM_NAME" 2>/dev/null || true)"
  [ -n "$VM_IP" ] && break
  sleep 2
done
[ -n "$VM_IP" ] || die "VM never got an IP"
log "VM IP: $VM_IP"

# sshpass -e reads SSHPASS from the environment so the password is
# not visible in `ps -ef` on the host. (NOPASSWD sudo is baked into
# the VM by `make rehearse-base` so subsequent `sudo` calls inside
# the VM don't need a password either.)
ssh_vm() {
  SSHPASS="$SSH_PASS" "$SSHPASS" -e ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=5 \
    -o LogLevel=ERROR \
    -o PreferredAuthentications=password \
    -o PubkeyAuthentication=no \
    -o IdentityAgent=none \
    "$SSH_USER@$VM_IP" \
    "$@"
}

log "Waiting for SSH"
for _ in $(seq 1 30); do
  ssh_vm true 2>/dev/null && break
  sleep 2
done
ssh_vm true || die "SSH never came up"

# Sanity-check the baked-in CLT — `tahoe-clt-base` should have it; if
# someone re-clones the wrong source this catches it early.
ssh_vm 'xcode-select -p >/dev/null 2>&1' || die "CLT missing in $BASE_VM — re-bake with 'make rehearse-base'"
# Sanity-check NOPASSWD sudo is in place (baked by `make rehearse-base`).
ssh_vm 'sudo -n true' 2>/dev/null || die "NOPASSWD sudo missing in $BASE_VM — re-bake with 'make rehearse-base'"

# -- Generate ephemeral inventory pointing at the VM --
cat > "$INV_FILE" <<EOF
---
# Ephemeral inventory for the Tart rehearsal VM. Do NOT set host-level
# become — that would make ansible_user_uid resolve to 0 and break
# our user-scope launchctl tasks (gui/0 is invalid). Only the L2 task
# declares its own become at task level. NOPASSWD sudo is baked into
# the image by make rehearse-base so no become_password is needed.
all:
  children:
    workstations:
      hosts:
        rehearsal-vm:
          ansible_host: $VM_IP
          ansible_user: $SSH_USER
          ansible_password: $SSH_PASS
          ansible_python_interpreter: /usr/bin/python3
          ansible_ssh_common_args: "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no -o IdentityAgent=none"
EOF

# -- Per-layer fixtures + extra-vars --
case "$LAYER" in
  layer2)
    log "Planting Layer 2 fixtures (empty .app dirs in /Applications/)"
    ssh_vm 'sudo mkdir -p /Applications/{GarageBand,iMovie,Keynote,Numbers,Pages}.app'
    ssh_vm 'ls /Applications/ | grep -E "^(GarageBand|iMovie|Keynote|Numbers|Pages)\.app$" | sort | tee /tmp/fixtures.txt'
    # JSON form so booleans stay typed; `-e key=value` would coerce to string.
    EXTRA_VARS='{"harden_apple_cruft_delete_bundles": true}'
    L2_TASK_NAME='Harden/L2 — delete user-removable consumer Apple app bundles'
    POST_VERIFY='ls /Applications/ | grep -E "^(GarageBand|iMovie|Keynote|Numbers|Pages)\.app$" && exit 1 || echo "(none of the targets remain — PASS)"'
    ;;
  layer3)
    die "layer3 rehearsal not implemented yet"
    ;;
  *)
    die "unknown layer: $LAYER (expected layer2 or layer3)"
    ;;
esac

cd "$REPO_ROOT"

# -- Apply 1: should remove the planted bundles --
log "Apply 1: ansible-playbook --tags harden -e $EXTRA_VARS"
ansible-playbook -i "$INV_FILE" --tags harden -e "$EXTRA_VARS" site.yml 2>&1 | tee "$APPLY1_LOG"

APPLY1_RECAP=$(grep '^rehearsal-vm' "$APPLY1_LOG" | tail -1 || true)
[ -n "$APPLY1_RECAP" ] || die "apply 1 produced no PLAY RECAP for rehearsal-vm"
echo "$APPLY1_RECAP" | grep -qE 'failed=0\b' || die "apply 1 reported failures: $APPLY1_RECAP"
echo "$APPLY1_RECAP" | grep -qvE 'changed=0\b' || die "apply 1 reported zero changes — fixtures may not have been planted: $APPLY1_RECAP"

# -- Independent verification: the bundles should be gone --
log "Independent verify inside VM"
ssh_vm "$POST_VERIFY"

# -- Apply 2 (via --check): idempotency proof. Layer 2 must report
# changed=0 because state=absent on already-absent paths is a no-op. --
log "Idempotency check (apply -> --check, expect changed=0)"
ansible-playbook -i "$INV_FILE" --tags harden -e "$EXTRA_VARS" --check site.yml 2>&1 | tee "$CHECK_LOG"

CHECK_RECAP=$(grep '^rehearsal-vm' "$CHECK_LOG" | tail -1 || true)
[ -n "$CHECK_RECAP" ] || die "second --check produced no PLAY RECAP"
echo "$CHECK_RECAP" | grep -qE 'failed=0\b' || die "second --check reported failures: $CHECK_RECAP"
echo "$CHECK_RECAP" | grep -qE 'changed=0\b' || die "Idempotency FAIL — second --check reports a change: $CHECK_RECAP"

# Confirm the L2 task itself did NOT report changed in the second run.
# Without this we'd be trusting the play recap to attribute changes
# correctly across all tasks.
if grep -qE "^changed: \[rehearsal-vm\].*${L2_TASK_NAME}" "$CHECK_LOG"; then
  die "Idempotency FAIL — L2 task itself reported changed on second run"
fi

log "Idempotency proven: $CHECK_RECAP"
log "Rehearsal $LAYER PASS. VM will be torn down on exit."
