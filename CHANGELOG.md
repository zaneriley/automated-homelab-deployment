# Changelog

All notable changes to this repository are recorded here.

This file is **generated** from Conventional Commits by `git-cliff` — see
[ADR-0012](ADRS.md). Do not hand-edit; edits are overwritten on the next
`make changelog` run, and CI (`make changelog-check`) fails on drift.

Format follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/).
Commit convention: [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).

## [Unreleased]


### Bootstrap
- Preflight, foundation dirs, Brewfile reconciliation ([`2986c19`](https://github.com/zaneriley/automated-homelab-deployment/commit/2986c19fc16fd09c34aab3062fd702cd51906b73))


### System defaults
- 12 baseline macOS defaults via osx_defaults ([`127fc40`](https://github.com/zaneriley/automated-homelab-deployment/commit/127fc40fa967073cdcd645bfe8d3aed53fa71eff))
- Always-on workstation — disable screen lock, key-repeat QoL, caffeinate LaunchAgent ([`616fff5`](https://github.com/zaneriley/automated-homelab-deployment/commit/616fff5287ae1af428e405fa6d10879e70bd8e0f))
- Race-resistant LaunchAgent reload + parent-dir guard ([`ee1df72`](https://github.com/zaneriley/automated-homelab-deployment/commit/ee1df7276d83524fb3993c3d90c8481acc71fb9e))


### Shell env
- Ghostty + Zed configs, JetBrainsMono Nerd Font Mono, Melange Dark ([`30485c3`](https://github.com/zaneriley/automated-homelab-deployment/commit/30485c37aa5ffcae46e5df5b301451fef8daa11b))
- Data-driven dotfile loop ([`802ea29`](https://github.com/zaneriley/automated-homelab-deployment/commit/802ea2918409758b8c095aa7327e80ac0d197b31))


### Harden
- Layer 1 — empty the Dock (first real de-Apple slice) ([`bcc67c0`](https://github.com/zaneriley/automated-homelab-deployment/commit/bcc67c01d657f12840d6a6d70c9a794a8caae472))
- Disable Siri + Apple Intelligence user launch agents ([`ef7a39a`](https://github.com/zaneriley/automated-homelab-deployment/commit/ef7a39a28df8dbd2749c052fdd74c4afff787e1c))
- Layer 2 mechanism + Tart rehearsal harness ([`a728c12`](https://github.com/zaneriley/automated-homelab-deployment/commit/a728c12d69a420aad4d1c6bce202dd8ecd0b6242))
- Layer 1 expansion (Calendar/Photos/Maps/etc.) + harness hardening ([`0bbf095`](https://github.com/zaneriley/automated-homelab-deployment/commit/0bbf095cc5db2c1158b03c10165254ad0be7c36c))


### Workstation tools
- Dark theme, AeroSpace config, Zen default browser ([`e3abb55`](https://github.com/zaneriley/automated-homelab-deployment/commit/e3abb5510b123d23fc6ce02c2b628575a5a72471))
- Wrap fail msg to satisfy yaml line-length ([`16f95ad`](https://github.com/zaneriley/automated-homelab-deployment/commit/16f95ad59f0cb5839426049f8cafa6d3bb66b21a))


### Harness
- Scaffold master-node harness (Makefile, inventory, 5 role skeletons) ([`1308614`](https://github.com/zaneriley/automated-homelab-deployment/commit/1308614702818cc4829fc687f69f5b20cf3d6935))
- Peer-review hardening (brew bundle semantics, bootstrap.sh, interpreter pin, gitignore) ([`cae340d`](https://github.com/zaneriley/automated-homelab-deployment/commit/cae340d9fa42a452a032eebad973b2e206d6f07f))
- Add deterministic CHANGELOG pipeline (ADR-0012) ([`02ca51c`](https://github.com/zaneriley/automated-homelab-deployment/commit/02ca51c193b93170882d692cf2be7bc2d61368b5))
- Move overridable lists from vars/ to defaults/ ([`bb9e7ec`](https://github.com/zaneriley/automated-homelab-deployment/commit/bb9e7ecf17530b6538cbdfed302ce5ec08c8fd31))
- Defer fact-gathering until after CLT preflight ([`6de42d0`](https://github.com/zaneriley/automated-homelab-deployment/commit/6de42d037d28bf295493df2384d4b70a178032fe))
- Replace fragile substring probes with parsed lists + failed_when guards ([`fc9a716`](https://github.com/zaneriley/automated-homelab-deployment/commit/fc9a716d5c4490f6c5c9d9a53dbfe0b186520489))
- Scope Restart Dock to Dock-key changes; lift handler to play-level ([`e31e1bf`](https://github.com/zaneriley/automated-homelab-deployment/commit/e31e1bf48c5af78b2f73e18e478fdb31cde4caec))


### Decisions (ADRs)
- ADR-0011 — commit-message claim discipline ([`ecc9871`](https://github.com/zaneriley/automated-homelab-deployment/commit/ecc9871af23a0620f1fc5dc881a7a27b07ba503a))


### Documentation
- Add AGENTS.md and ADRS.md ([`0a44aae`](https://github.com/zaneriley/automated-homelab-deployment/commit/0a44aaee9534ded66b812210f694906f9c5b03a3))
- Capture I/A in AGENTS.md §3 + ADR-0013 + 8 per-directory READMEs ([`4274917`](https://github.com/zaneriley/automated-homelab-deployment/commit/42749176d88b1d80a3e39c5471b20e41f83e4115))
- AGENTS.md §3 + ADRS.md cross-doc updates after IA reorg moves ([`da7f4fe`](https://github.com/zaneriley/automated-homelab-deployment/commit/da7f4feb900e97575312434cf0aba8ca5b9d8aff))
- Annotate backup architecture pivot — Mac as central cron, NAS subsystem ([`f297298`](https://github.com/zaneriley/automated-homelab-deployment/commit/f29729882303fc653378ef17bb7d7a8318c97214))
- Rewrite README from V1-legacy to current Mac-Studio-master-node scope ([`56d86a6`](https://github.com/zaneriley/automated-homelab-deployment/commit/56d86a6e018eb9dbd32c5455eaeca32291ca9cac))
- AGENTS.md §3 covers every tracked top-level entry; drop rotting backlog SHAs ([`e85eb6c`](https://github.com/zaneriley/automated-homelab-deployment/commit/e85eb6c5a0dbbb717aaa1709fd424a40c658435f))


