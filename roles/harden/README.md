# Role: harden

Three-layer de-Apple work per ADR-0003.

## Layers

| Variable | Default | What it does | Blast radius |
|---|---|---|---|
| `harden_apple_cruft_disable` | **true** | Empty Dock; disable unwanted launch agents (future commits); flip iCloud sync toggles where scriptable (future commits) | Low: visual/UX only; reversible |
| `harden_apple_cruft_delete_bundles` | false | `rm -rf` user-removable consumer `/Applications/*.app` (iWork, GarageBand, iMovie, etc.) | High: apps gone; reinstall via App Store |
| `harden_apple_cruft_block_telemetry` | false | `/etc/hosts` null-route Apple analytics domains | High: can break `softwareupdate` |

## Layer 1 — what's implemented now

Just Dock emptying: `persistent-apps` and `persistent-others` both become empty arrays, a handler runs `killall Dock` so the change takes effect without a reboot.

Additional layer 1 work (launch-agent disables via `launchctl disable`, iCloud sync toggles) is added in follow-up commits — each earns its place via verified behavior change and honest idempotency per Gate A.

## Toggle

Set `harden_apple_cruft_disable: false` in `group_vars/master.yml` to skip layer 1 entirely. Layers 2 and 3 have separate variables; flipping them to `true` opts into that layer's operations.

## Blast radius — layer 1, this commit

- The Dock becomes empty of pinned apps and pinned folders/files.
- Finder, Downloads, and Trash remain — those are structural, not in `persistent-apps` / `persistent-others`.
- Currently running apps continue to show in the Dock while running (blue dot); they disappear when quit.

## Undo — layer 1

Drag apps back from `/Applications` to the Dock manually. Flipping `harden_apple_cruft_disable: false` on a subsequent apply will NOT re-populate — Ansible only asserts declared state; it does not restore state that a prior run cleared.

For a precise restore, keep a `~/dock-backup.plist` beforehand and `defaults import com.apple.dock ~/dock-backup.plist`.

## Verify by hand

```
defaults read com.apple.dock persistent-apps    # expect: ( )
defaults read com.apple.dock persistent-others  # expect: ( )
```
