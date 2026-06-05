import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../functions/arcade_service.dart';
import '../../helpers/color.dart';
import '../../helpers/constant.dart';
import '../../helpers/utils.dart';
import 'game_widgets.dart';
import '../../screens/arcade_lobby.dart';

// 7 cols × 6 rows = 42 cells. Index = row*7 + col.
class Connect4GameScreen extends StatefulWidget {
  final GameArgs args;
  const Connect4GameScreen({super.key, required this.args});
  @override
  State<Connect4GameScreen> createState() => _Connect4GameScreenState();
}

class _Connect4GameScreenState extends State<Connect4GameScreen> {
  List<int> _board = List.filled(42, 0);
  int _turn = 1;
  bool _gameOver = false;
  bool _abandoned = false;
  StreamSubscription? _sub;
  StreamSubscription? _statusSub;
  int _myNum = 0;

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

      // Detect opponent win/draw on the loser's side so we show the correct
      // result ("You Lose") instead of the generic "Opponent Left" fallback.
      if (!_gameOver) {
        final oppNum = _myNum == 1 ? 2 : 1;
        outer:
        for (int r = 5; r >= 0; r--) {
          for (int c = 0; c < 7; c++) {
            if (board[r * 7 + c] == oppNum && _checkWin(board, r, c, oppNum)) {
              setState(() => _gameOver = true);
              _showResult(false, false);
              break outer;
            }
          }
        }
        if (!_gameOver && !board.contains(0)) {
          setState(() => _gameOver = true);
          _showResult(false, true);
        }
      }
    });
    // _statusSub is a true-disconnect fallback only: fires when status='finished'
    // but local win/draw detection above hasn't already set _gameOver.
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

  void _drop(int col) async {
    if (!_myTurn) return;
    // Find lowest empty row in this column
    int row = -1;
    for (int r = 5; r >= 0; r--) {
      if (_board[r * 7 + col] == 0) { row = r; break; }
    }
    if (row < 0) return; // column full

    final newBoard = List<int>.from(_board);
    newBoard[row * 7 + col] = _myNum;
    music.play(dice);

    final winner = _checkWin(newBoard, row, col, _myNum);
    final draw   = !newBoard.contains(0);
    final nextTurn = _turn == 1 ? 2 : 1;

    await ArcadeService.updateState(widget.args.type, widget.args.gameId,
        {'board': newBoard, 'turn': winner || draw ? _turn : nextTurn});

    if (winner) {
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
    // 4 directions: horizontal, vertical, diag↘, diag↙
    const dirs = [[0,1],[1,0],[1,1],[1,-1]];
    for (final d in dirs) {
      int count = 1;
      for (final sign in [-1, 1]) {
        int r = row + d[0]*sign, c = col + d[1]*sign;
        while (r>=0 && r<6 && c>=0 && c<7 && b[r*7+c]==player) {
          count++; r+=d[0]*sign; c+=d[1]*sign;
        }
      }
      if (count >= 4) return true;
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
    final myColor  = widget.args.isP1 ? const Color(0xFFFF5722) : const Color(0xFFFFEB3B);
    final oppColor = widget.args.isP1 ? const Color(0xFFFFEB3B) : const Color(0xFFFF5722);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _handleExit(); },
      child: Scaffold(
      body: Container(
        color: bgColor,
        child: SafeArea(child: Column(children: [
          gameHeader(context, 'CONNECT 4', _myTurn ? 'Your Turn' : "${widget.args.oppName}'s Turn", 0, 0, onExit: _handleExit),
          const SizedBox(height: 8),
          if (!_myTurn && !_gameOver) gamePill("Waiting for ${widget.args.oppName}…", inkColor.withValues(alpha: 0.5)),
          if (_myTurn) gamePill('Tap a column to drop!', myColor),

          const Spacer(),

          // Column tap targets
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: List.generate(7, (col) => Expanded(
              child: GestureDetector(
                onTap: () => _drop(col),
                child: Container(
                  height: 32,
                  color: Colors.transparent,
                  child: _myTurn ? Icon(Icons.arrow_drop_down, color: myColor, size: 28) : const SizedBox(),
                ),
              ),
            ))),
          ),

          // Board
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF1565C0),
              ),
              padding: const EdgeInsets.all(6),
              child: Column(
                children: List.generate(6, (row) => Row(
                  children: List.generate(7, (col) {
                    final cell = _board[row * 7 + col];
                    return Expanded(child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: AspectRatio(aspectRatio: 1, child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cell == 0
                              ? secondaryColor
                              : cell == 1 ? const Color(0xFFFF5722) : const Color(0xFFFFEB3B),
                          boxShadow: cell != 0 ? [BoxShadow(color: (cell == 1 ? const Color(0xFFFF5722) : const Color(0xFFFFEB3B)).withValues(alpha: 0.4), blurRadius: 6)] : null,
                        ),
                      )),
                    ));
                  }),
                )),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Legend
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _legendDot(myColor), const SizedBox(width: 4),
            Text('You', style: TextStyle(color: inkColor, fontSize: 12)),
            const SizedBox(width: 20),
            _legendDot(oppColor), const SizedBox(width: 4),
            Text(widget.args.oppName, style: TextStyle(color: inkColor, fontSize: 12)),
          ]),

          const SizedBox(height: 16),
        ])),
      ),
      ), // Scaffold
    ); // PopScope
  }

  Widget _legendDot(Color c) => Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: c));
}
