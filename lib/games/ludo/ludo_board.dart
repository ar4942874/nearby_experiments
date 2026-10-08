import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nearby_chat_app/design_tokens.dart';
import 'package:nearby_chat_app/games/ludo/ludo_state.dart';

class LudoBoard {
  LudoBoard._();

  static const int size = 15;
  static const int piecesPerPlayer = 4;

  static const int trackLast = 50;

  static const int homeColStart = 51;
  static const int homeColEnd = 55;

  static const int finished = 56;

  static const List<List<int>> path = [
    [6, 1], [6, 2], [6, 3], [6, 4], [6, 5],
    [5, 6], [4, 6], [3, 6], [2, 6], [1, 6], [0, 6],
    [0, 7], [0, 8],
    [1, 8], [2, 8], [3, 8], [4, 8], [5, 8],
    [6, 9], [6, 10], [6, 11], [6, 12], [6, 13],
    [6, 14], [7, 14], [8, 14],
    [8, 13], [8, 12], [8, 11], [8, 10], [8, 9],
    [9, 8], [10, 8], [11, 8], [12, 8], [13, 8], [14, 8],
    [14, 7], [14, 6],
    [13, 6], [12, 6], [11, 6], [10, 6], [9, 6],
    [8, 5], [8, 4], [8, 3], [8, 2], [8, 1],
    [8, 0], [7, 0], [6, 0],
  ];

  static const List<int> startIndex = [0, 26];

  static const List<List<List<int>>> homeCols = [
    [
      [7, 1], [7, 2], [7, 3], [7, 4], [7, 5]
    ],
    [
      [7, 13], [7, 12], [7, 11], [7, 10], [7, 9]
    ],
  ];

  static const Set<int> safeCells = {0, 8, 13, 21, 26, 34, 39, 47};

  static const List<List<List<int>>> baseSlots = [
    [
      [2, 2], [2, 3], [3, 2], [3, 3]
    ],
    [
      [11, 11], [11, 12], [12, 11], [12, 12]
    ],
  ];

  static const List<List<int>> baseOrigin = [
    [0, 0],
    [9, 9],
  ];

  static const List<List<int>> unusedBaseOrigin = [
    [0, 9],
    [9, 0],
  ];

  static int absoluteOf(int player, int rel) => (startIndex[player] + rel) % 52;

  static List<int>? cellOf(int player, int rel) {
    if (rel <= trackLast) return path[absoluteOf(player, rel)];
    if (rel >= homeColStart && rel <= homeColEnd) {
      return homeCols[player][rel - homeColStart];
    }
    return null;
  }

  static bool isSafe(int absoluteIndex) => safeCells.contains(absoluteIndex);

  static bool isTrackCell(int row, int col) {
    for (var i = 0; i < path.length; i++) {
      final c = path[i];
      if (c[0] == row && c[1] == col) return true;
    }
    return false;
  }
}

class LudoBoardPainter extends CustomPainter {
  LudoBoardPainter(
    this.state,
    this.myPlayer,
    this.movable,
    this.pulse,
  );

  final LudoState state;
  final int? myPlayer;
  final Set<int> movable;
  final double pulse;

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
    for (final origin in LudoBoard.unusedBaseOrigin) {
      final r = Rect.fromLTWH(origin[1] * c, origin[0] * c, 6 * c, 6 * c);
      _fillRounded(canvas, r, AppTokens.background, c * 0.18);
      _strokeRounded(canvas, r, AppTokens.border, 1, c * 0.18);
    }
    for (final p in const [0, 1]) {
      final color = AppTokens.playerColor(p);
      final origin = LudoBoard.baseOrigin[p];
      final r = Rect.fromLTWH(origin[1] * c, origin[0] * c, 6 * c, 6 * c);
      _fillRounded(canvas, r, AppTokens.playerTint(p), c * 0.18);
      _strokeRounded(canvas, r, color.withOpacity(0.35), 1.2, c * 0.18);
      final inner = Rect.fromLTWH(
          origin[1] * c + c, origin[0] * c + c, 4 * c, 4 * c);
      _fillRounded(canvas, inner, AppTokens.surface, c * 0.3);
      _strokeRounded(canvas, inner, AppTokens.border, 1, c * 0.3);
      for (final slot in LudoBoard.baseSlots[p]) {
        final center = Offset((slot[1] + 0.5) * c, (slot[0] + 0.5) * c);
        canvas.drawCircle(center, c * 0.36, Paint()..color = AppTokens.playerTint(p));
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
        fill = AppTokens.playerColor(0);
      } else if (i == LudoBoard.startIndex[1]) {
        fill = AppTokens.playerColor(1);
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
        _fillRounded(canvas, r, AppTokens.playerTint(p), c * 0.22);
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
    _triangle(canvas, [Offset(left, top), Offset(left, bottom), mid],
        AppTokens.playerColor(0), null);
    _triangle(canvas, [Offset(right, top), Offset(right, bottom), mid],
        AppTokens.playerColor(1), null);

    for (final p in const [0, 1]) {
      final count =
          state.pieces[p].where((pos) => pos == LudoState.posHome).length;
      final x = p == 0 ? left + 0.30 * c : right - 0.30 * c;
      for (var i = 0; i < count; i++) {
        final center = Offset(x, top + (0.72 + i * 0.55) * c);
        canvas.drawCircle(center, c * 0.22, Paint()..color = AppTokens.playerColor(p));
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

    for (var p = 0; p < 2; p++) {
      for (var i = 0; i < LudoBoard.piecesPerPlayer; i++) {
        if (state.pieces[p][i] != LudoState.posBase) continue;
        final slot = LudoBoard.baseSlots[p][i];
        final center = Offset((slot[1] + 0.5) * c, (slot[0] + 0.5) * c);
        _drawPiece(
          canvas,
          center,
          radius,
          AppTokens.playerColor(p),
          c,
          highlighted: p == myPlayer && movable.contains(i),
        );
      }
    }

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
          AppTokens.playerColor(p),
          c,
          highlighted: p == myPlayer && movable.contains(i),
        );
        return;
      }
      final off = c * 0.17;
      for (final (p, i) in occupants) {
        final dx = p == 0 ? -off : off;
        _drawPiece(
          canvas,
          Offset(center.dx + dx, center.dy + dx),
          radius * 0.86,
          AppTokens.playerColor(p),
          c,
          highlighted: p == myPlayer && movable.contains(i),
        );
      }
    });
  }

  void _paintTargets(Canvas canvas, double c) {
    if (myPlayer == null || state.dice == null || movable.isEmpty) return;
    final color = AppTokens.playerColor(myPlayer!);
    for (final i in movable) {
      final pos = state.pieces[myPlayer!][i];
      final rel = pos == LudoState.posBase ? 0 : pos + state.dice!;
      final cell = LudoBoard.cellOf(myPlayer!, rel);
      if (cell == null) continue;
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
      canvas.drawCircle(
        center,
        radius + c * (0.08 + 0.06 * pulse),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = c * 0.09
          ..color = fill.withOpacity(0.35 + 0.5 * pulse),
      );
    }
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
  bool shouldRepaint(LudoBoardPainter old) =>
      !identical(old.state, state) ||
      old.myPlayer != myPlayer ||
      old.pulse != pulse ||
      old.movable.length != movable.length ||
      old.movable.join(',') != movable.join(',');
}
