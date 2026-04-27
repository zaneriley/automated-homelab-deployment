#!/usr/bin/env bash
# scripts/bake-rehearse-nuc-base.sh
#
# One-time setup for the Linux fleet (NUC) rehearsal harness.
#
# Companion to scripts/bake-rehearse-base.sh — the macOS/Tart bake.
# Same shape, same idempotency posture; different substrate (Lima for
# Linux, Tart for Mac, per AGENTS.md §2 ratified split).
#
# Creates `nuc-rehearse-base`: an Ubuntu 22.04 LTS Lima VM, headless
# (--tty=false), trimmed to 2 CPU / 2 GiB RAM / 20 GiB disk so the
# rehearsal harness fits inside the master node's working set without
# inheriting Lima's 4/4/100 default-template baseline. Subsequent
# rehearsals clone from this base via `limactl clone`.
#
# Why a base? On first run Lima downloads the cloud-image (~600 MB),
# unpacks it, runs first-boot cloud-init, and brings the SSH agent
# online. That's ~60-90 seconds of work we don't want to repeat for
# every rehearsal. Bake once, clone fast.
#
# Why NOT reuse cloud-init/user-data? That file is Ubuntu-Subiquity
# autoinstall format (ISO-driven installer), not the cloud-config
# format Lima feeds to cloud-init on already-booted cloud-images. The
# two are different contracts — see file header in cloud-init/user-data.
# Lima's stock ubuntu-22.04 template already brings up python3 + SSH +
# our user; that's everything Ansible needs.
#
# Idempotent: if `nuc-rehearse-base` already exists and is in a sane
# stopped state with python3 reachable, this is a no-op.
#
# Run via:  make rehearse-nuc-bake

set -euo pipefail

BASE_VM="nuc-rehearse-base"
LIMACTL="/opt/homebrew/bin/limactl"
TEMPLATE="template://ubuntu-22.04"
# Trim from Lima's 4/4/100 defaults — this VM only needs to host an
# apt install + a couple of systemd services. 100 GiB sparse qcow2
# costs little on disk but signals "production sized," which this
# isn't.
CPUS="2"
MEMORY="2"
DISK="20"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==>\033[0m %s\n' "$*" >&2; exit 1; }

[ -x "$LIMACTL" ] || die "limactl not installed at $LIMACTL (brew install lima)"

# Existence check via `limactl list -q` (quiet — names only). Lima 2.x
# returns the bare name list which is a clean grep target; older
# `lima list` formats added a header row. Pin to -q to keep this stable.
local_has() { "$LIMACTL" list -q 2>/dev/null | grep -qx "$1"; }
vm_status() { "$LIMACTL" list 2>/dev/null | awk -v n="$1" 'NR>1 && $1 == n {print $2}'; }

# Trap: on exit, leave the VM in a stopped state so it's quiescent
# and clones-of-stopped behave deterministically. Don't delete — the
# bake's job is to leave $BASE_VM persistent.
cleanup_bake() {
  local rc=$?
  if local_has "$BASE_VM" && [ "$(vm_status "$BASE_VM")" = "Running" ]; then
    log "Cleanup: stopping $BASE_VM"
    "$LIMACTL" stop "$BASE_VM" 2>/dev/null || true
  fi
  exit "$rc"
}
trap cleanup_bake INT TERM EXIT

# 1. If the base VM already exists and python3 reaches over SSH, no-op.
# This is the idempotency cliff — re-running the bake on an already-
# baked host should be ~instant.
if local_has "$BASE_VM"; then
  status="$(vm_status "$BASE_VM")"
  log "$BASE_VM already exists (status=$status)"
  if [ "$status" != "Running" ]; then
    log "Booting $BASE_VM for verification"
    "$LIMACTL" start "$BASE_VM" --tty=false
  fi
  if "$LIMACTL" shell --workdir / "$BASE_VM" python3 --version >/dev/null 2>&1; then
    log "python3 verified inside $BASE_VM"
    log "Stopping $BASE_VM (already baked, leaving it stopped for clones)"
    "$LIMACTL" stop "$BASE_VM" 2>/dev/null || true
    log "Done — $BASE_VM is ready"
    exit 0
  fi
  warn "$BASE_VM exists but python3 missing — re-baking"
  "$LIMACTL" stop "$BASE_VM" 2>/dev/null || true
  "$LIMACTL" delete "$BASE_VM" 2>/dev/null || true
fi

# 2. Create fresh from the stock Ubuntu 22.04 template. --tty=false
# disables Lima's interactive editor (noninteractive automation
# contract — same as `tart run --no-graphics` in the macOS bake).
# --set drops CPU/memory/disk before first boot so we don't pay the
# 100 GiB sparse qcow2 cost; this also exercises Lima 2.x's `--set`
# yq-expression path, which is the supported way to template
# overrides without forking the upstream yaml.
log "Creating $BASE_VM from $TEMPLATE (Ubuntu 22.04 LTS, ~60-90 sec first-time)"
"$LIMACTL" create \
  --name="$BASE_VM" \
  --tty=false \
  --cpus="$CPUS" \
  --memory="$MEMORY" \
  --disk="$DISK" \
  "$TEMPLATE"

# 3. Start (create only stages; start brings the VM up + runs cloud-init)
log "Starting $BASE_VM"
"$LIMACTL" start "$BASE_VM" --tty=false

# 4. Verify SSH is reachable + python3 is present (Ansible's requirement).
# `limactl shell` uses Lima's generated ssh.config under the hood, so a
# successful `true` here proves both the VM and the SSH path are sane.
log "Verifying SSH"
"$LIMACTL" shell --workdir / "$BASE_VM" true || die "SSH never came up inside $BASE_VM"

log "Verifying python3"
"$LIMACTL" shell --workdir / "$BASE_VM" python3 --version || die "python3 not found in $BASE_VM (Ansible needs it; cloud-image regression?)"

# 5. Stop cleanly. Lima doesn't have first-class snapshots like Tart;
# the convention is "stopped VM = base," and `limactl clone` of a
# stopped VM gives us a fresh COW copy ready to start.
log "Stopping $BASE_VM (base is now ready; clones will start from this state)"
"$LIMACTL" stop "$BASE_VM"

log "Done. $BASE_VM is ready for rehearsals."
log "Use 'make check-rehearse PLAY=<path>' or 'make apply-rehearse PLAY=<path>' next."
