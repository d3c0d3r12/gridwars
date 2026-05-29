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
    if (_gameOver) return;
    final flat = List<dynamic>.generate(9, (i) => _board[i].isEmpty ? i : _board[i]);
    final move = _ai.getBestMove(flat, 3, 2); // Hard
    if (move < 0 || move >= 9) return;
    _board[move] = 'X';
    music.play(dice);
    setState(() {});
    if (_checkEnd()) return;
    _humanTurn = true;
    _status = 'Your Turn';
    setState(() {});
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
      _status = 'Draw!';
      setState(() {});
      Future.delayed(const Duration(seconds: 2), _startGame);
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
    _streak++;
    int coins = streakCoinPerWin * _streak;
    if (_streak == 5)  coins += streakBonusAt5;
    if (_streak == 10) coins += streakBonusAt10;
    _totalCoinsEarned += coins;
    _status = '🔥 Win! +$coins coins';
    await _saveBest();
    await _awardCoins(coins);
    _streakCtrl.forward(from: 0);
    setState(() {});
    music.play(wingame);
    Future.delayed(const Duration(seconds: 2), _startGame);
  }

  void _onHumanLoss() async {
    _status = 'STRIKER wins!';
    await _saveBest();
    music.play(losegame);
    setState(() {});
    Future.delayed(const Duration(milliseconds: 800), () => _showStreakSummary());
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
      builder: (_) => AlertDialog(
        backgroundColor: secondaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: secondarySelectedColor.withValues(alpha: 0.4), width: 1.5),
        ),
        title: Text('Streak Over!', style: TextStyle(color: white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Streak: $_streak', style: TextStyle(color: secondarySelectedColor, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Best: $_bestStreak', style: TextStyle(color: white.withValues(alpha: 0.7))),
          const SizedBox(height: 8),
          Text('Coins earned: $_totalCoinsEarned', style: TextStyle(color: yellow, fontWeight: FontWeight.w600)),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() { _streak = 0; _totalCoinsEarned = 0; });
              _startGame();
            },
            child: Text('Try Again', style: TextStyle(color: secondarySelectedColor, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: Text('Exit', style: TextStyle(color: white.withValues(alpha: 0.6))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: utils.gradBack(),
        child: SafeArea(
          child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                Column(children: [
                  Text('STREAK', style: TextStyle(color: white.withValues(alpha: 0.6), fontSize: 11, letterSpacing: 2)),
                  AnimatedBuilder(
                    animation: _streakCtrl,
                    builder: (_, __) => Transform.scale(
                      scale: _streakScale.value,
                      child: Text('$_streak 🔥', style: TextStyle(color: secondarySelectedColor, fontSize: 28, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('BEST', style: TextStyle(color: white.withValues(alpha: 0.6), fontSize: 11, letterSpacing: 2)),
                  Text('$_bestStreak', style: TextStyle(color: white, fontSize: 20, fontWeight: FontWeight.bold)),
                ]),
              ]),
            ),

            // Status
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: secondaryColor.withValues(alpha: 0.7),
                border: Border.all(color: secondarySelectedColor.withValues(alpha: 0.3)),
              ),
              child: Text(_status, style: TextStyle(color: white, fontWeight: FontWeight.w600)),
            ),

            // Board
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
                  ),
                  itemCount: 9,
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => _onTap(i),
                    child: Stack(fit: StackFit.expand, children: [
                      getSvgImage(imageName: 'grid_box', fit: BoxFit.fill),
                      if (_board[i].isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: getSvgImage(
                            imageName: _board[i] == 'O' ? widget.playerSkin : widget.opponentSkin,
                            fit: BoxFit.contain,
                            imageColor: _board[i] == 'O' ? secondarySelectedColor : null,
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
            ),

            // Players row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(children: [
                _playerChip('You', widget.playerSkin, true),
                const Spacer(),
                getSvgImage(imageName: 'vs_small', width: 22, height: 21),
                const Spacer(),
                _playerChip('STRIKER', widget.opponentSkin, false),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _playerChip(String name, String skin, bool isHuman) {
    return Row(children: [
      if (!isHuman) ...[
        getSvgImage(imageName: skin, height: 20),
        const SizedBox(width: 6),
      ],
      Column(crossAxisAlignment: isHuman ? CrossAxisAlignment.start : CrossAxisAlignment.end, children: [
        Text(name, style: TextStyle(color: white, fontWeight: FontWeight.bold)),
        Text(isHuman ? 'O' : 'X', style: TextStyle(color: secondarySelectedColor, fontSize: 11)),
      ]),
      if (isHuman) ...[
        const SizedBox(width: 6),
        getSvgImage(imageName: skin, height: 20),
      ],
    ]);
  }
}
