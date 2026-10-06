class TicTacToeState {
  List<List<String>> board;
  String currentPlayer;
  String? winner;
  bool isGameOver;

  TicTacToeState({
    List<List<String>>? board,
    this.currentPlayer = "X",
    this.winner,
    this.isGameOver = false,
  }) : board = board ?? List.generate(3, (_) => List.filled(3, ""));

  // Make a move
  bool makeMove(int row, int col, {String? player}) {
    if (board[row][col] == "" && !isGameOver) {
      board[row][col] = player ?? currentPlayer;
      winner = _checkWinner();
      
      if (winner != null || isDraw()) {
        isGameOver = true;
      } else {
        currentPlayer = currentPlayer == "X" ? "O" : "X";
      }
      return true;
    }
    return false;
  }

  // Check winner
  String? _checkWinner() {
    // Check rows
    for (int i = 0; i < 3; i++) {
      if (board[i][0] != "" && 
          board[i][0] == board[i][1] && 
          board[i][1] == board[i][2]) {
        return board[i][0];
      }
    }

    // Check columns
    for (int i = 0; i < 3; i++) {
      if (board[0][i] != "" && 
          board[0][i] == board[1][i] && 
          board[1][i] == board[2][i]) {
        return board[0][i];
      }
    }

    // Check diagonals
    if (board[0][0] != "" && 
        board[0][0] == board[1][1] && 
        board[1][1] == board[2][2]) {
      return board[0][0];
    }
    
    if (board[0][2] != "" && 
        board[0][2] == board[1][1] && 
        board[1][1] == board[2][0]) {
      return board[0][2];
    }

    return null;
  }

  // Check draw
  bool isDraw() {
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (board[i][j] == "") return false;
      }
    }
    return winner == null;
  }

  // Reset game
  void reset() {
    board = List.generate(3, (_) => List.filled(3, ""));
    currentPlayer = "X";
    winner = null;
    isGameOver = false;
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'board': board,
      'currentPlayer': currentPlayer,
      'winner': winner,
      'isGameOver': isGameOver,
    };
  }

  // From JSON
  factory TicTacToeState.fromJson(Map<String, dynamic> json) {
    return TicTacToeState(
      board: (json['board'] as List).map((row) => 
        (row as List).map((cell) => cell.toString()).toList()
      ).toList(),
      currentPlayer: json['currentPlayer'] ?? "X",
      winner: json['winner'],
      isGameOver: json['isGameOver'] ?? false,
    );
  }
}