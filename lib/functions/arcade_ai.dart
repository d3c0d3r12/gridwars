import 'dart:math';

// ════════════════════════════════════════════════════════════════════════════
// Local bot engines for the 6 arcade games (free "vs Computer" practice mode).
// Every engine is pure (no Firebase, no state) — it takes the current board and
// returns the bot's move. level: 0=Easy, 1=Medium, 2=Hard.
// Board encodings match each game screen exactly:
//   players are numbered 1 (P1 / human) and 2 (P2 / bot); 0 = empty cell.
// ════════════════════════════════════════════════════════════════════════════

final _rng = Random();

// ── Connect 4 ────────────────────────────────────────────────────────────────
// board: 42 ints, index = row*7 + col, row 0 = top .. 5 = bottom.
class Connect4Ai {
  static const _rows = 6, _cols = 7;

  /// Returns the column (0..6) the bot should drop into.
  static int bestMove(List<int> board, int ai, int human, int level) {
    final valid = _validCols(board);
    if (valid.isEmpty) return -1;

    // Easy: win if possible, sometimes block, otherwise random.
    if (level == 0) {
      final w = _findImmediate(board, ai);
      if (w != null) return w;
      final b = _findImmediate(board, human);
      if (b != null && _rng.nextDouble() > 0.4) return b;
      return valid[_rng.nextInt(valid.length)];
    }

    final depth = level == 2 ? 6 : 4;
    int bestScore = -1 << 30;
    int best = valid[_rng.nextInt(valid.length)];
    for (final c in _ordered(valid)) {
      final row = _dropRow(board, c);
      if (row < 0) continue;
      final next = List<int>.from(board)..[row * _cols + c] = ai;
      final score = _minimax(next, depth - 1, -(1 << 30), 1 << 30, false, ai, human);
      if (score > bestScore) { bestScore = score; best = c; }
    }
    return best;
  }

  static int _minimax(List<int> b, int depth, int alpha, int beta, bool maxing, int ai, int human) {
    if (_wins(b, ai)) return 100000 + depth;
    if (_wins(b, human)) return -100000 - depth;
    final valid = _validCols(b);
    if (depth == 0 || valid.isEmpty) return _eval(b, ai, human);

    if (maxing) {
      int v = -(1 << 30);
      for (final c in _ordered(valid)) {
        final row = _dropRow(b, c);
        final nb = List<int>.from(b)..[row * _cols + c] = ai;
        v = max(v, _minimax(nb, depth - 1, alpha, beta, false, ai, human));
        alpha = max(alpha, v);
        if (alpha >= beta) break;
      }
      return v;
    } else {
      int v = 1 << 30;
      for (final c in _ordered(valid)) {
        final row = _dropRow(b, c);
        final nb = List<int>.from(b)..[row * _cols + c] = human;
        v = min(v, _minimax(nb, depth - 1, alpha, beta, true, ai, human));
        beta = min(beta, v);
        if (alpha >= beta) break;
      }
      return v;
    }
  }

  static List<int> _validCols(List<int> b) =>
      [for (int c = 0; c < _cols; c++) if (b[c] == 0) c];

  static List<int> _ordered(List<int> cols) {
    // Centre-first improves alpha-beta pruning and play strength.
    const order = [3, 2, 4, 1, 5, 0, 6];
    return [for (final c in order) if (cols.contains(c)) c];
  }

  static int _dropRow(List<int> b, int col) {
    for (int r = _rows - 1; r >= 0; r--) if (b[r * _cols + col] == 0) return r;
    return -1;
  }

  static int? _findImmediate(List<int> b, int player) {
    for (final c in _validCols(b)) {
      final r = _dropRow(b, c);
      final nb = List<int>.from(b)..[r * _cols + c] = player;
      if (_wins(nb, player)) return c;
    }
    return null;
  }

