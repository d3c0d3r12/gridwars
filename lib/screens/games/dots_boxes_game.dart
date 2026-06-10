import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../functions/arcade_service.dart';
import '../../functions/arcade_ai.dart';
import '../../helpers/color.dart';
import '../../screens/arcade_lobby.dart';
import 'game_widgets.dart';

class DotsBoxesGameScreen extends StatefulWidget {
  final GameArgs args;
  const DotsBoxesGameScreen({super.key, required this.args});
  @override
  State<DotsBoxesGameScreen> createState() => _DotsBoxesGameScreenState();
}

class _DotsBoxesGameScreenState extends State<DotsBoxesGameScreen> {
  List<int> _hLines = List.filled(20, 0);
  List<int> _vLines = List.filled(20, 0);
  List<int> _boxes  = List.filled(16, 0);
  int _turn = 1;
  int _p1Score = 0, _p2Score = 0;
  bool _gameOver = false;
  bool _abandoned = false;
  bool _disposed = false;
  bool _resultShown = false;
  StreamSubscription? _sub;
  StreamSubscription? _statusSub;
  StreamSubscription? _presenceSub;
  Timer? _oppGoneTimer;
  Timer? _idleTimer;
  bool _oppSeen = false;
  late int _myNum;
  final String _myUid = FirebaseAuth.instance.currentUser!.uid;

  // Colors
  static const _myColor  = Color(0xFF4B4EE6);  // indigo — me
  static const _oppColor = Color(0xFFFB6B5B);  // coral  — opponent

  bool get _vsAi => widget.args.vsAi;

