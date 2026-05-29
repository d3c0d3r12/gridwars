import 'dart:async';
import 'package:flutter/material.dart';
import '../../functions/arcade_service.dart';
import '../../helpers/color.dart';
import '../../screens/arcade_lobby.dart';
import '../../screens/splash.dart' show utils;
import 'game_widgets.dart';

// 5×5 dots → 4×4 boxes, 20 horizontal + 20 vertical lines.
// hLines[row*4+col] = line between (row,col)↔(row,col+1)
// vLines[row*5+col] = line between (row,col)↔(row+1,col)
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
  StreamSubscription? _sub;
  StreamSubscription? _statusSub;
  late int _myNum;

  @override
  void initState() {
    super.initState();
    _myNum = widget.args.isP1 ? 1 : 2;
    _sub = ArcadeService.stateRef(widget.args.type, widget.args.gameId)
        .child('state')
        .onValue
        .listen((ev) {
      if (!mounted || ev.snapshot.value == null) return;
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
    });
    _statusSub = ArcadeService.stateRef(widget.args.type, widget.args.gameId)
        .child('status').onValue.listen((ev) {
      if (!mounted || _gameOver) return;
      if (ev.snapshot.value?.toString() == 'finished') {
        setState(() => _gameOver = true);
        showOpponentLeftDialog(context);
      }
    });
  }

  @override
  void dispose() { _sub?.cancel(); _statusSub?.cancel(); super.dispose(); }

  void _abandonGame() async {
    if (_gameOver) return;
    setState(() => _gameOver = true);
    _sub?.cancel();
    _statusSub?.cancel();
    await ArcadeService.endGame(widget.args.type, widget.args.gameId, widget.args.oppId, widget.args.entryFee);
    if (mounted) Navigator.pop(context);
  }

  void _handleExit() => showLeaveConfirmDialog(context, _abandonGame);

  bool get _myTurn => _turn == _myNum && !_gameOver;

  Future<void> _tapHLine(int row, int col) async {
    if (!_myTurn) return;
    final idx = row * 4 + col;
    if (_hLines[idx] != 0) return;

    final newH  = List<int>.from(_hLines);
    final newV  = List<int>.from(_vLines);
    final newB  = List<int>.from(_boxes);
    newH[idx] = _myNum;

    int scored = 0;
    // Check box above (row-1, col) and below (row, col)
    for (final br in [row - 1, row]) {
      if (br >= 0 && br < 4) {
        if (_isBoxComplete(newH, newV, br, col)) {
          newB[br * 4 + col] = _myNum; scored++;
        }
      }
    }

    int np1 = _p1Score + (widget.args.isP1 ? scored : 0);
    int np2 = _p2Score + (!widget.args.isP1 ? scored : 0);
    final next = scored > 0 ? _myNum : (_turn == 1 ? 2 : 1);

    await ArcadeService.updateState(widget.args.type, widget.args.gameId,
        {'hLines': newH, 'vLines': newV, 'boxes': newB, 'p1Score': np1, 'p2Score': np2, 'turn': next});
  }

  Future<void> _tapVLine(int row, int col) async {
    if (!_myTurn) return;
    final idx = row * 5 + col;
    if (_vLines[idx] != 0) return;

    final newH = List<int>.from(_hLines);
    final newV = List<int>.from(_vLines);
    final newB = List<int>.from(_boxes);
    newV[idx] = _myNum;

    int scored = 0;
    for (final bc in [col - 1, col]) {
      if (bc >= 0 && bc < 4) {
        if (_isBoxComplete(newH, newV, row, bc)) {
          newB[row * 4 + bc] = _myNum; scored++;
        }
      }
    }

    int np1 = _p1Score + (widget.args.isP1 ? scored : 0);
    int np2 = _p2Score + (!widget.args.isP1 ? scored : 0);
    final next = scored > 0 ? _myNum : (_turn == 1 ? 2 : 1);

    await ArcadeService.updateState(widget.args.type, widget.args.gameId,
        {'hLines': newH, 'vLines': newV, 'boxes': newB, 'p1Score': np1, 'p2Score': np2, 'turn': next});
  }

  bool _isBoxComplete(List<int> h, List<int> v, int row, int col) {
    final top    = h[row * 4 + col] != 0;
    final bottom = h[(row + 1) * 4 + col] != 0;
    final left   = v[row * 5 + col] != 0;
    final right  = v[row * 5 + col + 1] != 0;
    return top && bottom && left && right;
  }

  void _finishGame() async {
    setState(() => _gameOver = true);
    String? winner;
    if (_p1Score > _p2Score) winner = await _getId(true);
    else if (_p2Score > _p1Score) winner = await _getId(false);
    await ArcadeService.endGame(widget.args.type, widget.args.gameId, winner, widget.args.entryFee);
    if (mounted) _showResult();
  }

  Future<String> _getId(bool p1) async {
    final s = await ArcadeService.stateRef(widget.args.type, widget.args.gameId).once();
    final key = p1 ? 'p1' : 'p2';
    return ((s.snapshot.value as Map)[key] as String?) ?? '';
  }

  void _showResult() {
    final myScore  = widget.args.isP1 ? _p1Score : _p2Score;
    final oppScore = widget.args.isP1 ? _p2Score : _p1Score;
    final won = myScore > oppScore;
    final draw = myScore == oppScore;
    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      backgroundColor: secondaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: secondarySelectedColor.withValues(alpha: 0.4))),
      title: Text(draw ? '🤝 Draw!' : won ? '🏆 You Win!' : '😔 You Lose', style: TextStyle(color: white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      content: Text('$myScore — $oppScore boxes', style: TextStyle(color: secondarySelectedColor, fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: Text('Back', style: TextStyle(color: secondarySelectedColor)))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final myScore  = widget.args.isP1 ? _p1Score : _p2Score;
    final oppScore = widget.args.isP1 ? _p2Score : _p1Score;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _handleExit(); },
      child: Scaffold(
      body: Container(
        decoration: utils.gradBack(),
        child: SafeArea(child: Column(children: [
          gameHeader(context, 'DOTS & BOXES', _myTurn ? 'Your Turn' : "${widget.args.oppName}'s Turn", myScore, oppScore, onExit: _handleExit),
          const SizedBox(height: 6),
          if (_myTurn) gamePill('Tap a line to draw it — complete a box to score!', secondarySelectedColor),
          if (!_myTurn && !_gameOver) gamePill("${widget.args.oppName} is drawing…", white.withValues(alpha: 0.5)),

          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: LayoutBuilder(builder: (_, c) {
                    final sz  = c.maxWidth / 5.0;
                    return GestureDetector(
                      onTapUp: (det) => _handleTap(det.localPosition, sz, c.maxWidth),
                      child: CustomPaint(
                        painter: _DotsBoxesPainter(_hLines, _vLines, _boxes, sz, widget.args.isP1),
                        size: c.biggest,
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _scoreChip('You', myScore, secondarySelectedColor),
              const SizedBox(width: 24),
              _scoreChip(widget.args.oppName, oppScore, const Color(0xFFE91E63)),
            ]),
          ),
        ])),
      ),
      ), // Scaffold
    ); // PopScope
  }

  void _handleTap(Offset pos, double sz, double total) {
    // Determine if tap is near a horizontal or vertical line
    final col = (pos.dx / sz).floor().clamp(0, 4);
    final row = (pos.dy / sz).floor().clamp(0, 4);
    final fx  = (pos.dx % sz) / sz;
    final fy  = (pos.dy % sz) / sz;

    if (fy < 0.25 && row < 5 && col < 4) {
      _tapHLine(row, col);
    } else if (fy > 0.75 && row < 4 && col < 4) {
      _tapHLine(row + 1, col);
    } else if (fx < 0.25 && row < 4 && col < 5) {
      _tapVLine(row, col);
    } else if (fx > 0.75 && row < 4 && col < 4) {
      _tapVLine(row, col + 1);
    }
  }

  Widget _scoreChip(String name, int score, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: color.withValues(alpha: 0.15), border: Border.all(color: color.withValues(alpha: 0.4))),
    child: Text('$name: $score', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
  );
} // end _DotsBoxesGameScreenState

