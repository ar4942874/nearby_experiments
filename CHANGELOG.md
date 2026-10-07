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

## [Unreleased] — 2026-10-07

### Changed
- **Ludo redesign** — game code moved to `lib/games/ludo/` (from `lib/ludo/`)
  - Board now sits in a white card (radius 24, hairline border, soft
    shadow, 12px inner pad); track/home-column cells are rounder; unused
    bases tinted `background` so they read as out-of-play
  - Movable pieces pulse (1.2s attention cue) and each shows a soft
    landing-spot ring — tapping the landing spot moves the piece too
  - Dice card: tumbles 400ms before settling (haptic tick), shows the
    last roll dimmed while the next roll is pending
  - Status bar: two player plates (color dot, name, 4 progress pips)
    that light up on the active player's turn
  - Captures, pieces home and three-six forfeits called out on the
    status line with matching haptics
  - "New game" moved to the app bar; winner overlay animates in
  - Player colors tokenized (`AppTokens.player0/player1` + tints)
- `lib/design_tokens.dart` — game tokens: `player0` / `player1` colors
  and tints, `radiusBoard`, `motionSlow`, `motionPulse`
- `lib/feature_selection_screen.dart` — import path only
- `test/ludo_state_test.dart` — import paths only

### Docs
- `DESIGN.md` — player color aliases, `GameBoard` / `PlayerPlate`
  components, motion amendments for game feedback
- `README.md` — real project description + feature list
- `WORK_LOG.md` — session entry for the redesign
