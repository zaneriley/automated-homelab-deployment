# AGENTS.md — home-lab contract

Pick your altitude. Scroll-stop at the section that answers your question.

---

## 1. Philosophy

This repo configures a long-lived home lab declaratively via Ansible. The harness covers a Mac Studio master control node plus a Linux fleet (Pis, NUCs, a (redacted) NAS) managed over SSH.

Priorities, in order:

1. **De-Apple the Mac.** No iCloud sync, no Apple Intelligence, no Siri, delete consumer apps (Music/TV/News/Maps/Stocks/Photos/GarageBand/iMovie/iWork). Keep Messages (for LLM agent tooling), Safari (system fallback), Xcode + Command Line Tools.
2. **FLOSS-first toolchain** wherever viable.
3. **Declarative and reproducible.** Nothing clicked in the GUI that could be scripted. Every `defaults` key, every package, every service config lives here as YAML or text.
4. **One harness for the whole lab.** Same Ansible inventory and role structure for `master` (Mac), `nucs`, `pis`, `nas`. Apple-specific roles scoped `hosts: master` only.
5. **Clean machine.** No global language runtimes on the Mac. Use version managers (mise, nvm, uv, pipx) or Colima containers for language-specific work.

---

## 2. Ratified stack

| Layer | Pick | Rejected |
|---|---|---|
| Shell | zsh (macOS default) | fish |
| Terminal | Ghostty | iTerm2 |
| Editor | Zed | Neovim / Helix / VS Code (for this role) |
| Tiling WM | AeroSpace (no SIP disable) | yabai |
| Containers | Colima, on-demand | Docker Desktop, OrbStack |
| Outbound firewall | LuLu | Little Snitch |
| Browser | Zen | Chrome / Arc |
| Secrets | 1Password CLI + `community.general.onepassword` lookup | sops+age, Ansible Vault (for new work) |
| Config mgmt | Ansible | nix-darwin, chezmoi, shell scripts |
| Harness repo | This repo — extend to cover master node | new `homelab-master` |

Detailed rationale in [`ADRS.md`](./ADRS.md).

---

## 3. Backlog

Order matters. Do them in order. Cross off as done.

**Now**
- [ ] Scaffold master-node harness: inventory, group_vars, site.yml, 5-role skeleton
- [ ] `system_defaults` role + `bootstrap` role (so `make apply` does something meaningful)
- [ ] `harden` role layer 1 (de-Apple disable-only, variable-gated)
- [ ] `workstation_tools` role (Brewfile + installs)
- [ ] `shell_env` role (Ghostty/Zed configs + dotfile symlinks)

**Next**
- [ ] Obsidian vault → Linear-esque local backlog (frontmatter schema, Dataview dashboards, (redacted))
- [ ] Migrate `ansible/setup_nuc.yml` secrets from Ansible Vault → `onepassword` lookup

**Later**
- [ ] Populate `homelab-household-management` repo for a dedicated NUC (Immich, Home Assistant)
- [ ] Refactor `ansible/setup_nuc.yml` into NUC-scoped roles in this repo
- [ ] V1 legacy `homelab.family` forensic cleanup (missing Home Assistant container, orphaned AppDaemon, MQTT / DNS clarifications)
- [ ] DoH Pi for internal DNS (candidates: Technitium, Pi-hole+Unbound, AdGuard Home)
- [ ] Tailscale — add when there's a fleet host that needs remote reach; decision-ready (Tailscale over Headscale) but not installed
- [ ] On-device LLM serving (Ollama) — add when a concrete workflow needs it; Mac-local initially, a future (redacted) handles fine-tuning

**Deferred (decided, not scheduled)**
- `apple_cruft` layer 2 (delete consumer-app bundles) — default off; only enable after Tart VM rehearsal
- `apple_cruft` layer 3 (`/etc/hosts` telemetry block) — default off; same
- Terraform state backend migration (currently local)

