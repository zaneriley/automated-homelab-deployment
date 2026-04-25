# automated-homelab-deployment

A single Ansible harness that declaratively configures a small home lab: a Mac Studio acting as the master control node, plus a Linux fleet (NUCs, Pis, NAS) reached over SSH. The Mac runs the lab; the harness keeps the Mac (and eventually every fleet host) in a state that can be reproduced from a wipe in one command.

If you've ever lost a homelab to a botched upgrade, found yourself reading three-year-old Notes.app screenshots to remember how a service was wired, or rebuilt the same `defaults write` incantations on every fresh macOS — this is what I built so I'd never do that again.

## What lives here

| Layer | What it owns |
|---|---|
| Ansible roles | macOS configuration (defaults, dotfiles, de-Apple work, daily-driver tools); Linux fleet provisioning (legacy, being modernized) |
| Terraform | Cloudflare DNS + page rules. Tailscale next when the fleet needs remote reach. |
| cloud-init | Linux-fleet provisioning seed for fresh-install Ubuntu autoinstall. |
| docs/runbooks | The handful of things a SIP-on macOS can't script — iCloud sign-out, FileVault, TCC permission grants. |

Per-service deep config (the Plex compose stack, future household-NUC services) lives in sibling repos. This harness owns provisioning, OS config, deploy orchestration, and cross-cutting policy — the layer beneath service config.

## Philosophy (in priority order)

1. **De-Apple the Mac.** No iCloud sync, no Apple Intelligence, no Siri, consumer apps disabled or removed. Keep Messages (LLM agent tooling), Safari (system fallback), Xcode CLT.
2. **FLOSS-first toolchain** wherever viable.
3. **Declarative and reproducible.** Nothing clicked in the GUI that could be scripted. Every `defaults` key, every package, every service config lives here as YAML or text.
4. **One harness for the whole lab.** Same Ansible inventory and role structure for `workstations`, `nucs`, `pis`, `nas`. Apple-specific roles scoped `hosts: workstations` only — OS dispatch inside the role keeps the door open for non-Mac workstations later.
5. **Clean machine.** No global language runtimes. Use mise / nvm / uv / pipx, or Colima containers.

Full rationale + ratified stack in [`AGENTS.md`](./AGENTS.md). Decision log in [`ADRS.md`](./ADRS.md). Timeline in [`CHANGELOG.md`](./CHANGELOG.md) (deterministic, generated from Conventional Commits via `git-cliff`).

## Bootstrap on a fresh Mac

```sh
git clone git@github.com:zaneriley/automated-homelab-deployment.git
cd automated-homelab-deployment
./bootstrap.sh
```

`bootstrap.sh` is idempotent end-to-end:

1. Verify Xcode Command Line Tools (prompts for install if missing).
2. Install Homebrew if absent.
3. `brew bundle --no-upgrade` against the [`Brewfile`](./Brewfile).
4. `ansible-galaxy collection install -r requirements.yml`.
5. `ansible-playbook site.yml` — runs the five lifecycle-aligned roles in order: `bootstrap` → `system_defaults` → `shell_env` → `harden` → `workstation_tools`.

## Steady-state workflow

```sh
make help        # list targets
make lint        # ansible-lint + yamllint
make check       # --check --diff dry-run; review the diff
make apply       # apply
make check       # second run reports changed=0 — the idempotency witness (ADR-0009)
make changelog   # regenerate CHANGELOG.md (deterministic; git-cliff)
```

A second `make check` immediately after `make apply` that reports anything other than `changed=0` means a task is lying about its state. That's the load-bearing correctness invariant; if it breaks, the harness is broken, not the operator.

## Inventory shape

```
inventory/hosts.yml
  workstations:    # Mac Studio + future workstation hosts
    mac-studio:
  nucs:            # Linux NUC fleet (legacy roles in legacy/ansible/, being modernized)
  pis:             # Raspberry Pi fleet
  nas:             # NAS (Supermicro)
group_vars/
  all.yml          # cross-group, non-secret defaults (tracked)
  workstations.yml # gitignored; copy from workstations.example.yml
host_vars/<host>.yml  # gitignored; thin per-host overrides only
```

Secrets resolve via `community.general.onepassword` lookup (1Password CLI), never from git.

## Conventions

- **Conventional Commits** (`feat(scope):`, `fix(scope):`, `chore:`, `docs:`, `refactor:`). Scope is usually the role name. Small reviewable diffs.
- **No `Co-Authored-By:` trailers** on commits — enforced by a PreToolUse hook locally. One human accountable per commit.
- **No global language runtimes** on the master node. Use version managers or Colima.
- **Locked decisions stay locked.** New ADR for deviations; don't silently refactor a ratified shape.

## Status

Phase-1 (Mac Studio master-node onboarding) is shipped: 5-role lifecycle, Brewfile-driven daily-driver stack (Ghostty / Zed / AeroSpace / Zen / LuLu), de-Apple Layer 1, always-on power profile via user LaunchAgent, deterministic CHANGELOG. See [AGENTS.md §4 Backlog](./AGENTS.md) for what's queued (Tailscale, Ollama, NUC playbook modernization, backup architecture rewrite).

This is a personal lab. The shape and decisions are mine; you may find them useful as a reference rather than as something to fork verbatim.
