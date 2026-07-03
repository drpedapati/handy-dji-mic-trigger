I made a tiny macOS utility that turns the DJI Mic receiver's volume-up button into a physical dictation trigger for Handy.

It watches the DJI receiver's HID event, sends fn+F18 to Handy, and persists across reboot with a LaunchAgent.

Useful if you want a dedicated wireless push-to-talk button for local speech-to-text.

https://github.com/drpedapati/handy-dji-mic-trigger
