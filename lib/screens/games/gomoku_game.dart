import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../functions/arcade_service.dart';
import '../../helpers/color.dart';
import '../../helpers/constant.dart';
import '../../helpers/utils.dart';
import 'game_widgets.dart';
import '../../screens/arcade_lobby.dart';

// 11×11 board. Win = 5 in a row.
class GomokuGameScreen extends StatefulWidget {
  final GameArgs args;
  const GomokuGameScreen({super.key, required this.args});
  @override
  State<GomokuGameScreen> createState() => _GomokuGameScreenState();
}

class _GomokuGameScreenState extends State<GomokuGameScreen> {
  List<int> _board = List.filled(121, 0);
  int _turn = 1;
  bool _gameOver = false;
  bool _abandoned = false;
  StreamSubscription? _sub;
  StreamSubscription? _statusSub;
  late int _myNum;
  static const int N = 11;

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
      final board = List<int>.from((st['board'] as List).map((e) => int.parse(e.toString())));
      final turn  = int.parse(st['turn'].toString());
      setState(() { _board = board; _turn = turn; });
      // Always check for opponent win after any board update.
      // The previous condition (prevTurn != _myNum && turn == _myNum) was wrong:
      // when the opponent wins, 'turn' stays at their number, so the condition
      // was never true and the win was never detected on the loser's device.
      if (!_gameOver) {
        _scanOpponentWin(board);
      }
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
    if (_abandoned) return;
    _abandoned = true;
    setState(() => _gameOver = true);
    _sub?.cancel();
    _statusSub?.cancel();
    await ArcadeService.endGame(widget.args.type, widget.args.gameId, widget.args.oppId, widget.args.entryFee);
    if (mounted) {
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

  void _scanOpponentWin(List<int> board) {
    final oppNum = _myNum == 1 ? 2 : 1;
    for (int i = 0; i < N * N; i++) {
      if (board[i] == oppNum) {
        final row = i ~/ N, col = i % N;
        if (_checkWin(board, row, col, oppNum)) {
          setState(() => _gameOver = true);
          _showResult(false, false);
          return;
        }
      }
    }
  }

  void _place(int idx) async {
    if (!_myTurn || _board[idx] != 0) return;
    final newBoard = List<int>.from(_board);
    newBoard[idx] = _myNum;
    music.play(dice);

    final row  = idx ~/ N;
    final col  = idx % N;
    final won  = _checkWin(newBoard, row, col, _myNum);
    final draw = !newBoard.contains(0);
    final next = _turn == 1 ? 2 : 1;

    await ArcadeService.updateState(widget.args.type, widget.args.gameId,
        {'board': newBoard, 'turn': won || draw ? _turn : next});

    if (won) {
      setState(() => _gameOver = true);
      await ArcadeService.endGame(widget.args.type, widget.args.gameId,
          FirebaseAuth.instance.currentUser!.uid, widget.args.entryFee);
      if (mounted) _showResult(true, false);
    } else if (draw) {
      setState(() => _gameOver = true);
      await ArcadeService.endGame(widget.args.type, widget.args.gameId, null, widget.args.entryFee);
      if (mounted) _showResult(false, true);
    }
  }

  bool _checkWin(List<int> b, int row, int col, int player) {
    const dirs = [[0,1],[1,0],[1,1],[1,-1]];
    for (final d in dirs) {
      int count = 1;
      for (final sign in [-1, 1]) {
        int r = row + d[0]*sign, c = col + d[1]*sign;
        while (r>=0 && r<N && c>=0 && c<N && b[r*N+c]==player) {
          count++; r+=d[0]*sign; c+=d[1]*sign;
        }
      }
      if (count >= 5) return true;
    }
    return false;
  }

  void _showResult(bool won, bool draw) {
    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: xColor.withValues(alpha: 0.4))),
      title: Text(draw ? '🤝 Draw!' : won ? '🏆 You Win!' : '😔 You Lose', style: TextStyle(color: inkColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      content: Text(won ? '+${widget.args.entryFee * 2} coins!' : draw ? 'No winner' : 'Better luck next time', style: TextStyle(color: xColor), textAlign: TextAlign.center),
      actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: Text('Back', style: TextStyle(color: xColor)))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    const myColor  = Color(0xFF212121);  // Black stone
    const oppColor = Color(0xFFF5F5F5);  // White stone

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _handleExit(); },
      child: Scaffold(
      body: Container(
        color: bgColor,
        child: SafeArea(child: Column(children: [
          gameHeader(context, 'GOMOKU', _myTurn ? 'Your Turn' : "${widget.args.oppName}'s Turn", 0, 0, onExit: _handleExit),
          const SizedBox(height: 6),
          if (_myTurn) gamePill('Place your stone (5 in a row wins)', _myNum == 1 ? myColor : oppColor),
          if (!_myTurn && !_gameOver) gamePill("${widget.args.oppName}'s turn…", inkColor.withValues(alpha: 0.5)),

          const SizedBox(height: 8),

          // Board
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4A574),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: LayoutBuilder(builder: (_, constraints) {
                    final cellSize = constraints.maxWidth / N;
                    return GestureDetector(
                      onTapUp: (det) {
                        final col = (det.localPosition.dx / cellSize).floor().clamp(0, N-1);
                        final row = (det.localPosition.dy / cellSize).floor().clamp(0, N-1);
                        _place(row * N + col);
                      },
                      child: CustomPaint(
                        painter: _GomokuPainter(_board, cellSize, _myNum, myColor, oppColor),
                        size: constraints.biggest,
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),

          // Legend
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 14, height: 14, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF212121))),
              const SizedBox(width: 4),
              Text(widget.args.isP1 ? 'You' : widget.args.oppName, style: TextStyle(color: inkColor, fontSize: 12)),
              const SizedBox(width: 20),
              Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all())),
              const SizedBox(width: 4),
              Text(widget.args.isP1 ? widget.args.oppName : 'You', style: TextStyle(color: inkColor, fontSize: 12)),
            ]),
          ),
        ])),
      ),
      ), // Scaffold
    ); // PopScope
  }
}

class _GomokuPainter extends CustomPainter {
  final List<int> board;
  final double cellSize;
  final int myNum;
  final Color myColor, oppColor;
  _GomokuPainter(this.board, this.cellSize, this.myNum, this.myColor, this.oppColor);

  @override
  void paint(Canvas canvas, Size size) {
    const N = 11;
    final linePaint = Paint()..color = Colors.brown.shade700..strokeWidth = 0.8;
    final offset = cellSize / 2;

    // Grid lines
    for (int i = 0; i < N; i++) {
      canvas.drawLine(Offset(offset + i * cellSize, offset), Offset(offset + i * cellSize, size.height - offset), linePaint);
      canvas.drawLine(Offset(offset, offset + i * cellSize), Offset(size.width - offset, offset + i * cellSize), linePaint);
    }

    // Stones
    for (int idx = 0; idx < board.length; idx++) {
      if (board[idx] == 0) continue;
      final row = idx ~/ N, col = idx % N;
      final cx  = offset + col * cellSize;
      final cy  = offset + row * cellSize;
      final r   = cellSize * 0.42;
      final color = board[idx] == 1 ? myColor : oppColor;
      canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color);
      canvas.drawCircle(Offset(cx, cy), r, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 0.8);
    }
  }

  @override
  bool shouldRepaint(covariant _GomokuPainter old) => old.board != board;
}
