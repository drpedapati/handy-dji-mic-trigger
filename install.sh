#!/usr/bin/env bash
set -euo pipefail

LABEL="com.handy-dji-mic-trigger.remap"
VENDOR_ID="${DJI_VENDOR_ID:-0x2ca3}"
PRODUCT_ID="${DJI_PRODUCT_ID:-0x4008}"
MIC_NAME="${HANDY_MICROPHONE_NAME:-Wireless Microphone RX}"
HANDY_BUNDLE="/Applications/Handy.app"
HANDY_SETTINGS="$HOME/Library/Application Support/com.pais.handy/settings_store.json"
BIN_DIR="$HOME/.local/bin"
SCRIPT_PATH="$BIN_DIR/handy-dji-f18-remap.sh"
APP_DIR="$HOME/Applications/Handy DJI Mic Trigger.app"
APP_CONTENTS="$APP_DIR/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_EXECUTABLE="$APP_MACOS/Handy DJI Mic Trigger"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"

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

write_helper_app() {
  mkdir -p "$BIN_DIR"
  mkdir -p "$APP_MACOS"
  xcrun swiftc "$(dirname "$0")/src/HandyDjiMicTrigger.swift" -o "$APP_EXECUTABLE"
  chmod +x "$APP_EXECUTABLE"

  cat > "$APP_CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>Handy DJI Mic Trigger</string>
  <key>CFBundleExecutable</key>
  <string>Handy DJI Mic Trigger</string>
  <key>CFBundleIdentifier</key>
  <string>$LABEL</string>
  <key>CFBundleName</key>
  <string>Handy DJI Mic Trigger</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSBackgroundOnly</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Used to translate the DJI Mic receiver button into a Handy shortcut.</string>
  <key>NSInputMonitoringUsageDescription</key>
  <string>Used to detect the DJI Mic receiver button and translate it into fn+F18 for Handy.</string>
</dict>
</plist>
EOF
  plutil -lint "$APP_CONTENTS/Info.plist" >/dev/null
  codesign --force --sign - "$APP_DIR" >/dev/null 2>&1 || true

  cat > "$SCRIPT_PATH" <<EOF
#!/usr/bin/env bash
set -euo pipefail

export DJI_VENDOR_ID='$VENDOR_ID'
export DJI_PRODUCT_ID='$PRODUCT_ID'

exec '$APP_EXECUTABLE'
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
  need launchctl
  need plutil
  need /usr/bin/python3
  need xcrun

  install_handy_if_missing

  if system_profiler SPUSBDataType 2>/dev/null | grep -qi "Wireless Microphone"; then
    :
  else
    echo "Warning: no USB device named Wireless Microphone is visible."
    echo "The trigger will still be installed and will work when the receiver is connected."
  fi

  write_helper_app
  write_launch_agent
  load_launch_agent
  configure_handy_settings

  echo
  echo "Installed Handy DJI Mic Trigger."
  echo "Allow 'Handy DJI Mic Trigger' in System Settings > Privacy & Security > Accessibility."
  echo "Also allow 'Handy DJI Mic Trigger' in System Settings > Privacy & Security > Input Monitoring."
  echo "Then press the DJI Mic receiver volume-up button to send fn+F18 to Handy."
}

main "$@"