  @override
  void initState() {
    super.initState();
    _myNum = widget.args.isP1 ? 1 : 2;
    if (_vsAi) return; // local vs-Computer practice
    _sub = ArcadeService.stateRef(widget.args.type, widget.args.gameId)
        .child('state')
        .onValue
        .listen((ev) {
      if (_disposed || !mounted || ev.snapshot.value == null) return;
      final st = Map<String, dynamic>.from(ev.snapshot.value as Map);
      setState(() {
        _hLines  = List<int>.from((st['hLines'] as List).map((e) => int.parse(e.toString())));
        _vLines  = List<int>.from((st['vLines'] as List).map((e) => int.parse(e.toString())));
        _boxes   = List<int>.from((st['boxes']  as List).map((e) => int.parse(e.toString())));
        _p1Score = int.parse(st['p1Score'].toString());
        _p2Score = int.parse(st['p2Score'].toString());
        _turn    = int.parse(st['turn'].toString());
      });
      if (!_boxes.contains(0) && !_gameOver) _finishGame();
      _resetIdleTimer();
    });
    // Result driven by atomic status+winner field (single source of truth).
    _statusSub = ArcadeService.stateRef(widget.args.type, widget.args.gameId)
        .onValue.listen((ev) {
      if (_disposed || !mounted || ev.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(ev.snapshot.value as Map);
      final status = data['status']?.toString();
      if (status == 'finished' || status == 'cancelled') {
        _finish(data['winner']?.toString());
        return;
      }
      _watchOpponent(data);
    });
    _presenceSub = ArcadeService.keepPresence(widget.args.type, widget.args.gameId);
  }

  // Arms only after the opponent has been seen present — see connect4 for notes.
  void _watchOpponent(Map<String, dynamic> data) {
    final presence = data['presence'];
    final oppHere  = presence is Map && presence[widget.args.oppId] == true;
    if (oppHere) _oppSeen = true;
    if (_oppSeen && !oppHere && !_gameOver) {
      _oppGoneTimer ??= Timer(const Duration(seconds: 8), () {
        if (_gameOver || _disposed || !mounted) return;
        ArcadeService.endGame(widget.args.type, widget.args.gameId, _myUid, widget.args.entryFee);
        _finish(_myUid);
      });
    } else {
      _oppGoneTimer?.cancel();
      _oppGoneTimer = null;
    }
  }

  void _finish(String? winner) {
    if (_gameOver || _resultShown || _disposed || !mounted) return;
    setState(() => _gameOver = true);
    final won  = winner != null && winner.isNotEmpty && winner == _myUid;
    final draw = winner == null || winner.isEmpty || winner == 'draw';
    _showResult(won, draw);
  }

  // "Time over" watchdog: opponent forfeits if idle on their turn past the limit.
  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_gameOver || _disposed || _myTurn) return;
    _idleTimer = Timer(const Duration(seconds: 45), () {
      if (_gameOver || _disposed || _myTurn || !mounted) return;
      ArcadeService.endGame(widget.args.type, widget.args.gameId, _myUid, widget.args.entryFee);
      _finish(_myUid);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _idleTimer?.cancel();
    _sub?.cancel();
    _statusSub?.cancel();
    _presenceSub?.cancel();
    _oppGoneTimer?.cancel();
    if (!_vsAi) {
      ArcadeService.goOffline(widget.args.type, widget.args.gameId);
      if (_resultShown) ArcadeService.cleanup(widget.args.type, widget.args.gameId);
    }
    super.dispose();
  }

  void _abandonGame() async {
    if (_abandoned || _disposed) return;
    _abandoned = true;
    setState(() => _gameOver = true);
    _sub?.cancel();
    _statusSub?.cancel();
    if (!_vsAi) {
      await ArcadeService.endGame(widget.args.type, widget.args.gameId,
          widget.args.oppId, widget.args.entryFee);
    }
    if (mounted && !_disposed) {
      Navigator.of(context).popUntil((route) => route is PageRoute);
      Navigator.of(context).pop();
    }
  }

  void _handleExit() {
    if (!mounted) return;
    if (_gameOver) {
      Navigator.of(context).popUntil((route) => route is PageRoute);
      Navigator.of(context).pop();
      return;
    }
    showLeaveConfirmDialog(context, _abandonGame);
  }

  bool get _myTurn => _turn == _myNum && !_gameOver;

  List<int> _getCompletedBoxes(List<int> h, List<int> v) {
    final completed = <int>[];
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 4; col++) {
        final boxIdx = row * 4 + col;
        if (_boxes[boxIdx] != 0) continue;
        final top    = h[row * 4 + col] != 0;
        final bottom = h[(row + 1) * 4 + col] != 0;
        final left   = v[row * 5 + col] != 0;
        final right  = v[row * 5 + col + 1] != 0;
        if (top && bottom && left && right) completed.add(boxIdx);
      }
    }
    return completed;
  }

  Future<void> _tapHLine(int row, int col) async {
    if (!_myTurn || _disposed) return;
    final idx = row * 4 + col;
    if (idx < 0 || idx >= _hLines.length || _hLines[idx] != 0) return;
    await _playLine(isH: true, idx: idx);
  }

  Future<void> _tapVLine(int row, int col) async {
    if (!_myTurn || _disposed) return;
    final idx = row * 5 + col;
    if (idx < 0 || idx >= _vLines.length || _vLines[idx] != 0) return;
    await _playLine(isH: false, idx: idx);
  }

  // Human plays a line. Online → write to Firebase (echo updates state). vs-AI →
  // apply locally, then hand to the bot when the turn passes.
  Future<void> _playLine({required bool isH, required int idx}) async {
    final newH = List<int>.from(_hLines);
    final newV = List<int>.from(_vLines);
    final newB = List<int>.from(_boxes);
    if (isH) newH[idx] = _myNum; else newV[idx] = _myNum;

    final completed = _getCompletedBoxes(newH, newV);
    int scored = 0;
    for (final b in completed) {
      if (newB[b] == 0) { newB[b] = _myNum; scored++; }
    }

    int np1 = _p1Score, np2 = _p2Score;
    if (widget.args.isP1) np1 += scored; else np2 += scored;
    final next = scored > 0 ? _myNum : (_turn == 1 ? 2 : 1);

    if (_vsAi) {
      setState(() {
        _hLines = newH; _vLines = newV; _boxes = newB;
        _p1Score = np1; _p2Score = np2; _turn = next;
      });
      if (!_boxes.contains(0)) { _finishGame(); return; }
      if (_turn != _myNum) _scheduleAiTurn();
      return;
    }

    await ArcadeService.updateState(widget.args.type, widget.args.gameId,
        {'hLines': newH, 'vLines': newV, 'boxes': newB, 'p1Score': np1, 'p2Score': np2, 'turn': next});
  }

  // Bot is P2. It keeps moving while it completes boxes (bonus turns).
  void _scheduleAiTurn() {
    Future.delayed(const Duration(milliseconds: 550), () {
      if (!mounted || _gameOver || _disposed || _turn != 2) return;
      final m = DotsBoxesAi.bestMove(_hLines, _vLines, _boxes, widget.args.aiLevel);
      if (m == null) return;
      final newH = List<int>.from(_hLines);
      final newV = List<int>.from(_vLines);
      final newB = List<int>.from(_boxes);
      if (m.isH) newH[m.index] = 2; else newV[m.index] = 2;
      final completed = _getCompletedBoxes(newH, newV);
      int scored = 0;
      for (final b in completed) { if (newB[b] == 0) { newB[b] = 2; scored++; } }
      setState(() {
        _hLines = newH; _vLines = newV; _boxes = newB;
        _p2Score = _p2Score + scored;
        _turn = scored > 0 ? 2 : 1;
      });
      if (!_boxes.contains(0)) { _finishGame(); return; }
      if (_turn == 2) _scheduleAiTurn(); // bonus turn — keep going
    });
  }

  void _finishGame() async {
    if (_gameOver || _disposed) return;
    // Winner uid derived locally from scores (both players have them).
    String winner;
    if (_p1Score > _p2Score) {
      winner = widget.args.isP1 ? _myUid : widget.args.oppId;
    } else if (_p2Score > _p1Score) {
      winner = widget.args.isP1 ? widget.args.oppId : _myUid;
    } else {
      winner = 'draw';
    }
    if (!_vsAi) {
      await ArcadeService.endGame(
          widget.args.type, widget.args.gameId, winner, widget.args.entryFee);
    }
    _finish(winner);
  }

  void _showResult(bool won, bool draw) {
    if (_resultShown) return;
    _resultShown = true;
    final myScore  = widget.args.isP1 ? _p1Score : _p2Score;
    final oppScore = widget.args.isP1 ? _p2Score : _p1Score;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(draw ? '🤝' : won ? '🏆' : '😔', style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 8),
            Text(
              draw ? 'Match Draw' : won ? 'You Win!' : 'You Lose',
              style: TextStyle(
                color: draw ? ink2Color : won ? goodColor : red,
                fontWeight: FontWeight.w800, fontSize: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text('$myScore — $oppScore boxes',
                style: TextStyle(color: xColor, fontWeight: FontWeight.w700, fontSize: 18)),
            if (won && !_vsAi) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: goldSoft, borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.monetization_on_rounded, color: goldColor, size: 16),
                  const SizedBox(width: 5),
                  Text('+${widget.args.entryFee * 2} coins',
                      style: TextStyle(color: const Color(0xFF9A6516), fontWeight: FontWeight.w700)),
                ]),
              ),
            ],
            if (_vsAi) ...[
              const SizedBox(height: 10),
              Text('Practice vs Computer', style: TextStyle(color: ink3Color, fontSize: 12)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: xColor, foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () {
                if (Navigator.canPop(context)) Navigator.pop(context);
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
              child: const Text('Back to Arcade', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }

  void _handleTap(Offset pos, double boardWidth, double boardHeight) {
    // Must use the SAME geometry as the painter: pad=14, separate cell w/h so the
    // board can fill a non-square (full-page) area.
    const pad = 14.0;
    final cellW = (boardWidth  - pad * 2) / 4.0;
    final cellH = (boardHeight - pad * 2) / 4.0;

    double bestDist = double.infinity;
    String? bestType;
    int bestRow = 0, bestCol = 0;

    // Horizontal lines (5 rows × 4 cols) — midpoint at (pad + (c+0.5)*cellW, pad + r*cellH)
    for (int r = 0; r <= 4; r++) {
      for (int c = 0; c < 4; c++) {
        final mx = pad + (c + 0.5) * cellW;
        final my = pad + r * cellH;
        final d = (pos - Offset(mx, my)).distance;
        if (d < bestDist) {
          bestDist = d; bestType = 'h'; bestRow = r; bestCol = c;
        }
      }
    }

    // Vertical lines (4 rows × 5 cols) — midpoint at (pad + c*cellW, pad + (r+0.5)*cellH)
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c <= 4; c++) {
        final mx = pad + c * cellW;
        final my = pad + (r + 0.5) * cellH;
        final d = (pos - Offset(mx, my)).distance;
        if (d < bestDist) {
          bestDist = d; bestType = 'v'; bestRow = r; bestCol = c;
        }
      }
    }

    // Only register taps reasonably close to a line
    if (bestDist > ((cellW + cellH) / 2) * 0.6) return;

    if (bestType == 'h') {
      _tapHLine(bestRow, bestCol);
    } else if (bestType == 'v') {
      _tapVLine(bestRow, bestCol);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myScore  = widget.args.isP1 ? _p1Score : _p2Score;
    final oppScore = widget.args.isP1 ? _p2Score : _p1Score;
    final total    = _boxes.length; // 16

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop && !_disposed) _handleExit(); },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(children: [

            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: _handleExit,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: surfaceColor, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: lineColor),
                    ),
                    child: Icon(Icons.close_rounded, color: ink2Color, size: 18),
                  ),
                ),
                const Spacer(),
                Column(children: [
                  Text('DOTS & BOXES',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: inkColor, letterSpacing: 1.5)),
                  const SizedBox(height: 2),
                  Text(
                    _myTurn ? 'Your Turn' : "${_shortName(widget.args.oppName)}'s Turn",
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: _myTurn ? goodColor : red,
                    ),
                  ),
                ]),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: lineColor),
                  ),
                  child: Row(children: [
                    Text('$myScore', style: TextStyle(
                        color: myScore >= oppScore ? _myColor : ink3Color,
                        fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(' — ', style: TextStyle(color: ink3Color, fontWeight: FontWeight.w600)),
                    Text('$oppScore', style: TextStyle(
                        color: oppScore > myScore ? _oppColor : ink3Color,
                        fontWeight: FontWeight.w800, fontSize: 16)),
                  ]),
                ),
              ]),
            ),

            const SizedBox(height: 10),

            // ── Score cards ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _PlayerScore('You', myScore, total, _myColor),
                const SizedBox(width: 12),
                _PlayerScore(_shortName(widget.args.oppName), oppScore, total, _oppColor),
              ]),
            ),

            const SizedBox(height: 10),

            // ── Board (fills the page) ───────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: lineColor, width: 1.5),
                    boxShadow: [shadow],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(19),
                    child: LayoutBuilder(builder: (_, c) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (det) => _handleTap(det.localPosition, c.maxWidth, c.maxHeight),
                        child: CustomPaint(
                          painter: _DotsBoxesPainter(
                            h: _hLines, v: _vLines, boxes: _boxes,
                            isP1: widget.args.isP1,
                            myColor: _myColor, oppColor: _oppColor,
                            myTurn: _myTurn,
                          ),
                          size: c.biggest,
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),

            // ── Hint strip ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: _myTurn ? _myColor.withValues(alpha: 0.08) : surface2Color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _myTurn ? _myColor.withValues(alpha: 0.3) : lineColor,
                  ),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(
                    _myTurn ? Icons.touch_app_rounded : Icons.hourglass_top_rounded,
                    size: 15,
                    color: _myTurn ? _myColor : ink3Color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _myTurn
                        ? 'Tap near a line to draw it'
                        : 'Waiting for ${_shortName(widget.args.oppName)}…',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _myTurn ? _myColor : ink2Color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  static String _shortName(String name) {
    if (name.length <= 12) return name;
    return '${name.substring(0, 10)}…';
  }
}

