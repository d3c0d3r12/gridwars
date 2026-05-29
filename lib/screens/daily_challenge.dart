import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../helpers/utils.dart';
import '../screens/splash.dart';

// 31 daily puzzles — one per day of month.
// Board: 9 cells ('X' / 'O' / '').  winMove = correct index for X to win.
class _Puzzle {
  final List<String> board;
  final int winMove;
  final String hint;
  const _Puzzle(this.board, this.winMove, this.hint);
}

const _puzzles = [
  _Puzzle(['X','O','X','O','X','O','','',''], 6, 'Complete the diagonal!'),
  _Puzzle(['O','X','O','X','X','','O','',''], 5, 'Win in the middle row!'),
  _Puzzle(['X','','X','O','O','','','',''], 1, 'Win with the top row!'),
  _Puzzle(['','X','O','X','O','','X','',''], 8, 'Complete the anti-diagonal!'),
  _Puzzle(['X','O','','O','X','','','',''], 8, 'Win with the main diagonal!'),
  _Puzzle(['O','O','','X','X','','','',''], 5, 'Block and win!'),
  _Puzzle(['X','','','X','O','O','X','',''], 7, 'Win the first column!'),
  _Puzzle(['','','X','O','X','O','','','X'], 6, 'Spot the winning move!'),
  _Puzzle(['X','O','X','','O','','','O','X'], 3, 'Block the column!'),
  _Puzzle(['O','X','O','','X','','','X',''], 6, 'Win the middle column!'),
  _Puzzle(['X','X','','O','O','','','',''], 2, 'Complete the row!'),
  _Puzzle(['','O','X','O','X','','X','',''], 7, 'Build your diagonal!'),
  _Puzzle(['X','O','O','','X','','','','X'], 3, 'Win with the diagonal!'),
  _Puzzle(['O','','O','X','X','','','',''], 5, 'Complete and win!'),
  _Puzzle(['X','','','O','X','O','','','X'], 1, 'Find the winning gap!'),
  _Puzzle(['','X','O','X','O','','X','',''], 8, 'Win the last diagonal!'),
  _Puzzle(['X','O','X','O','','X','','O',''], 4, 'Center wins!'),
  _Puzzle(['O','X','','','X','O','X','',''], 8, 'Complete the column!'),
  _Puzzle(['X','','X','O','O','','','',''], 1, 'Middle of the row!'),
  _Puzzle(['','O','O','X','X','','X','',''], 5, 'Row or column?'),
  _Puzzle(['X','O','X','','O','O','X','',''], 7, 'Block and take the win!'),
  _Puzzle(['O','X','O','X','','','','X',''], 4, 'Take the center!'),
  _Puzzle(['X','O','','X','O','','X','',''], 7, 'Finish the column!'),
  _Puzzle(['','X','X','O','O','','','',''], 0, 'Complete the row!'),
  _Puzzle(['X','','O','','X','O','O','','X'], 1, 'Spot the diagonal!'),
  _Puzzle(['','O','X','O','X','','X','',''], 8, 'Win the corner!'),
  _Puzzle(['X','X','','O','O','','','',''], 2, 'Top row wins!'),
  _Puzzle(['','X','O','X','O','O','X','',''], 7, 'Column victory!'),
  _Puzzle(['O','','X','X','X','','O','O',''], 5, 'Middle row wins!'),
  _Puzzle(['X','O','O','X','','O','X','',''], 7, 'Finish the column!'),
  _Puzzle(['O','X','X','O','O','','X','','X'], 5, 'Block and win!'),
];

