# volumedeck
Hi deej team 👋

I’ve been building a companion app called VolumeDeck and I’d love to share it with you as something that complements the deej ecosystem. The goal is simple: make the “hardware slider → PC volume control” workflow smoother, more user-friendly, and easier to set up—especially for people who don’t want to manually deal with COM ports and repeated reconnect issues.

What VolumeDeck does

VolumeDeck is a desktop application that connects to an Arduino (or compatible board) and maps physical controls (sliders / knobs / buttons) to software actions such as:

Per-app volume control (like deej)

Master volume / system volume control

Mute / toggle actions

Optional macros or hotkey-style actions (if desired)

Key features

1) Automatic serial port detection & auto-connect

Scans available serial ports and identifies the correct device automatically (no “which COM port is it?” guesswork).

Auto-reconnects if the board is unplugged / replugged or if Windows resets the port.

2) Built-in port troubleshooting

Detects “port busy / access denied” states and provides clear guidance (e.g., another app holding the port).

Offers quick re-scan and reconnect workflows.

3) Multi-device / multi-profile support

Supports switching profiles (e.g., “Streaming”, “Editing”, “Gaming”) with different mappings.

Can store presets and quickly apply them without editing config files manually.

4) Smooth input processing

Dead-zone and smoothing to prevent jitter and micro-changes that cause constant volume flicker.

Optional acceleration/curves for more natural control (fast at extremes, precise around the center).

5) Buttons and advanced actions

Short press / long press actions (e.g., toggle active channel, save preset, play all, etc.).

Useful for workflows beyond just volume—still keeping it simple and predictable.

6) Friendly UI + logs

Clear UI that shows connection status, selected device, channel activity, and live input.

Debug logs only when meaningful actions happen (so it’s not noisy).

Why this might be interesting for deej

deej is already a great core project. VolumeDeck focuses on the “edge friction”: setup and reliability around serial ports, device reconnects, and usability for less technical users. If the idea is interesting, I’d be happy to:

share screenshots / demo video,

share the connection logic approach (auto-port detection + reconnect handling),

or discuss whether any of these UX improvements could be helpful upstream or as an optional companion.

If you’d like, I can open a discussion/issue with details, or share a repo link and a short demo.

Thanks for reading — and thanks for deej!

## Build (Windows)

Requirements:
- Flutter SDK (stable)
- Visual Studio 2022 with "Desktop development with C++"

Steps:
```bash
flutter pub get
flutter build windows --release
