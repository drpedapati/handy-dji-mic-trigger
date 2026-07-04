# Blog Raw Material: Handy DJI Mic Trigger

## One-Line Summary

Handy DJI Mic Trigger turns the volume-up button on a DJI Mic receiver into a
dedicated push-to-talk dictation button for Handy on macOS.

## Project Link

- GitHub: https://github.com/drpedapati/handy-dji-mic-trigger
- Handy: https://handy.computer/

## Working Title Ideas

- Turning a DJI Mic Receiver Into a Dictation Button for macOS
- A Tiny macOS Utility for Wireless Push-to-Talk Dictation
- Making Handy Dictation Feel Like a Hardware Button
- Repurposing the DJI Mic Volume Button for Local Speech-to-Text

## Audience

People who:

- use Handy or another local dictation workflow on macOS
- own a DJI Mic receiver
- want a physical push-to-talk button
- prefer local speech-to-text over cloud dictation
- like small hardware/software workflow hacks

## The Problem

Handy is a local speech-to-text app for macOS. It can be triggered with a
keyboard shortcut, but keyboard shortcuts are not always ergonomic when the user
is walking around, recording, presenting, or trying to keep their hands off the
keyboard.

The DJI Mic receiver has a convenient hardware button. Unfortunately, macOS
sees the receiver's button as a consumer-control media key, specifically a
volume-up event. Pressing it changes volume; it does not trigger Handy.

The goal was to make that receiver button behave like a dedicated dictation
button without breaking normal keyboard volume keys.

## The User Experience

After installation:

1. The user plugs the DJI Mic receiver into the Mac over USB.
2. Handy is configured to use `fn+F18` as the Transcribe shortcut.
3. The user grants macOS Accessibility and Input Monitoring permissions to
   `Handy DJI Mic Trigger`.
4. Pressing the DJI Mic receiver volume-up button starts or stops Handy
   transcription.
5. Normal keyboard volume buttons remain normal.

## Why This Is Useful

- It creates a physical push-to-talk button for dictation.
- It lets a wireless microphone become both the input device and trigger.
- It avoids awkward global keyboard shortcuts.
- It makes local speech-to-text feel more like a hardware recorder.
- It is small, inspectable, and open source.

## What The Utility Does

The utility installs a background macOS helper that:

- watches for HID input from the DJI Mic receiver
- confirms the source device by vendor ID and product ID
- intercepts the matching media-key event
- suppresses the original volume-up event
- posts `fn+F18` as a synthetic keyboard shortcut
- configures Handy to listen for `fn+F18`
- runs at login using a LaunchAgent

## Device Details

Default DJI Mic receiver identifiers:

- Vendor ID: `0x2ca3`
- Product ID: `0x4008`
- HID usage page: `0x0c` consumer control
- HID usage: `0xe9` volume increment
- macOS media event data values observed: `2560` and `2816`
- Shortcut emitted to Handy: `fn+F18`
- F18 key code used by the helper: `79`

The installer supports custom IDs:

```bash
DJI_VENDOR_ID=0x2ca3 DJI_PRODUCT_ID=0x4008 ./install.sh
```

## How It Works Technically

The DJI Mic receiver exposes its button as a consumer-control volume button.
Handy expects a keyboard shortcut. The utility bridges those two worlds.

The Swift helper uses two macOS APIs:

- `IOHIDManager` watches the DJI receiver's HID events.
- `CGEventTap` sees the macOS media-key event stream.

The helper does not blindly translate every volume-up key. It only translates a
media-key event when it just saw the matching DJI HID event within a short time
window. This is what keeps normal keyboard volume keys from being remapped.

The helper then posts a synthetic `fn+F18` key event. Handy is configured to use
`fn+F18` for transcription.

## Why Not Just Use hidutil?

An earlier attempt used a `hidutil` mapping from volume-up to F18:

```text
0x000C00E9 -> 0x0007006D
```

That proved useful for exploration, but the final repo uses the app-bundled
helper because the successful setup needed to:

- detect the DJI receiver specifically
- suppress the original media-key event
- send `fn+F18` in the form Handy recognizes
- present a clear permission target in macOS System Settings

The final shape is:

```text
LaunchAgent
  -> ~/.local/bin/handy-dji-f18-remap.sh
    -> ~/Applications/Handy DJI Mic Trigger.app/Contents/MacOS/Handy DJI Mic Trigger
```

## Why There Is An App Bundle

macOS privacy permissions are granted to apps. A raw command-line binary can
show up in System Settings with an unclear lowercase name, which is confusing
and can create duplicate entries after rebuilds.

The helper is packaged as:

```text
~/Applications/Handy DJI Mic Trigger.app
```

That gives users a clean permission entry named:

```text
Handy DJI Mic Trigger
```

## Why Accessibility Permission Is Needed

The helper posts a synthetic `fn+F18` keyboard shortcut to Handy. macOS requires
Accessibility permission for apps that control or synthesize input events.

## Why Input Monitoring Permission Is Needed

The helper reads low-level input events from the DJI receiver and the macOS
media-key stream. macOS requires Input Monitoring permission for that.

This was an important setup discovery: Accessibility alone was not enough. The
helper failed with:

```text
failed to create CGEvent tap; grant Accessibility/Input Monitoring permission to this helper
```

