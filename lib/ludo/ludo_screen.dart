import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nearby_chat_app/design_tokens.dart';
import 'package:nearby_chat_app/ludo/ludo_board.dart';
import 'package:nearby_chat_app/ludo/ludo_service.dart';
import 'package:nearby_chat_app/ludo/ludo_state.dart';

/// Two-player Ludo over the shared Nearby link.
///
/// The board is rendered with a [CustomPainter] on the standard 15×15
/// grid; only tiny dice/move payloads cross the link (see [LudoService]).
class LudoScreen extends StatefulWidget {
  const LudoScreen({super.key});

  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends State<LudoScreen> {
  final LudoService _service = LudoService();
  final _rng = math.Random();

  LudoState _state = LudoState();
  int? _myPlayer;
  Timer? _autoPassTimer;

  /// Pixel size of one board cell (set while the board lays out).
  double _cellSize = 0;

  @override
  void initState() {
    super.initState();
    _service.stateStream.listen((state) {
      if (mounted) setState(() => _state = state);
    });
    _service.statusStream.listen((_) {
      if (mounted) setState(() => _myPlayer = _service.myPlayer);
    });
  }

  bool get _connected => _myPlayer != null;
  bool get _myTurn => _connected && _state.canAct(_myPlayer!);
  List<int> get _movable =>
      _connected ? _state.movablePieces(_myPlayer!) : const <int>[];

  void _rollDice() {
    if (!_myTurn || !_state.awaitingRoll) return;
    _service.rollDice(_rng.nextInt(6) + 1);
    _scheduleAutoPassIfNeeded();
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
    for (final piece in _movable) {
      final pos = _state.pieces[_myPlayer!][piece];
      if (pos == LudoState.posBase) {
        final slot = LudoBoard.baseSlots[_myPlayer!][piece];
        if (slot[0] == row && slot[1] == col) {
          _service.movePiece(piece);
          return;
        }
        continue;
      }
      final cell = LudoBoard.cellOf(_myPlayer!, pos);
      if (cell != null && cell[0] == row && cell[1] == col) {
        _service.movePiece(piece);
        return;
      }
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
      ),
      body: _connected ? _buildGameView() : _buildNotConnectedView(),
    );
  }

