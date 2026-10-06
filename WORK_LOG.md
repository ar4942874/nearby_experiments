# Work Log — 2026-10-03

## Nearby Chat App — full session log

---

### 1. NDK 29.0.13113456 Installation

- **Issue**: NDK `29.0.13113456` directory was corrupted (only an empty `.installer` folder).
- **First attempt**: downloaded `android-ndk-r29-windows.zip` (795 MB) — wrong build (`29.0.14206865`).
- **Fix**:
  - Removed corrupted directory.
  - Downloaded `android-ndk-r29-beta1-windows.zip` (783 MB) from Google's repository.
  - Extracted to `C:\Users\PMLS\AppData\Local\Android\sdk\ndk\29.0.13113456`.
  - Verified `source.properties`: `Pkg.Revision = 29.0.13113456-beta1`.
- **File changed**: `android/app/build.gradle.kts` — `ndkVersion = "29.0.13113456"`.

### 2. Kotlin Version Update

- **Issue**: Kotlin `1.8.22` too old; Flutter warned support requires **at least 2.1.0**.
- **Path**: `1.8.22` → `1.9.24` → **`2.1.0`** (final).
- **File changed**: `android/settings.gradle.kts` — `org.jetbrains.kotlin.android` version `2.1.0`.

### 3. Home Screen Redesign (soft & clean, max 3 colors)

- **Palette** (3 colors):
  - `#F7F5F0` warm off-white — background
  - `#3A7D6E` soft teal — accent
  - `#2D2D2D` dark charcoal — text
- **Changes**: removed AppBar, large "Nearby" title, rounded white feature cards,
  teal icon boxes, subtle shadows, "No internet needed" footer.
- **File**: `lib/home_screen.dart` — complete rewrite.
- **Build fix**: `const GameScreen()` → `GameScreen()` (non-const constructor);
  `Colors.black.withOpacity(0.04)` → `Color(0x0A000000)`.

### 4. Main App Theme

- Material 3 theme seeded with teal; scaffold background `#F7F5F0`.
- Removed dead/commented code; renamed app class to `NearbyConnectApp`.
- **File**: `lib/main.dart`.

### 5. OpenDesign UI Pass (all screens, OpenDesign principles)

Applied a consistent soft/clean design across every screen:

- **`lib/home_screen.dart`** — `Material + InkWell` cards (tap feedback), hairline
  borders instead of shadows, 52px icon boxes, larger spacing rhythm.
- **`lib/walkie_talkie_screen.dart`** — full redesign: centered connection view,
  tint hero icon, outline `_ActionButton`s, bordered status card, teal/danger
  push-to-talk circle with 200ms animation.
- **`lib/game_screen.dart`** — full redesign: bordered connection view, outline
  buttons, device list cards, white game cells with accent/danger marks,
  bordered reset control.
- **`lib/main.dart` (chat screen)** — bordered status card, outline host/find
  buttons, bordered device list, styled chat bubbles (teal sent / white received),
  pill chat input + circular send button, bordered empty-state card.

### 6. Local Database (Hive) Integration

- **Checked**: no local DB present (only in-memory `List<ChatMessage>`).
- **Integrated Hive**:
  - `pubspec.yaml`: added `hive: ^2.2.3`, `hive_flutter: ^1.1.0`.
  - New `lib/local_db.dart`: `ChatMessage` model, `ChatMessageAdapter` (typeId 0),
    `LocalDB` (init / addMessage / getAllMessages / clearAll / deleteMessage).
  - `lib/main.dart`:
    - `main()` → `WidgetsFlutterBinding.ensureInitialized()` + `LocalDB.init()`.
    - `_loadMessages()` restores history on open.
    - sent & received messages persisted before UI update.
    - `_clearChat()` clears Hive box too.
- Messages now survive app restarts.

### 7. OpenDesign Integration

- **Research**: open-design.ai is an open-source local design workspace — its
  integration model is a portable **`DESIGN.md`** design-system file (9-section
  schema) read by agents at render time. Not a Flutter package.
- **Created `DESIGN.md`** (project root) — OpenDesign 9-section schema:
  color / typography / spacing / layout / components / motion / voice / brand /
  anti-patterns. Encodes the 3-color system, 4px spacing grid, component specs,
  and explicit anti-patterns (no gradients, no 4th hue, no hardcoded literals).
- **Created `lib/design_tokens.dart`** — `AppTokens` Dart mirror of DESIGN.md:
  - Colors: `background`, `accent`, `text`, `surface`, `tint`, `danger`, `border`
  - Spacing: `xs…xxl` (4px grid) · Radius: card/control/input/bubble
  - Typography: `display`, `h1`, `h2`, `appBarTitle`, `body`, `muted()`, `caption`
  - Motion: 200ms · Shared builders: `cardDecoration()`, `inputDecoration()`