  static bool _wins(List<int> b, int p) {
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        if (b[r * _cols + c] != p) continue;
        for (final d in const [[0, 1], [1, 0], [1, 1], [1, -1]]) {
          int cnt = 1, rr = r + d[0], cc = c + d[1];
          while (rr >= 0 && rr < _rows && cc >= 0 && cc < _cols && b[rr * _cols + cc] == p) {
            cnt++; rr += d[0]; cc += d[1];
          }
          if (cnt >= 4) return true;
        }
      }
    }
    return false;
  }

  static int _eval(List<int> b, int ai, int human) {
    int score = 0;
    // Prefer centre column.
    for (int r = 0; r < _rows; r++) if (b[r * _cols + 3] == ai) score += 3;
    // Score every 4-window.
    void windows(List<int> idxs) {
      int a = 0, h = 0, e = 0;
      for (final i in idxs) {
        if (b[i] == ai) a++; else if (b[i] == human) h++; else e++;
      }
      if (a > 0 && h > 0) return; // mixed, no value
      if (a == 3 && e == 1) score += 50;
      else if (a == 2 && e == 2) score += 10;
      if (h == 3 && e == 1) score -= 80;
      else if (h == 2 && e == 2) score -= 8;
    }
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        if (c + 3 < _cols) windows([for (int i = 0; i < 4; i++) r * _cols + c + i]);
        if (r + 3 < _rows) windows([for (int i = 0; i < 4; i++) (r + i) * _cols + c]);
        if (r + 3 < _rows && c + 3 < _cols) windows([for (int i = 0; i < 4; i++) (r + i) * _cols + c + i]);
        if (r + 3 < _rows && c - 3 >= 0) windows([for (int i = 0; i < 4; i++) (r + i) * _cols + c - i]);
      }
    }
    return score;
  }
}

// ── Gomoku ───────────────────────────────────────────────────────────────────
// board: N*N ints (N=11). Heuristic threat-scoring (fast and strong).
class GomokuAi {
  /// Returns the cell index the bot should play.
  static int bestMove(List<int> board, int n, int ai, int human, int level) {
    final empties = <int>[];
    bool anyStone = false;
    for (int i = 0; i < board.length; i++) {
      if (board[i] != 0) anyStone = true;
      if (board[i] == 0) empties.add(i);
    }
    if (empties.isEmpty) return -1;
    if (!anyStone) return (n ~/ 2) * n + (n ~/ 2); // open centre

    // Only consider cells near existing stones (huge speedup, no strength loss).
    final candidates = _nearby(board, n);
    final pool = candidates.isEmpty ? empties : candidates;

    int best = pool.first, bestScore = -1;
    final offenseW = level == 0 ? 1.0 : 1.0;
    final defenseW = level == 2 ? 1.15 : (level == 1 ? 1.0 : 0.8);
    for (final i in pool) {
      final atk = _score(board, n, i, ai);
      final def = (_score(board, n, i, human) * defenseW).round();
      var s = (atk * offenseW).round() + def;
      if (level == 0) s += _rng.nextInt(40); // Easy: noisier
      if (s > bestScore) { bestScore = s; best = i; }
    }
    return best;
  }

  static List<int> _nearby(List<int> b, int n) {
    final set = <int>{};
    for (int i = 0; i < b.length; i++) {
      if (b[i] == 0) continue;
      final r = i ~/ n, c = i % n;
      for (int dr = -2; dr <= 2; dr++) {
        for (int dc = -2; dc <= 2; dc++) {
          final rr = r + dr, cc = c + dc;
          if (rr >= 0 && rr < n && cc >= 0 && cc < n && b[rr * n + cc] == 0) {
            set.add(rr * n + cc);
          }
        }
      }
    }
    return set.toList();
  }

