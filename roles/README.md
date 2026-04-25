# roles/

WHAT — five function-named, lifecycle-aligned Ansible roles (ADR-0008). OS dispatch lives **inside** each role.

## Lifecycle order

1. **`bootstrap`** — preflight + foundation dirs + Brewfile reconciliation
2. **`system_defaults`** — data-driven `osx_defaults` (and `defaults`-equivalents on other OSes when added)
3. **`shell_env`** — terminal + editor configs (Ghostty, Zed); symlinks from `dotfiles/`
4. **`harden`** — three-layer de-Apple (disable / delete / block-telemetry); per-layer variable gates (ADR-0003)
5. **`workstation_tools`** — Colima, AeroSpace, 1Password adoption, dev tools

`site.yml` runs them in this order against the `workstations` inventory group.

## OS dispatch pattern (ADR-0013)

Each role's `tasks/main.yml` is a one-liner:

```yaml
- import_tasks: "{{ ansible_os_family }}.yml"
```

Per-OS work lives in `tasks/Darwin.yml`, `tasks/Debian.yml`, `tasks/Windows.yml`, etc. A role doesn't need every OS file — just the ones it supports. Unsupported OSes either (a) get a `tasks/<OsFamily>.yml` that fails fast with a clear "this role does not support `<OsFamily>`" message, or (b) are excluded via `when:` at the play level.

## Adding behavior

| What you're adding | Where it goes |
|---|---|
| A new macOS default | `roles/system_defaults/vars/main.yml` (data list, ADR-0004) |
| A new Linux package on workstations | `roles/bootstrap/tasks/Debian.yml` (or per-distro family) |
| A new tagged-block under `harden` Layer 1 (Mac) | `roles/harden/tasks/Darwin.yml`, gated by `harden_apple_cruft_disable \| bool` |
| Cross-role payload (font config, theme) | `dotfiles/` at repo root + reference from the consuming role |
| Role-private payload | `roles/<role>/files/` |

## Per-role gate (Gate B, AGENTS.md § 5)

Every role on `main` carries its own `README.md` with: purpose, toggle variable, blast radius, undo path. Destructive ops are layered + variable-gated.

See ADR-0013 for the function-named-no-OS-prefix decision; ADR-0008 for the 5-role count lock.
