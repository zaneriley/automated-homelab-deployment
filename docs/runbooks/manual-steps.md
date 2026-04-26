# Manual steps

Things that can't be — or shouldn't be — automated. Do these once per fresh install.

The harness does everything else declaratively; these are where Apple (or
reasonable caution) forces a human in the loop.

---

## iCloud — full sign-out

**System Settings → Apple ID → scroll down → Sign Out.**

Full iCloud sign-out cannot be scripted reliably — Apple gates it behind an interactive password / Find-My-Mac confirmation flow. Do this once during the fresh-install setup; the harness never re-signs-in.

After sign-out, verify:

```
defaults read MobileMeAccounts
```

should either return an empty / absent `Accounts` array or error with `Domain MobileMeAccounts does not exist`.

---

## iCloud Drive — Desktop & Documents folder sync

If you choose to stay signed into iCloud for App Store and iMessage (the latter is wanted for LLM-agent tooling), disable Desktop / Documents sync separately:

**System Settings → Apple ID → iCloud → iCloud Drive → Desktop & Documents Folders → OFF.**

This is a GUI-only flip on current macOS. The iCloud Drive daemons (`bird`, `cloudd`) don't expose a documented `defaults` key for selective-folder sync.

---

## Apple Intelligence — opt-out

If the "Set up Apple Intelligence?" prompt appears during first login: **Skip / Don't Enable.**

If already enabled:

**System Settings → Apple Intelligence & Siri → toggle Apple Intelligence → OFF.**

The `harden` role disables the user-scope launch agents (`com.apple.generativeexperiencesd`, `com.apple.intelligenceplatformd`, etc.) which prevents them from starting on next login — but flipping the System Settings toggle is the supported opt-out path and removes downloaded model caches.

---

## FileVault

If not already enabled during install:

**System Settings → Privacy & Security → FileVault → Turn On.**

Write down / 1Password-store the recovery key when prompted. The harness does not touch FileVault state — `fdesetup` requires an admin password at runtime, and the setup is a one-time capture we don't want to re-run.

---

## SIP

Leave it ON (ADR-0005). The harness never disables it.

If you ever want to remove `/System/Applications/*` bundles, do it manually via Recovery mode, and understand the trade-off: removed system apps can return on OS updates, and SIP off is a kernel-level security reduction.

---

## Zed — install Melange theme extension

Zed's built-in theme list does not include Melange; it's delivered via a theme extension. On first Zed launch:

1. Open **Zed.app**.
2. **Cmd+Shift+X** → search "Melange" → **Install**.
3. Zed will immediately honor `"theme": "Melange Dark"` from `settings.json` (the `shell_env` role sets this).

Until the extension is installed, Zed silently falls back to its default theme.

## iMessage / Messages

If you use Messages for LLM-agent tooling (per AGENTS.md §1 item 1), sign into iMessage interactively:

**Messages.app → Preferences → iMessage → Sign In.**

The harness keeps `Messages.app` installed (ADR-0008 and the `apple_cruft` preserve list) but does not manage the iMessage account state.

---

## AeroSpace — grant Accessibility permission

AeroSpace needs Accessibility access to read window state. macOS gates this behind TCC, which is SIP-protected and cannot be granted via script.

1. Launch **AeroSpace.app** (it lives in `/Applications/AeroSpace.app`; the harness installs it via Brewfile).
2. AeroSpace will prompt for Accessibility access on first launch. Click through to **System Settings → Privacy & Security → Accessibility**.
3. Toggle **AeroSpace** on. Click **Use** when re-prompted.
4. Quit and relaunch AeroSpace if window management feels stale.

Until the toggle is on, AeroSpace runs but its window-management commands are no-ops.

The TOML config lives at `~/.config/aerospace/aerospace.toml` (symlinked from `dotfiles/aerospace/aerospace.toml`). Edits to the symlinked file are live; reload via `alt+shift+c` inside AeroSpace.

---

## LuLu — grant Network Extension permission

LuLu (FLOSS outbound firewall by Objective-See) needs a Network Extension approval that cannot be scripted on a SIP-on Mac.

1. Launch **LuLu.app**.
2. The first-run wizard prompts for approval. Follow it through to **System Settings → Privacy & Security → Network Extensions** (or **Login Items & Extensions** depending on macOS version) and toggle **LuLu** on. Authenticate with your password / Touch ID when prompted.
3. LuLu's Activity Monitor and rule database become active after approval.
4. Optional: in LuLu's preferences, enable **Allow Apple Programs** (default) so first-party Apple binaries don't pop alerts every login.

LuLu's preferences live in `~/Library/Preferences/com.objective-see.lulu.plist` and are scriptable — but the harness doesn't manage them today; the right defaults (block-by-default? passive mode?) need a `/literature` pass before they're ratified. Tracked in AGENTS.md backlog.

---

## Zen — default browser confirmation

The `workstation_tools` role runs `defaultbrowser zen` to set Zen as the system default. macOS shows a one-time confirmation dialog the first time:

> "Do you want to use Zen as your default web browser?"

Click **Use "Zen"**. The setting persists across reboots; you should see no further dialogs unless another app re-asserts default-browser ownership (Safari sometimes does this on macOS major-version upgrades — re-run `make apply` to flip back).

To verify by hand:

```
defaultbrowser
```

— a `* zen` line means Zen is currently default.

---

## Removing system apps (Chess, Photos, Calendar, etc.)

These bundles live under `/System/Applications/`, which is SIP-protected. Per ADR-0005, the harness **never** disables SIP and **never** removes system app bundles via script.

Two realistic options:

1. **Suppress, don't remove.** Hide the app from Spotlight / Launchpad / Dock so it stops surfacing. The mechanism (`lsregister -u`, Spotlight Privacy plist, `mdutil` exclusions) is unsettled — tracked in AGENTS.md backlog as a `/literature`-gated task.
2. **Remove via Recovery + SIP off** (manual, expressly opt-in). Boot into Recovery → Terminal → `csrutil disable` → reboot → `sudo rm -rf /System/Applications/Chess.app` (or others) → reboot to Recovery → `csrutil enable` → reboot. Apple may restore removed system apps on the next macOS update; expect to redo. The harness does not script any of this; if you want it, it is a one-time-per-install human procedure.

The `harden` role already addresses the *behavioral* side — supporting daemons (`com.apple.gamed`, `com.apple.photoanalysisd`, `com.apple.calaccessd`, etc.) are launchctl-disabled at user scope, so the apps' background work stops at next login even if the bundles stay on disk.
