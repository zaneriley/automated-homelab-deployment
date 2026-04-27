#!/usr/bin/env bash
# scripts/rehearse-workstation.sh
#
# Rehearse the workstation_tools `agent_surface` tag against a throwaway
# macOS VM via Tart. Verifies positive presence: pai cloned at the
# canonical path, ~/.claude/CLAUDE.md and ~/.claude/skills resolve to
# the cloned repo. Then re-runs the play with --check and asserts
# changed=0 (ADR-0009 idempotency proof).
#
# Companion to scripts/rehearse-tart.sh, which rehearses harden's
# destructive layers. The shape differs enough that they're separate
# scripts: harden proves *absence* (bundles removed, idempotency on
# state=absent no-ops); this proves *presence* (clone+symlinks present,
# idempotency on stat-gated git module).
#
# Prereqs (installed via Brewfile):
#   - cirruslabs/cli/tart
#   - hudochenkov/sshpass/sshpass
#   - gh (authenticated; `gh auth status` should succeed)
#
# Base image must be present (one-time setup):
#   make rehearse-base
#
# Usage:
#   scripts/rehearse-workstation.sh

set -euo pipefail

BASE_VM="tahoe-clt-base"
VM_NAME="rehearsal-ws-$$"
SSH_USER="admin"
SSH_PASS="admin"
TART="/opt/homebrew/bin/tart"
SSHPASS="/opt/homebrew/bin/sshpass"

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
INV_FILE="$(mktemp -t rehearsal-ws-inv).yml"
APPLY1_LOG="$(mktemp -t rehearsal-ws-apply1).log"
CHECK_LOG="$(mktemp -t rehearsal-ws-check).log"

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

# -- Pre-flight: tools, base image, and host-side gh auth --
[ -x "$TART" ]    || die "tart not installed (brew bundle)"
[ -x "$SSHPASS" ] || die "sshpass not installed (brew bundle)"
command -v gh >/dev/null || die "gh CLI not installed (brew bundle)"
gh auth status >/dev/null 2>&1 || die "gh not authenticated on host (run 'gh auth login')"
"$TART" list 2>/dev/null | awk 'NR>1 {print $2}' | grep -qx "$BASE_VM" || \
  die "base image $BASE_VM missing — run 'make rehearse-base' to bake it (one-time, ~10 min)"

# Capture the host's gh OAuth token. It's planted into the VM as a
# git "store" credential so the role's HTTPS clone of the private pai
# repo works inside the VM. The VM is torn down at exit, so the token
# never persists past the rehearsal.
GH_TOKEN="$(gh auth token 2>/dev/null)" || die "gh auth token returned no token"
[ -n "$GH_TOKEN" ] || die "gh auth token returned empty"

# Pre-flight: a stale rehearsal-ws VM from a crashed prior run would
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

ssh_vm 'xcode-select -p >/dev/null 2>&1' || die "CLT missing in $BASE_VM — re-bake with 'make rehearse-base'"
ssh_vm 'sudo -n true' 2>/dev/null || die "NOPASSWD sudo missing in $BASE_VM — re-bake with 'make rehearse-base'"

# -- Plant ephemeral GitHub credentials so the role's HTTPS clone of
# the private pai repo works inside the VM. The git "store" helper
# reads ~/.git-credentials and answers https://github.com/...
# challenges with the embedded oauth2 token — functionally identical
# to gh's git-credential helper for the clone path. Token disappears
# with the VM at teardown. --
log "Planting ephemeral GitHub credentials in VM"
ssh_vm 'umask 077 && cat > ~/.git-credentials' <<< "https://oauth2:${GH_TOKEN}@github.com"
ssh_vm 'git config --global credential.helper store'

# -- Generate ephemeral inventory pointing at the VM --
cat > "$INV_FILE" <<EOF
---
# Ephemeral inventory for the workstation_tools rehearsal VM. Same
# password-auth shape as scripts/rehearse-tart.sh — NOPASSWD sudo
# is baked into tahoe-clt-base by 'make rehearse-base'.
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

cd "$REPO_ROOT"

# -- Apply 1: clone pai + create symlinks --
# --tags agent_surface runs only the new tasks plus the bootstrap
# `setup` task (tagged `always`), which populates ansible_env. Brew
# preflight + Brewfile reconciliation are skipped — that's fine; the
# rehearsal verifies the agent_surface play in isolation.
log "Apply 1: ansible-playbook --tags agent_surface"
ansible-playbook -i "$INV_FILE" --tags agent_surface site.yml 2>&1 | tee "$APPLY1_LOG"

