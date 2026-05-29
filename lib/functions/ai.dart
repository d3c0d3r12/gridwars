import 'dart:math';

class TicTacToeAI {
  static const String _ai = 'X';
  static const String _human = 'O';
  static const int _win = 10000;

  // Entry point.
  // board: flat list — empty cells hold their int index, occupied cells hold 'X' or 'O'.
  // level: 0=Easy, 1=Medium, 2=Hard
  int getBestMove(List board, int boardSize, int level) {
    final List<int> empty = _emptyIndices(board, boardSize);
    if (empty.isEmpty) return -1;

    // Easy: take immediate win, maybe block, otherwise random
    if (level == 0) {
      final win = _immediateMove(board, boardSize, _ai);
      if (win != null) return win;
      final block = _immediateMove(board, boardSize, _human);
      if (block != null && Random().nextDouble() > 0.4) return block;
      return empty[Random().nextInt(empty.length)];
    }

    final int depth = _searchDepth(boardSize, level, empty.length);
    int bestScore = -999999;
    int bestMove = _orderMoves(empty, boardSize).first;

    for (final move in _orderMoves(empty, boardSize)) {
      final copy = List.from(board);
      copy[move] = _ai;
      final score = _alphaBeta(copy, boardSize, depth - 1, -999999, 999999, false);
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }
    return bestMove;
  }

  int _alphaBeta(List board, int boardSize, int depth, int alpha, int beta, bool maximizing) {
    if (_wins(board, boardSize, _ai)) return _win + depth;
    if (_wins(board, boardSize, _human)) return -_win - depth;

    final empty = _emptyIndices(board, boardSize);
    if (empty.isEmpty) return 0;
    if (depth == 0) return _evaluate(board, boardSize);

    if (maximizing) {
      int best = -999999;
      for (final m in _orderMoves(empty, boardSize)) {
        final copy = List.from(board);
        copy[m] = _ai;
        best = max(best, _alphaBeta(copy, boardSize, depth - 1, alpha, beta, false));
        alpha = max(alpha, best);
        if (beta <= alpha) break;
      }
      return best;
    } else {
      int best = 999999;
      for (final m in _orderMoves(empty, boardSize)) {
        final copy = List.from(board);
        copy[m] = _human;
        best = min(best, _alphaBeta(copy, boardSize, depth - 1, alpha, beta, true));
        beta = min(beta, best);
        if (beta <= alpha) break;
      }
      return best;
    }
  }

  // Heuristic for non-terminal states: score each line by threat count
  int _evaluate(List board, int boardSize) {
    int score = 0;
    for (final line in _lines(boardSize)) {
      int ai = 0, human = 0;
      for (final idx in line) {
        if (board[idx] == _ai) ai++;
        else if (board[idx] == _human) human++;
      }
      if (human == 0) score += _threat(ai, boardSize);
      if (ai == 0) score -= _threat(human, boardSize) * 2; // Weight defence higher
    }
    // Bonus for holding center
    final center = (boardSize * boardSize) ~/ 2;
    if (board[center] == _ai) score += 30;
    else if (board[center] == _human) score -= 30;
    return score;
  }

  int _threat(int count, int n) {
    if (count == n - 1) return 500;
    if (count == n - 2 && n > 3) return 50;
    if (count == 1) return 2;
    return 0;
  }

  // Adaptive depth: deeper on small boards and hard difficulty
  int _searchDepth(int boardSize, int level, int emptyCount) {
    if (boardSize == 3) return level == 2 ? 9 : 4;
    if (boardSize == 4) return level == 2 ? min(7, emptyCount) : min(4, emptyCount);
    // 5x5
    return level == 2 ? min(5, emptyCount) : min(3, emptyCount);
  }

  // Move ordering: center → corners → edges → interior (improves alpha-beta pruning)
  List<int> _orderMoves(List<int> moves, int boardSize) {
    final n = boardSize;
    final center = (n * n) ~/ 2;
    final corners = {0, n - 1, n * (n - 1), n * n - 1};
    final priority = <int, int>{};
    for (final m in moves) {
      if (m == center) {
        priority[m] = 0;
      } else if (corners.contains(m)) {
        priority[m] = 1;
      } else if (m ~/ n == 0 || m ~/ n == n - 1 || m % n == 0 || m % n == n - 1) {
        priority[m] = 2;
      } else {
        priority[m] = 3;
      }
    }
    return List.from(moves)..sort((a, b) => priority[a]!.compareTo(priority[b]!));
  }

  // Returns the index of an immediate win or block, or null
  int? _immediateMove(List board, int boardSize, String piece) {
    for (final i in _emptyIndices(board, boardSize)) {
      final copy = List.from(board);
      copy[i] = piece;
      if (_wins(copy, boardSize, piece)) return i;
    }
    return null;
  }

  List<int> _emptyIndices(List board, int boardSize) {
    final result = <int>[];
    for (int i = 0; i < boardSize * boardSize; i++) {
      if (board[i] != _ai && board[i] != _human) result.add(i);
    }
    return result;
  }

  bool _wins(List board, int boardSize, String piece) {
    for (final line in _lines(boardSize)) {
      if (line.every((i) => board[i] == piece)) return true;
    }
    return false;
  }

  // All winning lines (rows, columns, both diagonals)
  List<List<int>> _lines(int n) {
    final lines = <List<int>>[];
    for (int r = 0; r < n; r++) {
      lines.add(List.generate(n, (c) => r * n + c));
    }
    for (int c = 0; c < n; c++) {
      lines.add(List.generate(n, (r) => r * n + c));
    }
    lines.add(List.generate(n, (i) => i * n + i));
    lines.add(List.generate(n, (i) => i * n + (n - 1 - i)));
    return lines;
  }
}
