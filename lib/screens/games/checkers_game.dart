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

class CheckersGameScreen extends StatefulWidget {
  final GameArgs args;
  const CheckersGameScreen({super.key, required this.args});
  @override
  State<CheckersGameScreen> createState() => _CheckersGameScreenState();
}

class _CheckersGameScreenState extends State<CheckersGameScreen> {
  List<int> _board = List.filled(64, 0);
  int _turn = 1, _selected = -1;
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
  List<int> _validMoves = [];
  final String _myUid = FirebaseAuth.instance.currentUser!.uid;

  bool get _vsAi => widget.args.vsAi;

  @override
  void initState() {
    super.initState();
    _myNum = widget.args.isP1 ? 1 : 2;
    if (_vsAi) {
      // Local vs-Computer: seed the starting layout (unlike empty-board games,
      // checkers needs its pieces placed). Human is P1 and moves first.
      final init = ArcadeService.initialState('checkers');
      _board = List<int>.from((init['board'] as List).map((e) => int.parse(e.toString())));
      _turn = 1;
      _selected = -1;
      return;
    }
    _sub = ArcadeService.stateRef(widget.args.type, widget.args.gameId)
        .child('state')
        .onValue
        .listen((ev) {
      if (_disposed || !mounted || ev.snapshot.value == null) return;
      final st = Map<String, dynamic>.from(ev.snapshot.value as Map);
      final board    = List<int>.from((st['board'] as List).map((e) => int.parse(e.toString())));
      final turn     = int.parse(st['turn'].toString());
      final selected = int.parse(st['selected'].toString());
      setState(() { _board = board; _turn = turn; _selected = selected; _validMoves = []; });
      if (!_gameOver) _checkGameOver(board, turn);
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

  // Unified, idempotent game-over driven by the winner uid.
  void _finish(String? winner) {
    if (_gameOver || _resultShown || _disposed || !mounted) return;
    setState(() => _gameOver = true);
    _showResult(winner != null && winner.isNotEmpty && winner == _myUid);
  }

  void _endWith(String winner) {
    // vs-AI is free practice — no Firebase write, no coins/stats.
    if (!_vsAi) {
      ArcadeService.endGame(widget.args.type, widget.args.gameId, winner, widget.args.entryFee);
    }
    _finish(winner);
  }

  // "Time over" watchdog: opponent forfeits if idle on their turn past the limit.
  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_gameOver || _disposed || _myTurn) return;
    _idleTimer = Timer(const Duration(seconds: 45), () {
      if (_gameOver || _disposed || _myTurn || !mounted) return;
      _endWith(_myUid);
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
      await ArcadeService.endGame(widget.args.type, widget.args.gameId, widget.args.oppId, widget.args.entryFee);
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

  // FIXED: Correct win detection
  void _checkGameOver(List<int> board, int turn) {
    if (_gameOver) return;
    final myPieces  = board.where((c) => c == _myNum || c == _myNum + 2).length;
    // BUG WAS HERE: the Set literal `{if (cond) boolExpr}` created Set<bool>,
    // so `.contains(intC)` always returned false. Fixed with correct int comparison.
    final oppNum      = _myNum == 1 ? 2 : 1;
    final oppKingNum  = _myNum == 1 ? 4 : 3;
    final oppPieces   = board.where((c) => c == oppNum || c == oppKingNum).length;

    // If I have no pieces, I lose. If opponent has none, I win.
    if (myPieces == 0) { _endWith(widget.args.oppId); return; }
    if (oppPieces == 0) { _endWith(_myUid); return; }

    // Check if the current player has any valid moves.
    bool hasMoves = false;
    for (int i = 0; i < 64; i++) {
      final piece = board[i];
      final isMyPiece = piece == _turn || piece == _turn + 2;
      if (isMyPiece && _getMoves(i, board).isNotEmpty) {
        hasMoves = true;
        break;
      }
    }

    if (!hasMoves) {
      // Current player (whose turn it is) can't move → they lose.
      _endWith(_turn == _myNum ? widget.args.oppId : _myUid);
    }
  }

  void _onTap(int idx) async {
    if (!_myTurn || _gameOver) return;
    final cell = _board[idx];
    final ownCell = cell == _myNum || cell == _myNum + 2;

    if (_selected == -1) {
      if (!ownCell) return;
      final moves = _getMoves(idx, _board);
      if (moves.isEmpty) return;
      setState(() { _selected = idx; _validMoves = moves; });
      return;
    }

    if (_validMoves.contains(idx)) {
      await _move(_selected, idx);
    } else if (ownCell) {
      final moves = _getMoves(idx, _board);
      setState(() { _selected = idx; _validMoves = moves; });
    } else {
      setState(() { _selected = -1; _validMoves = []; });
    }
  }

  List<int> _getMoves(int from, List<int> board) {
    final piece = board[from];
    final isKing = piece == 3 || piece == 4;
    final r = from ~/ 8, c = from % 8;
    final dirs = <List<int>>[];
    if (piece == 1 || isKing) dirs.addAll([[-1,-1],[-1,1]]);
    if (piece == 2 || isKing) dirs.addAll([[1,-1],[1,1]]);

    final moves = <int>[];
    // Check jumps first
    for (final d in dirs) {
      final nr = r + d[0], nc = c + d[1];
      final jr = r + d[0]*2, jc = c + d[1]*2;
      if (nr>=0&&nr<8&&nc>=0&&nc<8&&jr>=0&&jr<8&&jc>=0&&jc<8) {
        final mid = nr*8+nc;
        final jump = jr*8+jc;
        final opp = piece <= 2 ? (piece == 1 ? 2 : 1) : (piece == 3 ? 2 : 1);
        if ((board[mid]==opp||board[mid]==opp+2) && board[jump]==0) moves.add(jump);
      }
    }
    if (moves.isNotEmpty) return moves;

    for (final d in dirs) {
      final nr = r + d[0], nc = c + d[1];
      if (nr>=0&&nr<8&&nc>=0&&nc<8&&board[nr*8+nc]==0) moves.add(nr*8+nc);
    }
    return moves;
  }

  Future<void> _move(int from, int to) async {
    final newBoard = List<int>.from(_board);
    newBoard[to] = newBoard[from];
    newBoard[from] = 0;

    final fromR = from ~/ 8, fromC = from % 8;
    final toR   = to   ~/ 8, toC   = to   % 8;
    if ((fromR - toR).abs() == 2) {
      final midR = (fromR + toR) ~/ 2, midC = (fromC + toC) ~/ 2;
      newBoard[midR*8+midC] = 0;
    }

    if (newBoard[to] == 1 && toR == 0) newBoard[to] = 3;
    if (newBoard[to] == 2 && toR == 7) newBoard[to] = 4;

    music.play(dice);
    final next = _turn == 1 ? 2 : 1;

    final chainJumps = _getMoves(to, newBoard).where((m) => (m ~/ 8 - toR).abs() == 2).toList();
    if (chainJumps.isNotEmpty && (fromR - toR).abs() == 2) {
      setState(() { _board = newBoard; _selected = to; _validMoves = chainJumps; });
      if (_vsAi) return; // same player continues the chain locally
      await ArcadeService.updateState(widget.args.type, widget.args.gameId,
          {'board': newBoard, 'turn': _turn, 'selected': to});
      return;
    }

    if (_vsAi) {
      setState(() { _board = newBoard; _turn = next; _selected = -1; _validMoves = []; });
      _checkGameOver(newBoard, next);
      if (!_gameOver && _turn != _myNum) _scheduleAiMove();
      return;
    }

    setState(() { _selected = -1; _validMoves = []; });
    await ArcadeService.updateState(widget.args.type, widget.args.gameId,
        {'board': newBoard, 'turn': next, 'selected': -1});

    _checkGameOver(newBoard, next);
  }

  // Bot plays as P2 (values 2/4). Applies its full move (incl. chained jumps).
  void _scheduleAiMove() {
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || _gameOver || _disposed || _turn != 2) return;
      final m = CheckersAi.bestMove(_board, 2, widget.args.aiLevel);
      if (m == null) { _endWith(_myUid); return; } // bot stuck → human wins
      final nb = CheckersAi.apply(_board, m);
      music.play(dice);
      setState(() { _board = nb; _turn = 1; _selected = -1; _validMoves = []; });
      _checkGameOver(nb, 1);
    });
  }

  void _showResult(bool won) {
    if (_resultShown) return;
    _resultShown = true;
    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: xColor.withValues(alpha: 0.4))),
      title: Text(won ? '🏆 You Win!' : '😔 You Lose', style: TextStyle(color: inkColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      content: Text(_vsAi ? (won ? 'You beat the Computer!' : 'The Computer won') : (won ? '+${widget.args.entryFee * 2} coins!' : 'Better luck next time'), style: TextStyle(color: xColor), textAlign: TextAlign.center),
      actions: [TextButton(onPressed: () {
        if (Navigator.canPop(context)) Navigator.pop(context);
        if (Navigator.canPop(context)) Navigator.pop(context);
      }, child: Text('Back', style: TextStyle(color: xColor)))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final myColor  = widget.args.isP1 ? const Color(0xFFE53935) : const Color(0xFFFFECB3);
    final oppColor = widget.args.isP1 ? const Color(0xFFFFECB3) : const Color(0xFFE53935);

    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) { if (!didPop && !_disposed) _handleExit(); },
        child: Scaffold(
          body: Container(
            color: bgColor,
            child: SafeArea(child: Column(children: [
              gameHeader(context, 'CHECKERS', _myTurn ? 'Your Turn' : "${widget.args.oppName}'s Turn", 0, 0, onExit: _handleExit),
              const SizedBox(height: 6),
              if (_myTurn && _selected == -1) gamePill('Tap your piece to select, then tap to move', myColor),
              if (_myTurn && _selected != -1) gamePill('Tap destination (highlighted)', secondarySelectedColor),
              if (!_myTurn && !_gameOver) gamePill("${widget.args.oppName} is thinking…", inkColor.withValues(alpha: 0.5)),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: AspectRatio(aspectRatio: 1,
                    child: GestureDetector(
                      onTapUp: (det) {
                        final size = MediaQuery.of(context).size.width - 24;
                        final cs = size / 8;
                        final col = (det.localPosition.dx / cs).floor().clamp(0, 7);
                        final rawRow = (det.localPosition.dy / cs).floor().clamp(0, 7);
                        final row = widget.args.isP1 ? rawRow : 7 - rawRow;
                        _onTap(row * 8 + col);
                      },
                      child: CustomPaint(
                        painter: _CheckersPainter(_board, _selected, _validMoves, widget.args.isP1, myColor, oppColor),
                      ),
                    ),
                  ),
                ),
              ),

              Padding(padding: const EdgeInsets.only(bottom: 12),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _dot(myColor), const SizedBox(width: 4), Text('You', style: TextStyle(color: inkColor, fontSize: 12)),
                    const SizedBox(width: 20),
                    _dot(oppColor), const SizedBox(width: 4), Text(widget.args.oppName, style: TextStyle(color: inkColor, fontSize: 12)),
                  ])),
            ])),
          ),
        ));
  }

  Widget _dot(Color c) => Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: c));
}