  // Score a candidate cell for `player` by the line potential it creates.
  static int _score(List<int> b, int n, int idx, int player) {
    final r = idx ~/ n, c = idx % n;
    int total = 0;
    for (final d in const [[0, 1], [1, 0], [1, 1], [1, -1]]) {
      int run = 1, openEnds = 0;
      for (final sign in const [-1, 1]) {
        int rr = r + d[0] * sign, cc = c + d[1] * sign;
        while (rr >= 0 && rr < n && cc >= 0 && cc < n && b[rr * n + cc] == player) {
          run++; rr += d[0] * sign; cc += d[1] * sign;
        }
        if (rr >= 0 && rr < n && cc >= 0 && cc < n && b[rr * n + cc] == 0) openEnds++;
      }
      if (run >= 5) total += 1000000;
      else if (run == 4 && openEnds == 2) total += 100000;
      else if (run == 4 && openEnds == 1) total += 10000;
      else if (run == 3 && openEnds == 2) total += 5000;
      else if (run == 3 && openEnds == 1) total += 500;
      else if (run == 2 && openEnds == 2) total += 200;
      else total += run;
    }
    return total;
  }
}

// ── Checkers ─────────────────────────────────────────────────────────────────
// board: 64 ints. 1=P1 man, 2=P2 man, 3=P1 king, 4=P2 king. 0=empty.
// P1 men move up (decreasing row); P2 men move down. Kings both ways.
class CheckersMove {
  final int from, to;
  final bool isJump;
  const CheckersMove(this.from, this.to, this.isJump);
}

class CheckersAi {
  /// Returns the bot's chosen single move (jump or step), or null if none.
  static CheckersMove? bestMove(List<int> board, int ai, int level) {
    final moves = allMoves(board, ai);
    if (moves.isEmpty) return null;
    // Rule parity with the screen: jumps are offered per-piece, not globally
    // forced — but a decent bot should prefer captures.
    final jumps = moves.where((m) => m.isJump).toList();
    final pool = jumps.isNotEmpty ? jumps : moves;

    if (level == 0) return pool[_rng.nextInt(pool.length)];

    final depth = level == 2 ? 6 : 3;
    int bestScore = -1 << 30;
    CheckersMove best = pool.first;
    for (final m in pool) {
      final nb = apply(board, m);
      final score = -_negamax(nb, _opp(ai), ai, depth - 1, -(1 << 30), 1 << 30);
      if (score > bestScore) { bestScore = score; best = m; }
    }
    return best;
  }

  /// After a jump, the same piece may have further jumps (chain). Returns the
  /// next landing square from `from`, or -1 if the chain ends.
  static int continueJump(List<int> board, int from) {
    final js = _movesFor(board, from).where((m) => m.isJump).toList();
    if (js.isEmpty) return -1;
    return js.first.to;
  }

  static int _opp(int p) => p == 1 ? 2 : 1;
  static bool _isOwn(int cell, int p) => p == 1 ? (cell == 1 || cell == 3) : (cell == 2 || cell == 4);

  static List<CheckersMove> allMoves(List<int> b, int player) {
    final out = <CheckersMove>[];
    final jumps = <CheckersMove>[];
    for (int i = 0; i < 64; i++) {
      if (!_isOwn(b[i], player)) continue;
      for (final m in _movesFor(b, i)) {
        if (m.isJump) jumps.add(m); else out.add(m);
      }
    }
    return jumps.isNotEmpty ? jumps : out;
  }

  static List<CheckersMove> _movesFor(List<int> b, int from) {
    final piece = b[from];
    if (piece == 0) return const [];
    final isKing = piece == 3 || piece == 4;
    final owner = (piece == 1 || piece == 3) ? 1 : 2;
    final r = from ~/ 8, c = from % 8;
    final dirs = <List<int>>[];
    if (owner == 1 || isKing) dirs.addAll(const [[-1, -1], [-1, 1]]);
    if (owner == 2 || isKing) dirs.addAll(const [[1, -1], [1, 1]]);

    final jumps = <CheckersMove>[];
    for (final d in dirs) {
      final nr = r + d[0], nc = c + d[1];
      final jr = r + d[0] * 2, jc = c + d[1] * 2;
      if (jr >= 0 && jr < 8 && jc >= 0 && jc < 8) {
        final mid = nr * 8 + nc, jump = jr * 8 + jc;
        if (_isOwn(b[mid], _opp(owner)) && b[jump] == 0) {
          jumps.add(CheckersMove(from, jump, true));
        }
      }
    }
    if (jumps.isNotEmpty) return jumps;

    final steps = <CheckersMove>[];
    for (final d in dirs) {
      final nr = r + d[0], nc = c + d[1];
      if (nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && b[nr * 8 + nc] == 0) {
        steps.add(CheckersMove(from, nr * 8 + nc, false));
      }
    }
    return steps;
  }