class _DotsBoxesPainter extends CustomPainter {
  final List<int> h, v, boxes;
  final double sz;
  final bool isP1;
  _DotsBoxesPainter(this.h, this.v, this.boxes, this.sz, this.isP1);

  static const myColor  = Color(0xFF2196F3);
  static const oppColor = Color(0xFFE91E63);

  @override
  void paint(Canvas canvas, Size size) {
    final dot   = Paint()..color = Colors.white..style = PaintingStyle.fill;

    // Boxes
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        final owner = boxes[r * 4 + c];
        if (owner == 0) continue;
        final color = (isP1 ? owner == 1 : owner == 2) ? myColor : oppColor;
        canvas.drawRect(Rect.fromLTWH(c * sz + 4, r * sz + 4, sz - 8, sz - 8),
            Paint()..color = color.withValues(alpha: 0.25));
      }
    }

    // H lines
    for (int r = 0; r <= 4; r++) {
      for (int c = 0; c < 4; c++) {
        final owner = r < 5 ? (r * 4 + c < h.length ? h[r * 4 + c] : 0) : 0;
        final color = owner == 0 ? Colors.white24 : (isP1 ? owner == 1 : owner == 2) ? myColor : oppColor;
        canvas.drawLine(Offset(c * sz + 8, r * sz),
            Offset((c + 1) * sz - 8, r * sz),
            Paint()..color = color..strokeWidth = owner != 0 ? 4 : 2..strokeCap = StrokeCap.round);
      }
    }

    // V lines
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c <= 4; c++) {
        final owner = r * 5 + c < v.length ? v[r * 5 + c] : 0;
        final color = owner == 0 ? Colors.white24 : (isP1 ? owner == 1 : owner == 2) ? myColor : oppColor;
        canvas.drawLine(Offset(c * sz, r * sz + 8),
            Offset(c * sz, (r + 1) * sz - 8),
            Paint()..color = color..strokeWidth = owner != 0 ? 4 : 2..strokeCap = StrokeCap.round);
      }
    }

    // Dots
    for (int r = 0; r <= 4; r++) {
      for (int c = 0; c <= 4; c++) {
        canvas.drawCircle(Offset(c * sz.toDouble(), r * sz.toDouble()), 5, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotsBoxesPainter old) => true;
}
