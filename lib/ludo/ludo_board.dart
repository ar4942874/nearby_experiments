/// Board geometry for two-player Ludo on a standard 15×15 grid.
///
/// Coordinates are `(row, col)` with row 0 at the top and col 0 at the
/// left.
///
/// ```
/// cols:   0 1 2 3 4 5 | 6 7 8 | 9 10 11 12 13 14
/// rows  0-5:  [P1 BASE] | path  | [unused base]
/// rows  6-8:  path      | CENTER| path
/// rows  9-14: [unused base] | path | [P2 BASE]
/// ```
///
/// Player 0 (the host) sits top-left, player 1 (the guest) sits
/// bottom-right — opposite corners of the board.
///
/// The 52-cell main track is a CLOCKWISE loop. Player-relative
/// positions map onto it as `path[(startIndex + rel) % 52]`; the two
/// starts are 13 cells apart (4 × 13 = 52), which keeps the players on
/// opposite corners and the game symmetric.
class LudoBoard {
  LudoBoard._();

  static const int size = 15;
  static const int piecesPerPlayer = 4;

  /// Last relative position still on the main track.
  static const int trackLast = 50;

  /// Relative positions of the 5-cell home column.
  static const int homeColStart = 51;
  static const int homeColEnd = 55;

  /// Relative position of a piece that has reached the center.
  static const int finished = 56;

  /// The 52 main-track cells as (row, col), clockwise.
  /// Index 0 is player 0's entry cell.
  static const List<List<int>> path = [
    // 0–4    left arm, top row, →
    [6, 1], [6, 2], [6, 3], [6, 4], [6, 5],
    // 5–10   top arm, left column, ↑
    [5, 6], [4, 6], [3, 6], [2, 6], [1, 6], [0, 6],
    // 11–12  top edge, →
    [0, 7], [0, 8],
    // 13–17  top arm, right column, ↓
    [1, 8], [2, 8], [3, 8], [4, 8], [5, 8],
    // 18–22  right arm, top row, →
    [6, 9], [6, 10], [6, 11], [6, 12], [6, 13],
    // 23–25  right edge, ↓
    [6, 14], [7, 14], [8, 14],
    // 26–30  right arm, bottom row, ←  (index 26 = player 1's entry)
    [8, 13], [8, 12], [8, 11], [8, 10], [8, 9],
    // 31–36  bottom arm, right column, ↓
    [9, 8], [10, 8], [11, 8], [12, 8], [13, 8], [14, 8],
    // 37–38  bottom edge, ←
    [14, 7], [14, 6],
    // 39–43  bottom arm, left column, ↑
    [13, 6], [12, 6], [11, 6], [10, 6], [9, 6],
    // 44–48  left arm, bottom row, ←
    [8, 5], [8, 4], [8, 3], [8, 2], [8, 1],
    // 49–51  left edge, ↑
    [8, 0], [7, 0], [6, 0],
  ];

  /// Where each player enters the track after rolling a 6:
  /// relative 0 maps to `path[startIndex[player]]`.
  static const List<int> startIndex = [0, 26];

  /// Home columns (entrance → center), 5 cells each.
  static const List<List<List<int>>> homeCols = [
    // Player 0: row 7, cols 1→5 (entered from [7,0] = relative 50)
    [
      [7, 1], [7, 2], [7, 3], [7, 4], [7, 5]
    ],
    // Player 1: row 7, cols 13→9 (entered from [7,14] = relative 50)
    [
      [7, 13], [7, 12], [7, 11], [7, 10], [7, 9]
    ],
  ];

  /// Safe (star) cells — absolute path indices. Pieces on them cannot be
  /// captured. The four start cells plus four intermediate stars.
  static const Set<int> safeCells = {0, 8, 13, 21, 26, 34, 39, 47};

  /// Piece parking spots inside each 6×6 base (slot index = piece index).
  static const List<List<List<int>>> baseSlots = [
    [
      [2, 2], [2, 3], [3, 2], [3, 3]
    ],
    [
      [11, 11], [11, 12], [12, 11], [12, 12]
    ],
  ];

  /// Top-left cell of each player's 6×6 base area.
  static const List<List<int>> baseOrigin = [
    [0, 0],
    [9, 9],
  ];

  /// The two bases that are not used in two-player mode (decorative).
  static const List<List<int>> unusedBaseOrigin = [
    [0, 9],
    [9, 0],
  ];

  /// Absolute track index for a player-relative main-track position.
  static int absoluteOf(int player, int rel) => (startIndex[player] + rel) % 52;

  /// Board cell for a piece on the board (relative 0..55).
  /// Returns null for [finished] (drawn in the center triangle) or for an
  /// out-of-range value.
  static List<int>? cellOf(int player, int rel) {
    if (rel <= trackLast) return path[absoluteOf(player, rel)];
    if (rel >= homeColStart && rel <= homeColEnd) {
      return homeCols[player][rel - homeColStart];
    }
    return null;
  }

  static bool isSafe(int absoluteIndex) => safeCells.contains(absoluteIndex);

  /// Is this cell a main-track cell? (Home-column / center cells are not.)
  static bool isTrackCell(int row, int col) {
    for (var i = 0; i < path.length; i++) {
      final c = path[i];
      if (c[0] == row && c[1] == col) return true;
    }
    return false;
  }
}
