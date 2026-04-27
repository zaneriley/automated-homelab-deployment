# Brewfile — canonical bundle for the Mac Studio master node.
# Reconciled via `brew bundle --file=Brewfile` (invoked by bootstrap.sh
# and the roles/bootstrap role).
# Tailscale and Ollama are deferred (see AGENTS.md Backlog).

# === Taps ===
tap "nikitabobko/tap"   # source for the AeroSpace cask

# === Harness tooling (formulae) ===
brew "ansible"
brew "ansible-lint"
brew "yamllint"
brew "git-cliff"                        # CHANGELOG.md generator (ADR-0012)

# === Dev tooling ===
brew "gh"
brew "defaultbrowser"   # used by workstation_tools to set Zen as default; see roles/workstation_tools/

# === Containers (on-demand; not launched at boot) ===
brew "colima"
brew "docker"
brew "docker-compose"

# === Casks (GUI applications + CLI delivered as cask) ===
cask "ghostty"
cask "zed"
cask "lulu"
cask "zen"
cask "1password"
cask "1password-cli"
cask "nikitabobko/tap/aerospace"
cask "obsidian"   # vault tracked at ~/repos/obsidian-notes (see workstation_tools role + manual-steps.md)
cask "claude-code"   # Claude Code CLI; native binary, no Node runtime
cask "claude"        # Claude desktop app (hosts Cowork)

# === Fonts ===
cask "font-jetbrains-mono-nerd-font"

# === Rehearsal infrastructure (used by scripts/rehearse-tart.sh) ===
# Tart: macOS VM runner (Apple Silicon native, Apache-2.0).
# sshpass: password-auth helper for the rehearsal VM (cirruslabs vanilla
# image is admin/admin only; we don't bake keys into the base image).
brew "cirruslabs/cli/tart"
brew "hudochenkov/sshpass/sshpass"
