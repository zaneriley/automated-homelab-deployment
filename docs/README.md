# docs/

Operator-facing prose. Not contract (that's `AGENTS.md`), not decisions (that's `ADRS.md`), not timeline (that's `CHANGELOG.md`).

## Layout (target)

```
docs/
├── runbooks/        # canonical human procedures (manual steps, troubleshooting how-tos)
└── site/            # Nextra-built static documentation site
```

## Authoring rule

**Runbooks are canonical. The site INCLUDES from `runbooks/`; it does not duplicate.** A new procedure is authored in `docs/runbooks/<topic>.md`. The Nextra site (`docs/site/pages/`) imports or references that file rather than holding its own copy. This avoids the MECE-overlap flagged by the 2026-04-25 IA peer review.

## What lives where

- iCloud sign-out, FileVault setup, Zed Melange theme install, Apple Intelligence opt-out → `runbooks/manual-steps.md`
- Future "how do I…" pages → `runbooks/<task>.md`
- The published static site (Nextra) → `site/`

## Current state

- `manual-steps.md` is now at `docs/runbooks/manual-steps.md` (canonical location per ADR-0013).
- The Nextra site files (`package.json`, `next.config.js`, `pages/`, etc.) are still at `docs/` root.
- The Nextra → `docs/site/` move is pending (sequencing in AGENTS.md § 3).

To run the existing Nextra dev server (until the move):

```sh
curl -fsSL https://bun.sh/install | bash   # install bun (macOS / Linux / WSL)
bun install
bun dev
```

Edit `pages/*.mdx` to see changes.

## Site publishing — open question

Verify whether the Nextra site is still being published anywhere before investing in the move. If it is not, the Nextra app may be retired entirely (move to `legacy/`). Tracked as an open question in ADR-0013.
