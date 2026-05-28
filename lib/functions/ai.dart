class TicTacToeAI {
  final String player = 'X'; // Maximizing player
  final String opponent = 'O'; // Minimizing player

  // Get the best move based on priorities
  int getBestMove(List<List<String>> board, int boardSize) {
    final Map<String, int> toBeReturned = () {
      Map<String, int> move = checkImmediateMoves(board, boardSize);
      if (move.isNotEmpty)
        return move; // If there's an immediate win/blocking move, return it.

      move = takeCenter(board, boardSize);
      if (move.isNotEmpty) return move; // Take center if available.

      move = takeStrategicPositions(board, boardSize);
      return move.isNotEmpty
          ? move
          : getRandomMove(
              board, boardSize); // Default to random if no strategic move
    }();

    return (toBeReturned["x"] as int) * boardSize + (toBeReturned["y"] as int);
  }

  // Check for an immediate win or block
  Map<String, int> checkImmediateMoves(
      List<List<String>> board, int boardSize) {
    for (int i = 0; i < boardSize; i++) {
      // Check rows and columns
      Map<String, int>? rowMove = findWinningMove(board, i, 0, 0, 1, boardSize);
      if (rowMove != null) return rowMove;

      Map<String, int>? colMove = findWinningMove(board, 0, i, 1, 0, boardSize);
      if (colMove != null) return colMove;
    }

    // Check diagonals
    Map<String, int>? diag1Move = findWinningMove(board, 0, 0, 1, 1, boardSize);
    if (diag1Move != null) return diag1Move;

    Map<String, int>? diag2Move =
        findWinningMove(board, 0, boardSize - 1, 1, -1, boardSize);
    return diag2Move ?? {}; // Return empty if no winning move/block found
  }

  // Find winning/blocking move in a line (row/column/diagonal)
  Map<String, int>? findWinningMove(List<List<String>> board, int startX,
      int startY, int dirX, int dirY, int boardSize) {
    int playerCount = 0, opponentCount = 0;
    Map<String, int> winningMove = {};
    for (int i = 0; i < boardSize; i++) {
      int x = startX + i * dirX;
      int y = startY + i * dirY;
      if (board[x][y] == player)
        playerCount++;
      else if (board[x][y] == opponent)
        opponentCount++;
      else
        winningMove = {'x': x, 'y': y};
    }

    if (playerCount == boardSize - 1 && winningMove.isNotEmpty)
      return winningMove;
    if (opponentCount == boardSize - 1 && winningMove.isNotEmpty)
      return winningMove;

    return null;
  }

  // Take the center if available (important strategic move)
  Map<String, int> takeCenter(List<List<String>> board, int boardSize) {
    if (boardSize % 2 == 1 && board[boardSize ~/ 2][boardSize ~/ 2] == '') {
      return {'x': boardSize ~/ 2, 'y': boardSize ~/ 2};
    }
    return {}; // Return empty if center is unavailable
  }

  // Take strategic positions like corners and edges
  Map<String, int> takeStrategicPositions(
      List<List<String>> board, int boardSize) {
    List<Map<String, int>> strategicPositions = [
      {'x': 0, 'y': 0}, {'x': 0, 'y': boardSize - 1}, // Corners
      {'x': boardSize - 1, 'y': 0}, {'x': boardSize - 1, 'y': boardSize - 1},
      {'x': 0, 'y': boardSize ~/ 2}, // Edges
      {'x': boardSize - 1, 'y': boardSize ~/ 2},
      {'x': boardSize ~/ 2, 'y': 0}, {'x': boardSize ~/ 2, 'y': boardSize - 1}
    ];

    for (var position in strategicPositions) {
      if (board[position['x']!][position['y']!] == '') {
        return position;
      }
    }

    return {}; // No strategic positions left
  }

  // Get a random move if no strategic move is available
  Map<String, int> getRandomMove(List<List<String>> board, int boardSize) {
    List<Map<String, int>> availableMoves = [];
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] == '') {
          availableMoves.add({'x': i, 'y': j});
        }
      }
    }
    if (availableMoves.isNotEmpty) {
      return availableMoves[(availableMoves.length *
          (new DateTime.now().millisecondsSinceEpoch % 1000) ~/
          1000)];
    }
    return {}; // No moves left
  }
}