APPLY1_RECAP=$(grep '^rehearsal-vm' "$APPLY1_LOG" | tail -1 || true)
[ -n "$APPLY1_RECAP" ] || die "apply 1 produced no PLAY RECAP for rehearsal-vm"
echo "$APPLY1_RECAP" | grep -qE 'failed=0\b' || die "apply 1 reported failures: $APPLY1_RECAP"
echo "$APPLY1_RECAP" | grep -qvE 'changed=0\b' || die "apply 1 reported zero changes — fixtures wrong?: $APPLY1_RECAP"

# -- Independent verification: positive presence of the agent surface --
# Bundled into a single ssh call to avoid macOS sshd MaxStartups
# throttling against rapid-fire connections; failing exits with a
# distinct rc per check so the die message names the broken bit.
log "Independent verify inside VM"
ssh_vm bash -s <<'EOF' || die "FAIL — agent_surface verification (rc=$? — see line above for failed check)"
set -e
test -d ~/.agents/.git                                                                        || { echo "FAIL: ~/.agents/.git missing"; exit 11; }
test -f ~/.agents/AGENTS.md                                                                   || { echo "FAIL: ~/.agents/AGENTS.md missing"; exit 12; }
test -d ~/.agents/skills                                                                      || { echo "FAIL: ~/.agents/skills missing"; exit 13; }
test -L ~/.claude/CLAUDE.md                                                                   || { echo "FAIL: ~/.claude/CLAUDE.md not a symlink"; exit 14; }
test -L ~/.claude/skills                                                                      || { echo "FAIL: ~/.claude/skills not a symlink"; exit 15; }
[ "$(readlink ~/.claude/CLAUDE.md)" = "$HOME/.agents/AGENTS.md" ]                              || { echo "FAIL: CLAUDE.md target wrong: $(readlink ~/.claude/CLAUDE.md)"; exit 16; }
[ "$(readlink ~/.claude/skills)" = "$HOME/.agents/skills" ]                                    || { echo "FAIL: skills target wrong: $(readlink ~/.claude/skills)"; exit 17; }
# settings.json must be a real file (not a symlink — anthropics/claude-code#40857) matching pai bytes.
test -f ~/.claude/settings.json && [ ! -L ~/.claude/settings.json ]                            || { echo "FAIL: settings.json missing or unexpectedly a symlink"; exit 18; }
cmp -s ~/.claude/settings.json ~/.agents/claude-code/settings.json                             || { echo "FAIL: settings.json bytes differ from pai source"; exit 19; }
# hooks/ stays a real dir (full-dir symlinks broken — #5433); hook script is a file-level symlink.
test -d ~/.claude/hooks && [ ! -L ~/.claude/hooks ]                                            || { echo "FAIL: ~/.claude/hooks missing or unexpectedly a symlink"; exit 20; }
test -L ~/.claude/hooks/block-co-author.sh                                                     || { echo "FAIL: hook script not a symlink"; exit 21; }
[ "$(readlink ~/.claude/hooks/block-co-author.sh)" = "$HOME/.agents/claude-code/hooks/block-co-author.sh" ] || { echo "FAIL: hook symlink target wrong: $(readlink ~/.claude/hooks/block-co-author.sh)"; exit 22; }
test -x ~/.claude/hooks/block-co-author.sh                                                    || { echo "FAIL: hook script not executable through symlink"; exit 23; }
EOF
log "Presence verified: pai cloned, CLAUDE.md + skills symlinked, settings.json copied, hook script symlinked"

# -- Apply 2 (--check): idempotency proof. agent_surface tasks must
# all report changed=0 because the stat-gated clone is a no-op when
# .git/ exists, and `state: link` on already-correct symlinks is
# also a no-op. --
log "Idempotency check (--check, expect changed=0)"
ansible-playbook -i "$INV_FILE" --tags agent_surface --check site.yml 2>&1 | tee "$CHECK_LOG"

CHECK_RECAP=$(grep '^rehearsal-vm' "$CHECK_LOG" | tail -1 || true)
[ -n "$CHECK_RECAP" ] || die "second --check produced no PLAY RECAP"
echo "$CHECK_RECAP" | grep -qE 'failed=0\b' || die "second --check reported failures: $CHECK_RECAP"
echo "$CHECK_RECAP" | grep -qE 'changed=0\b' || die "Idempotency FAIL — second --check reports a change: $CHECK_RECAP"

log "Idempotency proven: $CHECK_RECAP"
log "Rehearsal workstation_tools/agent_surface PASS. VM will be torn down on exit."
