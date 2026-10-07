# Nearby Connect

A Flutter app that connects nearby devices over Google's Nearby
Connections API — no internet, no accounts, just a local radio link.
Both devices see the same app: one hosts, the other discovers and
joins, and the connection stays alive while you move between features.

## Features

- **Nearby Chat** — text messaging with local persistence (Hive) and
  system notifications when the chat is not on screen.
- **Walkie Talkie** — push-to-talk voice between the two devices.
- **Tic-Tac-Toe** — classic 3×3 over the shared link.
- **Ludo** — two-player Ludo on a 15×15 board (see
  `lib/games/ludo/`): tap-to-move with landing-spot hints, tumbling
  dice, and self-healing state sync if a peer leaves and rejoins.

## Design system

The visual language lives in `DESIGN.md` (OpenDesign 9-section
schema) with a Dart mirror in `lib/design_tokens.dart` — three brand
colors, a 4px spacing grid, and shared component builders. All
screens render against those tokens.

## Getting Started

This is a standard Flutter project:

```sh
flutter pub get
flutter run          # on a connected device
flutter test         # engine + sync tests
flutter analyze
```

Nearby Connections needs real hardware (two Android devices with
location services enabled) — the link does not work on emulators.

For Flutter documentation, see
[docs.flutter.dev](https://docs.flutter.dev/).
