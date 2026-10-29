#!/bin/bash
# Fork: build, sign and install ~/Applications/OmniWM Dev.app WITHOUT quitting or
# launching anything. This is the part of `make run` an agent can do from its
# own shell; quitting the release app and opening Dev need the user's GUI
# session, so finish in your own terminal: `make use-dev` to switch from the
# release app, or Scripts/fork-dev-restart.sh if Dev is already running.
#
# Usage: Scripts/fork-dev-install.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="${OMNIWM_DEV_APP_NAME:-OmniWM Dev}"
INSTALL_DIR="${OMNIWM_DEV_INSTALL_DIR:-$HOME/Applications}"
export PATH="${SWIFTLY_HOME_DIR:-$HOME/.swiftly}/bin:$PATH"

cd "$ROOT_DIR"
OMNIWM_APP_NAME="$APP_NAME" \
OMNIWM_BUNDLE_ID="com.barut.OmniWM.dev" \
OMNIWM_SIGNING_IDENTITY="${OMNIWM_SIGNING_IDENTITY:-OmniWM Dev}" \
  ./Scripts/package-app.sh debug dev

# Same seeding as omniwm-dev.sh: Dev gets its own copy of the release settings
# the first time only.
config_base="${XDG_CONFIG_HOME:-$HOME/.config}"
if [ ! -e "$config_base/omniwm-dev" ]; then
  mkdir -p "$config_base/omniwm-dev"
  if [ -f "$config_base/omniwm/settings.toml" ]; then
    cp -L "$config_base/omniwm/settings.toml" "$config_base/omniwm-dev/settings.toml"
    echo "fork-dev-install: copied settings to $config_base/omniwm-dev/settings.toml"
  fi
fi

mkdir -p "$INSTALL_DIR"
rm -rf "${INSTALL_DIR:?}/$APP_NAME.app"
mv "dist/$APP_NAME.app" "$INSTALL_DIR/$APP_NAME.app"
echo "fork-dev-install: installed $INSTALL_DIR/$APP_NAME.app"
echo "Next, in your own terminal: make -C \"$ROOT_DIR\" use-dev (switch from the release app)"
echo "  or $ROOT_DIR/Scripts/fork-dev-restart.sh (if Dev is already running)"
