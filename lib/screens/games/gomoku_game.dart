import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../functions/arcade_service.dart';
import '../../functions/arcade_ai.dart';
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
  bool _resultShown = false;
  StreamSubscription? _sub;
  StreamSubscription? _statusSub;
  StreamSubscription? _presenceSub;
  Timer? _oppGoneTimer;
  Timer? _idleTimer;
  bool _oppSeen = false;
  late int _myNum;
  static const int N = 11;
  final String _myUid = FirebaseAuth.instance.currentUser!.uid;

  bool get _vsAi => widget.args.vsAi;

  @override
  void initState() {
    super.initState();
    _myNum = widget.args.isP1 ? 1 : 2;
    if (_vsAi) return; // local vs-Computer practice
    // State listener: board + turn only.
    _sub = ArcadeService.stateRef(widget.args.type, widget.args.gameId)
        .child('state')
        .onValue
        .listen((ev) {
      if (!mounted || ev.snapshot.value == null) return;
      final st = Map<String, dynamic>.from(ev.snapshot.value as Map);
      final board = List<int>.from((st['board'] as List).map((e) => int.parse(e.toString())));
      final turn  = int.parse(st['turn'].toString());
      setState(() { _board = board; _turn = turn; });
      _resetIdleTimer();
    });
    // Result driven by atomic status+winner field (single source of truth).
    _statusSub = ArcadeService.stateRef(widget.args.type, widget.args.gameId)
        .onValue.listen((ev) {
      if (!mounted || ev.snapshot.value == null) return;
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
        if (_gameOver || !mounted) return;
        ArcadeService.endGame(widget.args.type, widget.args.gameId, _myUid, widget.args.entryFee);
        _finish(_myUid);
      });
    } else {
      _oppGoneTimer?.cancel();
      _oppGoneTimer = null;
    }
  }

  void _finish(String? winner) {
    if (_gameOver || _resultShown || !mounted) return;
    setState(() => _gameOver = true);
    final won  = winner != null && winner.isNotEmpty && winner == _myUid;
    final draw = winner == null || winner.isEmpty || winner == 'draw';
    _showResult(won, draw);
  }

  // "Time over" watchdog: opponent forfeits if idle on their turn past the limit.
  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_gameOver || _myTurn) return;
    _idleTimer = Timer(const Duration(seconds: 45), () {
      if (_gameOver || _myTurn || !mounted) return;
      ArcadeService.endGame(widget.args.type, widget.args.gameId, _myUid, widget.args.entryFee);
      _finish(_myUid);
    });
  }

  @override
  void dispose() {
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
    if (_abandoned) return;
    _abandoned = true;
    setState(() => _gameOver = true);
    _sub?.cancel();
    _statusSub?.cancel();
    if (!_vsAi) {
      await ArcadeService.endGame(widget.args.type, widget.args.gameId, widget.args.oppId, widget.args.entryFee);
    }
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

    if (_vsAi) {
      setState(() { _board = newBoard; _turn = won || draw ? _turn : next; });
      if (won) {
        _finish(_myUid);
      } else if (draw) {
        _finish('draw');
      } else {
        _scheduleAiMove();
      }
      return;
    }

    await ArcadeService.updateState(widget.args.type, widget.args.gameId,
        {'board': newBoard, 'turn': won || draw ? _turn : next});

    if (won) {
      await ArcadeService.endGame(widget.args.type, widget.args.gameId,
          _myUid, widget.args.entryFee);
      _finish(_myUid);
    } else if (draw) {
      await ArcadeService.endGame(widget.args.type, widget.args.gameId, 'draw', widget.args.entryFee);
      _finish('draw');
    }
  }

  // Bot plays as P2 (value 2).
  void _scheduleAiMove() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || _gameOver) return;
      final idx = GomokuAi.bestMove(_board, N, 2, 1, widget.args.aiLevel);
      if (idx < 0 || _board[idx] != 0) return;
      final nb = List<int>.from(_board)..[idx] = 2;
      music.play(dice);
      final win  = _checkWin(nb, idx ~/ N, idx % N, 2);
      final draw = !nb.contains(0);
      setState(() { _board = nb; _turn = win || draw ? _turn : 1; });
      if (win) {
        _finish(widget.args.oppId);
      } else if (draw) {
        _finish('draw');
      }
    });
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
    if (_resultShown) return;
    _resultShown = true;
    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: xColor.withValues(alpha: 0.4))),
      title: Text(draw ? '🤝 Draw!' : won ? '🏆 You Win!' : '😔 You Lose', style: TextStyle(color: inkColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      content: Text(_vsAi ? (won ? 'You beat the Computer!' : draw ? 'No winner' : 'The Computer won') : (won ? '+${widget.args.entryFee * 2} coins!' : draw ? 'No winner' : 'Better luck next time'), style: TextStyle(color: xColor), textAlign: TextAlign.center),
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
