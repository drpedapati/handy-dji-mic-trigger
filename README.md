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

Then allow the helper in:

```text
System Settings > Privacy & Security > Accessibility
```

If macOS also lists `Handy DJI Mic Trigger` under Input Monitoring, allow it
there too.

After granting permission, restart the LaunchAgent:

```bash
launchctl kickstart -k "gui/$(id -u)/com.handy-dji-mic-trigger.remap"
```

## What The Installer Does

The installer:

1. Builds a small Swift helper app in
   `~/Applications/Handy DJI Mic Trigger.app`.
2. Installs `~/.local/bin/handy-dji-f18-remap.sh`.
3. Installs and loads a per-user LaunchAgent:
   `~/Library/LaunchAgents/com.handy-dji-mic-trigger.remap.plist`.
4. Starts the helper in the background.
5. Backs up Handy's settings file, if present.
6. Sets Handy's transcribe shortcut to `fn+f18`.
7. Sets Handy's selected microphone to `Wireless Microphone RX`, if Handy
   settings exist.

No recordings, history databases, API keys, or personal vocabulary are copied.

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

This unloads and removes the LaunchAgent, remap script, helper binary, and app
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

If the log says `failed to create CGEvent tap`, macOS has not granted
Accessibility or Input Monitoring permission to `Handy DJI Mic Trigger` yet.

If Handy does not respond, confirm these Handy settings:

- Transcribe shortcut: `fn+F18`
- Microphone: `Wireless Microphone RX`

Also confirm macOS permissions for both Handy and `Handy DJI Mic Trigger` in
System Settings.