class _CheckersPainter extends CustomPainter {
  final List<int> board;
  final int selected;
  final List<int> validMoves;
  final bool isP1;
  final Color myColor, oppColor;
  _CheckersPainter(this.board, this.selected, this.validMoves, this.isP1, this.myColor, this.oppColor);

  @override
  void paint(Canvas canvas, Size size) {
    final cs = size.width / 8;
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final drawR = isP1 ? r : 7 - r;
        final isDark = (r + c) % 2 == 1;
        final idx = r * 8 + c;
        canvas.drawRect(Rect.fromLTWH(c * cs, drawR * cs, cs, cs),
            Paint()..color = isDark ? const Color(0xFF795548) : const Color(0xFFD7CCC8));
        if (idx == selected) canvas.drawRect(Rect.fromLTWH(c*cs, drawR*cs, cs, cs), Paint()..color = Colors.yellow.withValues(alpha: 0.35));
        if (validMoves.contains(idx)) canvas.drawRect(Rect.fromLTWH(c*cs, drawR*cs, cs, cs), Paint()..color = Colors.green.withValues(alpha: 0.35));
        if (board[idx] != 0) {
          final piece = board[idx];
          final color = (isP1 ? piece == 1 || piece == 3 : piece == 2 || piece == 4) ? myColor : oppColor;
          final cx = c * cs + cs / 2, cy = drawR * cs + cs / 2;
          canvas.drawCircle(Offset(cx, cy), cs * 0.38, Paint()..color = color);
          canvas.drawCircle(Offset(cx, cy), cs * 0.38, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.5);
          if (piece == 3 || piece == 4) {
            canvas.drawCircle(Offset(cx, cy), cs * 0.18, Paint()..color = Colors.amber);
          }
        }
      }
    }
  }
  @override
  bool shouldRepaint(covariant _CheckersPainter old) => true;
}