  Widget _buildNotConnectedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
            const SizedBox(height: 24),
            Text(
              'Ludo',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppTokens.text,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Not connected. Go back to establish connection.',
              style: AppTokens.muted(15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
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
                final side =
                    math.min(constraints.maxWidth, constraints.maxHeight);
                _cellSize = side / LudoBoard.size;
                return Center(
                  child: SizedBox(
                    width: side,
                    height: side,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) => _onBoardTap(d.localPosition),
                          child: CustomPaint(
                            painter: _LudoBoardPainter(
                              _state,
                              _myPlayer,
                              _movable.toSet(),
                            ),
                          ),
                        ),
                        if (_state.isGameOver) _buildWinnerOverlay(),
                      ],
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
        sub = _movable.isEmpty ? 'No moves — passing…' : 'Tap a highlighted piece';
      } else {
        title = "Peer's turn";
        sub = 'Waiting for them to move…';
      }
    } else {
      title = 'Ludo';
      sub = 'Connected';
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: AppTokens.md),
      decoration: AppTokens.cardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _playerChip(0),
              const SizedBox(width: AppTokens.lg),
              _playerChip(1),
            ],
          ),
          const SizedBox(height: AppTokens.sm),
          Text(title, style: AppTokens.h2),
          const SizedBox(height: 2),
          Text(sub, style: AppTokens.muted(13)),
        ],
      ),
    );
  }

  Widget _playerChip(int player) {
    final isMe = _myPlayer == player;
    final color = player == 0 ? AppTokens.accent : AppTokens.text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppTokens.xs + 2),
        Text(
          isMe ? 'You · ${_state.homeCount(player)}/4'
               : 'Peer · ${_state.homeCount(player)}/4',
          style: AppTokens.body.copyWith(
            fontSize: 13,
            fontWeight: isMe ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
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

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppTokens.sm + 4,
            horizontal: AppTokens.md,
          ),
          decoration: AppTokens.cardDecoration(),
          child: Row(
            children: [
              _DiceCard(value: dice ?? 0),
              const SizedBox(width: AppTokens.md),
              Expanded(
                child: SizedBox(
                  height: 52,
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
        ),
        const SizedBox(height: AppTokens.sm),
        Material(
          color: AppTokens.surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusControl),
          child: InkWell(
            onTap: _service.resetGame,
            borderRadius: BorderRadius.circular(AppTokens.radiusControl),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: AppTokens.sm + 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.radiusControl),
                border: AppTokens.cardBorder,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh_rounded, color: AppTokens.accent, size: 20),
                  const SizedBox(width: AppTokens.sm),
                  Text(
                    'New game',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWinnerOverlay() {
    final iWon = _state.winner == _myPlayer;
    return ColoredBox(
      color: AppTokens.text.withOpacity(0.25),
      child: Center(
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
              Text(iWon ? 'You won!' : 'Peer won!', style: AppTokens.h1),
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
    );
  }

  @override
  void dispose() {
    _autoPassTimer?.cancel();
    _service.dispose();
    super.dispose();
  }
}

// ============================================================ board paint

class _LudoBoardPainter extends CustomPainter {
  _LudoBoardPainter(this.state, this.myPlayer, this.movable);

  final LudoState state;
  final int? myPlayer;
  final Set<int> movable;

  static const Color _p0 = AppTokens.accent; // player 0 (host)
  static const Color _p1 = AppTokens.text; // player 1 (guest)

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.width / LudoBoard.size;
    _paintBases(canvas, c);
    _paintTrack(canvas, c);
    _paintHomeCols(canvas, c);
    _paintCenter(canvas, c);
    _paintPieces(canvas, c);
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
    // Unused bases (decorative, kept within the palette).
    for (final origin in LudoBoard.unusedBaseOrigin) {
      final r = Rect.fromLTWH(origin[1] * c, origin[0] * c, 6 * c, 6 * c);
      _fillRounded(canvas, r, AppTokens.surface, c * 0.18);
      _strokeRounded(canvas, r, AppTokens.border, 1, c * 0.18);
    }
    // Player bases with 4 parking slots each.
    for (final p in const [0, 1]) {
      final origin = LudoBoard.baseOrigin[p];
      final tint =
          p == 0 ? AppTokens.accentWith(0.10) : AppTokens.text.withOpacity(0.06);
      final r = Rect.fromLTWH(origin[1] * c, origin[0] * c, 6 * c, 6 * c);
      _fillRounded(canvas, r, tint, c * 0.18);
      _strokeRounded(
        canvas,
        r,
        p == 0 ? AppTokens.accentWith(0.5) : AppTokens.border,
        1.2,
        c * 0.18,
      );
      final inner = Rect.fromLTWH(origin[1] * c + c, origin[0] * c + c, 4 * c, 4 * c);
      _fillRounded(canvas, inner, AppTokens.surface, c * 0.3);
      _strokeRounded(canvas, inner, AppTokens.border, 1, c * 0.3);
      final slotColor =
          p == 0 ? AppTokens.accentWith(0.14) : AppTokens.text.withOpacity(0.07);
      for (final slot in LudoBoard.baseSlots[p]) {
        final center = Offset((slot[1] + 0.5) * c, (slot[0] + 0.5) * c);
        canvas.drawCircle(center, c * 0.34, Paint()..color = slotColor);
      }
    }
  }

  void _paintTrack(Canvas canvas, double c) {
    for (var i = 0; i < LudoBoard.path.length; i++) {
      final cell = LudoBoard.path[i];
      final r = _cellRect(cell[0], cell[1], c);
      var fill = AppTokens.surface;
      if (i == LudoBoard.startIndex[0]) {
        fill = _p0;
      } else if (i == LudoBoard.startIndex[1]) {
        fill = _p1;
      }
      _fillRounded(canvas, r, fill, c * 0.14);
      _strokeRounded(canvas, r, AppTokens.border, 1, c * 0.14);

      if (LudoBoard.isSafe(i)) {
        final center = Offset((cell[1] + 0.5) * c, (cell[0] + 0.5) * c);
        final starColor = (i == LudoBoard.startIndex[0] ||
                i == LudoBoard.startIndex[1])
            ? Colors.white
            : Colors.grey.shade400;
        canvas.drawPath(_starPath(center, c * 0.30), Paint()..color = starColor);
      }
    }
  }

  void _paintHomeCols(Canvas canvas, double c) {
    for (final p in const [0, 1]) {
      final fill =
          p == 0 ? AppTokens.accentWith(0.30) : AppTokens.text.withOpacity(0.18);
      for (final cell in LudoBoard.homeCols[p]) {
        final r = _cellRect(cell[0], cell[1], c);
        _fillRounded(canvas, r, fill, c * 0.14);
        _strokeRounded(canvas, r, AppTokens.border, 1, c * 0.14);
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
    _triangle(canvas, [Offset(left, top), Offset(left, bottom), mid], _p0, null);
    _triangle(canvas, [Offset(right, top), Offset(right, bottom), mid], _p1, null);

    // Finished pieces sit inside the home triangles.
    for (final p in const [0, 1]) {
      final count = state.pieces[p].where((pos) => pos == LudoState.posHome).length;
      final x = p == 0 ? left + 0.30 * c : right - 0.30 * c;
      for (var i = 0; i < count; i++) {
        final center = Offset(x, top + (0.72 + i * 0.55) * c);
        canvas.drawCircle(center, c * 0.22, Paint()..color = p == 0 ? _p0 : _p1);
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

    // 1) Pieces parked in bases (each in its own slot).
    for (var p = 0; p < 2; p++) {
      for (var i = 0; i < LudoBoard.piecesPerPlayer; i++) {
        if (state.pieces[p][i] != LudoState.posBase) continue;
        final slot = LudoBoard.baseSlots[p][i];
        final center = Offset((slot[1] + 0.5) * c, (slot[0] + 0.5) * c);
        _drawPiece(
          canvas,
          center,
          radius,
          p == 0 ? _p0 : _p1,
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
          p == 0 ? _p0 : _p1,
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
          p == 0 ? _p0 : _p1,
          c,
          highlighted: p == myPlayer && movable.contains(i),
        );
      }
    });
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
      canvas.drawCircle(
        center,
        radius + c * 0.16,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = c * 0.10
          ..color = fill,
      );
    }
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
      radius * 0.45,
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
      (old.movable.length != movable.length ||
          old.movable.join(',') != movable.join(','));
}

/// Small dice card showing the current roll as pips.
class _DiceCard extends StatelessWidget {
  const _DiceCard({required this.value});

  /// 0 means "no roll yet".
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: AppTokens.cardDecoration(radius: AppTokens.radiusControl),
      child: CustomPaint(painter: _DicePainter(value)),
    );
  }
}

class _DicePainter extends CustomPainter {
  _DicePainter(this.value);

  final int value;

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
            color: Colors.grey.shade400,
            fontSize: size.height * 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
      return;
    }
    for (final i in _faces[value]!) {
      final row = (i - 1) ~/ 3;
      final col = (i - 1) % 3;
      final center = Offset(
        size.width * (col + 0.5) / 3,
        size.height * (row + 0.5) / 3,
      );
      canvas.drawCircle(center, pipR, Paint()..color = AppTokens.text);
    }
  }

  @override
  bool shouldRepaint(_DicePainter old) => old.value != value;
}
