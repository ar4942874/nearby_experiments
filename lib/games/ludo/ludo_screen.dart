import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nearby_chat_app/design_tokens.dart';
import 'package:nearby_chat_app/games/ludo/ludo_board.dart';
import 'package:nearby_chat_app/games/ludo/ludo_service.dart';
import 'package:nearby_chat_app/games/ludo/ludo_state.dart';

/// Two-player Ludo over the shared Nearby link.
///
/// The board is rendered with a [CustomPainter] on the standard 15×15
/// grid; only tiny dice/move payloads cross the link (see [LudoService]).
///
/// Redesign (2026-10-07), now living under `lib/games/ludo/`:
///
/// - the board sits in a white card (radius `radiusBoard`, hairline
///   border, soft shadow) instead of floating on the scaffold;
/// - movable pieces pulse and each one marks its landing spot with a
///   soft ring — tapping either the piece or the spot moves it;
/// - the dice tumbles briefly before settling (with a haptic tick) and
///   shows the last roll dimmed while the next roll is pending;
/// - the status bar is two player plates (color dot, name, four
///   progress pips) that light up on the active player's turn;
/// - captures, finishes and three-six forfeits are called out on the
///   status line with matching haptics;
/// - "New game" moved into the app bar to give the board more room.
class LudoScreen extends StatefulWidget {
  const LudoScreen({super.key});

  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends State<LudoScreen>
    with SingleTickerProviderStateMixin {
  final LudoService _service = LudoService();
  final _rng = math.Random();

  LudoState _state = LudoState();
  int? _myPlayer;
  Timer? _autoPassTimer;
  Timer? _eventTimer;

  /// Transient callout ("You captured a piece"), shown on the status
  /// line for a beat, then cleared.
  String? _event;

  /// Most recent dice value seen — shown dimmed while a roll is pending.
  int _lastDice = 0;

  /// Pixel size of one board cell (set while the board lays out).
  double _cellSize = 0;

  /// Looping animation that makes movable pieces pulse (the sanctioned
  /// in-game attention cue, see DESIGN.md §6).
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppTokens.motionPulse,
  );

  StreamSubscription<LudoState>? _stateSub;
  StreamSubscription<String>? _statusSub;

  @override
  void initState() {
    super.initState();
    _stateSub = _service.stateStream.listen((state) {
      if (!mounted) return;
      _detectEvents(_state, state);
      if (state.dice != null) _lastDice = state.dice!;
      setState(() => _state = state);
      _updatePulse();
    });
    _statusSub = _service.statusStream.listen((_) {
      if (!mounted) return;
      setState(() => _myPlayer = _service.myPlayer);
      _updatePulse();
    });
  }

  bool get _connected => _myPlayer != null;
  bool get _myTurn => _connected && _state.canAct(_myPlayer!);
  List<int> get _movable =>
      _connected ? _state.movablePieces(_myPlayer!) : const <int>[];

  // ------------------------------------------------------------- actions

  void _rollDice() {
    if (!_myTurn || !_state.awaitingRoll) return;
    HapticFeedback.lightImpact();
    _service.rollDice(_rng.nextInt(6) + 1);
    _scheduleAutoPassIfNeeded();
  }

  void _movePiece(int piece) {
    HapticFeedback.selectionClick();
    _service.movePiece(piece);
  }

