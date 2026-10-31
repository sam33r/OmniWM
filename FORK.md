# sam33r/OmniWM fork

Personal fork of [OmniNull/OmniWM](https://github.com/OmniNull/OmniWM), forked
from upstream `main` at `43c178f6` (2026-10-26) and last caught up with it at
`ce40789d` (2026-10-30). Fork changes live on this fork's **`main`** branch. Run
it as **OmniWM Dev** (`~/Applications/OmniWM Dev.app`), next to the Homebrew
release.

This is a real fork: `main` never rebases onto upstream and is never
force-pushed. Now and then we review what upstream has changed and take what we
want, by cherry-picking a few commits or merging `upstream/main` when we want
most of it (see **Upstream check-ins** below). Fork changes can delete or rework
upstream code freely; a later merge then has to resolve those spots again.

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
- **`[focus] dimUnfocused`** (+ `dimUnfocusedOpacity`, default 0.6): dims
  everything but the focused window on every display, like HazeOver, with a
  short cross-fade when focus moves. Launchers above the layer (goose,
  Spotlight) keep the previous window bright instead of clearing the dim.
  Toggle with `omniwmctl command toggle-dim-unfocused` or the
  `toggleDimUnfocused` hotkey (unassigned).
- **`[overview] fitWorkspaceRows`** (2–6, unset = fixed size): overview rows
  shrink so up to this many workspaces fit on screen; fewer workspaces get
  bigger rows (never fewer than two).
- **Settings over IPC** (protocol 23): `omniwmctl query settings [--key <key>]`
  lists every scalar setting with its title, description, type, value, default,
  and range or choices; `omniwmctl settings set|toggle|reset <key> [value]`
  changes one live and saves it; `omniwmctl subscribe settings-changed` streams
  snapshots after any change (hotkey edits included). `query commands` entries
  gain `title`, `hotkeys` and `argumentHotkeys`, and arguments gain `choices`.
  Failures carry a top-level `detail` sentence. Built for goose's OmniWM plugin.
  The catalog of titles and descriptions is `IPC/IPCSettingsCatalog+Sections.swift`;
  a test fails when a new scalar setting is missing from it.

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
6. **Launch at login.** `make use-dev` doesn't touch login items, so a Mac that
   had the Homebrew app as a login item starts the release again after a
   reboot. Swap it to Dev (an agent can run this):
   ```bash
   osascript -e 'tell application "System Events"
     if exists login item "OmniWM" then delete login item "OmniWM"
     if not (exists login item "OmniWM Dev") then make login item at end with properties {path:(POSIX path of (path to home folder)) & "Applications/OmniWM Dev.app", hidden:false}
     get the name of every login item
   end tell'
   ```
   Or do it in System Settings → General → Login Items.
7. **Verify:** `omniwmctl version` should report `protocol 23` and `debug` with
   the fork's `main` commit. `~/bin/omniwmctl` picks the CLI of whichever OmniWM is
   running; the fork's IPC protocol differs from the 0.7.6 release, which
   would reject a mismatched client and break the skhd bindings.

In the user's own terminal, `make -C ~/src/OmniWM run` does steps 4 and 5 in one go.

## Everyday use

- **Update from GitHub** (another Mac): `git -C ~/src/OmniWM pull --ff-only`.
  If that refuses, the clone predates the switch away from rebasing (2026-10-30).
  Check for local work first (`git status`, `git log origin/main..main`), then
  run `git fetch && git reset --hard origin/main`. Then rebuild and restart as below.
- **Rebuild after a code change:** `Scripts/fork-dev-install.sh`, then
  **(user)** `Scripts/fork-dev-restart.sh` to quit and reopen Dev. (`make use-dev`
  only switches from the release app; it won't restart a running Dev.)
- **Back to the Homebrew release:** **(user)** `make -C ~/src/OmniWM use-release`,
  and swap the login item back to `/Applications/OmniWM.app` (step 6 in reverse).
- **Tests:** `. ~/.swiftly/env.sh && swift test --arch arm64 --disable-sandbox`.
- **Settings:** Dev reads `~/.config/omniwm-dev/settings.toml`, not
  `~/.config/omniwm/`. It uses a newer schema (v5) and migrated its copy on
  first launch (backup: `settings.toml.pre-v5`). OmniWM reloads it live.
  `~/.config/omniwm/CHANGES.md` in the dotfiles repo logs every settings change.
- **Upstream check-ins:** see the next section. Never rebase `main` onto
  upstream.

## Upstream check-ins

Upstream moves fast (178 commits and +81k lines in the four days after the fork
point), so we take only what we want, when we want it: bug fixes (especially
for new macOS releases), performance work, and features worth having.

**Reviewed through:** `ce40789d` (2026-10-30, merged in full).

1. Fetch: `git fetch upstream` (add the remote once:
   `git remote add upstream https://github.com/OmniNull/OmniWM.git`).
2. List what's new since the last review:
   `git log --no-merges --reverse --format='%h %ad %s' --date=short <reviewed>..upstream/main`.
   Add `-- <paths>` to limit it to code the fork still has.
3. Cherry-pick what we want with `git cherry-pick -x <sha>` (`-x` records the
   upstream commit in the message), then build and run the tests.
4. Set **Reviewed through** above to the upstream commit you reviewed up to, and
   commit that with the picks.

To take nearly everything instead, merge: `git merge upstream/main` on a branch
off `main` (or in a worktree), resolve, build with tests, run the full suite,
then fast-forward `main` to it. Spots that need fixing after a merge, beyond the
text conflicts:

- **Quake stub:** new `QuakeTerminalController` methods that the rest of the app
  calls need no-op versions in `QuakeTerminalDisabled.swift`.
- **Ghostty tests:** new test files that `import GhosttyKit` go in
  `ghosttyQuakeTerminalTests` in `Package.swift`.
- **Settings IPC:** `SettingsIPCTests` fails for each new upstream scalar
  setting until it has an entry in `IPCSettingsCatalog+Sections.swift` (or in
  `notSettableKeys`). New enum cases need adding to existing entries' choices.
- **IPC protocol:** if upstream bumps `OmniWMIPCProtocol.version`, ours must
  stay above it (it was 22 upstream, 23 here, as of 2026-10-30).

Good times to check in: when a macOS update breaks something, when hitting a
bug upstream may have fixed, or every month or so.
