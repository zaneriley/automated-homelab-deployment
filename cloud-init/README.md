# cloud-init/

**Linux-fleet provisioning seed.** Renamed from `ubuntu-server/` per ADR-0013.

cloud-init `meta-data` and `user-data` files consumed by Ubuntu autoinstall during fresh-install of a NUC or Pi. Files are byte-identical to the pre-rename state apart from updated header comments noting the rename + a "verify at next provisioning" reminder.

## Files

- `meta-data` — cloud-init metadata (instance-id, etc.)
- `user-data` — cloud-init user-data (packages, users, network, etc.); first non-comment line is `#cloud-config`, preserved
- `user-data.new` — staging area for the next user-data revision

## OS scope

cloud-init is **Linux-only** (and BSD-only). Does not run on macOS or Windows. Macs are provisioned via `bootstrap.sh` + Ansible; Windows machines are out-of-band (ADR-0013).

## What to verify at next NUC provisioning

When this seed is next consumed (either by Ubuntu's autoinstaller or via any tooling that reads from this directory):

1. **`#cloud-config` magic header.** Confirmed at line 4 of `user-data` and line 1 of `user-data.new`. Cloud-init scans the first few lines for that exact directive — break it and Ubuntu silently falls back to no-config. The annotation header inserts AFTER `#cloud-config`, never before.
2. **References from `legacy/ansible/setup_nuc.yml`.** Today: zero hits (the playbook does not reference `ubuntu-server/` or `cloud-init/` paths internally). If a future legacy-refactor pass introduces a reference, it must point here (`cloud-init/`).
3. **Documentation slugs.** The `docs/site/pages/control-node-setup/…` MDX files reference cloud-init concepts but not the directory path. No update needed.

## If a second seed type arrives

If the fleet ever adds Talos config, k3os autoinstall, raspi-imager presets, or Packer-built images, the layout will be:

```
provisioning/
├── cloud-init/   # this dir's content
├── talos/
└── packer/
```

— per ADR-0013 (non-Ansible declarative state nests under a tool-named subdirectory under a domain parent).
