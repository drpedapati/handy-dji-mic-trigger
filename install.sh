#!/usr/bin/env bash
set -euo pipefail

LABEL="com.handy-dji-mic-trigger.remap"
VENDOR_ID="${DJI_VENDOR_ID:-0x2ca3}"
PRODUCT_ID="${DJI_PRODUCT_ID:-0x4008}"
PRIMARY_USAGE_PAGE="${DJI_PRIMARY_USAGE_PAGE:-12}"
PRIMARY_USAGE="${DJI_PRIMARY_USAGE:-1}"
SRC_KEY="${DJI_SOURCE_KEY:-0x000C00E9}"
DST_KEY="${DJI_DEST_KEY:-0x0007006D}"
MIC_NAME="${HANDY_MICROPHONE_NAME:-Wireless Microphone RX}"
HANDY_BUNDLE="/Applications/Handy.app"
HANDY_SETTINGS="$HOME/Library/Application Support/com.pais.handy/settings_store.json"
BIN_DIR="$HOME/.local/bin"
SCRIPT_PATH="$BIN_DIR/handy-dji-f18-remap.sh"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
MATCHING="{\"VendorID\":$VENDOR_ID,\"ProductID\":$PRODUCT_ID,\"PrimaryUsagePage\":$PRIMARY_USAGE_PAGE,\"PrimaryUsage\":$PRIMARY_USAGE}"
MAPPING="{\"UserKeyMapping\":[{\"HIDKeyboardModifierMappingSrc\":$SRC_KEY,\"HIDKeyboardModifierMappingDst\":$DST_KEY}]}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

install_handy_if_missing() {
  if [[ -d "$HANDY_BUNDLE" ]]; then
    return
  fi

  if command -v brew >/dev/null 2>&1; then
    echo "Handy is not installed. Installing with Homebrew..."
    brew install --cask handy
  else
    echo "Handy is not installed. Install Handy from https://handy.computer/ and rerun this script." >&2
    exit 1
  fi
}

configure_handy_settings() {
  if [[ ! -f "$HANDY_SETTINGS" ]]; then
    echo "Handy settings not found yet. Open Handy once, then rerun this installer to configure Handy automatically."
    return
  fi

  local backup="$HANDY_SETTINGS.backup.$(date +%Y%m%d-%H%M%S)"
  cp "$HANDY_SETTINGS" "$backup"

  /usr/bin/python3 - "$HANDY_SETTINGS" "$MIC_NAME" <<'PY'
import json
import sys
from pathlib import Path

settings_path = Path(sys.argv[1])
mic_name = sys.argv[2]

data = json.loads(settings_path.read_text())
settings = data.setdefault("settings", {})
bindings = settings.setdefault("bindings", {})
bindings["transcribe"] = {
    "current_binding": "fn+f18",
    "default_binding": "option+space",
    "description": "Converts your speech into text.",
    "id": "transcribe",
    "name": "Transcribe",
}

settings["keyboard_implementation"] = "handy_keys"
settings["selected_microphone"] = mic_name
settings["paste_method"] = settings.get("paste_method", "ctrl_v")
settings["paste_delay_ms"] = settings.get("paste_delay_ms", 60)
settings["autostart_enabled"] = True

settings_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
PY

  echo "Backed up Handy settings to: $backup"
  echo "Configured Handy transcribe shortcut: fn+F18"
  echo "Configured Handy microphone: $MIC_NAME"
}

write_remap_script() {
  mkdir -p "$BIN_DIR"
  cat > "$SCRIPT_PATH" <<EOF
#!/usr/bin/env bash
set -euo pipefail

/usr/bin/hidutil property \\
  --matching '$MATCHING' \\
  --set '$MAPPING'
EOF
  chmod +x "$SCRIPT_PATH"
}

write_launch_agent() {
  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$LAUNCH_AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$SCRIPT_PATH</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StartInterval</key>
  <integer>30</integer>
  <key>StandardOutPath</key>
  <string>/tmp/$LABEL.out</string>
  <key>StandardErrorPath</key>
  <string>/tmp/$LABEL.err</string>
</dict>
</plist>
EOF
  plutil -lint "$LAUNCH_AGENT" >/dev/null
}

load_launch_agent() {
  launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT"
  launchctl kickstart -k "gui/$(id -u)/$LABEL"
}

main() {
  need hidutil
  need launchctl
  need plutil
  need /usr/bin/python3

  install_handy_if_missing

  if ! hidutil list | grep -qi "Wireless Microphone"; then
    echo "Warning: no device named Wireless Microphone is visible in hidutil list."
    echo "The mapping will still be installed and will apply when the matching device is connected."
  fi

  write_remap_script
  write_launch_agent
  load_launch_agent
  configure_handy_settings

  echo
  echo "Installed Handy DJI Mic Trigger."
  echo "Press the DJI Mic receiver volume-up button to send F18 to Handy."
}

main "$@"

