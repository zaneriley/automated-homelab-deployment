#!/usr/bin/env bash
# scripts/rehearse-nuc.sh
#
# Rehearse Ansible plays against a throwaway Ubuntu VM via Lima.
# Linux-fleet companion to scripts/rehearse-tart.sh (the Mac/Tart
# rehearsal). Same pattern: clone a known base, run the play, prove
# idempotency, tear down.
#
# Per AGENTS.md §2 the harness's ratified Linux substrate is Lima
# (Colima already runs on it). Tart is for Mac. Don't introduce a
# third VM tool here.
#
# Idempotency proof shape (ADR-0009): when --apply is passed we run
# the play once for real, then re-run with --check. The second --check
# MUST report changed=0 — that's the witness for a role being honest
# about its state.
#
# Prereqs (installed via Brewfile):
#   - lima (limactl)
#
# Base image must be present (one-time setup):
#   make rehearse-nuc-bake
#
# Usage:
#   scripts/rehearse-nuc.sh [--apply] [--keep] PLAY
#
#   PLAY  Path to a playbook OR `/dev/stdin` (then the play comes from
#         stdin — useful for ad-hoc role-runs without committing a
#         throwaway playbook to the repo).
#
# Flags:
#   --apply  Run the play for real (no --check on the first pass), then
#            re-run with --check to prove idempotency. Without --apply,
#            the script does a single --check --diff pass (rehearsal
#            preview, no state mutated even inside the VM).
#   --keep   Don't destroy the clone on exit. Useful for postmortem.

set -euo pipefail

APPLY=0
KEEP=0
PLAY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --keep)  KEEP=1; shift ;;
    --help|-h)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    -*) echo "unknown flag: $1" >&2; exit 2 ;;
    *)  PLAY="$1"; shift ;;
  esac
done
[ -n "$PLAY" ] || { echo "usage: $0 [--apply] [--keep] PLAY" >&2; exit 2; }

BASE_VM="nuc-rehearse-base"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
VM_NAME="nuc-rehearse-${TIMESTAMP}-$$"
LIMACTL="/opt/homebrew/bin/limactl"

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$REPO_ROOT/.tmp"
LOG_FILE="$REPO_ROOT/.tmp/rehearse-nuc-${TIMESTAMP}.log"
INV_FILE="$(mktemp -t rehearsal-nuc-inv).yml"
CHECK1_LOG="$(mktemp -t rehearsal-nuc-check1).log"
APPLY_LOG="$(mktemp -t rehearsal-nuc-apply).log"
CHECK2_LOG="$(mktemp -t rehearsal-nuc-check2).log"

# stdin-fed plays need to land on disk because ansible-playbook resolves
# its argument once. We materialize stdin into REPO_ROOT/.tmp/ rather
# than mktemp so the path resolves under the role-search root and
# operators can postmortem the exact play that ran.
if [ "$PLAY" = "/dev/stdin" ] || [ "$PLAY" = "-" ]; then
  STDIN_PLAY="$REPO_ROOT/.tmp/rehearse-nuc-${TIMESTAMP}.yml"
  cat > "$STDIN_PLAY"
  PLAY="$STDIN_PLAY"
fi

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*" | tee -a "$LOG_FILE"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==>\033[0m %s\n' "$*" >&2; exit 1; }

local_has() { "$LIMACTL" list -q 2>/dev/null | grep -qx "$1"; }

cleanup() {
  local rc=$?
  for f in "$INV_FILE" "$CHECK1_LOG" "$APPLY_LOG" "$CHECK2_LOG"; do
    [ -f "$f" ] && rm -f "$f"
  done
  if [ "$KEEP" = 1 ]; then
    log "Keeping $VM_NAME (--keep)"
  elif [ -n "${VM_NAME:-}" ] && local_has "$VM_NAME"; then
    log "Cleanup: stopping + deleting $VM_NAME"
    "$LIMACTL" stop "$VM_NAME" 2>/dev/null || true
    "$LIMACTL" delete "$VM_NAME" --force 2>/dev/null || true
  fi
  exit "$rc"
}
trap cleanup INT TERM EXIT

# -- Pre-flight: tools, base image, play file --
[ -x "$LIMACTL" ] || die "limactl not installed (brew install lima)"
local_has "$BASE_VM" || die "base image $BASE_VM missing — run 'make rehearse-nuc-bake' first"
[ -f "$PLAY" ] || die "play not found: $PLAY"

# -- Clone + start --
# `limactl clone --start` (Lima 2.x) creates a clone and brings it up
# in one step. The base VM is in `Stopped` state from the bake; clones
# inherit that on-disk state but get a fresh first-boot.
log "Cloning $BASE_VM → $VM_NAME"
"$LIMACTL" clone --start "$BASE_VM" "$VM_NAME" --tty=false

# -- Wait for SSH (limactl shell uses Lima's ssh.config under the hood) --
log "Waiting for SSH inside $VM_NAME"
for _ in $(seq 1 30); do
  "$LIMACTL" shell --workdir / "$VM_NAME" true 2>/dev/null && break
  sleep 2
