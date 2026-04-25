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

These five are the only consumer Apple bundles that ship under `/Applications/` on a clean install — Music/TV/News/Maps/Stocks/Photos/Podcasts/etc. are all under `/System/Applications/` and are **deliberately out of scope** per ADR-0005 (SIP stays on; system bundles are not scripted). For those, see `docs/runbooks/manual-steps.md` (Recovery-mode procedure, expressly opt-in and manual).

`state: absent` is honestly idempotent: first apply removes, second reports unchanged. Mac App Store will offer to reinstall any bundle bought under Z's Apple ID — accept the loop: re-apply removes again, no special handling.

**Rehearsal:** apply Layer 2 against a Tart VM via `scripts/rehearse-tart.sh` before flipping the toggle on the real Mac (ADR-0003). The vanilla VM image doesn't ship with iLife/iWork, so the rehearsal harness plants empty `.app` directories as fixtures — enough to exercise `state: absent` semantics and idempotency.

## Layer 1 — what's implemented now

1. **Dock emptying** — `persistent-apps` and `persistent-others` become empty arrays; a handler runs `killall Dock` so the change takes effect immediately.
2. **Launch-agent disables** (user scope, `gui/<uid>`) — persistent `launchctl disable` for ~50 daemons covering:
   - **Siri** (assistantd, siriactionsd, siri.context.service)
   - **Apple Intelligence** (generativeexperiencesd, intelligenceplatformd, intelligenceflowd, intelligencetasksd, intelligencecontextd, callintelligenced)
   - **Apple-bundled consumer apps Z does not use**: Calendar, Photos, Maps, News, Mail, Contacts, Books, FaceTime, Find My, Game Center, Home, Notes, Podcasts, Voice (memos / banking), Weather, Stickers, Safari bookmark sync
   The full per-app list with grouping and side-effect notes is in `vars/main.yml`. The disables are persistent — daemons won't relaunch on next login. Currently-running instances stay up until logout (we don't `launchctl bootout` to avoid that idempotency dance).
3. **Siri user-preference disables** — `Assistant Enabled`, `StatusMenuVisible`, `VoiceTriggerUserEnabled` — set in `roles/system_defaults/vars/main.yml`.

### Side-effect contract for the launch-agent set

Disabling supporting daemons is the closest we get to "remove" without disabling SIP (ADR-0005). The `.app` bundles still exist under `/System/Applications/` and remain double-clickable. What's gone:

- Background sync, indexing, and network calls from the disabled apps
- Auto-launch on login
- Most cross-app integrations that depend on these daemons (e.g. Mail's contact autocomplete relies on `contactsd` — see `vars/main.yml` for the full side-effect inventory)

What's NOT addressed by Layer 1 (intentionally):

- Spotlight / Launchpad still surface the apps as launchable — a future commit will add Spotlight exclusion
- The system-app bundles themselves (system-app *removal* is forbidden by ADR-0005 because it requires SIP-off + Recovery boot, which we don't do)

### Layer 1 — manual follow-ups (tracked in `docs/runbooks/manual-steps.md`)

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
