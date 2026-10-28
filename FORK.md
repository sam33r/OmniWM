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
- **Scripts:** `Scripts/fork-dev-cert.sh` (signing identity) and
  `Scripts/fork-dev-install.sh` (build, sign, install without launching).

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
  **(user)** `make use-dev` to restart Dev.
- **Back to the Homebrew release:** **(user)** `make -C ~/src/OmniWM use-release`.
- **Tests:** `. ~/.swiftly/env.sh && swift test --arch arm64 --disable-sandbox`.
- **Settings:** Dev reads `~/.config/omniwm-dev/settings.toml`, not
  `~/.config/omniwm/`. It uses a newer schema (v5) and migrated its copy on
  first launch (backup: `settings.toml.pre-v5`). OmniWM reloads it live.
  `~/.config/omniwm/CHANGES.md` in the dotfiles repo logs every settings change.
- **Pull upstream:** `git fetch upstream && git rebase upstream/main` on
  `main`, then `git push --force-with-lease` (add the remote once: `git remote add upstream https://github.com/OmniNull/OmniWM.git`). If upstream changes `QuakeTerminalController`'s interface,
  update `QuakeTerminalDisabled.swift` to match.
