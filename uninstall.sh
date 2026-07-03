#!/usr/bin/env bash
set -euo pipefail

LABEL="com.handy-dji-mic-trigger.remap"
SCRIPT_PATH="$HOME/.local/bin/handy-dji-f18-remap.sh"
HELPER_PATH="$HOME/.local/bin/handy-dji-mic-trigger"
APP_DIR="$HOME/Applications/Handy DJI Mic Trigger.app"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT" >/dev/null 2>&1 || true
rm -f "$LAUNCH_AGENT" "$SCRIPT_PATH" "$HELPER_PATH"
rm -rf "$APP_DIR"

echo "Uninstalled Handy DJI Mic Trigger."
echo "Handy settings and settings backups were left untouched."
