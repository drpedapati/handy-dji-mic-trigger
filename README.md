# Handy DJI Mic Trigger

Use the volume-up button on a DJI Mic receiver as a push button for
[Handy](https://handy.computer/) dictation on macOS.

This installs a small background macOS helper that watches the DJI Mic
receiver's consumer volume-up event, emits `fn+F18`, and configures Handy to use
`fn+F18` for transcription.

## What This Is For

Handy is a local speech-to-text app for macOS. The DJI Mic receiver is a
convenient physical button, but macOS normally treats its button as a volume
key. This repo makes that button usable as a dedicated dictation trigger without
changing your main keyboard.

The helper is scoped to the DJI Mic receiver:

- Vendor ID: `0x2ca3`
- Product ID: `0x4008`
- HID usage: consumer control
- Source button: volume up
- Handy shortcut emitted: `fn+F18`

## How It Works

The DJI Mic receiver exposes its button to macOS as a consumer-control volume
button. Handy needs a keyboard shortcut, not a media-volume event. This utility
bridges that gap:

1. An `IOHIDManager` listener watches only the DJI receiver's HID device ID.
2. A `CGEventTap` sees the matching macOS media-key event.
3. The helper only translates the media event when it just saw the DJI HID
   event, so normal keyboard volume keys are left alone.
4. The helper suppresses the original media-key event and posts `fn+F18`.
5. Handy is configured to use `fn+F18` as its Transcribe shortcut.

The helper is packaged as a small `.app` because macOS privacy permissions are
granted to apps. The LaunchAgent starts a wrapper script, and the wrapper starts
the app's executable. This is the path that gives the background helper a stable
identity in System Settings.

## Requirements

- macOS
- Handy installed
- DJI Mic receiver connected over USB

If Handy is not installed, the installer can install it with Homebrew.

## Quick Install

```bash
git clone https://github.com/drpedapati/handy-dji-mic-trigger.git
cd handy-dji-mic-trigger
./install.sh
```

Then allow `Handy DJI Mic Trigger` in both macOS privacy panes:

```text
System Settings > Privacy & Security > Accessibility
System Settings > Privacy & Security > Input Monitoring
```

Use the app bundle at `~/Applications/Handy DJI Mic Trigger.app` if you need to
add it manually.

After granting permission, restart the LaunchAgent:

```bash
launchctl kickstart -k "gui/$(id -u)/com.handy-dji-mic-trigger.remap"
```

Press the DJI Mic receiver volume-up button. Handy should start or stop
transcription instead of changing the system volume.

## What The Installer Does

The installer:

1. Builds a small Swift helper app in
   `~/Applications/Handy DJI Mic Trigger.app`.
2. Installs a wrapper script at `~/.local/bin/handy-dji-f18-remap.sh`.
3. Installs and loads a per-user LaunchAgent:
   `~/Library/LaunchAgents/com.handy-dji-mic-trigger.remap.plist`.
4. Starts the helper in the background through the wrapper script.
5. Backs up Handy's settings file, if present.
6. Sets Handy's transcribe shortcut to `fn+f18`.
7. Sets Handy's selected microphone to `Wireless Microphone RX`, if Handy
   settings exist.

No recordings, history databases, API keys, or personal vocabulary are copied.

## Why These Pieces Exist

- The `.app` bundle exists so macOS can show a friendly, stable item named
  `Handy DJI Mic Trigger` in Privacy & Security.
- Accessibility is required because the helper posts the synthetic `fn+F18`
  shortcut to Handy.
- Input Monitoring is required because the helper reads low-level input events
  from the DJI receiver and the macOS media-key stream.
- The LaunchAgent exists so the trigger starts automatically after login.
- The wrapper script exists so environment variables such as `DJI_VENDOR_ID` and
  `DJI_PRODUCT_ID` can be passed to the app cleanly.
- Handy settings are updated so the generated `fn+F18` shortcut has something
  useful to trigger.

## Custom Device IDs

If your receiver reports different IDs, pass them as environment variables:

```bash
DJI_VENDOR_ID=0x2ca3 DJI_PRODUCT_ID=0x4008 ./install.sh
```

You can inspect devices with:

```bash
hidutil list | grep -i "Wireless Microphone"
```

If your receiver reports a different device name, the vendor and product IDs
are what matter.

## Uninstall

```bash
./uninstall.sh
```

This unloads and removes the LaunchAgent, wrapper script, and helper app
bundle. It does not uninstall Handy and does not delete Handy settings backups.

## Troubleshooting

Check the LaunchAgent:

```bash
launchctl print "gui/$(id -u)/com.handy-dji-mic-trigger.remap"
```

Check helper logs:

```bash
tail -f /tmp/com.handy-dji-mic-trigger.remap.err
```

If the log says `failed to create CGEvent tap`, macOS has not granted both
Accessibility and Input Monitoring permission to `Handy DJI Mic Trigger` yet.

If Handy does not respond, confirm these Handy settings:

- Transcribe shortcut: `fn+F18`
- Microphone: `Wireless Microphone RX`

Also confirm macOS permissions for both Handy and `Handy DJI Mic Trigger` in
System Settings. `Handy DJI Mic Trigger` needs both Accessibility and Input
Monitoring.
