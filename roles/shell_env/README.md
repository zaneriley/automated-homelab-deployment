# Role: shell_env

Terminal and editor config for the master node. Font + theme for Ghostty and Zed.

## What it does

- Ensures `~/.config/ghostty/` and `~/.config/zed/` exist.
- Symlinks `~/.config/ghostty/config` → `<repo>/dotfiles/ghostty/config`.
- Symlinks `~/.config/zed/settings.json` → `<repo>/dotfiles/zed/settings.json`.

Symlink pattern (not templating): edits to the config files land in git directly — no render-then-apply loop, no drift between "what's on disk" and "what's in the repo." The next `make apply` is a no-op unless the symlink itself was removed or pointed elsewhere.

## Ratified settings

- **Font:** `JetBrainsMono Nerd Font Mono` (installed via `Brewfile` → `font-jetbrains-mono-nerd-font` cask)
- **Theme:** `Melange Dark`
- **Font size:** 14pt (both Ghostty and Zed)

## Toggle

No on/off. The role is purely about ensuring the symlinks exist.

## Blast radius

- If `~/.config/ghostty/config` or `~/.config/zed/settings.json` exist as **regular files** at apply time (e.g. hand-edited post-launch before the role ran), `force: true` on the `file: state=link` tasks will delete them and replace with a symlink. On a fresh install this is a no-op — those files don't exist. On a reinstall where you've been tweaking configs directly in place, back them up first.

## Undo

Remove the symlinks: `rm ~/.config/ghostty/config ~/.config/zed/settings.json`. The canonical files at `<repo>/dotfiles/` are untouched — you can rebuild the configs from scratch (or point the symlink elsewhere) without losing the ratified defaults.

## Manual follow-up — Zed Melange theme extension

Zed's built-in theme list does **not** include Melange. Zed has a per-extension theme system (Extensions panel in-app). On first Zed launch:

1. Open Zed.
2. Cmd+Shift+X → search "Melange" → install.
3. Zed will start honoring `"theme": "Melange Dark"` in `settings.json`.

Until the extension is installed, Zed ignores the unknown theme value and falls back to its default (One Dark, typically).

Ghostty's Melange Dark is built-in; no manual step required.