  /// Apply a move to a copy and return the new board (handles capture + kinging
  /// + chained jumps, matching the screen's `_move`).
  static List<int> apply(List<int> board, CheckersMove m) {
    final b = List<int>.from(board);
    int from = m.from, to = m.to;
    b[to] = b[from];
    b[from] = 0;
    if ((from ~/ 8 - to ~/ 8).abs() == 2) {
      final mid = ((from ~/ 8 + to ~/ 8) ~/ 2) * 8 + (from % 8 + to % 8) ~/ 2;
      b[mid] = 0;
      // chain jumps
      int next = continueJump(b, to);
      while (next >= 0) {
        final cmid = ((to ~/ 8 + next ~/ 8) ~/ 2) * 8 + (to % 8 + next % 8) ~/ 2;
        b[next] = b[to]; b[to] = 0; b[cmid] = 0;
        to = next;
        next = continueJump(b, to);
      }
    }
    if (b[to] == 1 && to ~/ 8 == 0) b[to] = 3;
    if (b[to] == 2 && to ~/ 8 == 7) b[to] = 4;
    return b;
  }

  static int _negamax(List<int> b, int player, int rootAi, int depth, int alpha, int beta) {
    final moves = allMoves(b, player);
    if (depth == 0 || moves.isEmpty) {
      final e = _eval(b, rootAi);
      return player == rootAi ? e : -e;
    }
    int v = -(1 << 30);
    for (final m in moves) {
      final nb = apply(b, m);
      v = max(v, -_negamax(nb, _opp(player), rootAi, depth - 1, -beta, -alpha));
      alpha = max(alpha, v);
      if (alpha >= beta) break;
    }
    return v;
  }

  static int _eval(List<int> b, int ai) {
    int score = 0;
    for (int i = 0; i < 64; i++) {
      final cell = b[i];
      if (cell == 0) continue;
      final isKing = cell == 3 || cell == 4;
      final owner = (cell == 1 || cell == 3) ? 1 : 2;
      final val = isKing ? 5 : 3;
      // Advancement bonus for men.
      final r = i ~/ 8;
      final adv = isKing ? 0 : (owner == 1 ? (7 - r) : r);
      final mine = owner == ai;
      score += (mine ? 1 : -1) * (val * 10 + adv);
    }
    return score; // already relative to `ai`
  }
}

// ── Dots & Boxes ─────────────────────────────────────────────────────────────
// hLines[20]=5r×4c, vLines[20]=4r×5c, boxes[16]=4×4.
class DotsMove {
  final bool isH;
  final int index;
  const DotsMove(this.isH, this.index);
}