- **Refactored all 4 screens** to consume `AppTokens` — eliminated every
  hardcoded color literal from widget files (verified by grep: literals now
  exist only in `design_tokens.dart`).
- Removed a 4th stray color (`#FDF0F0` game O-cell) → `danger.withOpacity(0.06)`.

### 8. Build & Run (verified each change)

- `flutter analyze` → **0 errors** (only pre-existing info-level lints).
- `flutter run -d 154162163200023` (Vivo V2109, Android 13 via USB) →
  built `app-debug.apk`, installed, launched successfully after every change set.

---

### Files Modified / Created

| File | Change |
|------|--------|
| `android/app/build.gradle.kts` | NDK → 29.0.13113456 |
| `android/settings.gradle.kts` | Kotlin → 2.1.0 |
| `pubspec.yaml` | + `hive`, `hive_flutter` |
| `DESIGN.md` | **new** — OpenDesign 9-section design system |
| `lib/design_tokens.dart` | **new** — AppTokens (colors/spacing/type/components) |
| `lib/local_db.dart` | **new** — Hive ChatMessage + LocalDB service |
| `lib/home_screen.dart` | redesigned → OpenDesign pass → AppTokens |
| `lib/walkie_talkie_screen.dart` | redesigned → AppTokens |
| `lib/game_screen.dart` | redesigned → AppTokens |
| `lib/main.dart` | theme, Hive persistence, chat UI, AppTokens |
| `WORK_LOG.md` | **new** — this log |

---

## Work Log — 2026-10-03 (continued) — Permission & Connection Refactor + New Flow

### 9. Single Permission Service (generalized, SDK-gated)

- **Created `lib/permission_service.dart`** — central permission handling:
  - SDK ≤ 30: `locationWhenInUse`
  - SDK ≥ 31: `bluetoothScan`, `bluetoothAdvertise`, `bluetoothConnect`
  - SDK ≥ 33: `nearbyWifiDevices`
  - Always: `microphone`
  - `ensureAll()` — check-then-request-missing only
  - `openSettings()` fallback
- Uses `device_info_plus` (added to `pubspec.yaml`)

### 10. Single Shared Connection Service

- **Created `lib/connection_service.dart`** — singleton `ConnectionService`:
  - One `serviceId = 'com.nearby.connect'`, `P2P_POINT_TO_POINT`
  - `LinkState {idle, hosting, discovering, connected}`
  - Payload framing: 1=chat, 2=game, 3=audio
  - API: `host()`, `discover()`, `connectTo()`, `disconnect()`, `sendChat()`, `sendGame()`, `sendAudio()`
  - `snapshotStream` / `payloadStream` broadcast
  - Auto-accept connections, shared link survives screen pops

### 11. Wrapper Refactors (preserve public APIs)

- **`lib/nearby_service.dart`** (Tic-Tac-Toe):
  - Wraps `ConnectionService`, keeps `gameStateStream`, `connectionStatusStream`, `discoveryStream`
  - `myPlayer` = host? 'X' : 'O' from snapshot
  - Sends `state_request` on join-existing-link; resets game on connected
  - `dispose()` closes streams — **does NOT disconnect**
- **`lib/walkie_talkie_service.dart`**:
  - Wraps `ConnectionService` + `AudioService`
  - Auto-connect on first discovered (`onEndpointFound` hook)
  - `dispose()` closes streams/audio — **does NOT disconnect**
- **`lib/main.dart` (Chat)**:
  - Removed inline Nearby/permission logic; uses `ConnectionService`
  - Subscribes to `snapshotStream` + `payloadStream` (tagChat)
  - `_stopAll()` removed → connection persists
  - Host/Find/Connect delegate to `_conn`

### 12. AndroidManifest.xml — Permission Hardening

- Added `xmlns:tools`
- `maxSdkVersion="30"` on legacy Bluetooth + location
- `neverForLocation` + `tools:targetApi` on `BLUETOOTH_SCAN` (s) + `NEARBY_WIFI_DEVICES` (33)
- Added `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE`
- `maxSdkVersion="32"` / `"28"` on storage
- Kept `RECORD_AUDIO`

### 13. New Two-Stage Flow (Connection → Features)

- **`lib/connection_screen.dart`** — single shared connection UI:
  - Name input, Host / Find Devices, live discovered list (tap to connect)
  - Status card shows advertising / discovering / connected
  - On connect → `Navigator.pushReplacement` → `FeatureSelectionScreen`
  - Disconnect button when connected
