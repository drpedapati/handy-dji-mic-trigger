# Handy DJI Mic Trigger

Use the volume-up button on a DJI Mic receiver as a push button for
[Handy](https://handy.computer/) dictation on macOS.

This installs a small macOS `hidutil` mapping that converts the DJI Mic
receiver's consumer volume-up event into `F18`, then configures Handy to use
`fn+F18` for transcription.

## What This Is For

Handy is a local speech-to-text app for macOS. The DJI Mic receiver is a
convenient physical button, but macOS normally treats its button as a media
volume key. This repo makes that button usable as a dedicated dictation trigger
without changing your main keyboard.

The default mapping is scoped to the DJI Mic receiver:

- Vendor ID: `0x2ca3`
- Product ID: `0x4008`
- HID usage: consumer control
- Source key: volume up
- Destination key: `F18`

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

Then open Handy once and allow any macOS permissions it requests, such as
microphone, accessibility, or input monitoring.

## What The Installer Does

The installer:

1. Detects the DJI Mic receiver in `hidutil list`.
2. Installs `~/.local/bin/handy-dji-f18-remap.sh`.
3. Installs and loads a per-user LaunchAgent:
   `~/Library/LaunchAgents/com.handy-dji-mic-trigger.remap.plist`.
4. Applies the mapping immediately.
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

## Uninstall

```bash
./uninstall.sh
```

This unloads and removes the LaunchAgent and remap script. It does not uninstall
Handy and does not delete Handy settings backups.

## Troubleshooting

Check whether the mapping is active:

```bash
hidutil property \
  --matching '{"VendorID":0x2ca3,"ProductID":0x4008,"PrimaryUsagePage":12,"PrimaryUsage":1}' \
  --get UserKeyMapping
```

Check the LaunchAgent:

```bash
launchctl print "gui/$(id -u)/com.handy-dji-mic-trigger.remap"
```

If Handy does not respond, confirm these Handy settings:

- Transcribe shortcut: `fn+F18`
- Microphone: `Wireless Microphone RX`

Also confirm macOS permissions for Handy in System Settings.

