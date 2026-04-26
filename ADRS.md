# ADRS.md — decision log

Append-only record of architectural and tooling decisions. **Most recent at the top.**

When a prior decision is reversed, do **not** delete it — add a new entry that marks the old one *Superseded by ADR-NNNN* and explains why.

Format:

```
## ADR-NNNN: <Title>
**Date:** YYYY-MM-DD
**Status:** Accepted | Superseded by ADR-MMMM | Deprecated
**Decision:** <one sentence>
**Alternatives:** <what was rejected>
**Rationale:** <why>
```

---

## ADR-0014: Retire the Nextra docs site to `legacy/docs-site/`
**Date:** 2026-04-26
**Status:** Accepted
**Decision:** Move `docs/site/` → `legacy/docs-site/`. The Nextra documentation site documents the pre-Mac-Studio fleet topology (NUC `setup_nuc.yml`, Cloudflare DNS, cloud-init), is `noindex, nofollow` by design, and has not had a successful Vercel deploy since 2024-12-15. It does not describe the current Mac-Studio-master-node harness. Same legacy-treatment pattern as `legacy/ansible/`. Closes the open question raised in ADR-0013 § "Open question".

**Alternatives:**
- **Delete entirely.** Rejected — preserves zero forensic reference for the V1 fleet topology, which Z's NUCs still run today.
- **Keep at `docs/site/` and fix the deploy.** Rejected — the site documents a topology this repo no longer drives; maintaining it would mean writing fresh content for the master-node harness, which doesn't earn its keep when AGENTS.md / ADRS.md / `docs/runbooks/` already serve the orientation triad.
- **Add a new ADR for it.** Z's pacing: small focused decisions land as their own ADR rather than amending ADR-0013. (This ADR.)

**Rationale:** The same capability-vs-surface logic from `feedback_capability_over_surface.md`: the durable capability is "operator orientation to the harness." The published Nextra surface was 1-3 year lifespan and didn't survive a topology change. AGENTS.md (contract) + ADRS.md (decisions) + `docs/runbooks/` (procedures) carry the durable capability today; the Nextra surface was redundant. Moving rather than deleting matches the `legacy/ansible/` precedent — kept on disk for forensic reference, not built or deployed. Off-repo follow-ups (operator action, not codified): disconnect the Vercel project on vercel.com so the failing-deploy red badges stop; clear the GitHub repo's `homepageUrl` field.

**Consequences:**
- Future Dependabot bumps for the Nextra site live under `legacy/docs-site/`. Add `.github/dependabot.yml` with `updates: []` so they stop firing entirely (this PR).
- AGENTS.md §3 row for `docs/site/` removed; `legacy/docs-site/` added.
- AGENTS.md §3 "Open question" about Nextra publishing is closed.
- `next.config.js` carries an in-file freeze annotation, matching the legacy/ansible/ in-file annotation pattern.
- Vercel-side and GitHub `homepageUrl` cleanup are operator actions, not codified.

## ADR-0013: Repo information architecture — function-named roles + facts-based OS dispatch + tool/vendor partition
**Date:** 2026-04-25
**Status:** Accepted
**Decision:** Adopt a flat top-level layout with three load-bearing rules:

1. **Roles are function-named, never OS-prefixed.** OS dispatch lives inside each role via `import_tasks: "{{ ansible_os_family }}.yml"`. The `tasks/<OsFamily>.yml` pattern (`Darwin`, `Debian`, `RedHat`, `Windows`) replaces parallel `_mac/` / `_fleet/` role trees.
2. **Inventory groups are by purpose, not OS.** `workstations`, `nucs`, `pis`, `nas` — heterogeneous by design. OS is computed from facts at runtime, never encoded in path.
3. **Tool/vendor declarative state lives in tool-named top-level dirs with vendor sub-dirs.** `terraform/cloudflare/` today, `terraform/tailscale/` when ratified-but-deferred lands. The vendor name is a sub-dir, not the dir.

The full top-level layout is documented in `AGENTS.md` § 3. Local conventions live in code (file headers, task comments, vars-file blurbs); per-directory READMEs were retired — AGENTS.md §3 is the only contract for layout.

