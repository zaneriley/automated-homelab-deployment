# Automated Homelab Deployment with Ansible and Terraform

This is a set of Ansible playbooks and Terraform configurations to automate setting up and managing my homelab environment.

## Overview

The playbooks and configs here allow you to:

* Set up Ubuntu Server LTS on mini-pcs using auto-configurations. 
* Utilize Ansible to manage server states and perform nightly backups
* Use Terraform to connect Docker containers to publicly accessible domain names (e.g., yourhomelab.com)

While this is for my personal homelab, you might find some use from this if you:

* Don't want to set up your homelab (e.g. servers, software, dns, etc) manually each time
* You had your entire homelab get deleted and feel bad about it so you tell yourself you'll automate it but then it takes forever to remember all things you did to create your server in the first place but after a while you finally get something working
* Are interesting in learning more about idempotency, IaC, etc

## Getting Started
[You can read the docs here.](https://automated-homelab-deployment.vercel.app/)

## What this sets up

### Mac Studio (master node)
- **Apps**: Ghostty, Zed, Zen, Lulu, AeroSpace, Obsidian, 1Password (+ CLI), Claude Code, Claude desktop.
- **Tooling**: ansible (+ lint), gh, git-cliff, colima + docker, tart + sshpass, JetBrains Mono Nerd Font.
- **System config**: Zen set as default browser, ~70 macOS defaults (Finder, Dock, keyboard, smart-substitutions, …), always-on power-management LaunchAgent.
- **Dotfiles**: Ghostty, Zed, AeroSpace configs symlinked from `dotfiles/`.
- **Hardening**: disables consumer Apple user-agents (Apple Intelligence, gamed, photoanalysisd, …); removes user-removable Apple bundles (GarageBand, iMovie, Keynote, Numbers, Pages).
- **Agent surface**: clones [pai](https://github.com/zaneriley/pai) to `~/.agents/`; sets up `~/.claude/` (CLAUDE.md, skills, settings.json, co-author hook).

### NUCs / NAS / Raspberry Pis
Inventory placeholders today. The legacy NUC playbook still lives at `legacy/ansible/setup_nuc.yml` pending the phase-2 refactor; nothing is reconciled on these hosts by `site.yml` yet.