class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  late _Puzzle _puzzle;
  bool _completed = false;
  bool _alreadyDoneToday = false;
  String _resultMsg = '';
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    final dayIdx = (DateTime.now().day - 1) % _puzzles.length;
    _puzzle = _puzzles[dayIdx];
    _checkAlreadyDone();
  }

  String get _todayKey => 'daily_${DateTime.now().year}_${DateTime.now().month}_${DateTime.now().day}';

  Future<void> _checkAlreadyDone() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_todayKey) == true) {
      setState(() { _alreadyDoneToday = true; _completed = true; _resultMsg = 'Already completed today!'; });
    }
  }

  void _onTap(int idx) {
    if (_completed || _alreadyDoneToday) return;
    if (_puzzle.board[idx].isNotEmpty) return; // cell already filled

    _attempts++;
    if (idx == _puzzle.winMove) {
      _onCorrect();
    } else {
      setState(() => _resultMsg = 'Wrong cell! Try again. (Attempt $_attempts)');
    }
  }

  void _onCorrect() async {
    setState(() {
      _completed = true;
      _resultMsg = '✅ Correct! +50 coins earned!';
    });
    music.play(wingame);
    await _awardCoins(50);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_todayKey, true);
  }

  Future<void> _awardCoins(int amount) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final ref = FirebaseDatabase.instance.ref().child('users').child(uid).child('coin');
      await ref.runTransaction((v) => Transaction.success((v as int? ?? 0) + amount));
    } catch (_) {}
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                IconButton(icon: Icon(Icons.arrow_back, color: white), onPressed: () => Navigator.pop(context)),
                const Spacer(),
                Column(children: [
                  Text('DAILY CHALLENGE', style: TextStyle(color: white, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 13)),
                  Text(
                    '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: TextStyle(color: secondarySelectedColor, fontSize: 12),
                  ),
                ]),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: secondarySelectedColor.withValues(alpha: 0.15),
                    border: Border.all(color: secondarySelectedColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    getSvgImage(imageName: 'coin_symbol', height: 12),
                    const SizedBox(width: 4),
                    Text('+50', style: TextStyle(color: yellow, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ]),
            ),

            // Hint
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: white.withValues(alpha: 0.06),
                border: Border.all(color: white.withValues(alpha: 0.12)),
              ),
              child: Row(children: [
                Icon(Icons.lightbulb_outline, color: secondarySelectedColor, size: 16),
                const SizedBox(width: 8),
                Text('Hint: ${_puzzle.hint}', style: TextStyle(color: white.withValues(alpha: 0.8), fontSize: 13)),
              ]),
            ),

            // Instruction
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                _alreadyDoneToday ? 'Come back tomorrow!' : 'Tap the correct cell to make X win!',
                style: TextStyle(color: white.withValues(alpha: 0.6), fontSize: 13),
              ),
            ),

            // Board
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
                  ),
                  itemCount: 9,
                  itemBuilder: (_, i) {
                    final cell = _puzzle.board[i];
                    final isWinCell = _completed && i == _puzzle.winMove && !_alreadyDoneToday;
                    return GestureDetector(
                      onTap: () => _onTap(i),
                      child: Stack(fit: StackFit.expand, children: [
                        getSvgImage(imageName: 'grid_box', fit: BoxFit.fill),
                        if (cell.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: getSvgImage(
                              imageName: cell == 'X' ? 'cross_skin' : 'circle_skin',
                              fit: BoxFit.contain,
                              imageColor: cell == 'X' ? secondarySelectedColor : white.withValues(alpha: 0.7),
                            ),
                          ),
                        // Highlight empty cells as tappable
                        if (cell.isEmpty && !_completed)
                          Container(
                            margin: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: secondarySelectedColor.withValues(alpha: 0.25), width: 1),
                            ),
                          ),
                        // Green glow on correct win cell
                        if (isWinCell)
                          Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 4)],
                            ),
                          ),
                      ]),
                    );
                  },
                ),
              ),
            ),

            // Result message
            if (_resultMsg.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: _completed && !_alreadyDoneToday
                      ? Colors.greenAccent.withValues(alpha: 0.15)
                      : secondaryColor.withValues(alpha: 0.8),
                  border: Border.all(
                    color: _completed && !_alreadyDoneToday
                        ? Colors.greenAccent.withValues(alpha: 0.5)
                        : secondarySelectedColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _resultMsg,
                  style: TextStyle(
                    color: _completed && !_alreadyDoneToday ? Colors.greenAccent : white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }
}