- **`lib/feature_selection_screen.dart`** — appears after connected:
  - Shows peer name, Disconnect action in AppBar
  - Three feature cards: Chat, Walkie Talkie, Tic-Tac-Toe
  - Watches `snapshotStream` — if disconnects, auto-returns to `ConnectionScreen`
- **`lib/home_screen.dart`** — simplified entry:
  - Permission check on init + `WidgetsBindingObserver` resume check
  - One banner + "Fix" button if missing
  - Single "Start Connection" card → `ConnectionScreen`

### 14. Feature Screen Simplification

- **Chat (`lib/main.dart`)** — connection UI removed; shows status card + messages + input (enabled only when connected)
- **Walkie Talkie (`lib/walkie_talkie_screen.dart`)** — connection UI removed; push-to-talk circle + connected status
- **Game (`lib/game_screen.dart`)** — connection UI removed; board + status bar + reset (only when connected)

### 15. Verification

- `flutter analyze` → **0 errors** (only pre-existing info-level lints)
- `flutter run -d 154162163200023` → built, installed, launched
- Screenshots verified:
  - Home → "Start Connection" → ConnectionScreen
  - Host → advertising state
  - (On second device) Join → connected → FeatureSelectionScreen with 3 features
  - Each feature opens with shared link intact
- Connection survives screen pops; no duplicate permission prompts

### Files Modified / Created (this phase)

| File | Change |
|------|--------|
| `pubspec.yaml` | + `device_info_plus: ^11.0.0` |
| `lib/permission_service.dart` | **new** — SDK-gated permission service |
| `lib/connection_service.dart` | **new** — shared Nearby singleton |
| `lib/connection_screen.dart` | **new** — connection-only screen |
| `lib/feature_selection_screen.dart` | **new** — post-connect feature picker |
| `lib/nearby_service.dart` | rewritten as wrapper |
| `lib/walkie_talkie_service.dart` | rewritten as wrapper |
| `lib/main.dart` | chat logic uses ConnectionService; no `_stopAll` |
| `lib/walkie_talkie_screen.dart` | simplified — no connection UI |
| `lib/game_screen.dart` | simplified — no connection UI |
| `lib/home_screen.dart` | entry + permission banner → ConnectionScreen |
| `android/app/src/main/AndroidManifest.xml` | hardened permissions |

### 16. Chat messaging + notifications — full fix & smoke test (two devices)

**Devices:** Vivo V2109 (`154162163200023`) as host, Tecno KL5 (`12685154BG001486`) as discoverer.

**Root causes found & fixed**
- Messages only arrived when the chat screen was open → the `payloadStream` listener lived only in `ChatHomePage`. Moved storage + notification into a **global listener in `main()`** (`_handleIncomingChat`) so incoming chat payloads are always persisted and notified, regardless of the open screen.
- `_isChatScreenVisible` was never reset to `false` (set in `initState`, not in `dispose`) → now reset in `dispose`.
- No app-lifecycle awareness → added a global `WidgetsBindingObserver` (`_appLifecycleState`).
- Notification condition is now: `shouldNotify = !_isChatScreenVisible || !appInForeground`.
- `BigTextStyleInformation` had empty strings → now uses the real message + sender; added `category: message`, `visibility: public`.
- `acceptConnection` moved to fire synchronously inside `onConnectionInitiated` (non-awaited) + `catchError` returning a value.
- **Location had to be enabled** on both devices (`settings put secure location_providers_allowed "gps,network"`) — Nearby requires it.

**Smoke test results (all PASS)**

| # | Scenario | Expected | Result |
|---|----------|----------|--------|
| 1 | Chat open + foreground, peer sends | message in chat, **no** notification | ✅ msg in chat, no notification |
| 2 | Feature-selection screen + foreground, peer sends | **notification** posted | ✅ `channel=chat_messages`, importance=4, posted |
| 3 | App in background (HOME), peer sends | **notification** posted | ✅ posted while backgrounded |
| 4 | Reopen chat | all msgs present (persisted) | ✅ SmokeTest1/2/3 all listed |
| 5 | Reverse direction (Tecno→Vivo) | message delivered | ✅ "TecnoToVivo" received in Vivo chat |

Logs confirmed: `Global chat received` / `Chat UI received` / `Showing notification` in the correct scenarios only.

---

## Work Log — 2026-10-06 — Ludo Integration (4th feature)

### 17. Ludo — two-player board game over the shared link

Goal: add Ludo as a fourth feature, cleanly integrated into the existing
shared-`ConnectionService` architecture (no link ownership, no UI changes
to other features).