// ── Player score card ──────────────────────────────────────────────────────────

class _PlayerScore extends StatelessWidget {
  final String name;
  final int score;
  final int total;
  final Color color;
  const _PlayerScore(this.name, this.score, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : score / total;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(name,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text('$score', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 4,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Custom Painter ─────────────────────────────────────────────────────────────

class _DotsBoxesPainter extends CustomPainter {
  final List<int> h, v, boxes;
  final bool isP1;
  final Color myColor, oppColor;
  final bool myTurn;

  _DotsBoxesPainter({
    required this.h, required this.v, required this.boxes,
    required this.isP1,
    required this.myColor, required this.oppColor,
    required this.myTurn,
  });

  Color _ownerColor(int owner) =>
      owner == 0 ? Colors.transparent
      : (isP1 ? owner == 1 : owner == 2) ? myColor : oppColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Padding inside the white card. Separate cell width/height lets the board
    // fill a non-square (full-page) area instead of being locked to a square.
    const pad = 14.0;
    final cellW = (size.width  - pad * 2) / 4.0;
    final cellH = (size.height - pad * 2) / 4.0;
    final cellMin = cellW < cellH ? cellW : cellH;

    // ── 1. Box fills ────────────────────────────────────────────────────
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        final owner = boxes[r * 4 + c];
        if (owner == 0) continue;
        final col = _ownerColor(owner);
        final rect = Rect.fromLTWH(
          pad + c * cellW + 3, pad + r * cellH + 3,
          cellW - 6, cellH - 6,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()..color = col.withValues(alpha: 0.22),
        );
        // Owner initial letter
        final tp = TextPainter(
          text: TextSpan(
            text: isP1 ? (owner == 1 ? 'Y' : 'O') : (owner == 2 ? 'Y' : 'O'),
            style: TextStyle(
              color: col.withValues(alpha: 0.55),
              fontSize: cellMin * 0.35,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(
          pad + c * cellW + (cellW - tp.width) / 2,
          pad + r * cellH + (cellH - tp.height) / 2,
        ));
      }
    }

    // ── 2. Empty box hint grid (very subtle) ────────────────────────────
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        if (boxes[r * 4 + c] != 0) continue;
        final rect = Rect.fromLTWH(
          pad + c * cellW, pad + r * cellH,
          cellW, cellH,
        );
        canvas.drawRect(rect,
          Paint()
            ..color = const Color(0xFFE7E9EF).withValues(alpha: 0.6)
            ..style = PaintingStyle.fill,
        );
      }
    }

    // ── 3. Horizontal lines ─────────────────────────────────────────────
    for (int r = 0; r <= 4; r++) {
      for (int c = 0; c < 4; c++) {
        final owner = h[r * 4 + c];
        final drawn = owner != 0;
        final col = drawn ? _ownerColor(owner) : const Color(0xFFCDD0DA);
        final x1 = pad + c * cellW + (drawn ? 4.0 : 8.0);
        final x2 = pad + (c + 1) * cellW - (drawn ? 4.0 : 8.0);
        final y  = pad + r * cellH;

        canvas.drawLine(
          Offset(x1, y), Offset(x2, y),
          Paint()
            ..color = col
            ..strokeWidth = drawn ? 5 : 2.5
            ..strokeCap = StrokeCap.round,
        );

        // Glow for drawn lines
        if (drawn) {
          canvas.drawLine(
            Offset(x1, y), Offset(x2, y),
            Paint()
              ..color = col.withValues(alpha: 0.25)
              ..strokeWidth = 10
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
        }
      }
    }

    // ── 4. Vertical lines ───────────────────────────────────────────────
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c <= 4; c++) {
        final owner = v[r * 5 + c];
        final drawn = owner != 0;
        final col = drawn ? _ownerColor(owner) : const Color(0xFFCDD0DA);
        final x  = pad + c * cellW;
        final y1 = pad + r * cellH + (drawn ? 4.0 : 8.0);
        final y2 = pad + (r + 1) * cellH - (drawn ? 4.0 : 8.0);

        canvas.drawLine(
          Offset(x, y1), Offset(x, y2),
          Paint()
            ..color = col
            ..strokeWidth = drawn ? 5 : 2.5
            ..strokeCap = StrokeCap.round,
        );

        if (drawn) {
          canvas.drawLine(
            Offset(x, y1), Offset(x, y2),
            Paint()
              ..color = col.withValues(alpha: 0.25)
              ..strokeWidth = 10
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
        }
      }
    }

    // ── 5. Dots ─────────────────────────────────────────────────────────
    for (int r = 0; r <= 4; r++) {
      for (int c = 0; c <= 4; c++) {
        final cx = pad + c * cellW;
        final cy = pad + r * cellH;
        // Shadow
        canvas.drawCircle(Offset(cx, cy), 7,
          Paint()..color = const Color(0x22000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
        // Dot
        canvas.drawCircle(Offset(cx, cy), 6,
          Paint()..color = const Color(0xFF1A2B3C));
        // Highlight
        canvas.drawCircle(Offset(cx - 1.5, cy - 1.5), 2,
          Paint()..color = Colors.white.withValues(alpha: 0.5));
      }
    }

    // ── 6. "My turn" glow on tappable lines ────────────────────────────
    if (myTurn) {
      // Subtle pulse effect — draw semi-transparent rects near undrawn lines
      // to hint they are interactive (done via the light gray color above)
    }
  }

  @override
  bool shouldRepaint(covariant _DotsBoxesPainter old) => true;
}
