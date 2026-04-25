# ansible/   *(planned move: `legacy/ansible/`)*

**FROZEN — V1 (pre-Mac-Studio) NUC provisioning. Do not edit.**

This directory holds the legacy NUC playbooks from before the master-node refactor. It is parity-pending: when the new role-shaped harness (per ADR-0008) covers all the behavior here, this directory moves to `legacy/ansible/` (per ADR-0013). Until that move, do not modify these files — they are the parity oracle.

## Files

- `setup_nuc.yml` — the original NUC bootstrap playbook
- `backup.yml` — backup tasks
- `scheduler.yml` — cron / systemd-timer scheduling
- `vault.yml` — Ansible Vault-encrypted secrets (deprecated by ADR-0007 1Password lookup)
- `templates/cloudflared_config.yml.j2` — Cloudflare tunnel config template

## Parity-verification protocol (gates the move)

Per ADR-0013 § "Convergence path":

1. **Inventory the legacy surface.** `grep -hE '^- name:|^    - name:' ansible/*.yml | sort -u` → write to `legacy/INVENTORY.md`. Each task gets a row: `task name | playbook | proposed new home | status (kept/refactored/deferred/dropped)`.
2. **Tag a baseline.** Cut a `legacy-baseline-vN` git tag before any move.
3. **Behavioral baseline.** Run `ansible-playbook ansible/setup_nuc.yml --check --diff` against a representative NUC (or a Tart Linux VM seeded from `ubuntu-server/user-data`). Capture the change-list as the contract.
4. **Refactor by slice.** For each capability (NFS mounts, BorgBackup, Cloudflared tunnels), build the target role / per-OS taskfile, run it on the same VM, diff resulting state against the legacy baseline. Only when diff is empty does the legacy task get marked `refactored`.
5. **Vault migration.** ADR-0007 says secrets move to `community.general.onepassword` lookups. `vault.yml` cannot be deleted until every reference is rewritten.
6. **Move physically only when zero rows in `INVENTORY.md` are `kept`.** Until then, this directory stays at `ansible/`.

The protocol is the same one all 5 IA peer reviewers proposed (independent convergence). See ADR-0013.