class DotsBoxesAi {
  /// Pick a line for the bot. Strategy: take a free box if available; otherwise
  /// play a "safe" line that doesn't hand the opponent a 3-sided box; if none is
  /// safe, give away the smallest sacrifice.
  static DotsMove? bestMove(List<int> h, List<int> v, List<int> boxes, int level) {
    final moves = _freeLines(h, v);
    if (moves.isEmpty) return null;

    // 1) Complete a box right now.
    for (final m in moves) {
      if (_boxesCompletedBy(h, v, m) > 0) return m;
    }
    if (level == 0) return moves[_rng.nextInt(moves.length)];

    // 2) Safe moves: don't create a box with exactly 3 sides for the opponent.
    final safe = <DotsMove>[];
    for (final m in moves) {
      if (!_createsThreeSided(h, v, m)) safe.add(m);
    }
    if (safe.isNotEmpty) return safe[_rng.nextInt(safe.length)];

    // 3) Forced to give away — Hard picks the move opening the smallest chain.
    if (level == 2) {
      DotsMove worstLeast = moves.first;
      int leastGiven = 1 << 30;
      for (final m in moves) {
        final g = _chainSizeOpened(h, v, m);
        if (g < leastGiven) { leastGiven = g; worstLeast = m; }
      }
      return worstLeast;
    }
    return moves[_rng.nextInt(moves.length)];
  }

  static List<DotsMove> _freeLines(List<int> h, List<int> v) => [
        for (int i = 0; i < h.length; i++) if (h[i] == 0) DotsMove(true, i),
        for (int i = 0; i < v.length; i++) if (v[i] == 0) DotsMove(false, i),
      ];

  static int _sides(List<int> h, List<int> v, int br, int bc) {
    int s = 0;
    if (h[br * 4 + bc] != 0) s++;
    if (h[(br + 1) * 4 + bc] != 0) s++;
    if (v[br * 5 + bc] != 0) s++;
    if (v[br * 5 + bc + 1] != 0) s++;
    return s;
  }

  // Boxes adjacent to a given line.
  static List<List<int>> _adjBoxes(DotsMove m) {
    final out = <List<int>>[];
    if (m.isH) {
      final r = m.index ~/ 4, c = m.index % 4;
      if (r - 1 >= 0) out.add([r - 1, c]);
      if (r < 4) out.add([r, c]);
    } else {
      final r = m.index ~/ 5, c = m.index % 5;
      if (c - 1 >= 0) out.add([r, c - 1]);
      if (c < 4) out.add([r, c]);
    }
    return out;
  }

  static int _boxesCompletedBy(List<int> h, List<int> v, DotsMove m) {
    int n = 0;
    for (final bx in _adjBoxes(m)) {
      if (_sides(h, v, bx[0], bx[1]) == 3) n++;
    }
    return n;
  }

  static bool _createsThreeSided(List<int> h, List<int> v, DotsMove m) {
    for (final bx in _adjBoxes(m)) {
      if (_sides(h, v, bx[0], bx[1]) == 2) return true; // would become 3
    }
    return false;
  }

  // Rough size of the chain a sacrifice opens (count of boxes that would become
  // takeable). Good enough to prefer the least costly sacrifice.
  static int _chainSizeOpened(List<int> h, List<int> v, DotsMove m) {
    int n = 0;
    for (final bx in _adjBoxes(m)) {
      if (_sides(h, v, bx[0], bx[1]) == 2) n++;
    }
    return n;
  }
}