**Alternatives considered (and rejected):**
- **DDD bounded-context neighborhoods** (`workstation/`, `fleet/`, `edge/`, `ops/`, `secrets/`) — over-engineered for current scale; agent 1 of the IA fan-out flagged this against itself in §7.
- **`_mac/` / `_fleet/` role-name prefixes** — double-codes information already in `inventory/` + `ansible_os_family`. The `/literature` confirmed nobody in the field uses this pattern; `meta/main.yml platforms` is deprecated/ignored.
- **`cloudflare/` as a top-level dir** (vendor-named) — collapses the moment a second vendor arrives. 4 of 5 peer reviewers independently rejected this in favor of `terraform/<vendor>/`.
- **`infra/` umbrella over `terraform/` + `cloud-init/`** — speculative grouping; only 2 occupants today; ADR-0011 / minimalist agent rejects scaffolding for future content.
- **Per-host top-level playbooks** — `/literature` p101+p102+p107 converge on thin-host-files + shared-roles; per-host playbooks rot at >5 hosts.
- **Renaming `ansible/` → `legacy/ansible/` immediately** — accepted in principle but gated by the parity-verification protocol; 5/5 IA reviewers proposed the same gate.

**Convergence path** (artifacts that produced this decision; ephemeral, retained as long as useful):
- 2026-04-25 IA proposal fan-out — 5 Opus agents (DDD purist / onboarding-first / LLM-orientation-first / scale-out / minimalist) at `.tmp/2026-04-25-ia-proposals/`
- 2026-04-25 multi-OS-workstation-fleet-ia `/literature` brief — 25 sources at `.tmp/2026-04-25-multi-os-workstation-fleet-ia/literature/`. Convergent finding: function-named roles + `ansible_os_family` dispatch is the dominant pattern; the multi-user-family-Macs case is unmodeled in public; Windows-via-Ansible workstations are a wasteland.
- 2026-04-25 IA peer-review fan-out — 5 Sonnet reviewers (MECE rigor / naming honesty / multi-vendor scaling / root-placement criterion / first-principles re-derivation) at `.tmp/2026-04-25-ia-peer-review/`. Convergent corrections: keep `terraform/` (don't rename to `cloudflare/`); `dotfiles/` semantics need clarification; `scripts/` has a junk-drawer cliff at ~3 distinct domains; `cloud-init/` Linux-only scope needs a README signal.

The compressed essence above is the durable artifact. The `.tmp/` files are forensic — kept locally as long as useful, deletable thereafter without losing the decision.

**Rationale.** The repo's primary audience is an LLM cold-loading to do new work (ADR-0012). The structure is judged on a single metric: how few files an agent reads before correctly placing a new change. Function-named roles + inventory-driven OS dispatch is the lowest-information-loss shape: an agent reads `AGENTS.md § 3` (the table), the relevant role's `defaults/main.yml` + `tasks/main.yml` (or per-OS taskfile when the split lands) — two-to-three reads, end-to-end, for "where does my new macOS default go" or "where does my new Debian package install go."

Workstation heterogeneity across the fleet (multiple OS families, multiple form factors) does not multiply the role tree — it multiplies the per-OS taskfiles inside existing roles. ADR-0008's 5-role lock holds.

**Consequences:**
- Adding a new OS to an existing role = one new `tasks/<OsFamily>.yml` file. Linear cost.
- Adding a Windows workstation today is supported in *shape* but unsupported in *practice* — the `/literature` found zero exemplars. Realistic path: out-of-band (Chocolatey / winget) with an inventory stub + runbook in `docs/runbooks/`.
- Per-host `host_vars/` files are thin (overrides only). Heavy logic lives in roles and group_vars.
- `terraform/<vendor>/` absorbs new vendors with one `mkdir`. No re-org churn.
- All five planned moves landed across this commit cycle: `terraform/*.tf` → `terraform/cloudflare/*.tf` (`a2d0dcd`); `docs/manual-steps.md` → `docs/runbooks/manual-steps.md` (`e458f29`); legacy in-file annotations (`520ca0e`); and the three relocations (`ansible/` → `legacy/ansible/`, `ubuntu-server/` → `cloud-init/`, Nextra files → `docs/site/`). The legacy moves landed *without* completing the parity-verification protocol — Z's NUCs/Pis are working as intended and re-running the legacy plays just to satisfy a paper protocol was higher cost than benefit. Legacy file headers enumerate what to verify *when* the plays are next run; the protocol lives there for that day.
- The per-directory READMEs that landed with this ADR (and the four per-role READMEs added with each role-skeleton commit) were retired in a follow-up — AGENTS.md §3 is the only layout contract, file headers carry the rest. The IA decision (the three structural rules above) stands; per-directory README scaffolding was a consequence, not the decision.

## ADR-0012: `CHANGELOG.md` is a deterministic artifact; no LLM-generated changelogs
**Date:** 2026-04-25
**Status:** Accepted
**Decision:** `CHANGELOG.md` at the repo root is generated by `git-cliff` from Conventional Commits — a pure function of (commit history, `cliff.toml`). It is the **timeline** leg of the orientation triad (AGENTS.md = contract, ADRS.md = decisions, CHANGELOG.md = timeline). Operationally:

- **Regenerated** via `make changelog` — never hand-edited.
- **Verified** via `make changelog-check` — fails on any drift from what `git-cliff` would emit.
- **Released** via `make release TAG=vX.Y.Z` — tags, regenerates with the tag, hands off to the operator for commit + push.
- **Grouped by commit scope** (role name) to mirror the lifecycle-aligned role structure from ADR-0008.
- **Never LLM-generated.** Non-determinism breaks the re-run-as-witness pattern (ADR-0009, ADR-0011): if the artifact varies across regenerations, "did the CHANGELOG change?" stops being a meaningful question. LLMs also import a network/API-cost/auth dependency into a harness whose ethos is offline text-to-text transforms.

**Alternatives:**
- **LLM-generated CHANGELOG** (rejected: non-deterministic; can't be verified against a re-run; external runtime dependency).
- **`antsibull-changelog` / `towncrier`** (rejected: fragment-per-PR ceremony designed for multi-maintainer Galaxy-published collections; solo-operator harness has no merge-conflict problem that fragments solve).
- **`release-please` / `semantic-release`** (rejected: release-PR workflow aimed at published artifacts with downstream consumers; adds noise without earning its keep here).
- **Per-role semantic versioning** (rejected: reopens the role-count sprawl ADR-0008 rejected).
- **No CHANGELOG** (rejected: leaves no compressed-timeline artifact for the primary audience).

**Rationale:** The primary audience is **LLM agents orienting cold to do new work** (e.g. "connect the NAS to a NUC"). Secondary audiences: future-self returning after a long gap, other solo devs who clone the harness, forkers syncing upstream. All four share the same failure mode: `git log --oneline` is the verbose source, and loading it into a finite context window on every orientation is expensive and noisy. A scope-grouped `CHANGELOG.md` compresses it — ~200 tokens per release vs. ~2000 tokens of commit soup — and makes BREAKING changes first-class via the `BREAKING CHANGE:` footer.

Determinism is load-bearing because verification depends on it. The "second `make check` run reports zero changes" pattern (ADR-0009) generalizes: if `make changelog` twice in a row produces two different files, the artifact is narrating itself into existence — exactly the ceremony pattern ADR-0011 rejects. `git-cliff` as a pure function satisfies this; LLM generation does not.

A 2026-04-25 `/literature` brief (`.tmp/2026-04-25-versioning-infra-playbooks/literature/brief.md`) surveyed 50 sources across arxiv, engineering blogs, exemplar Ansible forks, changelog tooling, and heterogeneous-fleet versioning practice; `git-cliff` + Conventional Commits scored highest on ROI for this repo's shape (solo operator, no Galaxy publishing, no downstream pin-consumers, role-name commit scopes already in force).

**Where LLMs *can* fit — separately:** at commit-authoring time (e.g. a local hook that reviews a staged diff and flags *"this touches `roles/harden/tasks/layer2.yml` — should this carry a `BREAKING CHANGE:` footer?"*). That's an LLM as coach, producing a suggestion the human writes into the commit message. The commit remains the canonical input; the changelog pipeline stays deterministic. Not in scope for this ADR; revisit if the pattern proves useful in practice.

## ADR-0011: Commit-message claim discipline — "idempotency proof" is earned, not structural
**Date:** 2026-04-25
**Status:** Accepted
**Decision:** Commit messages state what changed and what was verified. Claims like "Gate A verified," "idempotency proof," or "first real slice" are only used when the commit materially exercises the claim — real tasks managing real state, independently verified by an out-of-band read (`ls`, `defaults read`, `launchctl print`, `brew bundle check`, a visible observation). When a commit is infrastructure, scaffolding, or documentation, the message names it as such — `docs:`, `chore:`, `scaffolding,` `placeholder` — without borrowing the language of substantive work.
**Alternatives:** Keep the pattern of reporting `ok=N, changed=0` as "idempotency proof" on every commit regardless of whether real state was under management.
**Rationale:** A 2026-04-25 peer review flagged `cc379ff feat: scaffold master-node harness` for claiming "check → apply → check all report changed=0 (idempotency proof)" when every task in the play was a debug `no-op` — `changed=0` was structurally guaranteed, not earned. That is exactly the ceremony-labeled-as-progress pattern this repo is trying to avoid. The ceremony-vs-real-work framework lives in the global `~/.agents/AGENTS.md` § 3 (symlinked to `~/.claude/CLAUDE.md`); this ADR mirrors the machine-scoped rule into this repo so it's locally ratified. The `cc379ff` commit message is left in place as archeology — the lesson is captured here and in the global AGENTS.md, not by rewriting history.

## ADR-0010: Conventional Commits; no `Co-Authored-By` trailers
**Date:** 2026-04-24
**Status:** Accepted
**Decision:** Commits in this repo (and across this machine) follow Conventional Commits and carry a single author — the human. A PreToolUse hook at `~/.claude/hooks/block-co-author.sh` blocks any `git commit` whose command string contains `co-authored-by` (case-insensitive), regardless of the named co-author.
**Alternatives:** Allow default Claude Code / Cowork co-author trailers on AI-assisted commits.
**Rationale:** Attribution ambiguity muddies `git blame` and breaks the "one human accountable per commit" norm. Block at the tool layer so intent is enforced, not trusted.

## ADR-0009: `--check --diff` is the verify mechanism; drop `verify.yml`
**Date:** 2026-04-24
**Status:** Accepted
**Decision:** The correctness witness is running `ansible-playbook site.yml --check --diff` after an apply and confirming zero changes. A separate `verify.yml` is redundant because the declarative modules we use (`osx_defaults`, `file`, `community.general.homebrew`) have honest check-mode + diff support.
**Alternatives:** Maintain a separate `verify.yml` that reads every managed key back and asserts equality.
**Rationale:** Duplicates `--check --diff`. Adds drift risk between the apply path and the verify path. The second check-run provides the same evidence with less code. Runtime facts that `--check` can't cover (Tailscale up, Ollama listening) live in an optional, minimal `smoke.yml`.

## ADR-0008: 5 roles, lifecycle-aligned; not 13 capability-bucket roles
**Date:** 2026-04-24
**Status:** Accepted
**Decision:** The Mac-side of the harness has five roles: `bootstrap`, `system_defaults`, `shell_env`, `harden`, `workstation_tools`. Roles are organized by lifecycle phase, not by capability bucket.
**Alternatives:** 13 roles matching capability buckets (`preflight`, `foundation`, `homebrew`, `system_defaults`, `apple_cruft`, `terminal`, `editors`, `homelab_tooling`, `productivity`, `privacy`, `ssh_server`, `llm_host`, `dotfiles`).
**Rationale:** A 2026-04-24 literature review of canonical Ansible-for-Mac playbooks (e.g. `geerlingguy/mac-dev-playbook`) found typical shapes are 4–5 roles. 13 is roughly 3× the field's reference. Lifecycle alignment gives a natural `make apply` ordering (bootstrap → defaults → env → harden → tools) and simpler blast-radius reasoning.

## ADR-0007: `community.general.onepassword` lookup for new-work secrets
**Date:** 2026-04-24
**Status:** Accepted
**Decision:** New secret lookups in playbooks resolve via `{{ lookup('community.general.onepassword', '<path>') }}` against the 1Password desktop app's CLI integration (Touch ID at task-run time). The existing `legacy/ansible/vault.yml` is frozen in place until migrated.
**Alternatives:** Continue Ansible Vault; wrap `ansible-playbook` in `op run`; shell out to `op read` per task.
**Rationale:** Vault requires a password at runtime with no clean integration with the human's auth surface. `op run` wraps the whole playbook in a single env scope (pollution risk). The lookup plugin resolves per-task, composes with normal Ansible vars, and uses the desktop app's already-authenticated session (biometric). Migration of existing `vault.yml` is a separate, tracked task in the backlog.

## ADR-0006: No global language runtimes; version managers or containers
**Date:** 2026-04-24
**Status:** Accepted
**Decision:** No global language runtimes are installed on the master node (no `brew install node`, `brew install python`, `brew install ruby`, etc.). Language-level tooling runs via version managers (mise, nvm, uv, pipx) or in Colima containers.
**Alternatives:** Install language runtimes globally via Homebrew.
**Rationale:** A long-lived home lab survives wipes only if state lives in config. Global `brew install node@20` silently drifts; upgrades bump major versions unpredictably; multiple projects need different versions. Version managers scope runtimes to the work. Colima covers the container-native case. The master node stays clean.

## ADR-0005: SIP stays on; `/System/Applications/*` removal is manual-only
**Date:** 2026-04-24
**Status:** Accepted
**Decision:** System Integrity Protection (SIP) is never disabled as part of any Ansible role. System-app bundles under `/System/Applications/` are not removed from playbooks; if removal is desired, it is a one-time manual procedure documented in `docs/runbooks/manual-steps.md`.
**Alternatives:** Provide a layer-4 `apple_cruft` play that boots into Recovery, runs `csrutil disable`, deletes `/System/Applications/*.app`, re-enables SIP.
**Rationale:** SIP disable requires a Recovery-mode boot outside Ansible's reach. Removed system apps reappear or break on OS updates. The cost-benefit of nuking `/System/Applications/Chess.app` doesn't justify trading away kernel-level integrity protection.

## ADR-0004: `community.general.osx_defaults`, never `command: defaults write`
**Date:** 2026-04-24
**Status:** Accepted
**Decision:** All `defaults` plist writes on the master node go through `community.general.osx_defaults`, driven by YAML data in `roles/system_defaults/vars/main.yml`. `command: defaults write` is prohibited.
**Alternatives:** Loop over `defaults write` via `ansible.builtin.command` with `changed_when: true`. Write a custom action plugin.
**Rationale:** `osx_defaults` reads the current value before writing and only reports changed when it actually changed. That means `make apply` on a converged system reports zero changes (honest), and the second `make check` run is a real correctness witness. `command: defaults write` cannot honestly distinguish "no change" from "changed" without a manual pre-read — and that is exactly what `osx_defaults` does internally.

## ADR-0003: Three-layer de-Apple; per-layer variable gates; tagged blocks inside `harden`
**Date:** 2026-04-24
**Status:** Accepted
**Decision:** De-Apple work is split into three layers by blast radius, implemented as tagged blocks inside the single `harden` role (not three separate roles):

1. `harden_apple_cruft_disable` — disable launch agents, empty Dock, iCloud sync toggles. Default **ON**.
2. `harden_apple_cruft_delete_bundles` — `rm -rf` user-removable `/Applications/*.app` bundles (iWork, GarageBand, iMovie). Default **OFF**.
3. `harden_apple_cruft_block_telemetry` — `/etc/hosts` null-route of Apple analytics domains. Default **OFF**.

**Alternatives:** Single "nuclear" toggle; always-nuclear; three separate roles (`harden_apple_cruft_disable`, `harden_apple_cruft_delete_bundles`, `harden_apple_cruft_block_telemetry`).
**Rationale:** Each layer has a distinct blast radius and recovery cost. Tagged blocks inside `harden` let us run specific layers via `--tags` without splitting into separate roles (consistent with the lifecycle-aligned role count from ADR-0008). Defaults recommend layer 1 universally, layer 2 only after Tart VM rehearsal, layer 3 only for users willing to troubleshoot `softwareupdate` failures.

## ADR-0002: Ansible, not nix-darwin / chezmoi / pyinfra / shell
**Date:** 2026-04-24
**Status:** Accepted
**Decision:** Ansible is the configuration-management tool for the entire fleet (Mac master + Pis + NUCs + NAS), with inventory groups (`workstations`, `pis`, `nucs`, `nas`) and group-scoped roles.
**Alternatives:**
- **nix-darwin**: most declarative but Mac-only; would require a second tool for Linux hosts.
- **chezmoi**: dotfiles-scoped; insufficient for service config, brew bundles, launchd state.
- **pyinfra**: nicer DSL, smaller ecosystem.
- **Plain shell + `brew bundle`**: fine for a single Mac, no inventory abstraction for a heterogeneous fleet.

**Rationale:** The lab is heterogeneous. A single harness with inventory groups is simpler than running nix-darwin on the Mac plus Ansible on the Linux hosts. If the Mac ever becomes the only managed target, revisit.

## ADR-0001: One Ansible repo for the whole fleet; extend `automated-homelab-deployment`
**Date:** 2026-04-24
**Status:** Accepted
**Decision:** This repo (`automated-homelab-deployment`) is the single source of truth for lab configuration. The Mac Studio master node joins as a new inventory group (`workstations`), with Mac-specific roles scoped `hosts: workstations` only. No parallel `homelab-master` repo is created.
**Alternatives:**
- Create a new `homelab-master` repo for the Mac, keep `automated-homelab-deployment` NUC-only.
- Split further into per-concern repos (`llm-serving`, `fleet-config`, …) coordinated loosely.

**Rationale:** One tree, one inventory, one pattern for roles. An earlier plan for a separate `homelab-master` repo contradicted its own recommendation of "one harness with inventory groups." Splitting means duplicated `ansible.cfg`, duplicated roles, two verify flows. One repo is the architecturally correct shape.
