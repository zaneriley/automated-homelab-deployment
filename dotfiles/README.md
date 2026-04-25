# dotfiles/

**Ansible role payload, NOT chezmoi / stow / yadm.**

This directory holds static configuration files that the `shell_env` role symlinks into the user's home (typically `~/.config/<app>/`). The semantics are *Ansible's* (`ansible.builtin.file: state=link`) — there is no chezmoi, stow, or yadm in this repo (ADR-0002 explicitly rejected dotfile-only tools). Editing a file here updates the source-of-truth; the next `make apply` re-asserts the symlink (idempotent).

## Layout

```
dotfiles/
├── ghostty/
│   └── config           → ~/.config/ghostty/config
└── zed/
    └── settings.json    → ~/.config/zed/settings.json
```

## Adding a tool

1. Create `dotfiles/<tool>/<file>`.
2. Add a symlink task in `roles/shell_env/tasks/Darwin.yml` (or the relevant OS family).
3. `make check` → `make apply` → `make check`. Second check should report `changed=0` (ADR-0009).

## Why a top-level dir, not `roles/shell_env/files/`?

Some payloads are referenced by more than one role. Keeping them at root lets multiple roles symlink the same canonical file. If a payload is *only* used by one role and never will be cross-referenced, it can live in `roles/<role>/files/` instead. Today everything here is `shell_env`-only — but this is the conventional Ansible escape hatch.

See ADR-0013 for the directory-naming rationale (the 2026-04-25 IA peer review flagged the name as semantically loaded; the README is the corrective).
