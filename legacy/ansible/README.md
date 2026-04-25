# legacy/ansible/

**FROZEN — V1 (pre-Mac-Studio) NUC provisioning. Do not edit.** Moved here from `ansible/` per ADR-0013.

This directory holds the legacy NUC playbooks from before the master-node refactor. The files were relocated as a single `git mv` operation; their contents are byte-identical to the pre-move state apart from updated header comments. Path resolution **on paper** is correct (templates moved with the playbooks; `vars_files: vault.yml` still resolves; `templates/` references still resolve). Path resolution **at runtime** has NOT been verified — Z's NUCs and Pis are working as-is and the legacy playbooks are not being rerun against them right now.

## Files

- `setup_nuc.yml` — the original NUC bootstrap playbook
- `backup.yml` — backup tasks
- `scheduler.yml` — cron / systemd-timer scheduling
- `vault.yml` — Ansible Vault-encrypted secrets (deprecated by ADR-0007 1Password lookup)
- `templates/cloudflared_config.yml.j2` — Cloudflare tunnel config template

## What to verify when this is next run

Whenever the legacy playbooks are next executed against a real NUC (or a Tart Linux VM seeded from `cloud-init/user-data`):

1. **Template paths.** `template: src: …` lookups should resolve to `legacy/ansible/templates/<name>` — Ansible looks adjacent to the playbook by default; the templates moved with us, so this should hold.
2. **`vars_files:` paths.** Any reference to `vault.yml` should resolve to `legacy/ansible/vault.yml` — same default-adjacent rule.
3. **Cross-dir references.** Any reference to `ubuntu-server/…` is now stale — that directory was renamed to `cloud-init/` in the same commit cycle. Expect zero hits today (none in the playbook bodies as of the move) but recheck.
4. **Output paths.** `setup_nuc.yml` writes `./cloudflare/{{ tunnel_name }}-tunnel-uuid.txt` — that's relative to the *invocation cwd*, not to the playbook file. Behavior unchanged by the move; runtime check is "is the cwd what you expect?"
5. **The `cloudflare/*.txt` `.gitignore` rule** still covers both old (`./cloudflare/<name>.txt` at repo root) and new (anywhere a `cloudflare/` subdir is) paths — that glob is path-anchorless.

## Parity-verification protocol (deferred until actually needed)

ADR-0013 § "Convergence path" documents the full parity protocol. It runs only when the new role-shaped harness needs to *replace* one of these legacy playbooks. Until that day, this directory remains the steady-state authority for what's running on the NUCs — frozen, annotated, and out of the way.

If/when the protocol does run:

1. Inventory each task → mark `kept` / `refactored` / `deferred` / `dropped` in `legacy/INVENTORY.md`.
2. Cut a `legacy-baseline-vN` git tag.
3. Capture a `--check --diff` baseline against a representative NUC.
4. Refactor by slice; re-run; diff resulting state against the baseline.
5. Migrate `vault.yml` secrets to `community.general.onepassword` lookups (ADR-0007).
6. Delete the relevant files from `legacy/ansible/` only when zero rows in the inventory remain `kept`.

## Why frozen

Z's NUCs are working as intended. The cost of a parity protocol that breaks something is higher than the cost of leaving the legacy playbooks where they are with clear "this is legacy" signage. ADR-0013.
