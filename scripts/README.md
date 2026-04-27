# scripts/

Operator helpers. Per `AGENTS.md §3` this directory has a "junk-drawer
cliff at ~3 distinct domains" — keep it tight, prefer role-internal
tooling for new helpers, and only land things here when they don't
have a natural home inside a role or `playbooks/`.

Today's contents are all rehearsal harnesses — destructive plays
running against throwaway VMs before they touch real hosts.

## Rehearsal scripts

| Script | Substrate | Target group | Purpose |
|---|---|---|---|
| `bake-rehearse-base.sh` | Tart (macOS) | `workstations` | Bake the `tahoe-clt-base` VM (Xcode CLT + NOPASSWD sudo). One-time, ~10 min. |
| `rehearse-tart.sh` | Tart (macOS) | `workstations` | Rehearse `harden`'s destructive layers (`layer2`, `layer3`). |
| `rehearse-workstation.sh` | Tart (macOS) | `workstations` | Rehearse `workstation_tools`'s `agent_surface` tag. |
| `bake-rehearse-nuc-base.sh` | Lima (Linux) | `nucs` | Bake the `nuc-rehearse-base` Ubuntu 22.04 VM. One-time, ~60-90 sec. |
| `rehearse-nuc.sh` | Lima (Linux) | `nucs` | Rehearse an arbitrary play (or stdin-fed ad-hoc play) against a fresh clone of `nuc-rehearse-base`. Proves idempotency on `--apply`. |

The Mac/Linux split is the substrate split ratified in `AGENTS.md §2`:
Tart is for macOS rehearsal, Lima is for Linux rehearsal (Lima is
already the substrate of Colima, which is the harness's container
runtime). Don't reach for Multipass / UTM here — adding a third VM
tool burns operator attention without earning anything.

## Make targets

```text
make rehearse-base               # Tart bake (one-time, macOS rehearsal)
make rehearse                    # Tart rehearsal of a harden layer
make rehearse-workstation        # Tart rehearsal of agent_surface

make rehearse-nuc-bake           # Lima bake (one-time, Linux rehearsal)
make check-rehearse PLAY=...     # Lima --check pass (no apply)
make apply-rehearse PLAY=...     # Lima apply + idempotency proof
make rehearse-clean              # Destroy all transient nuc-rehearse-* VMs
```

`PLAY` accepts a file path or `/dev/stdin`. The latter is useful for
ad-hoc role rehearsals without committing a throwaway playbook:

```bash
make apply-rehearse PLAY=/dev/stdin <<'EOF'
- hosts: all
  become: true
  roles: [diagnostics]
EOF
```

## What rehearsal CAN catch

- **Idempotency lies.** A task that reports `changed` on a re-run is
  the load-bearing signal — without VM rehearsal, you can't catch
  this on a fresh host because the real fleet is rarely fresh. The
  second `--check` after `--apply` is the witness.
- **Broken assumptions about base state.** A role that assumes a
  package, file, or service exists pre-apply will fail loudly on a
  bare Ubuntu image; on the real fleet it might "work" because the
  state was set by a previous, undocumented manual step.
- **Module choice errors.** `command:` shelling out to `apt-get` /
  `systemctl` instead of the native modules — the dishonesty surfaces
  as a non-zero second-`--check`, since shell modules can't read state.
- **Cloud-init or boot-time race conditions** that happen on a fresh
  VM but get masked on a long-uptime real host.
- **Apt cache / package availability** drift between the role and the
  upstream Ubuntu archive.

## What rehearsal CAN'T catch

The rehearsal VM is *not* a fleet host. These categories of failure
are out-of-scope for this harness and need different verification
(real-host smoke, vault drills, hardware-specific tests):

- **Host-specific NFS mounts** — the rehearsal VM has no `/srv/nfs/*`
  layout, no NAS reachability, no real exports. A play that mounts
  NFS will pass on the VM iff the `apt install nfs-common` works; the
  actual mount target won't exist.
- **Real Tailscale auth** — no auth key, no tailnet reachability, no
  `tailscale up` will succeed against the production tailnet from
  inside the VM. Plays that depend on tailnet membership for
  follow-up tasks will fail or get stubbed.
- **1Password lookups** — the rehearsal VM has no `op` CLI, no
  account, no service-account token. Any `community.general.onepassword`
  lookup must be mocked via `group_vars/nucs_rehearsal.yml`
  overrides, or the task must skip on the rehearsal group.
- **Real container state** — Docker / Podman containers running on a
  real NUC with persistent volumes, network namespaces, and bind
  mounts to host paths. The VM doesn't have those volumes.
- **Hardware events** — sysstat / rasdaemon / EDAC / temperature
  sensors are kernel-feature-dependent. Lima's KVM/VZ guest doesn't
  expose physical MCEs, so `rasdaemon` will start happily but never
  capture an event the way it would on the i5-1340P.
- **Network neighbor reachability** — the rehearsal VM is in Lima's
  user-mode network by default and can't see other lab hosts. Roles
  that probe `192.168.x.x` neighbours will time out.
- **Cross-host orchestration** — anything in `site.yml` that depends
  on the master node's local state (Brewfile, dotfile symlinks)
  doesn't apply here.

If a play depends on something in this list, rehearse the parts that
*are* in scope (apt installs, lineinfile edits, systemd service
states) and verify the rest on the real host with extra care. The
rehearsal pattern earns its keep on the apt + systemd + file layer;
above that it's diminishing returns.

## Cleaning up

`make rehearse-clean` destroys all transient `nuc-rehearse-*` VMs but
leaves the base intact. To nuke the base too (full reset, forces a
re-bake on the next rehearsal):

```bash
limactl stop nuc-rehearse-base
limactl delete --force nuc-rehearse-base
```

For Tart: `tart list` + `tart delete <name>`.
