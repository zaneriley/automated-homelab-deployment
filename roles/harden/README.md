# Role: harden

Three-layer de-Apple work per ADR-0003.

## Layers

| Variable | Default | What it does | Blast radius |
|---|---|---|---|
| `harden_apple_cruft_disable` | **true** | Empty Dock; disable unwanted launch agents (future commits); flip iCloud sync toggles where scriptable (future commits) | Low: visual/UX only; reversible |
| `harden_apple_cruft_delete_bundles` | false | `rm -rf` user-removable consumer `/Applications/*.app` (iWork, GarageBand, iMovie, etc.) | High: apps gone; reinstall via App Store |
| `harden_apple_cruft_block_telemetry` | false | `/etc/hosts` null-route Apple analytics domains | High: can break `softwareupdate` |

## Layer 2 — what's implemented now (default OFF)

When `harden_apple_cruft_delete_bundles: true` is set in `group_vars/master.yml`:

`/Applications/{GarageBand,iMovie,Keynote,Numbers,Pages}.app` are removed via `ansible.builtin.file: state=absent` with `become: true`. The list lives in `vars/main.yml` (`harden_apple_cruft_bundles`).

These five are the only consumer Apple bundles that ship under `/Applications/` on a clean install — Music/TV/News/Maps/Stocks/Photos/Podcasts/etc. are all under `/System/Applications/` and are **deliberately out of scope** per ADR-0005 (SIP stays on; system bundles are not scripted). For those, see `docs/manual-steps.md` (Recovery-mode procedure, expressly opt-in and manual).

`state: absent` is honestly idempotent: first apply removes, second reports unchanged. Mac App Store will offer to reinstall any bundle bought under Z's Apple ID — accept the loop: re-apply removes again, no special handling.

**Rehearsal:** apply Layer 2 against a Tart VM via `scripts/rehearse-tart.sh` before flipping the toggle on the real Mac (ADR-0003). The vanilla VM image doesn't ship with iLife/iWork, so the rehearsal harness plants empty `.app` directories as fixtures — enough to exercise `state: absent` semantics and idempotency.

## Layer 1 — what's implemented now

1. **Dock emptying** — `persistent-apps` and `persistent-others` become empty arrays; a handler runs `killall Dock` so the change takes effect immediately.
2. **Siri / Apple Intelligence launch-agent disables** (user scope, `gui/<uid>`) — persistent `launchctl disable` for 9 daemons across Siri and the AI stack (list in `vars/main.yml`). The Dock handler is separate from launchctl; a logout/login cycle actually stops the running instances.
3. **Siri user-preference disables** — the user-preference side (Siri menu-bar entry, "Hey Siri," main assistant switch) lives in `roles/system_defaults/vars/main.yml` under the Siri block.

Not yet in the role, tracked in `docs/manual-steps.md` because they're genuinely GUI-only:

- Full iCloud sign-out (Apple requires an interactive password + Find-My confirmation)
- iCloud Drive Desktop/Documents folder sync toggle
- Apple Intelligence System Settings toggle (the authoritative opt-out; our launchctl disables are a supporting measure)

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
