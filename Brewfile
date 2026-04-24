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

# === Dev tooling ===
brew "gh"

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
