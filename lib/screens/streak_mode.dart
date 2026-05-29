import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../functions/ai.dart';
import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../helpers/utils.dart';
import '../screens/splash.dart';

class StreakModeScreen extends StatefulWidget {
  final String playerSkin;
  final String opponentSkin;
  const StreakModeScreen({super.key, required this.playerSkin, required this.opponentSkin});

  @override
  State<StreakModeScreen> createState() => _StreakModeScreenState();
}

class _StreakModeScreenState extends State<StreakModeScreen> with TickerProviderStateMixin {
  final TicTacToeAI _ai = TicTacToeAI();

  // Board state: 9 cells, '' = empty, 'X' = AI, 'O' = human
  List<String> _board = List.filled(9, '');
  bool _humanTurn = false; // AI goes first or human — randomised each game
  bool _gameOver = false;
  String _status = '';

  int _streak = 0;
  int _bestStreak = 0;
  int _totalCoinsEarned = 0;
  int _consecutiveDraws = 0;

  late AnimationController _streakCtrl;
  late Animation<double> _streakScale;

  @override
  void initState() {
    super.initState();
    _streakCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _streakScale = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _streakCtrl, curve: Curves.elasticOut),
    );
    _loadBest();
    _startGame();
  }

  @override
  void dispose() {
    _streakCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _bestStreak = prefs.getInt('streak_best') ?? 0);
  }

  Future<void> _saveBest() async {
    if (_streak > _bestStreak) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('streak_best', _streak);
      setState(() => _bestStreak = _streak);
    }
  }

  void _startGame() {
    _board = List.filled(9, '');
    _gameOver = false;
    _humanTurn = Random().nextBool();
    _status = _humanTurn ? 'Your Turn' : "STRIKER's Turn";
    setState(() {});
    if (!_humanTurn) {
      Future.delayed(const Duration(milliseconds: 600), _aiMove);
    }
  }

  void _onTap(int idx) {
    if (!_humanTurn || _gameOver || _board[idx].isNotEmpty) return;
    _board[idx] = 'O';
    music.play(dice);
    setState(() {});
    if (_checkEnd()) return;
    _humanTurn = false;
    _status = "STRIKER's Turn";
    setState(() {});
    Future.delayed(const Duration(milliseconds: 500), _aiMove);
  }

  void _aiMove() {
    // Guard: widget may have been disposed before the delayed callback fires.
    if (!mounted || _gameOver) return;
    final flat = List<dynamic>.generate(9, (i) => _board[i].isEmpty ? i : _board[i]);
    final move = _ai.getBestMove(flat, 3, 2); // Hard
    if (move < 0 || move >= 9) return;
    _board[move] = 'X';
    music.play(dice);
    if (_checkEnd()) {
      if (mounted) setState(() {});
      return;
    }
    _humanTurn = true;
    _status = 'Your Turn';
    if (mounted) setState(() {});
  }

  bool _checkEnd() {
    final winner = _winner();
    if (winner != null) {
      _gameOver = true;
      if (winner == 'O') {
        _onHumanWin();
      } else {
        _onHumanLoss();
      }
      return true;
    }
    if (!_board.contains('')) {
      _gameOver = true;
      _status = 'Draw — next round!';
      _consecutiveDraws++;
      if (mounted) setState(() {});
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) { _consecutiveDraws = 0; _startGame(); }
      });
      return true;
    }
    return false;
  }

  String? _winner() {
    const lines = [
      [0,1,2],[3,4,5],[6,7,8],
      [0,3,6],[1,4,7],[2,5,8],
      [0,4,8],[2,4,6],
    ];
    for (final l in lines) {
      if (_board[l[0]].isNotEmpty &&
          _board[l[0]] == _board[l[1]] &&
          _board[l[1]] == _board[l[2]]) {
        return _board[l[0]];
      }
    }
    return null;
  }

  void _onHumanWin() async {
    if (!mounted) return;
    _streak++;
    int coins = streakCoinPerWin * _streak;
    if (_streak == 5)  coins += streakBonusAt5;
    if (_streak == 10) coins += streakBonusAt10;
    _totalCoinsEarned += coins;
    _status = '🔥 Win! +$coins coins';
    _streakCtrl.forward(from: 0);
    if (mounted) setState(() {});
    music.play(wingame);
    // Award coins in background — don't await so UI stays responsive.
    _saveBest();
    _awardCoins(coins);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _startGame();
    });
  }

  void _onHumanLoss() async {
    if (!mounted) return;
    _status = 'STRIKER wins!';
    if (mounted) setState(() {});
    music.play(losegame);
    _saveBest();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _showStreakSummary();
    });
  }

  Future<void> _awardCoins(int amount) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final ref = FirebaseDatabase.instance.ref().child('users').child(uid).child('coin');
      await ref.runTransaction((v) => Transaction.success((v as int? ?? 0) + amount));
    } catch (_) {}
  }

  void _showStreakSummary() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Streak Over!', style: TextStyle(color: inkColor, fontWeight: FontWeight.w800, fontSize: 20), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text('$_streak 🔥', style: TextStyle(color: xColor, fontSize: 36, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Best: $_bestStreak', style: TextStyle(color: ink2Color, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(color: goldSoft, borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.monetization_on_rounded, color: goldColor, size: 16),
                const SizedBox(width: 5),
                Text('$_totalCoinsEarned coins earned', style: TextStyle(color: const Color(0xFF9A6516), fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () { Navigator.pop(context); Navigator.pop(context); },
                  style: OutlinedButton.styleFrom(side: BorderSide(color: lineColor), foregroundColor: ink2Color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Exit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(context); setState(() { _streak = 0; _totalCoinsEarned = 0; }); _startGame(); },
                  style: ElevatedButton.styleFrom(backgroundColor: xColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Try Again'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: lineColor), boxShadow: [shadowSm]),
                  child: Icon(Icons.arrow_back_rounded, color: inkColor, size: 20),
                ),
              ),
              const Spacer(),
              Column(children: [
                Text('STREAK CHALLENGE', style: TextStyle(color: ink3Color, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700)),
                AnimatedBuilder(
                  animation: _streakCtrl,
                  builder: (_, __) => Transform.scale(
                    scale: _streakScale.value,
                    child: Text('$_streak 🔥', style: TextStyle(color: xColor, fontSize: 26, fontWeight: FontWeight.w800)),
                  ),
                ),
              ]),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('BEST', style: TextStyle(color: ink3Color, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700)),
                Text('$_bestStreak', style: TextStyle(color: inkColor, fontSize: 20, fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),

          const SizedBox(height: 10),

          // Status pill
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: surfaceColor,
              border: Border.all(color: lineColor),
              boxShadow: [shadowSm],
            ),
            child: Text(_status, style: TextStyle(color: inkColor, fontWeight: FontWeight.w600, fontSize: 14)),
          ),

          // Board
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
                ),
                itemCount: 9,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _onTap(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: lineColor),
                      boxShadow: [shadowSm],
                    ),
                    child: _board[i].isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(14),
                            child: getSvgImage(
                              imageName: _board[i] == 'O' ? widget.playerSkin : widget.opponentSkin,
                              fit: BoxFit.contain,
                              imageColor: _board[i] == 'O' ? xColor : oColor,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),

          // Players row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              decoration: BoxDecoration(
                color: surface2Color,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: lineColor),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                _playerChip('You', widget.playerSkin, true),
                const Spacer(),
                Text('VS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: ink3Color, letterSpacing: 1)),
                const Spacer(),
                _playerChip('STRIKER', widget.opponentSkin, false),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _playerChip(String name, String skin, bool isHuman) {
    final col = isHuman ? xColor : oColor;
    return Row(children: [
      if (!isHuman) ...[
        getSvgImage(imageName: skin, height: 20, imageColor: col),
        const SizedBox(width: 6),
      ],
      Column(crossAxisAlignment: isHuman ? CrossAxisAlignment.start : CrossAxisAlignment.end, children: [
        Text(name, style: TextStyle(color: inkColor, fontWeight: FontWeight.w700, fontSize: 13)),
        Text(isHuman ? 'O' : 'X', style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
      if (isHuman) ...[
        const SizedBox(width: 6),
        getSvgImage(imageName: skin, height: 20, imageColor: col),
      ],
    ]);
  }
}