Granting both Accessibility and Input Monitoring fixed the event tap.

## Why There Is A LaunchAgent

The utility should work after login without manually starting a terminal
process. The installer creates a per-user LaunchAgent:

```text
~/Library/LaunchAgents/com.handy-dji-mic-trigger.remap.plist
```

The LaunchAgent runs the wrapper script and restarts periodically if needed.

## Why There Is A Wrapper Script

The LaunchAgent starts:

```text
~/.local/bin/handy-dji-f18-remap.sh
```

The wrapper script sets environment variables such as `DJI_VENDOR_ID` and
`DJI_PRODUCT_ID`, then launches the app executable. This keeps device
configuration simple and makes the LaunchAgent plist cleaner.

## Install Flow

Basic install:

```bash
git clone https://github.com/drpedapati/handy-dji-mic-trigger.git
cd handy-dji-mic-trigger
./install.sh
```

Then grant both permissions:

```text
System Settings > Privacy & Security > Accessibility
System Settings > Privacy & Security > Input Monitoring
```

Enable:

```text
Handy DJI Mic Trigger
```

If adding manually, choose:

```text
~/Applications/Handy DJI Mic Trigger.app
```

Restart the helper after granting permissions:

```bash
launchctl kickstart -k "gui/$(id -u)/com.handy-dji-mic-trigger.remap"
```

## What The Installer Changes

The installer:

1. builds the Swift helper app in `~/Applications`
2. writes a wrapper script to `~/.local/bin`
3. writes a LaunchAgent to `~/Library/LaunchAgents`
4. starts the LaunchAgent
5. backs up Handy settings, if present
6. sets Handy's Transcribe shortcut to `fn+f18`
7. sets Handy's microphone to `Wireless Microphone RX`, if Handy settings exist

The installer does not copy recordings, history databases, API keys, or
personal vocabulary.

## Troubleshooting Notes

Check the LaunchAgent:

```bash
launchctl print "gui/$(id -u)/com.handy-dji-mic-trigger.remap"
```

Check helper logs:

```bash
tail -f /tmp/com.handy-dji-mic-trigger.remap.err
```

Common failure:

```text
failed to create CGEvent tap
```

Likely fix:

- enable `Handy DJI Mic Trigger` in Accessibility
- enable `Handy DJI Mic Trigger` in Input Monitoring
- restart the LaunchAgent

If duplicate permission entries appear, remove stale entries and keep the app
bundle entry named `Handy DJI Mic Trigger`, not a lowercase raw binary entry.

## Uninstall

```bash
./uninstall.sh
```

This removes:

- LaunchAgent
- wrapper script
- helper app bundle

It does not remove Handy or Handy settings backups.

## Good Blog Angles

### Workflow Angle

The story is about making dictation feel physical. Instead of thinking about a
keyboard shortcut, the user gets a wireless button that starts and stops local
speech-to-text.

### Technical Angle

The interesting bit is safely translating a media key into a keyboard shortcut
only when it came from a specific HID device.

### macOS Systems Angle

The post can explain why Accessibility and Input Monitoring are separate, why a
background helper needs an app bundle, and how LaunchAgents fit into a polished
personal automation tool.

### Open Source Angle

This is a small, focused repo with a clear install script, a Swift helper, MIT
license, and public documentation.

## Possible Blog Outline

1. I wanted a physical dictation button.
2. The DJI Mic receiver already had the perfect button.
3. macOS saw it as volume-up, not a dictation trigger.
4. First attempts showed the event path: HID consumer control and media key.
5. The final solution pairs `IOHIDManager` with `CGEventTap`.
6. The helper checks that the event came from the DJI receiver before acting.
7. It sends `fn+F18`, and Handy listens for that shortcut.
8. Packaging matters: macOS permissions work best with a small app bundle.
9. The install script sets up the app, LaunchAgent, permissions instructions,
   and Handy shortcut.
10. Result: a DJI Mic receiver becomes a wireless push-to-talk dictation
    trigger.

## Phrases The Writer Can Reuse

- "A tiny bridge between a hardware media key and a software dictation
  shortcut."
- "The receiver button still looks like volume-up to macOS, but the helper
  recognizes when that event came from the DJI device."
- "The app does not remap the whole keyboard. It waits for a DJI HID event, then
  translates the corresponding media-key event."
- "The useful part was not just detecting the button. It was making the setup
  survive reboot and survive macOS privacy rules."
- "A good hardware shortcut should disappear into the workflow."

## Suggested Tweet

```text
I made a tiny macOS utility that turns the DJI Mic receiver's volume-up button into a physical dictation trigger for Handy.

It watches the DJI receiver's HID event, sends fn+F18 to Handy, and persists across reboot with a LaunchAgent.

Useful if you want a dedicated wireless push-to-talk button for local speech-to-text.

https://github.com/drpedapati/handy-dji-mic-trigger
```

## Important Accuracy Notes

- Do not describe this as only a `hidutil` remap. The final implementation is a
  Swift app-bundled helper using `IOHIDManager` and `CGEventTap`.
- Mention both Accessibility and Input Monitoring. Both were required in
  practice.
- The normal keyboard volume keys are intended to remain normal because the
  helper requires a recent DJI HID event before translating.
- The shortcut sent to Handy is `fn+F18`, not plain F18.
- The tool is designed for macOS.

