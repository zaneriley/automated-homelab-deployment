# Role: system_defaults

Applies macOS user-defaults as data, not code. ADR-0004.

## What it does

Iterates `system_defaults_entries` (defined in `vars/main.yml`) and applies each one with `community.general.osx_defaults`. The module reads the current plist value before writing and only reports `changed` when it actually changed — this is the honest-idempotency story that lets us use "second `make check` reports zero changes" as a real correctness witness (ADR-0009).

## Variables

- `system_defaults_entries` (list of dicts): each entry has `domain`, `key`, `type`, `value`. Defined in `vars/main.yml`. Adding a managed setting = one new entry in that list — no task block changes.

## Toggle

No on/off — this role is declarative config. Individual entries can be removed from `system_defaults_entries` to stop managing a key. Note: removing a managed entry does NOT revert the setting on the machine; it only stops Ansible from reasserting it. If you want to revert, either add `state: absent` temporarily or run `defaults delete <domain> <key>` manually.

## Blast radius

- Reads the current plist value for each managed key before writing.
- Writes only when the current value differs from the declared value.
- Does NOT delete keys that aren't declared (this role is additive; the machine keeps its un-declared defaults).

## Undo

For a specific key:

```
defaults delete <domain> <key>
```

Then remove the entry from `vars/main.yml` so Ansible doesn't reassert on the next apply.

For all managed keys: `defaults read <domain>` per entry, decide, `defaults delete` per key.

## Verifying by hand

Any managed key can be verified with:

```
defaults read <domain> <key>
```

For example:

```
defaults read com.apple.screencapture location
```

should return `/Users/<you>/Screenshots`.
