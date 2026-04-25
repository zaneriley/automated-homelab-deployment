# inventory/

WHO — host groups by **purpose**, not by OS. OS is computed at runtime from `ansible_os_family`.

## Files

- `hosts.yml` — host group definitions (`workstations`, `nucs`, `nas`, `pis`)
- `group_vars/` — per-group vars; `*.example.yml` is tracked, `*.yml` is gitignored (ADR-0007)
- `host_vars/` — per-host vars; same template/secret discipline; **thin overrides only**

## Variable precedence (Ansible's three layers)

1. `roles/<role>/defaults/main.yml` — role's own defaults; lowest priority
2. `inventory/group_vars/<group>.yml` — group-scoped overrides
3. `inventory/host_vars/<host>.yml` — host-scoped overrides; highest priority

| Where the value comes from | Where the value lives |
|---|---|
| Shared default for the role | `roles/<role>/defaults/main.yml` |
| Workstation-only override | `inventory/group_vars/workstations.yml` |
| One-host override (e.g. workstation softer harden list) | `inventory/host_vars/workstation.yml` |

## Adding a host

1. Add to the right group in `hosts.yml`.
2. Create `host_vars/<hostname>.yml` with overrides only — the role defaults + group vars carry the rest.
3. `make check` to confirm the inventory parses and the play converges in the new host's group.

See ADR-0013 for the design rationale and ADR-0008 for the role-shape lock.