// ── Battleship ───────────────────────────────────────────────────────────────
// 10×10 grids (100 ints). attacks: 0=not tried, 1=tried. ships: 1=ship cell.
class BattleshipAi {
  /// Next cell the bot fires at, given its own attack history and the human's
  /// ship layout (so it can read its own hits).
  static int nextAttack(List<int> humanShips, List<int> aiAttacks, int level) {
    final untried = [for (int i = 0; i < 100; i++) if (aiAttacks[i] == 0) i];
    if (untried.isEmpty) return -1;

    // Target mode: extend from any existing hit.
    // A cell is a known hit if it was fired at (non-zero) and held a ship.
    final hits = [for (int i = 0; i < 100; i++) if (aiAttacks[i] != 0 && humanShips[i] == 1) i];
    if (level >= 1 && hits.isNotEmpty) {
      // Prefer continuing along a line of 2+ aligned hits.
      final targets = <int>{};
      for (final hcell in hits) {
        final r = hcell ~/ 10, c = hcell % 10;
        for (final d in const [[0, 1], [0, -1], [1, 0], [-1, 0]]) {
          final rr = r + d[0], cc = c + d[1];
          if (rr < 0 || rr >= 10 || cc < 0 || cc >= 10) continue;
          final idx = rr * 10 + cc;
          if (aiAttacks[idx] == 0) targets.add(idx);
        }
      }
      // Weight cells that line up with two hits.
      int? bestLine;
      for (final t in targets) {
        final r = t ~/ 10, c = t % 10;
        for (final d in const [[0, 1], [1, 0]]) {
          final a = (r - d[0]) * 10 + (c - d[1]);
          final b = (r + d[0]) * 10 + (c + d[1]);
          final aHit = _valid(r - d[0], c - d[1]) && aiAttacks[a] != 0 && humanShips[a] == 1;
          final bHit = _valid(r + d[0], c + d[1]) && aiAttacks[b] != 0 && humanShips[b] == 1;
          if (aHit || bHit) bestLine = t;
        }
      }
      if (bestLine != null) return bestLine;
      if (targets.isNotEmpty) return targets.elementAt(_rng.nextInt(targets.length));
    }

    // Hunt mode: Medium/Hard use a checkerboard parity (ships span ≥2 cells).
    if (level >= 1) {
      final parity = [for (final i in untried) if (((i ~/ 10) + (i % 10)) % 2 == 0) i];
      if (parity.isNotEmpty) return parity[_rng.nextInt(parity.length)];
    }
    return untried[_rng.nextInt(untried.length)];
  }

  static bool _valid(int r, int c) => r >= 0 && r < 10 && c >= 0 && c < 10;
}

// ── Rock Paper Scissors ──────────────────────────────────────────────────────
class RpsAi {
  static const _choices = ['rock', 'paper', 'scissors'];
  static const _counter = {'rock': 'paper', 'paper': 'scissors', 'scissors': 'rock'};

  /// `history` = the human's past choices, in order.
  /// - Easy: random.
  /// - Medium: counters your most-frequent throw, 35% of the time random.
  /// - Hard: a last-move Markov predictor — learns "after you play X you tend to
  ///   play Y" and counters the predicted Y. Falls back to frequency until it has
  ///   enough data. This beats humans who fall into patterns.
  static String pick(List<String> history, int level) {
    if (level == 0 || history.isEmpty) return _choices[_rng.nextInt(3)];

    if (level == 1) {
      if (_rng.nextDouble() < 0.35) return _choices[_rng.nextInt(3)];
      return _counter[_mostFrequent(history)]!;
    }

    // Hard: Markov on the human's last move.
    final last = history.last;
    final trans = <String, Map<String, int>>{
      'rock': {'rock': 0, 'paper': 0, 'scissors': 0},
      'paper': {'rock': 0, 'paper': 0, 'scissors': 0},
      'scissors': {'rock': 0, 'paper': 0, 'scissors': 0},
    };
    for (int i = 0; i < history.length - 1; i++) {
      final from = history[i], to = history[i + 1];
      if (trans.containsKey(from) && trans[from]!.containsKey(to)) {
        trans[from]![to] = trans[from]![to]! + 1;
      }
    }
    final row = trans[last]!;
    final totalFromLast = row.values.fold(0, (a, b) => a + b);
    // Not enough pattern data yet → fall back to overall frequency.
    if (totalFromLast < 2) return _counter[_mostFrequent(history)]!;

    String predicted = 'rock';
    int best = -1;
    row.forEach((k, val) { if (val > best) { best = val; predicted = k; } });
    return _counter[predicted]!;
  }

  static String _mostFrequent(List<String> history) {
    final counts = <String, int>{'rock': 0, 'paper': 0, 'scissors': 0};
    for (final h in history) {
      if (counts.containsKey(h)) counts[h] = counts[h]! + 1;
    }
    String likely = 'rock';
    int best = -1;
    counts.forEach((k, val) { if (val > best) { best = val; likely = k; } });
    return likely;
  }
}
