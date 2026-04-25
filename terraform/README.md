# terraform/

Per-vendor declarative state for non-Ansible infrastructure.

## Layout (target)

```
terraform/
├── cloudflare/    # DNS + page rules + Cloudflare tunnels
├── tailscale/     # ACLs + ratified-but-deferred (AGENTS.md backlog)
└── <future>/      # one subdir per vendor, with its own .tf files + state
```

Each vendor subdirectory is a self-contained Terraform module: `cd terraform/<vendor> && terraform init && terraform plan`. Independent state per vendor — no cross-vendor coupling.

## Why per-vendor subdirs (not flat `.tf` files at top, not a `cloudflare/` rename)

The 2026-04-25 IA peer review rejected the `cloudflare/` top-level rename 4-of-5 in favor of `terraform/<vendor>/` because vendor-named root dirs collapse the moment a second vendor arrives. Tool name = stable invariant; vendor = implementation detail that multiplies. See ADR-0013.

## Current state

`cloudflare/` holds the existing Cloudflare DNS + page rules. The flat `.tf` files at this directory's root will be moved into `cloudflare/` once the rename lands (sequencing TBD; tracked in AGENTS.md § 3).

## Secrets

Per ADR-0007, secrets live in 1Password. Terraform vars consume them via `op run --env-file=.env.op -- terraform plan` (or the equivalent inline lookup). Real `.tfvars` files are gitignored; tracked templates are `*.tfvars.example`.