**Explicitly out of scope**
- `Connected-Home*` repos (side project, ignored)
- `personal` legacy dotfiles repo (toss)
- `shiny-system` repo (not confirmed in scope)

---

## 4. How we work — acceptance gates

Three nested levels. A change doesn't land unless it clears the relevant gate(s).

### A. Per-commit gate

Every commit that touches a role or config must pass:

1. `make lint` clean (`ansible-lint` + `yamllint`)
2. `make check` shows the diff you expected — if more, different, or empty-when-nonempty-expected, stop
3. `make apply` succeeds
4. Re-run `make check` immediately after → **must report zero changes.** This is the idempotency proof. If non-zero, a task is lying about its state.
5. Managed macOS settings go through `community.general.osx_defaults` — never `command: defaults write`
6. Destructive effects are default-off behind a variable gate

### B. Per-role gate

Before a role lands on `main`:

1. All of A
2. Role has a short `README.md`: purpose, toggle variable, blast radius, undo path
3. Destructive ops gated per-layer (three-layer pattern inside `harden`)

### C. Whole-harness gate

The harness is "working" when:

1. `./bootstrap.sh` on a fresh macOS install produces the configured state in one command
2. Immediately after, `make check` reports zero changes
3. Human-visible state in System Settings matches `group_vars/master.yml`
4. Wipe + rebuild reproduces the same state

### What we rely on (honestly)

- Honest idempotency via native modules (`osx_defaults`, `file`, `homebrew`) — no `changed_when: true` lies, ever
- `--check --diff` as the drift detector
- The **second** check-run as the correctness witness

### What we do NOT rely on

- CI against the real machine. CI runs lint + `--syntax-check` on a Linux runner only.
- Tart VMs until destructive `apple_cruft` layers go live. For phase 1, the real Mac is the sandbox.

### Commits, secrets, style

- Conventional Commits (`feat(role): …`, `fix(role): …`, `docs: …`, `chore: …`). Small reviewable diffs.
- **No `Co-Authored-By:` trailers on commits, ever.** Enforced by a PreToolUse hook at `~/.claude/hooks/block-co-author.sh`.
- Secrets never in git. Real secrets live in 1Password; playbooks resolve via the `community.general.onepassword` lookup. Tracked templates only (`group_vars/*.example.yml`).
- One concern per commit. Scope is usually the role name.

---

## 5. References

- **[`ADRS.md`](./ADRS.md)** — decision log; read this to understand *why* a thing is the way it is. Append-only. Supersede old entries rather than delete.
- **[`CHANGELOG.md`](./CHANGELOG.md)** — timeline of what landed when, grouped by role scope. Generated from Conventional Commits by `git-cliff` (see [ADR-0012](./ADRS.md)). Third orientation leg: ADRS explains *why*, AGENTS defines *what should be true*, CHANGELOG records *when*. Regenerate with `make changelog`; verify with `make changelog-check`. Never hand-edit.
- **[`Makefile`](./Makefile)** — `make help` for the full target list. Primary targets: `lint`, `check`, `apply`, `smoke`, `changelog`, `changelog-check`, `release`.
- **[`inventory/hosts.yml`](./inventory/hosts.yml)** — host groups (`master`, `nucs`, `nas`, `pis`).
- **[`group_vars/master.example.yml`](./group_vars/master.example.yml)** — the tracked template. Copy to `master.yml` (gitignored) for real values.
- **Related repos** (not under this harness): `homelab-media-streaming` (standalone Plex NUC), `homelab-household-management` (dedicated NUC — currently empty, populated later), `homelab.family` (V1 legacy — forensic only), `obsidian-notes` (local notes vault).
- **Machine memory** (Claude Code, per-user): `~/.claude/projects/-Users-homelab/memory/` — session-persistent context notes.

---

*AGENTS.md is the contract. When code and this file disagree, open an ADR, fix the code, update this file — in that order.*
