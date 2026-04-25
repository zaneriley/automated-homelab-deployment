# scripts/

Operator helpers. Today: Tart-VM rehearsal scripts.

## Files

- `bake-rehearse-base.sh` — one-time setup of the CLT-baked Tart base image (`make rehearse-base`)
- `rehearse-tart.sh` — clone-boot-apply-verify-teardown of a destructive layer in a throwaway VM (`make rehearse`)

## When to add a new script here vs. inside a role

A script earns a place in `scripts/` when it is:

- Invoked by an operator from the command line (or `make`), not by a playbook
- Cross-cutting (touches multiple roles or none)
- Stateful in a way Ansible cannot honestly idempotency-track

If the helper is logically part of one role's apply path — e.g., a font-rendering or template-generation step — it belongs in that role's `files/` or `tasks/`.

## Junk-drawer cliff

The 2026-04-25 IA peer review flagged this directory as junk-drawer-prone at **~3 distinct domains**. Today: 1 domain (Tart rehearsal). When the second domain wants in (e.g., a 1Password rotation helper, a dotfile renderer), the right reflex is to ask whether it could live inside a role first.

See ADR-0013 for the placement criterion.
