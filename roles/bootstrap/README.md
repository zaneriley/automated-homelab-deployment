# Role: bootstrap

Brings a fresh Mac to a state where every other role can run.

## What it does

1. **Preflight** — hard-fail if any of:
   - Xcode Command Line Tools missing (`xcode-select -p` nonzero)
   - Homebrew not present at `/opt/homebrew/bin/brew`
   - Current user not in the `admin` group
2. **Foundation** — ensure the canonical directories exist: `~/lab`, `~/repos`, `~/models`, `~/notes`, `~/Screenshots`. Idempotent via `ansible.builtin.file`.
3. **Homebrew bundle** — reconcile against `Brewfile` in the repo root. `brew bundle check` detects drift; the reconcile task runs only when drift is detected. `--no-upgrade` is passed so already-installed packages are NOT upgraded silently.

## Variables

- `foundation_dirs` (list): the canonical directories to ensure. Defined in `group_vars/master.example.yml`.
- `brewfile_path` (string): absolute path to the Brewfile. Defined in `group_vars/master.example.yml`.

## Toggle

No on/off switch — `bootstrap` is foundational and runs on every `site.yml` apply.

## Blast radius

- **Preflight**: zero side effects; read-only probes.
- **Foundation**: creates directories if missing. Never deletes, never reorders existing content.
- **Homebrew bundle**: installs `brew` formulae, casks, and taps declared in `Brewfile` that are missing on the machine. Does NOT upgrade already-installed packages (`--no-upgrade`). Does NOT remove packages that are installed but not declared (we use `brew bundle`, not `brew bundle cleanup`).

## Undo

- **Preflight**: nothing to undo.
- **Foundation**: `rm -rf ~/lab ~/repos ~/models ~/notes ~/Screenshots`. Refuses to delete non-empty directories only if you pass `-i`; otherwise it wipes contents — think twice, you'll have work there by then.
- **Homebrew bundle**: `brew uninstall <formula>` or `brew uninstall --cask <cask>` per package. No wholesale revert — the Brewfile is a declaration of wanted state, not a reversible transaction. If you want to drop something the Brewfile declares, remove it from the Brewfile *and* `brew uninstall` it manually.
