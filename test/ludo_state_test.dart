import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_chat_app/games/ludo/ludo_board.dart';
import 'package:nearby_chat_app/games/ludo/ludo_state.dart';

void main() {
  // -------------------------------------------------------------- helpers

  /// Places a player's pieces at the given relative positions, skipping the
  /// normal turn flow (test setup only). Unlisted pieces stay in base.
  void forceRel(LudoState s, int player, List<int> rels) {
    for (var i = 0; i < LudoBoard.piecesPerPlayer; i++) {
      s.pieces[player][i] = i < rels.length ? rels[i] : LudoState.posBase;
    }
  }

  // ------------------------------------------------------------ geometry

  group('LudoBoard geometry', () {
    test('path has exactly 52 unique cells', () {
      expect(LudoBoard.path.length, 52);
      final seen = <String>{};
      for (final c in LudoBoard.path) {
        expect(seen.add('${c[0]},${c[1]}'), true,
            reason: 'duplicate cell $c');
      }
    });

    test('every path cell is inside the cross of the board', () {
      for (final c in LudoBoard.path) {
        final inCross = (c[0] >= 6 && c[0] <= 8) || (c[1] >= 6 && c[1] <= 8);
        expect(inCross, true, reason: 'cell $c outside the cross');
      }
    });

    test('consecutive cells are adjacent (the four elbow turns excepted)',
        () {
      // The four "elbow" turns of the real Ludo board wrap around the
      // centre-block corners, so they are the only diagonal steps.
      var elbows = 0;
      for (var i = 0; i < LudoBoard.path.length; i++) {
        final a = LudoBoard.path[i];
        final b = LudoBoard.path[(i + 1) % LudoBoard.path.length];
        final dr = (a[0] - b[0]).abs();
        final dc = (a[1] - b[1]).abs();
        if (dr == 1 && dc == 1) {
          elbows++;
        } else {
          expect(dr + dc, 1, reason: 'non-adjacent cells $a -> $b at index $i');
        }
      }
      expect(elbows, 4, reason: 'expected exactly 4 elbow turns, got $elbows');
    });

    test('player starts are 13 cells apart (opposite corners)', () {
      expect(LudoBoard.startIndex[1] - LudoBoard.startIndex[0], 26);
    });

    test('home column entrance is adjacent to the last track cell', () {
      // Relative 50 (last track cell) must be adjacent to home column cell 0.
      for (final p in const [0, 1]) {
        final last = LudoBoard.cellOf(p, 50)!;
        final home0 = LudoBoard.homeCols[p][0];
        expect(
          (last[0] - home0[0]).abs() + (last[1] - home0[1]).abs(),
          1,
          reason: 'player $p home column not adjacent to track',
        );
      }
    });

    test('start cells and star cells line up with the safe set', () {
      expect(LudoBoard.safeCells, containsAll(<int>[
        LudoBoard.startIndex[0],
        LudoBoard.startIndex[1],
      ]));
      expect(LudoBoard.safeCells.length, 8);
    });
  });

  // ------------------------------------------------------------ basics

  group('LudoState basics', () {
    test('initial state: all pieces in base, player 0 to roll', () {
      final s = LudoState();
      expect(s.currentPlayer, 0);
      expect(s.dice, isNull);
      expect(s.winner, isNull);
      expect(s.version, 0);
      expect(s.pieces[0], everyElement(LudoState.posBase));
      expect(s.pieces[1], everyElement(LudoState.posBase));
      expect(s.awaitingRoll, true);
      expect(s.awaitingMove, false);
    });

    test('roll sets pending dice and bumps the version', () {
      final s = LudoState();
      expect(s.roll(0, 4), true);
      expect(s.dice, 4);
      expect(s.awaitingMove, true);
      expect(s.version, 1);
    });

    test('only the current player may roll', () {
      final s = LudoState();
      expect(s.roll(1, 3), false);
      expect(s.dice, isNull);
    });

    test('cannot roll twice without moving', () {
      final s = LudoState();
      expect(s.roll(0, 3), true);
      expect(s.roll(0, 5), false);
      expect(s.dice, 3);
    });

    test('reset restores the initial state and clears the version', () {
      final s = LudoState();
      s.roll(0, 6);
      s.move(0, 0, 6);
      s.roll(1, 2);
      s.move(1, 0, 2);
      s.reset();
      expect(s.pieces[0], everyElement(LudoState.posBase));
      expect(s.pieces[1], everyElement(LudoState.posBase));
      expect(s.currentPlayer, 0);
      expect(s.dice, isNull);
      expect(s.winner, isNull);
      expect(s.version, 0);
    });

    test('toJson/fromJson round trip', () {
      final s = LudoState();
      s.roll(0, 6);
      s.move(0, 0, 6);
      final restored = LudoState.fromJson(s.toJson());
      expect(restored.toJson(), s.toJson());
    });
  });

  // -------------------------------------------------------------- moves

  group('Piece movement', () {
    test('pieces leave the base only on a 6', () {
      for (var d = 1; d <= 5; d++) {
        final s = LudoState();
        s.roll(0, d);
        expect(s.movablePieces(0), isEmpty, reason: 'dice=$d');
      }
      final s = LudoState();
      s.roll(0, 6);
      expect(s.movablePieces(0), hasLength(4));
    });

    test('a 6 releases a piece onto the start cell', () {
      final s = LudoState();
      s.roll(0, 6);
      expect(s.move(0, 2, 6), true);
      expect(s.pieces[0], [
        LudoState.posBase,
        LudoState.posBase,
        0,
        LudoState.posBase,
      ]);
    });

    test('a base piece cannot exit while the start cell is occupied', () {
      final s = LudoState();
      s.roll(0, 6);
      s.move(0, 0, 6); // start cell (rel 0) now occupied
      s.roll(0, 6); // extra turn
      expect(s.movablePieces(0), [0],
          reason: 'only the piece already out can move');
    });

    test('pieces advance by the dice value', () {
      final s = LudoState();
      s.roll(0, 6);
      s.move(0, 0, 6); // rel 0
      s.roll(0, 3);
      s.move(0, 0, 3); // rel 3
      expect(s.pieces[0][0], 3);
    });

    test('exact roll required to finish', () {
      final s = LudoState();
      forceRel(s, 0, [55]); // last home-column cell
      s.currentPlayer = 0;

      s.roll(0, 1);
      expect(s.movablePieces(0), [0]);
      expect(s.move(0, 0, 1), true);
      expect(s.pieces[0][0], LudoState.posHome);

      final t = LudoState();
      forceRel(t, 0, [55]);
      t.currentPlayer = 0;
      t.roll(0, 2);
      expect(t.movablePieces(0), isEmpty,
          reason: '55 + 2 overshoots home');
    });

    test('own piece blocks the target track cell (no stacking)', () {
      final s = LudoState();
      forceRel(s, 0, [0, 5]); // siblings at rel 0 and rel 5
      s.currentPlayer = 0;
      s.roll(0, 5);
      // Piece at 0 cannot land on the occupied cell 5; the piece at 5 can.
      expect(s.movablePieces(0), [1]);
    });

    test('own piece blocks the home column too', () {
      final s = LudoState();
      forceRel(s, 0, [52, 47]);
      s.currentPlayer = 0;
      s.roll(0, 5);
      expect(s.movablePieces(0), isEmpty,
          reason: 'piece at 47 cannot land on occupied home cell 52');
    });

    test('rolling a 6 grants an extra turn', () {
      final s = LudoState();
      s.roll(0, 6);
      s.move(0, 0, 6);
      expect(s.currentPlayer, 0, reason: 'extra roll after a 6');
      expect(s.dice, isNull);
    });

    test('a non-6 move hands the turn over', () {
      final s = LudoState();
      s.roll(0, 6);
      s.move(0, 0, 6); // extra turn
      s.roll(0, 2);
      s.move(0, 0, 2);
      expect(s.currentPlayer, 1);
    });
  });

  // ------------------------------------------------------------ captures

  group('Captures', () {
    test('landing on an opponent sends it back and grants an extra turn', () {
      final s = LudoState();
      forceRel(s, 1, [1]); // player 1 on absolute 27 (not safe)
      forceRel(s, 0, [24]); // player 0 three cells behind absolute 27
      expect(LudoBoard.absoluteOf(1, 1), 27);
      expect(LudoBoard.isSafe(27), false);

      s.currentPlayer = 0;
      s.roll(0, 3);
      expect(s.movablePieces(0), contains(0));
      expect(s.move(0, 0, 3), true);
      expect(s.pieces[0][0], 27);
      expect(s.pieces[1][0], LudoState.posBase, reason: 'captured');
      expect(s.currentPlayer, 0, reason: 'extra turn on capture');
    });

    test('no capture on safe (star) cells', () {
      final s = LudoState();
      forceRel(s, 1, [34]); // absolute 26 + 34 = 8 (safe star)
      expect(LudoBoard.isSafe(LudoBoard.absoluteOf(1, 34)), true);
      forceRel(s, 0, [5]);
      s.currentPlayer = 0;
      s.roll(0, 3); // lands on absolute 8
      expect(s.move(0, 0, 3), true);
      expect(s.pieces[1][0], 34, reason: 'safe cell: no capture');
      expect(s.currentPlayer, 1,
          reason: 'no extra turn (non-6, no capture, no finish)');
    });

    test('both players can occupy the same safe cell', () {
      // Player 0 rel 8 and player 1 rel 34 both map to absolute 8.
      expect(LudoBoard.absoluteOf(0, 8), 8);
      expect(LudoBoard.absoluteOf(1, 34), 8);
      final s = LudoState();
      forceRel(s, 0, [8]);
      forceRel(s, 1, [34]);
      expect(s.pieces[0][0], 8);
      expect(s.pieces[1][0], 34);
    });
  });

  // ---------------------------------------------------------- turn rules

  group('Turn rules', () {
    test('third consecutive six forfeits the turn', () {
      final s = LudoState();
      s.roll(0, 6);
      s.move(0, 0, 6); // piece 0 at rel 0
      s.roll(0, 6);
      // Only piece 0 can move: the start cell (rel 0) is occupied, so base
      // pieces cannot exit.
      expect(s.movablePieces(0), [0]);
      s.move(0, 0, 6); // piece 0 at rel 6
      s.roll(0, 6);
      expect(s.dice, isNull, reason: 'third six: no move allowed');
      expect(s.currentPlayer, 1, reason: 'turn forfeited');
      expect(s.consecutiveSixes, 0);
    });

    test('a non-6 roll clears the six streak', () {
      final s = LudoState();
      s.roll(0, 6);
      s.move(0, 0, 6);
      s.roll(0, 6);
      s.move(0, 0, 6);
      s.roll(0, 2);
      expect(s.consecutiveSixes, 0);
      final movable = s.movablePieces(0);
      expect(movable, isNotEmpty);
      s.move(0, movable.first, 2);
      expect(s.currentPlayer, 1);
    });

    test('pass works only when no piece can move', () {
      final s = LudoState();
      s.roll(0, 3);
      // All four pieces in base with dice 3 -> nothing movable.
      expect(s.movablePieces(0), isEmpty);
      expect(s.pass(0), true);
      expect(s.currentPlayer, 1);

      final t = LudoState();
      t.roll(0, 6);
      expect(t.pass(0), false, reason: 'cannot pass while a move exists');
    });

    test('bringing a piece home grants an extra turn', () {
      final s = LudoState();
      forceRel(s, 0, [55]);
      s.currentPlayer = 0;
      s.roll(0, 1);
      expect(s.move(0, 0, 1), true);
      expect(s.pieces[0][0], LudoState.posHome);
      expect(s.winner, isNull);
      expect(s.currentPlayer, 0, reason: 'extra turn on finishing a piece');
    });
  });

  // -------------------------------------------------------------- winning

  group('Winning', () {
    test('all four pieces home wins the game', () {
      final s = LudoState();
      forceRel(s, 0, [55, 55, 55, 55]);
      s.currentPlayer = 0;
      for (var i = 0; i < 4; i++) {
        s.roll(0, 1);
        expect(s.move(0, i, 1), true);
      }
      expect(s.winner, 0);
      expect(s.isGameOver, true);
      expect(s.homeCount(0), 4);
    });

    test('no further actions after the game is over', () {
      final s = LudoState();
      forceRel(s, 0, [55, 55, 55, 55]);
      s.currentPlayer = 0;
      for (var i = 0; i < 4; i++) {
        s.roll(0, 1);
        s.move(0, i, 1);
      }
      expect(s.winner, 0);
      expect(s.roll(1, 4), false);
      expect(s.pass(1), false);
    });
  });

  // ----------------------------------------------------- two-device sync

  /// Mirrors LudoService's wire handling: decodes the JSON payload and
  /// applies it to [s] (plain action sync, no version adoption).
  void _applyPayload(LudoState s, String data) {
    final json = jsonDecode(data) as Map<String, dynamic>;
    switch (json['type']) {
      case 'roll':
        if (!s.roll((json['player'] as num).toInt(), (json['dice'] as num).toInt())) {
          fail('peer rejected roll');
        }
        break;
      case 'move':
        if (!s.move(
              (json['player'] as num).toInt(),
              (json['piece'] as num).toInt(),
              (json['dice'] as num).toInt(),
            )) {
          fail('peer rejected move');
        }
        break;
      case 'pass':
        if (!s.pass((json['player'] as num).toInt())) {
          fail('peer rejected pass');
        }
        break;
      case 'reset':
        s.reset();
        break;
      default:
        fail('unknown payload ${json['type']}');
    }
  }

  String _rollPayload(int p, int d) =>
      jsonEncode({'type': 'roll', 'player': p, 'dice': d});
  String _movePayload(int p, int piece, int d) =>
      jsonEncode({'type': 'move', 'player': p, 'piece': piece, 'dice': d});
  String _passPayload(int p) => jsonEncode({'type': 'pass', 'player': p});

  /// Mirrors LudoService's `state` handler (version-gated adoption).
  void _receiveState(LudoState target, Map<String, dynamic> json) {
    final incoming = LudoState.fromJson(json);
    if (incoming.version > target.version) {
      target
        ..reset()
        ..pieces[0].setAll(0, incoming.pieces[0])
        ..pieces[1].setAll(0, incoming.pieces[1])
        ..currentPlayer = incoming.currentPlayer
        ..dice = incoming.dice
        ..consecutiveSixes = incoming.consecutiveSixes
        ..winner = incoming.winner
        ..version = incoming.version;
    }
  }

  group('Two-device synchronisation', () {
    test('a full random game keeps both engines identical', () {
      final rng = Random(42);
      final a = LudoState(); // device A
      final b = LudoState(); // device B

      var actions = 0;
      while (a.winner == null && actions < 3000) {
        String payload;
        if (a.awaitingRoll) {
          final p = a.currentPlayer;
          final d = rng.nextInt(6) + 1;
          expect(a.roll(p, d), true);
          payload = _rollPayload(p, d);
        } else {
          final p = a.currentPlayer;
          final d = a.dice!;
          final movable = a.movablePieces(p);
          if (movable.isEmpty) {
            expect(a.pass(p), true);
            payload = _passPayload(p);
          } else {
            final piece = movable[rng.nextInt(movable.length)];
            expect(a.move(p, piece, d), true);
            payload = _movePayload(p, piece, d);
          }
        }
        _applyPayload(b, payload);
        expect(b.toJson(), a.toJson(),
            reason: 'desync after $actions actions: $payload');
        actions++;
      }
      expect(actions, greaterThan(0));
      expect(b.toJson(), a.toJson());
      if (a.winner != null) {
        expect(b.winner, a.winner);
      }
    });

    test('a duplicated roll is rejected without diverging', () {
      final a = LudoState();
      final b = LudoState();
      final roll = _rollPayload(0, 6);
      _applyPayload(a, roll);
      _applyPayload(b, roll);
      // B receives the same roll twice.
      expect(b.roll(0, 6), false,
          reason: 'pending dice blocks a second roll');
      expect(b.toJson(), a.toJson());
    });

    test('a late joiner adopts the newer state via version', () {
      final ahead = LudoState();
      ahead.roll(0, 6);
      ahead.move(0, 0, 6); // v = 2
      ahead.roll(0, 3); // v = 3

      final late = LudoState(); // v = 0

      // Receiving a same-or-older state must be ignored.
      _receiveState(late, LudoState().toJson());
      expect(late.version, 0);

      _receiveState(late, ahead.toJson());
      expect(late.toJson(), ahead.toJson());
    });

    test('the fresher side never regresses to an older state', () {
      final a = LudoState();
      a.roll(0, 6);
      a.move(0, 0, 6); // v = 2
      final snapshot = a.toJson();

      _receiveState(a, LudoState().toJson());
      expect(a.toJson(), snapshot,
          reason: 'older state must not overwrite');
    });
  });

  // -------------------------------------------------------------- helpers

}
