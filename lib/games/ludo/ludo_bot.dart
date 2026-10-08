import 'dart:math' as math;

import 'package:nearby_chat_app/games/ludo/ludo_board.dart';
import 'package:nearby_chat_app/games/ludo/ludo_state.dart';

class LudoBot {
  LudoBot({this.difficulty = BotDifficulty.normal});

  final BotDifficulty difficulty;
  final math.Random _rng = math.Random();

  int chooseMove(LudoState state, int player, int diceValue) {
    final movable = state.movablePieces(player, diceValue);
    if (movable.isEmpty) return -1;
    if (movable.length == 1) return movable.first;

    switch (difficulty) {
      case BotDifficulty.easy:
        return movable[_rng.nextInt(movable.length)];
      case BotDifficulty.normal:
        return _chooseNormal(state, player, diceValue, movable);
      case BotDifficulty.hard:
        return _chooseHard(state, player, diceValue, movable);
    }
  }

  int _chooseNormal(LudoState state, int player, int diceValue, List<int> movable) {
    final scored = <int, double>{};
    for (final piece in movable) {
      scored[piece] = _scoreMove(state, player, piece, diceValue);
    }
    final best = scored.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return best.key;
  }

  int _chooseHard(LudoState state, int player, int diceValue, List<int> movable) {
    final scored = <int, double>{};
    for (final piece in movable) {
      var score = _scoreMove(state, player, piece, diceValue);
      score += _captureBonus(state, player, piece, diceValue);
      score += _safetyBonus(state, player, piece, diceValue);
      scored[piece] = score;
    }
    final best = scored.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return best.key;
  }

  double _scoreMove(LudoState state, int player, int piece, int diceValue) {
    final pos = state.pieces[player][piece];
    final fromBase = pos == LudoState.posBase;
    final target = fromBase ? 0 : pos + diceValue;

    var score = 0.0;

    if (fromBase) score += 30.0;

    if (target == LudoState.posHome) score += 50.0;

    if (target > LudoBoard.trackLast && target < LudoState.posHome) {
      score += 20.0;
    }

    if (!fromBase && target <= LudoBoard.trackLast) {
      final abs = LudoBoard.absoluteOf(player, target);
      if (LudoBoard.isSafe(abs)) score += 15.0;
    }

    if (!fromBase) {
      final currentAbs = LudoBoard.absoluteOf(player, pos);
      if (LudoBoard.isSafe(currentAbs)) score -= 10.0;
    }

    return score;
  }

  double _captureBonus(LudoState state, int player, int piece, int diceValue) {
    final pos = state.pieces[player][piece];
    final target = pos == LudoState.posBase ? 0 : pos + diceValue;
    if (target > LudoBoard.trackLast) return 0.0;

    final abs = LudoBoard.absoluteOf(player, target);
    if (LudoBoard.isSafe(abs)) return 0.0;

    for (var opp = 0; opp < state.pieces.length; opp++) {
      if (opp == player) continue;
      for (var i = 0; i < LudoBoard.piecesPerPlayer; i++) {
        final q = state.pieces[opp][i];
        if (q >= 0 && q <= LudoBoard.trackLast &&
            LudoBoard.absoluteOf(opp, q) == abs) {
          return 25.0;
        }
      }
    }
    return 0.0;
  }

  double _safetyBonus(LudoState state, int player, int piece, int diceValue) {
    final pos = state.pieces[player][piece];
    final target = pos == LudoState.posBase ? 0 : pos + diceValue;
    if (target > LudoBoard.trackLast) return 0.0;

    final abs = LudoBoard.absoluteOf(player, target);
    for (var opp = 0; opp < state.pieces.length; opp++) {
      if (opp == player) continue;
      for (var i = 0; i < LudoBoard.piecesPerPlayer; i++) {
        final q = state.pieces[opp][i];
        if (q < 0 || q > LudoBoard.trackLast) continue;
        final oppAbs = LudoBoard.absoluteOf(opp, q);
        final dist = (abs - oppAbs + 52) % 52;
        if (dist > 0 && dist <= 6) return -15.0;
      }
    }
    return 0.0;
  }
}

enum BotDifficulty { easy, normal, hard }
