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

## iMessage / Messages

If you use Messages for LLM-agent tooling (per AGENTS.md §1 item 1), sign into iMessage interactively:

**Messages.app → Preferences → iMessage → Sign In.**

The harness keeps `Messages.app` installed (ADR-0008 and the `apple_cruft` preserve list) but does not manage the iMessage account state.
