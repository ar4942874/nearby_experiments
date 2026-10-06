# Changelog

## [Unreleased]

### Added
- **Home Screen** (`lib/home_screen.dart`)
  - New `HomeScreen` widget serving as the app's main entry point
  - Three feature cards: Nearby Chat, Walkie Talkie, Tic-Tac-Toe
  - Each card has icon, title, subtitle, and navigation to respective screen
  - Clean Material Design UI with `Card` + `InkWell` for tap handling
  - Responsive layout with `Padding`, `Column`, and `Row` widgets

### Changed
- **`lib/main.dart`**
  - Added import for `home_screen.dart`
  - Changed `TicTacToeApp` home widget from `GameScreen()` to `HomeScreen()`
  - App now launches into a mode-selection screen instead of directly into Tic-Tac-Toe

### Navigation Flow (After Change)
```
App Launch → HomeScreen (mode selection)
               ├── Nearby Chat → ChatHomePage
               ├── Walkie Talkie → WalkieTalkieScreen
               └── Tic-Tac-Toe → GameScreen
```

### Changed (2026-10-03)
- **`android/app/build.gradle.kts`**
  - Changed NDK version to `28.2.13676358` (pre-installed; `29.0.13113456` was corrupted and re-download too slow)

### Unchanged Files
- `lib/game_screen.dart` — Tic-Tac-Toe game UI
- `lib/game_state.dart` — Tic-Tac-Toe game logic
- `lib/nearby_service.dart` — Nearby Connections service for Tic-Tac-Toe
- `lib/walkie_talkie_screen.dart` — Walkie-Talkie UI
- `lib/walkie_talkie_service.dart` — Walkie-Talkie Nearby Connections service
- `lib/audio_service.dart` — Audio recording/playback service
- `lib/haptic_feedback.dart` — Haptic feedback test widget

## [Unreleased] — 2026-10-06

### Added
- **Ludo** (`lib/ludo/`) — two-player Ludo over the shared Nearby link
  - `ludo_board.dart` — standard 15×15 board geometry (52-cell clockwise
    track, home columns, 8 safe cells, base slots)
  - `ludo_state.dart` — pure-Dart rules engine (base release on 6,
    no-stacking, exact finish, captures on non-safe cells, extra turn on
    6/capture/finish, three-six forfeit, pass, win)
  - `ludo_service.dart` — transport on new `tagLudo = 4`; tiny JSON
    roll/move/pass/reset payloads + version-gated state adoption for
    self-healing resync when a peer (re)joins
  - `ludo_screen.dart` — `CustomPainter` board, tap-to-move, dice card,
    status card, auto/manual pass, winner overlay; all `AppTokens`
- `lib/connection_service.dart` — `tagLudo = 4` + `sendLudo()`
- `lib/feature_selection_screen.dart` — Ludo feature card (4th feature)
- `test/ludo_state_test.dart` — engine, geometry and two-device sync
  tests (run with `flutter test`)