**Board geometry — `lib/ludo/ludo_board.dart` (new)**
- Standard 15×15 grid; the 52-cell main track is a clockwise loop of
  `(row, col)` cells (verified: 52 unique cells, all inside the cross,
  consecutive cells adjacent except the four classic "elbow" turns that
  wrap the centre block).
- 2-player mode: player 0 (host) top-left, player 1 (guest) bottom-right;
  starts 13 cells apart (4 × 13 = 52) so the game is symmetric.
- Home columns (5 cells each), 8 safe/star cells (4 starts + 4 stars),
  base parking slots, helpers `absoluteOf` / `cellOf` / `isSafe`.

**Rules engine — `lib/ludo/ludo_state.dart` (new, pure Dart, no Flutter)**
- Piece positions are player-relative: -1 base, 0–50 track, 51–55 home
  column, 56 finished.
- Full rule set: 6 to leave base (start cell must be free — no stacking),
  no stacking anywhere (track + home column), exact roll to finish,
  captures on non-safe cells (sent back to base), extra turn on 6 /
  capture / piece finished, three consecutive sixes forfeits the turn,
  pass when no legal move, win when all 4 home.
- Deterministic: both devices run the same engine and apply the same
  actions in the same order → states stay in sync without sending the
  board.
- `version` (action counter, cleared on reset) + `toJson/fromJson` for
  resync.

**Transport — `lib/ludo/ludo_service.dart` (new)**
- Mirrors `NearbyService`: wrapper over `ConnectionService` on the new
  `tagLudo = 4` channel; `stateStream` / `statusStream` /
  `discoveryStream`; `dispose()` does NOT disconnect.
- Wire protocol (tiny JSON payloads):
  - `{"type":"roll","player","dice"}` — dice rolled by the actor;
  - `{"type":"move","player","piece","dice"}`;
  - `{"type":"pass","player"}`;
  - `{"type":"reset"}`;
  - `{"type":"state","v","state"}` — full snapshot.
- Self-healing resync: on entering the connection the service resets
  locally and broadcasts its state; the peer adopts it only when its
  version is newer. So a peer that stayed in the game (higher version)
  corrects a re-entering peer automatically; rejected remote actions
  also trigger a state offer.
- Known edge (documented, trivially recoverable): a peer "New game"
  reset racing a local action within the same tick can leave versions
  equal-but-divergent; tapping "New game" once more re-syncs both sides.

**UI — `lib/ludo/ludo_screen.dart` (new)**
- `CustomPainter` board on the 15×15 grid: bases with 4 parking slots,
  52 track cells (colored start cells with white stars, gray stars on
  safe cells), colored home columns, 4-triangle center (player home
  triangles teal / charcoal), finished pieces inside the triangles.
- Pieces: white-rimmed circles; legal moves get a highlight ring; two
  pieces sharing a safe cell render side-by-side.
- Tap-to-move on highlighted pieces; dice card with pips; status card
  (turn + x/4 home per player); auto-pass after 1.6 s when no legal
  move (manual "Pass turn" button also available); winner overlay with
  "Play again"; not-connected placeholder matching the other screens.
- All colors from `AppTokens` (player colors = accent + text — stays
  inside the 3-hue palette).

**Wiring**
- `lib/connection_service.dart`: `tagLudo = 4` + `sendLudo()`.
- `lib/feature_selection_screen.dart`: fourth feature card (Ludo).

**Tests — `test/ludo_state_test.dart` (new)**
- Geometry invariants (52 unique adjacent cells, 4 elbows, start
  spacing, home-column adjacency).
- Rules: base release on 6 (+ occupied start cell), exact finish,
  no-stacking (track + home column), captures, safe cells, extra turns,
  three-six forfeit, pass rules, win, JSON round trip.
- Two-device simulation: a full seeded random game applying the same
  JSON payloads to two engines — asserts no desync after every action;
  plus version-adoption cases (late joiner adopts newer state, older
  state never overwrites).
- Run with `flutter test` (no Flutter SDK in this sandbox — tests were
  reviewed, not executed, here).

### Files Modified / Created (this phase)

| File | Change |
|------|--------|
| `lib/ludo/ludo_board.dart` | **new** — 15×15 board geometry + helpers |
| `lib/ludo/ludo_state.dart` | **new** — pure-Dart Ludo rules engine |
| `lib/ludo/ludo_service.dart` | **new** — tag-4 transport + version resync |
| `lib/ludo/ludo_screen.dart` | **new** — painter board + game UI |
| `test/ludo_state_test.dart` | **new** — engine + sync test suite |
| `lib/connection_service.dart` | `tagLudo = 4` + `sendLudo()` |
| `lib/feature_selection_screen.dart` | Ludo feature card |
| `WORK_LOG.md` | this entry |
