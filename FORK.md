# sam33r/OmniWM fork

Personal fork of [OmniNull/OmniWM](https://github.com/OmniNull/OmniWM). Fork changes
live on this fork's **`main`** branch, on top of upstream `main`. Run it as
**OmniWM Dev** (`~/Applications/OmniWM Dev.app`), next to the Homebrew release.

## What the fork changes

- **No Ghostty.** The built-in Quake terminal is compiled out, so GhosttyKit,
  Nix and `make setup` aren't needed. `QuakeTerminal/QuakeTerminalDisabled.swift`
  stands in for its controller. The Kitty Quick Access provider still works.
- **Agent-friendly builds.** SwiftPM runs with `--disable-sandbox` (its sandbox
  can't nest inside an agent's sandboxed shell), and dev packaging skips the
  release checks.
- **Scripts:** `Scripts/fork-dev-cert.sh` (signing identity),
  `Scripts/fork-dev-install.sh` (build, sign, install without launching) and
  `Scripts/fork-dev-restart.sh` (quit and reopen a running Dev).
- **Workspaces from the keyboard:** `move-to-workspace new` (new workspace on
  the window's monitor, move the window, follow it), `switch-workspace new`,
  and `move-to-workspace next|prev` (same order as `switch-workspace next|prev`).
  Hotkey ids `moveToWorkspace.new`, `switchWorkspace.new`, `moveToWorkspace.next`,
  `moveToWorkspace.previous` (unassigned by default). Pull more windows into the
  new workspace with the command palette's Shift-Enter (summon right).
- **`[focus] followsMouseMaxScrollPercent`** (0–100, unset = unlimited): mouse
  focus skips Niri windows that would scroll the view more than this, like
  niri's `max-scroll-amount`.
- **`ignore` rule layout** (`layout = "ignore"`, `omniwmctl rule add ... --layout ignore`):
  matching windows are never managed (no tiling, floating, overview or bar).
- **`[monitors] defaultOrientation`** (`auto` | `horizontal` | `vertical`):
  global default under per-monitor `monitorOrientationOverrides`.
- **`[focus] moveToMonitorWrapsAround`**: move-to-monitor wraps to the far
  monitor at the edge.
- **`[focus] relativeWorkspaceEdgeBehavior`** (`cycle` | `none` | `onePast`):
  what next/prev workspace switches and moves do at the ends. `onePast` is
  niri-style: next past the last occupied workspace opens a new one (a move
  carries the window into it), so no separate new-workspace key is needed.

## Set up Dev on a new Mac

Prerequisites: Apple Silicon, macOS 27, Xcode 27 selected (`xcode-select -p`),
Homebrew, `jq`, and the `~` dotfiles repo pulled (it has `~/bin/omniwmctl`,
the skhd bindings and the swiftly line in `~/.zprofile`).

Steps marked **(user)** need the user's terminal: password prompts, or
quitting/launching apps. An agent can do the rest.

1. **Clone the fork:**
   ```bash
   git clone git@github.com:sam33r/OmniWM.git ~/src/OmniWM   # or: git -C ~/src/OmniWM fetch
   ```
2. **Swift toolchain.** The repo pins a development snapshot in `.swift-version`.
   ```bash
   brew install swiftly
   swiftly init --skip-install --quiet-shell-followup -y
   . ~/.swiftly/env.sh
   cd ~/src/OmniWM && swiftly install -y          # ~1 GB
   swiftly use --global-default xcode -y          # only this repo uses the snapshot
   ```
   `swiftly init` appends a line to `~/.zprofile`. The dotfiles version already
   has a guarded one, so drop the duplicate if it adds another.
3. **(user) Signing identity**, once per Mac: `~/src/OmniWM/Scripts/fork-dev-cert.sh`.
   It asks for the password twice. Without it, builds are ad-hoc signed and
   macOS asks for permissions again after every rebuild.
4. **Build and install:** `~/src/OmniWM/Scripts/fork-dev-install.sh`. The first
   build takes a few minutes. It copies `~/.config/omniwm/settings.toml` to
   `~/.config/omniwm-dev/settings.toml` the first time only.
5. **(user) Switch to Dev:** `make -C ~/src/OmniWM use-dev`. This quits the
   Homebrew OmniWM and opens Dev. On first launch, grant **OmniWM Dev**
   Accessibility and Input Monitoring (Screen Recording is optional), follow
   any restart prompt, then click **Start OmniWM**.
6. **Verify:** `omniwmctl version` should report `protocol 22` and `debug` with
   the fork's `main` commit. `~/bin/omniwmctl` picks the CLI of whichever OmniWM is
   running; the fork's IPC protocol differs from the 0.7.6 release, which
   would reject a mismatched client and break the skhd bindings.

In the user's own terminal, `make -C ~/src/OmniWM run` does steps 4 and 5 in one go.

## Everyday use

- **Rebuild after a code change:** `Scripts/fork-dev-install.sh`, then
  **(user)** `Scripts/fork-dev-restart.sh` to quit and reopen Dev. (`make use-dev`
  only switches from the release app; it won't restart a running Dev.)
- **Back to the Homebrew release:** **(user)** `make -C ~/src/OmniWM use-release`.
- **Tests:** `. ~/.swiftly/env.sh && swift test --arch arm64 --disable-sandbox`.
- **Settings:** Dev reads `~/.config/omniwm-dev/settings.toml`, not
  `~/.config/omniwm/`. It uses a newer schema (v5) and migrated its copy on
  first launch (backup: `settings.toml.pre-v5`). OmniWM reloads it live.
  `~/.config/omniwm/CHANGES.md` in the dotfiles repo logs every settings change.
- **Pull upstream:** `git fetch upstream && git rebase upstream/main` on
  `main`, then `git push --force-with-lease` (add the remote once: `git remote add upstream https://github.com/OmniNull/OmniWM.git`). If upstream changes `QuakeTerminalController`'s interface,
  update `QuakeTerminalDisabled.swift` to match.
