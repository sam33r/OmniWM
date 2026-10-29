#!/bin/bash
# Fork: quit OmniWM Dev cleanly and open it again, e.g. after
# Scripts/fork-dev-install.sh replaced the app. `make use-dev` doesn't do this:
# it only quits *other* OmniWM copies, so a running Dev keeps its old build.
# Needs the user's GUI session (Apple events and LaunchServices).

set -euo pipefail

APP="${OMNIWM_DEV_INSTALL_DIR:-$HOME/Applications}/${OMNIWM_DEV_APP_NAME:-OmniWM Dev}.app"
[ -d "$APP" ] || { echo "fork-dev-restart: $APP is missing; run Scripts/fork-dev-install.sh" >&2; exit 1; }

osascript -e 'tell application id "com.barut.OmniWM.dev" to quit' >/dev/null 2>&1 || true
for _ in $(seq 1 60); do
  pgrep -f "$APP/Contents/MacOS/OmniWM\$" >/dev/null || break
  sleep 0.25
done
open "$APP"
echo "fork-dev-restart: opened $APP"