done
"$LIMACTL" shell --workdir / "$VM_NAME" true || die "SSH never came up inside $VM_NAME"

# -- Discover Lima's SSH config + the in-VM user. Lima writes ~/.lima/
# <name>/ssh.config and the `lima-<name>` host alias resolves through
# it. Ansible can drive the connection via ansible_ssh_common_args="-F
# <ssh.config>", which means we don't reinvent any of Lima's port /
# key / user wiring. --
LIMA_SSH_CONFIG="$HOME/.lima/$VM_NAME/ssh.config"
[ -f "$LIMA_SSH_CONFIG" ] || die "Lima ssh.config missing at $LIMA_SSH_CONFIG"
LIMA_HOST_ALIAS="lima-$VM_NAME"
# The in-VM user matches the host user by default — Lima reads
# `whoami` on the host and creates a matching user inside the guest
# (see `limactl info | jq .defaultTemplate.user.name`). We pin it
# explicitly so the inventory entry is reproducible regardless of who
# runs the rehearsal.
VM_USER="$(whoami)"

# -- Generate ephemeral inventory pointing at the Lima VM --
# Group: nucs_rehearsal. This mirrors the harness convention from
# inventory/rehearsal.yml (the example is in group_vars/nucs_rehearsal
# .example.yml). We park the host inside `nucs` too so any play that
# `hosts: nucs` will pick it up — but only after explicit operator
# intent (this script is the only thing that writes this file).
cat > "$INV_FILE" <<EOF
---
# Ephemeral inventory for the Lima rehearsal VM. Generated by
# scripts/rehearse-nuc.sh; lifetime is one rehearsal run.
all:
  children:
    nucs:
      hosts:
        $VM_NAME:
          ansible_host: $LIMA_HOST_ALIAS
          ansible_user: $VM_USER
          ansible_python_interpreter: /usr/bin/python3
          ansible_ssh_common_args: "-F $LIMA_SSH_CONFIG"
    nucs_rehearsal:
      hosts:
        $VM_NAME: {}
EOF

cd "$REPO_ROOT"

if [ "$APPLY" = 0 ]; then
  # -- Single --check --diff pass: rehearsal preview --
  # Mirrors `make check`: shows what *would* change without mutating
  # the VM. Useful for "what does this role want to do on a fresh
  # NUC?" without committing to the apply path yet.
  log "Check pass: ansible-playbook --check --diff $PLAY (target group: nucs)"
  ansible-playbook -i "$INV_FILE" --check --diff "$PLAY" 2>&1 | tee "$CHECK1_LOG" | tee -a "$LOG_FILE"

  CHECK1_RECAP=$(grep "^$VM_NAME" "$CHECK1_LOG" | tail -1 || true)
  [ -n "$CHECK1_RECAP" ] || die "--check produced no PLAY RECAP for $VM_NAME"
  echo "$CHECK1_RECAP" | grep -qE 'failed=0\b' || die "--check reported failures: $CHECK1_RECAP"
  log "Check pass complete: $CHECK1_RECAP"
  log "Rehearsal (check-only) PASS. VM will be torn down on exit."
  exit 0
fi

# -- Apply path: run for real, then prove idempotency --
log "Apply: ansible-playbook $PLAY (target group: nucs)"
ansible-playbook -i "$INV_FILE" "$PLAY" 2>&1 | tee "$APPLY_LOG" | tee -a "$LOG_FILE"

APPLY_RECAP=$(grep "^$VM_NAME" "$APPLY_LOG" | tail -1 || true)
[ -n "$APPLY_RECAP" ] || die "apply produced no PLAY RECAP for $VM_NAME"
echo "$APPLY_RECAP" | grep -qE 'failed=0\b' || die "apply reported failures: $APPLY_RECAP"
echo "$APPLY_RECAP" | grep -qvE 'changed=0\b' || warn "apply reported zero changes — was the VM already in target state?"

# -- Idempotency proof: second --check must report changed=0 --
log "Idempotency check (--check, expect changed=0)"
ansible-playbook -i "$INV_FILE" --check "$PLAY" 2>&1 | tee "$CHECK2_LOG" | tee -a "$LOG_FILE"

CHECK2_RECAP=$(grep "^$VM_NAME" "$CHECK2_LOG" | tail -1 || true)
[ -n "$CHECK2_RECAP" ] || die "second --check produced no PLAY RECAP"
echo "$CHECK2_RECAP" | grep -qE 'failed=0\b' || die "second --check reported failures: $CHECK2_RECAP"
echo "$CHECK2_RECAP" | grep -qE 'changed=0\b' || die "Idempotency FAIL — second --check reports changes: $CHECK2_RECAP"

log "Idempotency proven: $CHECK2_RECAP"
log "Rehearsal apply PASS. Full log: $LOG_FILE. VM will be torn down on exit."