  void _scheduleAutoPassIfNeeded() {
    _autoPassTimer?.cancel();
    _autoPassTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      if (_myTurn && _state.awaitingMove && _movable.isEmpty) {
        _service.passTurn();
      }
    });
  }

  void _passTurn() {
    if (_myTurn && _state.awaitingMove && _movable.isEmpty) {
      _service.passTurn();
    }
  }

  void _onBoardTap(Offset local) {
    if (!_connected || !_state.awaitingMove || !_myTurn || _cellSize == 0) {
      return;
    }
    final col = (local.dx / _cellSize).floor();
    final row = (local.dy / _cellSize).floor();
    if (row < 0 || row >= LudoBoard.size || col < 0 || col >= LudoBoard.size) {
      return;
    }

    // 1) Direct tap on a movable piece — in its base slot or on the
    //    board.
    for (final piece in _movable) {
      final pos = _state.pieces[_myPlayer!][piece];
      if (pos == LudoState.posBase) {
        final slot = LudoBoard.baseSlots[_myPlayer!][piece];
        if (slot[0] == row && slot[1] == col) {
          _movePiece(piece);
          return;
        }
        continue;
      }
      final cell = LudoBoard.cellOf(_myPlayer!, pos);
      if (cell != null && cell[0] == row && cell[1] == col) {
        _movePiece(piece);
        return;
      }
    }

    // 2) Tap on a piece's landing spot (the soft ring the painter draws).
    final dice = _state.dice;
    if (dice == null) return;
    for (final piece in _movable) {
      final pos = _state.pieces[_myPlayer!][piece];
      final rel = pos == LudoState.posBase ? 0 : pos + dice;
      final cell = LudoBoard.cellOf(_myPlayer!, rel);
      if (cell != null && cell[0] == row && cell[1] == col) {
        _movePiece(piece);
        return;
      }
    }
  }

  // -------------------------------------------------------- event callouts

  /// Pieces of one player currently on the main track (captures only
  /// happen there, so a shrinking count means "was captured").
  int _onTrack(List<int> pieces) =>
      pieces.where((p) => p >= 0 && p <= LudoBoard.trackLast).length;

  void _detectEvents(LudoState before, LudoState after) {
    // Reset / new game (version dropped to zero).
    if (after.version == 0 && before.version > 0) {
      _showEvent('New game');
      HapticFeedback.lightImpact();
      return;
    }

    if (after.isGameOver && !before.isGameOver) {
      HapticFeedback.heavyImpact();
      return; // the winner overlay says the rest
    }

    // A move resolved and the mover kept the turn (extra turn) —
    // look for a capture or a finished piece.
    if (before.dice != null &&
        after.dice == null &&
        before.currentPlayer == after.currentPlayer) {
      final mover = before.currentPlayer;
      final iMoved = mover == _myPlayer;
      final captured =
          _onTrack(after.pieces[1 - mover]) < _onTrack(before.pieces[1 - mover]);
      final finished = after.homeCount(mover) > before.homeCount(mover);
      if (captured) {
        _showEvent(iMoved ? 'You captured a piece — roll again'
                          : 'Peer captured your piece');
        HapticFeedback.mediumImpact();
      } else if (finished) {
        _showEvent(iMoved ? 'Piece home — roll again'
                          : 'Peer brought a piece home');
        HapticFeedback.lightImpact();
      }
      return;
    }

    // Turn flipped with no pending dice → third six forfeited it.
    if (before.dice == null &&
        after.dice == null &&
        before.currentPlayer != after.currentPlayer) {
      _showEvent(before.currentPlayer == _myPlayer
          ? 'Three sixes — turn forfeited'
          : 'Peer forfeited on three sixes');
      HapticFeedback.lightImpact();
    }
  }

  void _showEvent(String text) {
    _event = text;
    _eventTimer?.cancel();
    _eventTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _event = null);
    });
  }

  void _updatePulse() {
    final needs =
        _connected && _myTurn && _state.awaitingMove && _movable.isNotEmpty;
    if (needs && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!needs && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.background,
      appBar: AppBar(
        backgroundColor: AppTokens.background,
        elevation: 0,
        title: Text('Ludo', style: AppTokens.appBarTitle),
        centerTitle: true,
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back_ios_rounded, color: AppTokens.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppTokens.text, size: 22),
            tooltip: 'New game',
            onPressed: _service.resetGame,
          ),
        ],
      ),
      body: _connected ? _buildGameView() : _buildNotConnectedView(),
    );
  }

  Widget _buildNotConnectedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTokens.tint,
                borderRadius: BorderRadius.circular(28),
              ),
              child:
                  Icon(Icons.casino_rounded, color: AppTokens.accent, size: 48),
            ),
            const SizedBox(height: AppTokens.md),
            Text('Ludo', style: AppTokens.h1),
            const SizedBox(height: AppTokens.sm),
            Text(
              'Not connected. Go back to establish connection.',
              style: AppTokens.muted(15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.lg),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to Connection'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTokens.accent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameView() {
    return Padding(
      padding: const EdgeInsets.all(AppTokens.md),
      child: Column(
        children: [
          _buildStatusBar(),
          const SizedBox(height: AppTokens.md),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const pad = AppTokens.sm + 4.0; // inner padding of board card
                final side = math.max(
                  0.0,
                  math.min(constraints.maxWidth, constraints.maxHeight) -
                      pad * 2,
                );
                _cellSize = side / LudoBoard.size;
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(pad),
                    decoration: BoxDecoration(
                      color: AppTokens.surface,
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusBoard),
                      border: AppTokens.cardBorder,
                      boxShadow: AppTokens.cardShadow,
                    ),
                    child: SizedBox(
                      width: side,
                      height: side,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (d) => _onBoardTap(d.localPosition),
                            child: AnimatedBuilder(
                              animation: _pulse,
                              builder: (context, _) => CustomPaint(
                                painter: _LudoBoardPainter(
                                  _state,
                                  _myPlayer,
                                  _movable.toSet(),
                                  _pulse.value,
                                ),
                              ),
                            ),
                          ),
                          if (_state.isGameOver) _buildWinnerOverlay(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppTokens.md),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    String title;
    String sub;
    if (_state.isGameOver) {
      title = _state.winner == _myPlayer ? 'You won' : 'Peer won';
      sub = 'Tap Play again to start a new game';
    } else if (_state.awaitingRoll) {
      if (_myTurn) {
        title = 'Your turn';
        sub = 'Roll the dice';
      } else {
        title = "Peer's turn";
        sub = 'Waiting for them to roll…';
      }
    } else if (_state.awaitingMove) {
      if (_myTurn) {
        title = 'Your turn';
        sub = _movable.isEmpty
            ? 'No moves — passing…'
            : 'Tap a pulsing piece or its landing spot';
      } else {
        title = "Peer's turn";
        sub = 'Waiting for them to move…';
      }
    } else {
      title = 'Ludo';
      sub = 'Connected';
    }
    if (_event != null && !_state.isGameOver) sub = _event!;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppTokens.sm + 4,
        horizontal: AppTokens.md,
      ),
      decoration: AppTokens.cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _playerPlate(0)),
              const SizedBox(width: AppTokens.sm),
              Expanded(child: _playerPlate(1)),
            ],
          ),
          const SizedBox(height: AppTokens.sm + 4),
          Text(title, style: AppTokens.h2),
          const SizedBox(height: 2),
          Text(
            sub,
            style: AppTokens.muted(13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Compact player plate: color dot, name, and four progress pips that
  /// fill as pieces reach home. The plate of the player on turn lights
  /// up with their tint.
  Widget _playerPlate(int player) {
    final isMe = _myPlayer == player;
    final active = !_state.isGameOver && _state.currentPlayer == player;
    final color = player == 0 ? AppTokens.player0 : AppTokens.player1;
    final tint = player == 0 ? AppTokens.player0Tint : AppTokens.player1Tint;
    final home = _state.homeCount(player);

    return AnimatedContainer(
      duration: AppTokens.motion,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.sm + 2,
        vertical: AppTokens.sm,
      ),
      decoration: BoxDecoration(
        color: active ? tint : AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusControl),
        border: Border.fromBorderSide(
          BorderSide(
            color: active ? color.withOpacity(0.45) : AppTokens.border,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppTokens.xs + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? 'You' : 'Peer',
                  style: AppTokens.body.copyWith(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    for (var i = 0; i < LudoBoard.piecesPerPlayer; i++)
                      Container(
                        width: 7,
                        height: 7,
                        margin: EdgeInsets.only(right: i < 3 ? 3 : 0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < home ? color : AppTokens.border,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final dice = _state.dice;
    String label;
    VoidCallback? onTap;
    bool filled = true;

    if (_state.isGameOver) {
      label = 'Game over';
      filled = false;
    } else if (_state.awaitingRoll) {
      if (_myTurn) {
        label = 'Roll dice';
        onTap = _rollDice;
      } else {
        label = 'Waiting for peer…';
        filled = false;
      }
    } else if (_state.awaitingMove) {
      if (_myTurn && _movable.isEmpty) {
        label = 'Pass turn';
        onTap = _passTurn;
      } else if (_myTurn) {
        label = 'Tap a piece';
        filled = false;
      } else {
        label = 'Waiting for peer…';
        filled = false;
      }
    } else {
      label = 'Ready';
      filled = false;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppTokens.sm + 4,
        horizontal: AppTokens.md,
      ),
      decoration: AppTokens.cardDecoration(),
      child: Row(
        children: [
          _DiceCard(value: dice ?? _lastDice, dimmed: dice == null),
          const SizedBox(width: AppTokens.md),
          Expanded(
            child: SizedBox(
              height: 56,
              child: filled
                  ? FilledButton.icon(
                      onPressed: onTap,
                      icon: Icon(
                        _state.awaitingRoll
                            ? Icons.casino_rounded
                            : Icons.skip_next_rounded,
                        size: 20,
                      ),
                      label: Text(
                        label,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTokens.accent,
                      ),
                    )
                  : OutlinedButton(
                      onPressed: onTap,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: onTap != null
                              ? AppTokens.accent
                              : Colors.grey.shade400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: onTap != null
                              ? AppTokens.accentWith(0.4)
                              : AppTokens.border,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWinnerOverlay() {
    final iWon = _state.winner == _myPlayer;
    return ColoredBox(
      color: AppTokens.text.withOpacity(0.25),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: AppTokens.motionSlow,
          curve: Curves.easeOut,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.88 + 0.12 * t, child: child),
          ),
          child: Container(
            width: 250,
            padding: const EdgeInsets.all(AppTokens.lg),
            decoration: AppTokens.cardDecoration(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  iWon
                      ? Icons.emoji_events_rounded
                      : Icons.celebration_outlined,
                  color: AppTokens.accent,
                  size: 44,
                ),
                const SizedBox(height: AppTokens.md),
                Text(iWon ? 'You won' : 'Peer won', style: AppTokens.h1),
                const SizedBox(height: AppTokens.xs),
                Text('Great game.', style: AppTokens.muted(14)),
                const SizedBox(height: AppTokens.lg),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _service.resetGame,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTokens.accent,
                    ),
                    child: const Text(
                      'Play again',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _autoPassTimer?.cancel();
    _eventTimer?.cancel();
    _pulse.dispose();
    _stateSub?.cancel();
    _statusSub?.cancel();
    _service.dispose();
    super.dispose();
  }
}

// ============================================================ board paint

class _LudoBoardPainter extends CustomPainter {
  _LudoBoardPainter(this.state, this.myPlayer, this.movable, this.pulse);

  final LudoState state;
  final int? myPlayer;

  /// Movable piece indices of [myPlayer] (drives rings + landing spots).
  final Set<int> movable;

  /// 0..1 progress of the attention pulse (0 when not animating).
  final double pulse;

  static Color _playerColor(int p) =>
      p == 0 ? AppTokens.player0 : AppTokens.player1;
  static Color _playerTint(int p) =>
      p == 0 ? AppTokens.player0Tint : AppTokens.player1Tint;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.width / LudoBoard.size;
    _paintBases(canvas, c);
    _paintTrack(canvas, c);
    _paintHomeCols(canvas, c);
    _paintCenter(canvas, c);
    _paintPieces(canvas, c);
    _paintTargets(canvas, c);
  }

  Rect _cellRect(int row, int col, double c, [double inset = 1.5]) {
    return Rect.fromLTWH(
      col * c + inset,
      row * c + inset,
      c - inset * 2,
      c - inset * 2,
    );
  }

  void _paintBases(Canvas canvas, double c) {
    // Unused bases (decorative, kept within the palette) — background
    // tint so they read as "not in play" against the white card.
    for (final origin in LudoBoard.unusedBaseOrigin) {
      final r = Rect.fromLTWH(origin[1] * c, origin[0] * c, 6 * c, 6 * c);
      _fillRounded(canvas, r, AppTokens.background, c * 0.18);
      _strokeRounded(canvas, r, AppTokens.border, 1, c * 0.18);
    }
    // Player bases: tinted yard, white inner panel, four circular docks.
    for (final p in const [0, 1]) {
      final color = _playerColor(p);
      final origin = LudoBoard.baseOrigin[p];
      final r = Rect.fromLTWH(origin[1] * c, origin[0] * c, 6 * c, 6 * c);
      _fillRounded(canvas, r, _playerTint(p), c * 0.18);
      _strokeRounded(canvas, r, color.withOpacity(0.35), 1.2, c * 0.18);
      final inner = Rect.fromLTWH(
          origin[1] * c + c, origin[0] * c + c, 4 * c, 4 * c);
      _fillRounded(canvas, inner, AppTokens.surface, c * 0.3);
      _strokeRounded(canvas, inner, AppTokens.border, 1, c * 0.3);
      for (final slot in LudoBoard.baseSlots[p]) {
        final center = Offset((slot[1] + 0.5) * c, (slot[0] + 0.5) * c);
        canvas.drawCircle(center, c * 0.36, Paint()..color = _playerTint(p));
        canvas.drawCircle(
          center,
          c * 0.36,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = color.withOpacity(0.30),
        );
      }
    }
  }

  void _paintTrack(Canvas canvas, double c) {
    for (var i = 0; i < LudoBoard.path.length; i++) {
      final cell = LudoBoard.path[i];
      final r = _cellRect(cell[0], cell[1], c, 1.25);
      var fill = AppTokens.surface;
      if (i == LudoBoard.startIndex[0]) {
        fill = AppTokens.player0;
      } else if (i == LudoBoard.startIndex[1]) {
        fill = AppTokens.player1;
      }
      _fillRounded(canvas, r, fill, c * 0.22);
      _strokeRounded(canvas, r, AppTokens.border, 1, c * 0.22);

      if (LudoBoard.isSafe(i)) {
        final center = Offset((cell[1] + 0.5) * c, (cell[0] + 0.5) * c);
        final starColor = (i == LudoBoard.startIndex[0] ||
                i == LudoBoard.startIndex[1])
            ? Colors.white
            : Colors.grey.shade400;
        canvas.drawPath(_starPath(center, c * 0.28), Paint()..color = starColor);
      }
    }
  }

  void _paintHomeCols(Canvas canvas, double c) {
    for (final p in const [0, 1]) {
      for (final cell in LudoBoard.homeCols[p]) {
        final r = _cellRect(cell[0], cell[1], c, 1.25);
        _fillRounded(canvas, r, _playerTint(p), c * 0.22);
        _strokeRounded(canvas, r, AppTokens.border, 1, c * 0.22);
      }
    }
  }

  void _paintCenter(Canvas canvas, double c) {
    final left = 6 * c;
    final top = 6 * c;
    final right = 9 * c;
    final bottom = 9 * c;
    final mid = Offset(7.5 * c, 7.5 * c);

    // Unused (top + bottom) triangles.
    _triangle(
      canvas,
      [Offset(left, top), Offset(right, top), mid],
      AppTokens.surface,
      AppTokens.border,
    );
    _triangle(
      canvas,
      [Offset(left, bottom), Offset(right, bottom), mid],
      AppTokens.surface,
      AppTokens.border,
    );
    // Player home triangles: P0 enters from the left, P1 from the right.
    _triangle(canvas, [Offset(left, top), Offset(left, bottom), mid],
        _playerColor(0), null);
    _triangle(canvas, [Offset(right, top), Offset(right, bottom), mid],
        _playerColor(1), null);

    // Finished pieces sit inside the home triangles.
    for (final p in const [0, 1]) {
      final count =
          state.pieces[p].where((pos) => pos == LudoState.posHome).length;
      final x = p == 0 ? left + 0.30 * c : right - 0.30 * c;
      for (var i = 0; i < count; i++) {
        final center = Offset(x, top + (0.72 + i * 0.55) * c);
        canvas.drawCircle(center, c * 0.22, Paint()..color = _playerColor(p));
        canvas.drawCircle(
          center,
          c * 0.22,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.white,
        );
      }
    }
  }

  void _paintPieces(Canvas canvas, double c) {
    final radius = c * 0.30;

    // 1) Pieces parked in bases (each in its own dock).
    for (var p = 0; p < 2; p++) {
      for (var i = 0; i < LudoBoard.piecesPerPlayer; i++) {
        if (state.pieces[p][i] != LudoState.posBase) continue;
        final slot = LudoBoard.baseSlots[p][i];
        final center = Offset((slot[1] + 0.5) * c, (slot[0] + 0.5) * c);
        _drawPiece(
          canvas,
          center,
          radius,
          _playerColor(p),
          c,
          highlighted: p == myPlayer && movable.contains(i),
        );
      }
    }

    // 2) Pieces on the track / home column. Two pieces can share a safe
    //    cell — group by cell so they render side by side.
    final byCell = <String, List<(int, int)>>{};
    for (var p = 0; p < 2; p++) {
      for (var i = 0; i < LudoBoard.piecesPerPlayer; i++) {
        final pos = state.pieces[p][i];
        if (pos == LudoState.posBase || pos == LudoState.posHome) continue;
        final cell = LudoBoard.cellOf(p, pos);
        if (cell == null) continue;
        byCell.putIfAbsent('${cell[0]},${cell[1]}', () => []).add((p, i));
      }
    }
    byCell.forEach((key, occupants) {
      final parts = key.split(',');
      final row = int.parse(parts[0]);
      final col = int.parse(parts[1]);
      final center = Offset((col + 0.5) * c, (row + 0.5) * c);

      if (occupants.length == 1) {
        final (p, i) = occupants.single;
        _drawPiece(
          canvas,
          center,
          radius,
          _playerColor(p),
          c,
          highlighted: p == myPlayer && movable.contains(i),
        );
        return;
      }
      // Shared (safe) cell: P0 top-left, P1 bottom-right.
      final off = c * 0.17;
      for (final (p, i) in occupants) {
        final dx = p == 0 ? -off : off;
        _drawPiece(
          canvas,
          Offset(center.dx + dx, center.dy + dx),
          radius * 0.86,
          _playerColor(p),
          c,
          highlighted: p == myPlayer && movable.contains(i),
        );
      }
    });
  }

  /// Soft landing-spot rings for every movable piece — tap targets the
  /// player can aim at instead of the piece itself. Painted last so a
  /// ring also outlines an opponent piece that is about to be captured.
  void _paintTargets(Canvas canvas, double c) {
    if (myPlayer == null || state.dice == null || movable.isEmpty) return;
    final color = _playerColor(myPlayer!);
    for (final i in movable) {
      final pos = state.pieces[myPlayer!][i];
      final rel = pos == LudoState.posBase ? 0 : pos + state.dice!;
      final cell = LudoBoard.cellOf(myPlayer!, rel);
      if (cell == null) continue; // finishing move — target is the center
      final center = Offset((cell[1] + 0.5) * c, (cell[0] + 0.5) * c);
      canvas.drawCircle(
        center,
        c * 0.30,
        Paint()..color = color.withOpacity(0.10),
      );
      canvas.drawCircle(
        center,
        c * 0.30,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = color.withOpacity(0.45 + 0.20 * pulse),
      );
    }
  }

  void _drawPiece(
    Canvas canvas,
    Offset center,
    double radius,
    Color fill,
    double c, {
    required bool highlighted,
  }) {
    if (highlighted) {
      // Attention pulse (DESIGN.md §6 — the sanctioned looping cue).
      canvas.drawCircle(
        center,
        radius + c * (0.08 + 0.06 * pulse),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = c * 0.09
          ..color = fill.withOpacity(0.35 + 0.5 * pulse),
      );
    }
    // Soft drop shadow.
    canvas.drawCircle(
      Offset(center.dx, center.dy + c * 0.06),
      radius,
      Paint()..color = const Color(0x12000000),
    );
    canvas.drawCircle(center, radius, Paint()..color = fill);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
    // Subtle inner dot for depth.
    canvas.drawCircle(
      center,
      radius * 0.42,
      Paint()..color = Colors.white.withOpacity(0.35),
    );
  }

  void _triangle(
    Canvas canvas,
    List<Offset> pts,
    Color fill,
    Color? stroke,
  ) {
    final path = Path()
      ..moveTo(pts[0].dx, pts[0].dy)
      ..lineTo(pts[1].dx, pts[1].dy)
      ..lineTo(pts[2].dx, pts[2].dy)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    if (stroke != null) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = stroke,
      );
    }
  }

  Path _starPath(Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    return path;
  }

  void _fillRounded(Canvas canvas, Rect r, Color color, double radius) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(radius)),
      Paint()..color = color,
    );
  }

  void _strokeRounded(
    Canvas canvas,
    Rect r,
    Color color,
    double width,
    double radius,
  ) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_LudoBoardPainter old) =>
      !identical(old.state, state) ||
      old.myPlayer != myPlayer ||
      old.pulse != pulse ||
      old.movable.length != movable.length ||
      old.movable.join(',') != movable.join(',');
}

// ================================================================ dice

/// Dice card: tumbles for a beat when a new roll arrives, then settles
/// on the face with a haptic tick. While no roll is pending it shows
/// the last roll dimmed.
class _DiceCard extends StatefulWidget {
  const _DiceCard({required this.value, this.dimmed = false});

  /// Current face; 0 means "never rolled" (draws a question mark).
  final int value;

  /// Whether to render at reduced opacity (no pending roll).
  final bool dimmed;

  @override
  State<_DiceCard> createState() => _DiceCardState();
}

class _DiceCardState extends State<_DiceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tumble = AnimationController(
    vsync: this,
    duration: AppTokens.motionSlow,
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.selectionClick();
      }
    });

  @override
  void didUpdateWidget(covariant _DiceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && widget.value > 0) {
      _tumble.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: AnimatedBuilder(
        animation: _tumble,
        builder: (context, _) {
          final rolling = _tumble.isAnimating;
          // Face changes every ~1/12 of the tumble so it reads as a roll
          // (two full cycles of the six faces).
          final face = rolling
              ? 1 + (_tumble.value * 12).floor() % 6
              : widget.value;
          final scale =
              1.0 + 0.10 * math.sin(math.pi * (rolling ? _tumble.value : 0.0));
          return Transform.scale(
            scale: scale,
            child: Container(
              decoration:
                  AppTokens.cardDecoration(radius: AppTokens.radiusControl),
              child:
                  CustomPaint(painter: _DicePainter(face, dimmed: widget.dimmed)),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tumble.dispose();
    super.dispose();
  }
}

class _DicePainter extends CustomPainter {
  _DicePainter(this.value, {this.dimmed = false});

  /// 0 means "no roll yet".
  final int value;

  final bool dimmed;

  static const Map<int, List<int>> _faces = {
    1: [5],
    2: [3, 7],
    3: [3, 5, 7],
    4: [1, 3, 7, 9],
    5: [1, 3, 5, 7, 9],
    6: [1, 3, 4, 6, 7, 9],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final pipR = size.width * 0.085;
    if (value < 1 || value > 6) {
      final tp = TextPainter(
        text: TextSpan(
          text: '?',
          style: TextStyle(
            color: dimmed ? Colors.grey.shade300 : Colors.grey.shade400,
            fontSize: size.height * 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
      return;
    }
    final pipColor = dimmed
        ? AppTokens.text.withOpacity(0.30)
        : AppTokens.text;
    for (final i in _faces[value]!) {
      final row = (i - 1) ~/ 3;
      final col = (i - 1) % 3;
      final center = Offset(
        size.width * (col + 0.5) / 3,
        size.height * (row + 0.5) / 3,
      );
      canvas.drawCircle(center, pipR, Paint()..color = pipColor);
    }
  }

  @override
  bool shouldRepaint(_DicePainter old) =>
      old.value != value || old.dimmed != dimmed;
}
