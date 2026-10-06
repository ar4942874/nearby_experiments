import 'ludo_board.dart';

/// Pure-Dart Ludo rules engine for two players (no Flutter imports, so it
/// can be unit tested headless).
///
/// Piece positions are PLAYER-RELATIVE:
///
/// - `-1`        → in the home base
/// - `0..50`     → on the main track (`LudoBoard.absoluteOf` maps to the
///                 shared 52-cell loop)
/// - `51..55`    → on the player's home column
/// - `56`        → finished (all the way home)
///
/// Both peers run this same engine and apply the same actions in the same
/// order, so their states stay in sync without exchanging full boards —
/// only small dice/move payloads cross the link.
class LudoState {
  static const int posBase = -1;
  static const int posHome = LudoBoard.finished;

  /// `pieces[player][pieceIndex]` — 2 players × 4 pieces.
  final List<List<int>> pieces;

  /// Whose turn it is (0 or 1).
  int currentPlayer;

  /// Dice value waiting for a piece to be chosen (null while awaiting a
  /// roll).
  int? dice;

  /// Consecutive sixes rolled by the current turn — three in a row
  /// forfeits the turn.
  int consecutiveSixes;

  /// Winning player, or null while the game is running.
  int? winner;

  /// Monotonic action counter: bumped by every applied action, cleared by
  /// [reset]. Lets a peer that (re)joins detect it is behind and adopt the
  /// other side's newer state.
  int version;

  LudoState()
      : pieces = [
          List.filled(LudoBoard.piecesPerPlayer, posBase),
          List.filled(LudoBoard.piecesPerPlayer, posBase),
        ],
        currentPlayer = 0,
        dice = null,
        consecutiveSixes = 0,
        winner = null,
        version = 0;

  bool get isGameOver => winner != null;
  bool get awaitingRoll => !isGameOver && dice == null;
  bool get awaitingMove => !isGameOver && dice != null;

  /// Whether [player] may act right now (roll, move or pass).
  bool canAct(int player) => !isGameOver && player == currentPlayer;

  /// Piece indices (of [player]) that can legally move with [diceValue].
  List<int> movablePieces(int player, [int? diceValue]) {
    final d = diceValue ?? dice;
    if (d == null || isGameOver || player != currentPlayer) return const [];

    final mine = pieces[player];
    final result = <int>[];
    for (var i = 0; i < LudoBoard.piecesPerPlayer; i++) {
      final p = mine[i];
      if (p == posHome) continue;

      if (p == posBase) {
        // A piece leaves the base only on a 6, and the start cell must be
        // free (no stacking).
        if (d != 6) continue;
        var blocked = false;
        for (var j = 0; j < LudoBoard.piecesPerPlayer; j++) {
          if (j == i) continue;
          if (mine[j] == 0) {
            blocked = true;
            break;
          }
        }
        if (!blocked) result.add(i);
        continue;
      }

      final target = p + d;
      // Exact roll required to reach home.
      if (target > posHome) continue;

      var blocked = false;
      for (var j = 0; j < LudoBoard.piecesPerPlayer; j++) {
        if (j == i) continue;
        final q = mine[j];
        if (q < 0 || q == posHome) continue;
        if (target <= LudoBoard.trackLast) {
          // No stacking: own piece already on the target track cell?
          if (q <= LudoBoard.trackLast &&
              LudoBoard.absoluteOf(player, q) ==
                  LudoBoard.absoluteOf(player, target)) {
            blocked = true;
            break;
          }
        } else {
          // Home column: own piece already on the same column cell?
          if (q >= LudoBoard.homeColStart && q == target) {
            blocked = true;
            break;
          }
        }
      }
      if (!blocked) result.add(i);
    }
    return result;
  }

  /// Applies a dice roll by the current player.
  ///
  /// Returns false if the roll is not valid right now (wrong player,
  /// pending dice, or game over). Rolling a third six in a row forfeits
  /// the turn immediately.
  bool roll(int player, int value) {
    if (player != currentPlayer || dice != null || isGameOver) return false;
    if (value < 1 || value > 6) return false;

    dice = value;
    if (value == 6) {
      consecutiveSixes += 1;
    } else {
      consecutiveSixes = 0;
    }
    version++;

    if (consecutiveSixes >= 3) {
      // Third six in a row: turn forfeited.
      dice = null;
      consecutiveSixes = 0;
      currentPlayer = 1 - currentPlayer;
    }
    return true;
  }

