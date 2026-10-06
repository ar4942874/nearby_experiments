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
