# Changelog

All notable changes to this repository are recorded here.

This file is **generated** from Conventional Commits by `git-cliff` — see
[ADR-0012](ADRS.md). Do not hand-edit; edits are overwritten on the next
`make changelog` run, and CI (`make changelog-check`) fails on drift.

Format follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/).
Commit convention: [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).

## [Unreleased]


### Bootstrap
- Preflight, foundation dirs, Brewfile reconciliation ([`2f25e1d`](https://github.com/zaneriley/automated-homelab-deployment/commit/2f25e1df2a9d7cb881cfb51ca073618bec7bbab4))


### System defaults
- 12 baseline macOS defaults via osx_defaults ([`78b4f5f`](https://github.com/zaneriley/automated-homelab-deployment/commit/78b4f5f2371fdf637d26a24dd414ef87000af93f))


### Shell env
- Ghostty + Zed configs, JetBrainsMono Nerd Font Mono, Melange Dark ([`461dbc7`](https://github.com/zaneriley/automated-homelab-deployment/commit/461dbc7f936e65dc164dfe41d53e8c0da6247d38))


### Harden
- Layer 1 — empty the Dock (first real de-Apple slice) ([`17e3379`](https://github.com/zaneriley/automated-homelab-deployment/commit/17e33794fb4203fe2fefb69d5b5dc6d38d0e20c8))
- Disable Siri + Apple Intelligence user launch agents ([`89b1fa9`](https://github.com/zaneriley/automated-homelab-deployment/commit/89b1fa997e4fcc3a223d0835a9689095fd837694))
- Layer 2 mechanism + Tart rehearsal harness ([`87fe4ae`](https://github.com/zaneriley/automated-homelab-deployment/commit/87fe4ae34bf4e4d450d8e95d7362af226616a10d))
- Layer 1 expansion (Calendar/Photos/Maps/etc.) + harness hardening ([`b21ee5f`](https://github.com/zaneriley/automated-homelab-deployment/commit/b21ee5fb7b946e9ed7fb5dcd3996e3889df8d45e))


### Harness
- Scaffold master-node harness (Makefile, inventory, 5 role skeletons) ([`cc379ff`](https://github.com/zaneriley/automated-homelab-deployment/commit/cc379ff2857ecbc617b99749b3e47ab6e7883093))
- Peer-review hardening (brew bundle semantics, bootstrap.sh, interpreter pin, gitignore) ([`1a5d1d0`](https://github.com/zaneriley/automated-homelab-deployment/commit/1a5d1d085c91fd6be62b050045e9d3e02da88e2b))


### Decisions (ADRs)
- ADR-0011 — commit-message claim discipline ([`1bc4434`](https://github.com/zaneriley/automated-homelab-deployment/commit/1bc443406d4ab7f26b2312f489bba7afcd626046))


### Documentation
- Add AGENTS.md and ADRS.md ([`fd9ecc7`](https://github.com/zaneriley/automated-homelab-deployment/commit/fd9ecc773dc0c38503c10658638f12f9a52bc0ed))