  /// Applies a piece move by the current player.
  ///
  /// Handles captures, finishing, win detection and the extra-turn rules
  /// (extra roll on a 6, on a capture, or on sending a piece home).
  bool move(int player, int piece, int diceValue) {
    if (player != currentPlayer || dice != diceValue || isGameOver) {
      return false;
    }
    if (!movablePieces(player, diceValue).contains(piece)) return false;

    final mine = pieces[player];
    final to = mine[piece] == posBase ? 0 : mine[piece] + diceValue;
    mine[piece] = to;

    var captured = false;
    final finished = to == posHome;

    // Captures only happen on the main track and never on safe cells.
    if (to <= LudoBoard.trackLast) {
      final abs = LudoBoard.absoluteOf(player, to);
      if (!LudoBoard.isSafe(abs)) {
        final opp = pieces[1 - player];
        for (var j = 0; j < LudoBoard.piecesPerPlayer; j++) {
          final q = opp[j];
          if (q >= 0 &&
              q <= LudoBoard.trackLast &&
              LudoBoard.absoluteOf(1 - player, q) == abs) {
            opp[j] = posBase;
            captured = true;
          }
        }
      }
    }

    dice = null;
    version++;

    if (finished && mine.every((p) => p == posHome)) {
      winner = player;
      return true;
    }

    if (!captured && !finished && diceValue != 6) {
      // No extra turn: hand over and clear the six streak.
      currentPlayer = 1 - currentPlayer;
      consecutiveSixes = 0;
    }
    return true;
  }

  /// Forfeits the turn because the current player has no legal move.
  bool pass(int player) {
    if (player != currentPlayer || dice == null || isGameOver) return false;
    if (movablePieces(player).isNotEmpty) return false;
    dice = null;
    consecutiveSixes = 0;
    currentPlayer = 1 - currentPlayer;
    version++;
    return true;
  }

  /// Starts a new game: player 0 rolls first.
  void reset() {
    for (var i = 0; i < LudoBoard.piecesPerPlayer; i++) {
      pieces[0][i] = posBase;
      pieces[1][i] = posBase;
    }
    currentPlayer = 0;
    dice = null;
    consecutiveSixes = 0;
    winner = null;
    version = 0;
  }

  /// How many of [player]'s pieces have reached home.
  int homeCount(int player) =>
      pieces[player].where((p) => p == posHome).length;

  // -------------------------------------------------------------- JSON

  Map<String, dynamic> toJson() => {
        'pieces': [
          List<int>.from(pieces[0]),
          List<int>.from(pieces[1]),
        ],
        'current': currentPlayer,
        'dice': dice,
        'sixes': consecutiveSixes,
        'winner': winner,
        'v': version,
      };

  factory LudoState.fromJson(Map<String, dynamic> json) {
    final s = LudoState();
    final raw = json['pieces'] as List? ?? const [];
    for (var p = 0; p < 2; p++) {
      final row = (p < raw.length ? raw[p] : const []) as List;
      for (var i = 0; i < LudoBoard.piecesPerPlayer; i++) {
        s.pieces[p][i] = i < row.length ? (row[i] as num).toInt() : posBase;
      }
    }
    s.currentPlayer = (json['current'] as num?)?.toInt() ?? 0;
    s.dice = (json['dice'] as num?)?.toInt();
    s.consecutiveSixes = (json['sixes'] as num?)?.toInt() ?? 0;
    s.winner = (json['winner'] as num?)?.toInt();
    s.version = (json['v'] as num?)?.toInt() ?? 0;
    return s;
  }

  LudoState copy() => LudoState.fromJson(toJson());

  @override
  String toString() =>
      'LudoState(p=${pieces.map((l) => l.join('')).toList()}, cur=$currentPlayer, '
      'dice=$dice, sixes=$consecutiveSixes, winner=$winner, v=$version)';
}
