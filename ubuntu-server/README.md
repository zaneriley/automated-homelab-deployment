# ubuntu-server/   *(planned rename: `cloud-init/`)*

**Linux-fleet provisioning seed.** cloud-init `meta-data` and `user-data` files consumed by Ubuntu autoinstall during a fresh-install of a NUC or Pi.

## Files

- `meta-data` — cloud-init metadata (instance-id, etc.)
- `user-data` — cloud-init user-data (packages, users, network, etc.)
- `user-data.new` — staging area for the next user-data revision

## OS scope

cloud-init is **Linux-only** (and BSD-only). Does not run on macOS or Windows. Macs are provisioned via `bootstrap.sh` + Ansible; Windows machines are out-of-band (ADR-0013).

## Planned rename

This directory will be renamed to `cloud-init/` (artifact-accurate) per ADR-0013. The rename is **gated by the legacy parity-verification protocol** because the legacy `ansible/setup_nuc.yml` may reference paths under here. See ADR-0013 § "Convergence path" for the protocol and AGENTS.md § 3 for the pending-moves list.

## If a second seed type arrives

If the fleet ever adds Talos config, k3os autoinstall, raspi-imager presets, or Packer-built images, the layout will be:

```
provisioning/
├── cloud-init/   # this dir's content
├── talos/
└── packer/
```

— per ADR-0013 (non-Ansible declarative state nests under a tool-named subdirectory under a domain parent).
