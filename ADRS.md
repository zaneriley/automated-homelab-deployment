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
**Decision:** New secret lookups in playbooks resolve via `{{ lookup('community.general.onepassword', '<path>') }}` against the 1Password desktop app's CLI integration (Touch ID at task-run time). The existing `ansible/vault.yml` is frozen in place until migrated.
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
**Decision:** System Integrity Protection (SIP) is never disabled as part of any Ansible role. System-app bundles under `/System/Applications/` are not removed from playbooks; if removal is desired, it is a one-time manual procedure documented in `docs/manual-steps.md` (when that file is created).
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
**Decision:** Ansible is the configuration-management tool for the entire fleet (Mac master + Pis + NUCs + NAS), with inventory groups (`master`, `pis`, `nucs`, `nas`) and group-scoped roles.
**Alternatives:**
- **nix-darwin**: most declarative but Mac-only; would require a second tool for Linux hosts.
- **chezmoi**: dotfiles-scoped; insufficient for service config, brew bundles, launchd state.
- **pyinfra**: nicer DSL, smaller ecosystem.
- **Plain shell + `brew bundle`**: fine for a single Mac, no inventory abstraction for a heterogeneous fleet.

**Rationale:** The lab is heterogeneous. A single harness with inventory groups is simpler than running nix-darwin on the Mac plus Ansible on the Linux hosts. If the Mac ever becomes the only managed target, revisit.

## ADR-0001: One Ansible repo for the whole fleet; extend `automated-homelab-deployment`
**Date:** 2026-04-24
**Status:** Accepted
**Decision:** This repo (`automated-homelab-deployment`) is the single source of truth for lab configuration. The Mac Studio master node joins as a new inventory group (`master`), with Mac-specific roles scoped `hosts: master` only. No parallel `homelab-master` repo is created.
**Alternatives:**
- Create a new `homelab-master` repo for the Mac, keep `automated-homelab-deployment` NUC-only.
- Split further into per-concern repos (`llm-serving`, `fleet-config`, …) coordinated loosely.

**Rationale:** One tree, one inventory, one pattern for roles. An earlier plan for a separate `homelab-master` repo contradicted its own recommendation of "one harness with inventory groups." Splitting means duplicated `ansible.cfg`, duplicated roles, two verify flows. One repo is the architecturally correct shape.
