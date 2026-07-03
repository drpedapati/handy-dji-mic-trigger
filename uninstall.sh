#!/usr/bin/env bash
set -euo pipefail

LABEL="com.handy-dji-mic-trigger.remap"
SCRIPT_PATH="$HOME/.local/bin/handy-dji-f18-remap.sh"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT" >/dev/null 2>&1 || true
rm -f "$LAUNCH_AGENT" "$SCRIPT_PATH"

echo "Uninstalled Handy DJI Mic Trigger."
echo "Restart or reconnect the DJI Mic receiver if macOS keeps the old in-memory mapping."

