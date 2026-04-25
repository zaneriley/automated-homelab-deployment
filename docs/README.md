# docs/

Operator-facing prose. Not contract (that's `AGENTS.md`), not decisions (that's `ADRS.md`), not timeline (that's `CHANGELOG.md`).

## Layout

```
docs/
├── runbooks/        # canonical human procedures (manual-steps.md + future how-tos)
└── site/            # Nextra-built static documentation site
```

## Authoring rule

**Runbooks are canonical. The site INCLUDES from `runbooks/`; it does not duplicate.** A new procedure is authored in `docs/runbooks/<topic>.md`. The Nextra site (`docs/site/pages/`) imports or references that file rather than holding its own copy. This avoids the MECE-overlap flagged by the 2026-04-25 IA peer review.

## What lives where

- iCloud sign-out, FileVault setup, Zed Melange theme install, Apple Intelligence opt-out → `runbooks/manual-steps.md`
- Future "how do I…" pages → `runbooks/<task>.md`
- The published static site (Nextra) → `site/`

## Running the Nextra dev server

```sh
cd docs/site
curl -fsSL https://bun.sh/install | bash   # one-time, if bun isn't installed
bun install
bun dev
```

Edit `site/pages/*.mdx` to see changes.

## Site publishing — open question

Verify whether the Nextra site is still being published anywhere (CI hook, Vercel, GitHub Pages). If not, it may be retired entirely (move to `legacy/docs-site/`). Tracked as an open question in ADR-0013.
