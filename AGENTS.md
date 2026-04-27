# AGENTS.md — home-lab contract

Pick your altitude. Scroll-stop at the section that answers your question.

---

## Objectives

**Purpose.** Build and maintain home-cooked relationship technology — Plex / Plexamp, book library, photos, messaging, home automation, DNS, and adjacent services — for Z and a private trusted audience, outside capitalist platforms. Z and LLM agents are the operators; this harness is what makes that operator role tractable enough that running the lab does not become a full-time job. Audience specifics — counts, identities, relationships — live in `~/.agents/memory/long-term/project_homelab_household.md`, not here. This file is git-tracked.

**Done looks like.**

- Any node can be stood back up to its most recent state within a day.
- Backups guarantee no catastrophic loss. *(Threshold: `unknown — to clarify`. What counts as catastrophic — full photo library? specific datasets? per-service RPO/RTO targets?)*
- PII and other private state is reliably held outside any public git repo, by design — no per-commit vigilance required.
- Z is operating the lab ~zero-touch in steady state and can manage it from anywhere when away.

**Out of scope** — layer-shaped, not capability-shaped. Eventually *all* lab hardware becomes managed by this harness; the line is *which layer*.

- Per-service deep config (e.g. the Plex compose stack with Gluetun/NFS wiring) lives in the per-node repo — `homelab-media-streaming`, future `homelab-household-management`, etc. The harness owns provisioning, OS config, deploy orchestration, secrets injection, and cross-cutting policy.
- Service users are not operators. The harness owes them a working stack and readable docs, not a UX.
- No per-user provisioning automation — the harness is not a multi-tenant system.

**Who else.** Audience categories — counts, identities, relationships live in `~/.agents/memory/long-term/project_homelab_household.md`.

- **Primary trusted user** — daily user; technical reader; not an operator. Quality bar: best-in-class. Docs and behavior are technical-grade, not dumbed-down. Things should just work.
- **Other trusted users** — service users only. Most depend on Plex + its backends; some on Plexamp, the book library, adjacent services.
- **Future-Z** — engages in scheduled bursts. Tinkers little when nothing is broken.
- **LLM agents** — co-operators alongside Z. Take on the infra / ops / documenting / incident-management work that Z is explicitly trying to minimize.
- **Z himself** — the minimization target is *Z's time on infra, ops, documenting, and outage handling*. The experience for trusted users is **not** a minimization target; it gets full investment.

---

## 1. Philosophy

This repo configures a home lab declaratively via Ansible. The harness covers a Mac master control node plus a Linux fleet managed over SSH. Inventory uses generic group names by purpose (`workstations`, `nucs`, `pis`, `nas`) — the Mac Studio is the sole `workstations` member today. Specific hardware models, host counts, and topology live in `~/.agents/memory/long-term/project_homelab_household.md`, not here.

Priorities, in order:

1. **De-Apple the Mac.** No iCloud sync, no Apple Intelligence, no Siri, delete consumer apps (Music/TV/News/Maps/Stocks/Photos/GarageBand/iMovie/iWork). Keep Messages (for LLM agent tooling), Safari (system fallback), Xcode + Command Line Tools.
2. **FLOSS-first toolchain** wherever viable.
3. **Declarative and reproducible.** Nothing clicked in the GUI that could be scripted. Every `defaults` key, every package, every service config lives here as YAML or text.
4. **One harness for the whole lab.** Same Ansible inventory and role structure for `workstations`, `nucs`, `pis`, `nas`. Apple-specific roles scoped `hosts: workstations` only — OS dispatch inside the role keeps the door open for non-Mac workstations later.
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

## 3. Repo information architecture

Every tracked top-level entry, with a one-line purpose. Local conventions live next to the code (file headers, task comments, vars-file blurbs) — this file is the only layout contract.

**Directories**

