#!/usr/bin/env bash
# bootstrap.sh — idempotent first-run on a fresh macOS install.
# Each step detects existing state and no-ops if already done.

set -euo pipefail

# Fail clearly on interrupts so brew / ansible aren't left in an
# inconsistent mid-action state. Exit 130 is the conventional SIGINT code.
trap 'printf "\033[1;31m==>\033[0m interrupted; state may be inconsistent — review before re-running\n" >&2; exit 130' INT TERM

# Resolve the script's directory robustly (survives symlinks).
cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")")"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==>\033[0m %s\n' "$*" >&2; exit 1; }

# --- Xcode Command Line Tools ---
if xcode-select -p >/dev/null 2>&1; then
  log "Xcode Command Line Tools: present"
else
  log "Xcode Command Line Tools: installing (an interactive prompt will appear)"
  xcode-select --install
  die "Re-run bootstrap.sh after the CLT install completes"
fi

# --- Homebrew ---
if command -v brew >/dev/null 2>&1; then
  log "Homebrew: present"
else
  log "Homebrew: installing"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Put brew on PATH for this session (fresh installs may not have
# evaluated ~/.zprofile yet).
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# --- Brewfile reconciliation ---
# --no-upgrade matches the roles/bootstrap task: install missing entries,
# do NOT upgrade already-installed packages (avoids surprise major-version
# bumps during a bootstrap).
log "brew bundle --no-upgrade (reconciling against Brewfile)"
brew bundle --file="$PWD/Brewfile" --no-upgrade

# --- Ansible Galaxy collections ---
log "ansible-galaxy collection install -r requirements.yml"
ansible-galaxy collection install -r requirements.yml

# --- Run the playbook ---
log "ansible-playbook site.yml"
ansible-playbook site.yml

log "bootstrap complete. Re-run 'make check' to confirm convergence (zero changes expected)."