| Path | Purpose |
|---|---|
| `inventory/` | WHO — host groups by purpose (`workstations`, `nucs`, `pis`, `nas`); OS resolved at runtime via `ansible_os_family` |
| `group_vars/`, `host_vars/` | Group- and host-scoped overrides at repo root (Ansible's default lookup); `*.example.yml` tracked, `*.yml` gitignored |
| `roles/` | WHAT — function-named, OS-dispatched inside via `import_tasks: "{{ ansible_os_family }}.yml"` (target shape — single-OS today, see §3 note below) |
| `playbooks/` | One-shot host-targeted plays for cross-cutting fixes that don't yet warrant a role. Flat by design pending the `nuc_lifecycle` role refactor (ADR-0008); plays migrate into roles when their scope generalizes. Filename = the host or capability the play targets, never the operator's mental state (no `*-fixups.yml`). |
| `dotfiles/` | Ansible role payload (NOT chezmoi/stow); symlinked into `~/.config/<tool>/` by `shell_env` |
| `scripts/` | Operator helpers (Tart rehearsal today); prefer role-internal for new ones; junk-drawer cliff at ~3 distinct domains |
| `terraform/<vendor>/` | Per-vendor declarative state — `cloudflare/` today, `tailscale/` next |
| `cloud-init/` | Linux-fleet provisioning seed; cloud-init `user-data` + `meta-data` |
| `docs/runbooks/` | Human procedures (canonical) — `manual-steps.md`, future how-tos |
| `legacy/ansible/` | Frozen pre-Mac-Studio NUC playbooks; parity not yet runtime-verified |
| `legacy/docs-site/` | Frozen Nextra docs site (pre-Mac-Studio fleet topology); retired per ADR-0014 |

**Files**

| Path | Purpose |
|---|---|
| `AGENTS.md` | This file — the contract. Philosophy, ratified stack, IA, backlog, gates, references. |
| `ADRS.md` | Decision log — append-only; supersede via new entries (ADR-0011). |
| `CHANGELOG.md` | Timeline — deterministic, generated by `git-cliff` from Conventional Commits (ADR-0012). Never hand-edit. |
| `README.md` | Public-facing intro. The orientation a stranger lands on. |
| `site.yml` | Top-level Ansible playbook — routes roles to host groups, defines play-level handlers. |
| `Brewfile` | Canonical brew bundle for the master node. |
| `Makefile` | Operator targets — `make help` for the list. |
| `bootstrap.sh` | One-shot first-run on a fresh macOS install. Idempotent end-to-end. |
| `ansible.cfg` | Ansible runtime config (inventory path, interpreter pin, etc.). |
| `cliff.toml` | `git-cliff` parser config — drives `CHANGELOG.md` generation (ADR-0012). |
| `requirements.yml` | Galaxy collections required (`community.general`, `ansible.posix`). |
| `.ansible-lint`, `.yamllint` | Lint configs — what `make lint` enforces. |
| `.gitignore` | Repo gitignore. Notably: `group_vars/*.yml` is gitignored, `*.example.yml` and `all.yml` excepted. |

**Locked structural decisions:** ADR-0013 (this layout), ADR-0008 (5 lifecycle-aligned roles), ADR-0001 (single Ansible repo for the whole fleet), ADR-0012 (orientation triad at root).

**Why this shape:** function-named roles + facts-based OS dispatch is the dominant pattern in heterogeneous-fleet IaC repos. See **ADR-0013** for the convergence trace (5 IA proposals → multi-OS `/literature` brief → 5 peer reviews).

**OS dispatch — target vs current.** ADR-0013 ratified the `tasks/main.yml` → `tasks/{{ ansible_os_family }}.yml` indirection as the eventual shape. Today every role's `tasks/main.yml` contains the macOS work directly — `workstations` has one Mac host, the indirection earns nothing yet. Split when a second OS family lands in `workstations`, or when a role's macOS body grows large enough that the indirection pays for itself.

**Runtime verification** (deferred, intentional):
The legacy NUC playbooks at `legacy/ansible/` are path-correct on paper but not runtime-verified — Z's NUCs and Pis are working as-is and we're not re-running the legacy plays right now. The "what to verify when next run" notes live in file headers inside `legacy/ansible/`.

---

## 4. Backlog

Order matters. Do them in order. Cross off as done.

**Now** — empty. Phase-1 scaffold and the five master-node roles all shipped. Move to **Next** for the active queue.

- [x] Scaffold master-node harness: inventory, group_vars, site.yml, 5-role skeleton
- [x] `system_defaults` role + `bootstrap` role
- [x] `harden` role layer 1 — de-Apple disable-only, variable-gated
- [x] `workstation_tools` role — default browser, AeroSpace, dark theme
- [x] `shell_env` role — Ghostty/Zed configs + dotfile symlinks

(Commit hashes deliberately omitted — they rot on rebase. `CHANGELOG.md` is the authoritative timeline; cross-reference there if you need the specific commits.)

**Next**
- [x] Obsidian vault → Linear-esque local backlog (frontmatter schema, Dataview dashboards). Convention: `~/repos/obsidian-notes/Backlog/README.md`. Active DAG: `Backlog/active-dag.md`.
- [ ] Migrate `legacy/ansible/setup_nuc.yml` secrets from Ansible Vault → `onepassword` lookup. Vault detail: [`harness-vault-to-1password`](../../obsidian-notes/Backlog/automated-homelab-deployment/harness-vault-to-1password.md).

**Later**
- [ ] **Rethink backup architecture.** Replace the legacy per-host cron (`legacy/ansible/scheduler.yml`) with master-driven orchestration: cron lives on the master node and SSHes out to fleet hosts. Gated by NAS subsystem work-in-progress. Out of scope this round: cloud backups — separate decision. Operational specifics (current state of each subsystem, which hosts hold which datasets) live in memory, not here.
- [ ] Populate `homelab-household-management` repo for a dedicated NUC (Immich, Home Assistant)
- [ ] Refactor `legacy/ansible/setup_nuc.yml` into NUC-scoped roles in this repo
- [ ] V1 legacy `homelab.family` forensic cleanup (missing Home Assistant container, orphaned AppDaemon, MQTT / DNS clarifications)
- [ ] DoH Pi for internal DNS (candidates: Technitium, Pi-hole+Unbound, AdGuard Home)
- [ ] System-app suppression (Chess, Photos, Calendar, etc. — bundles in `/System/Applications/` are SIP-protected per ADR-0005; suppression rather than removal). Pending `/literature` to settle the mechanism: `lsregister -u`, Spotlight Privacy plist, `mdutil` exclusions, or a combination.
- [ ] LuLu preferences ratification — preferences plist (`com.objective-see.lulu`) is scriptable, but the right defaults (block-by-default? passive mode? alert-vs-allow for Apple binaries?) need a `/literature` pass before being baked in.
- [ ] Tailscale — add when there's a fleet host that needs remote reach; decision-ready (Tailscale over Headscale) but not installed
- [ ] On-device LLM serving (Ollama) — add when a concrete workflow needs it
- [ ] PXE / netboot.xyz fleet provisioning — automate adding a new NUC / Pi / NAS device end-to-end (likely overlaps with the `legacy/ansible/setup_nuc.yml` refactor above; sequence/merge during scoping). Promoted from `obsidian-notes` Phase 2 triage 2026-04-25.
- [ ] NUT server proper shutdown command to NUC, Pi, and NAS — current `nut` setup doesn't issue the shutdown reliably. Promoted from `obsidian-notes` Phase 2 triage 2026-04-25.

**Deferred (decided, not scheduled)**
- `apple_cruft` layer 2 (delete consumer-app bundles) — default off; only enable after Tart VM rehearsal
- `apple_cruft` layer 3 (`/etc/hosts` telemetry block) — default off; same
- Terraform state backend migration (currently local)

**Explicitly out of scope**
- `Connected-Home*` repos (side project, ignored)
- `personal` legacy dotfiles repo (toss)
- `shiny-system` repo (not confirmed in scope)

---

## 5. How we work — acceptance gates

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
2. Destructive ops gated per-layer (three-layer pattern inside `harden`)
3. Toggle, blast radius, and undo path are documented **in the code** — `defaults/main.yml` headers, task-file comments, vars-file blurbs. Not a separate README. AGENTS.md is the only contract; per-folder READMEs proliferate and rot.

### C. Whole-harness gate

The harness is "working" when:

1. `./bootstrap.sh` on a fresh macOS install produces the configured state in one command
2. Immediately after, `make check` reports zero changes
3. Human-visible state in System Settings matches `group_vars/workstations.yml`
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

## 6. References

- **[`ADRS.md`](./ADRS.md)** — decision log; read this to understand *why* a thing is the way it is. Append-only. Supersede old entries rather than delete.
- **[`CHANGELOG.md`](./CHANGELOG.md)** — timeline of what landed when, grouped by role scope. Generated from Conventional Commits by `git-cliff` (see [ADR-0012](./ADRS.md)). Third orientation leg: ADRS explains *why*, AGENTS defines *what should be true*, CHANGELOG records *when*. Regenerate with `make changelog`; verify with `make changelog-check`. Never hand-edit.
- **[`Makefile`](./Makefile)** — `make help` for the full target list. Primary targets: `lint`, `check`, `apply`, `smoke`, `changelog`, `changelog-check`, `release`.
- **[`inventory/hosts.yml`](./inventory/hosts.yml)** — host groups (`workstations`, `nucs`, `nas`, `pis`).
- **[`group_vars/workstations.example.yml`](./group_vars/workstations.example.yml)** — the tracked template. Copy to `workstations.yml` (gitignored) for real values.
- **Related repos** (not under this harness): `homelab-media-streaming` (standalone Plex NUC), `homelab-household-management` (dedicated NUC — currently empty, populated later), `homelab.family` (V1 legacy — forensic only), `obsidian-notes` (local notes vault).
- **Machine memory** (Claude Code, per-user): `~/.agents/memory/` (symlinked from `~/.claude/projects/-Users-homelab/memory/`) — private per-machine context. Routing contract: `~/.agents/memory/AGENTS.md`.

---

*AGENTS.md is the contract. When code and this file disagree, open an ADR, fix the code, update this file — in that order.*
