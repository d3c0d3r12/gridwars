import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../helpers/utils.dart';

// 31 daily puzzles — one per day of month.
class _Puzzle {
  final List<String> board;
  final int winMove;
  final String hint;
  final String lineName; // which line completes the win
  const _Puzzle(this.board, this.winMove, this.hint, this.lineName);
}

// All 31 puzzles with better hints
const _puzzles = [
  _Puzzle(['','','O','X','O','','X','',''], 0, 'Place X in top-left to complete the left column!', 'Left Column'),
  _Puzzle(['','O','O','','','','X','X',''], 8, 'Place X in bottom-right to complete the bottom row!', 'Bottom Row'),
  _Puzzle(['','X','O','','X','O','','',''], 7, 'Place X in bottom-center to complete the middle column!', 'Middle Column'),
  _Puzzle(['O','','X','','','X','O','',''], 8, 'Place X in bottom-right to complete the right column!', 'Right Column'),
  _Puzzle(['','','','O','X','O','','','X'], 0, 'Place X in top-left to complete the main diagonal!', 'Main Diagonal ↘'),
  _Puzzle(['','','','','X','X','O','O',''], 3, 'Place X in middle-left to complete the middle row!', 'Middle Row'),
  _Puzzle(['','','','','X','O','X','O',''], 2, 'Place X in top-right to complete the anti-diagonal!', 'Anti-Diagonal ↙'),
  _Puzzle(['','X','X','','','','O','O',''], 0, 'Place X in top-left to complete the top row!', 'Top Row'),
  _Puzzle(['','','O','X','','','X','O',''], 0, 'Place X in top-left to complete the left column!', 'Left Column'),
  _Puzzle(['','','O','O','','','X','','X'], 7, 'Place X in bottom-center to complete the bottom row!', 'Bottom Row'),
  _Puzzle(['O','X','','','X','','','','O'], 7, 'Place X in bottom-center to complete the middle column!', 'Middle Column'),
  _Puzzle(['O','','','','','X','','O','X'], 2, 'Place X in top-right to complete the right column!', 'Right Column'),
  _Puzzle(['X','O','','','X','O','','',''], 8, 'Place X in bottom-right to complete the main diagonal!', 'Main Diagonal ↘'),
  _Puzzle(['','','O','X','','X','','','O'], 4, 'Place X in center to complete the middle row!', 'Middle Row'),
  _Puzzle(['O','','X','O','X','','','',''], 6, 'Place X in bottom-left to complete the anti-diagonal!', 'Anti-Diagonal ↙'),
  _Puzzle(['X','X','','','','','','O','O'], 2, 'Place X in top-right to complete the top row!', 'Top Row'),
  _Puzzle(['X','','','X','O','O','','',''], 6, 'Place X in bottom-left to complete the left column!', 'Left Column'),
  _Puzzle(['','O','','O','','','X','','X'], 7, 'Place X in bottom-center to complete the bottom row!', 'Bottom Row'),
  _Puzzle(['','','','','X','','O','X','O'], 1, 'Place X in top-center to complete the middle column!', 'Middle Column'),
  _Puzzle(['','','','O','','X','O','','X'], 2, 'Place X in top-right to complete the right column!', 'Right Column'),
  _Puzzle(['X','','O','','X','','','O',''], 8, 'Place X in bottom-right to complete the main diagonal!', 'Main Diagonal ↘'),
  _Puzzle(['','O','','','X','X','','O',''], 3, 'Place X in middle-left to complete the middle row!', 'Middle Row'),
  _Puzzle(['O','','X','','','O','X','',''], 4, 'Place X in center to complete the anti-diagonal!', 'Anti-Diagonal ↙'),
  _Puzzle(['X','','X','O','','O','','',''], 1, 'Place X in top-center to complete the top row!', 'Top Row'),
  _Puzzle(['X','','O','X','','','','O',''], 6, 'Place X in bottom-left to complete the left column!', 'Left Column'),
  _Puzzle(['','','','','O','O','X','','X'], 7, 'Place X in bottom-center to complete the bottom row!', 'Bottom Row'),
  _Puzzle(['O','','','','X','','O','X',''], 1, 'Place X in top-center to complete the middle column!', 'Middle Column'),
  _Puzzle(['','O','','','','X','O','','X'], 2, 'Place X in top-right to complete the right column!', 'Right Column'),
  _Puzzle(['X','O','','','','O','','','X'], 4, 'Place X in center to complete the main diagonal!', 'Main Diagonal ↘'),
  _Puzzle(['O','','','','X','X','O','',''], 3, 'Place X in middle-left to complete the middle row!', 'Middle Row'),
  _Puzzle(['','O','X','O','X','','','',''], 6, 'Place X in bottom-left to complete the anti-diagonal!', 'Anti-Diagonal ↙'),
];

class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen>
    with SingleTickerProviderStateMixin {
  late _Puzzle _puzzle;
  bool _completed = false;
  bool _alreadyDoneToday = false;
  String _resultMsg = '';
  int _attempts = 0;
  int _correctCell = -1;
  
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _celebrationCtrl;
  late Animation<double> _celebrationAnim;

  @override
  void initState() {
    super.initState();
    final dayIdx = (DateTime.now().day - 1) % _puzzles.length;
    _puzzle = _puzzles[dayIdx];
    _correctCell = _puzzle.winMove;
    
    _pulseCtrl = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    
    _celebrationCtrl = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 600),
    );
    _celebrationAnim = CurvedAnimation(
      parent: _celebrationCtrl, 
      curve: Curves.elasticOut,
    );
    
    _checkAlreadyDone();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _celebrationCtrl.dispose();
    super.dispose();
  }

  String get _todayKey => 'daily_${DateTime.now().year}_${DateTime.now().month}_${DateTime.now().day}';

  Future<void> _checkAlreadyDone() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_todayKey) == true) {
      setState(() { 
        _alreadyDoneToday = true; 
        _completed = true; 
        _resultMsg = '🎉 Already completed today! Come back tomorrow.';
      });
    }
  }

  void _onTap(int idx) {
    if (_completed || _alreadyDoneToday) return;
    if (_puzzle.board[idx].isNotEmpty) {
      // Show feedback for already filled cell
      setState(() => _resultMsg = '❌ This cell is already filled!');
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _resultMsg == '❌ This cell is already filled!') {
          setState(() => _resultMsg = '');
        }
      });
      return;
    }

    _attempts++;
    if (idx == _puzzle.winMove) {
      _onCorrect();
    } else {
      setState(() => _resultMsg = '❌ Wrong cell! Try again. (Attempt $_attempts)');
      music.play(losegame);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _resultMsg.contains('Wrong')) {
          setState(() => _resultMsg = '');
        }
      });
    }
  }

  void _onCorrect() async {
    _celebrationCtrl.forward();
    _pulseCtrl.stop();
    
    setState(() {
      _completed = true;
      _resultMsg = '🎉 Perfect! +50 coins earned! 🎉';
    });
    music.play(wingame);
    await _awardCoins(50);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_todayKey, true);
    
    // Show celebration dialog
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      _showCelebrationDialog();
    }
  }

  void _showCelebrationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Column(children: [
          const Text('🎉', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text(
            'Challenge Complete!',
            style: TextStyle(color: inkColor, fontWeight: FontWeight.w800, fontSize: 20),
          ),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'You solved the puzzle in $_attempts ${_attempts == 1 ? 'attempt' : 'attempts'}!',
            style: TextStyle(color: ink2Color, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: goldSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.monetization_on_rounded, color: goldColor, size: 28),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('+50 COINS',
                    style: TextStyle(color: const Color(0xFF9A6516), fontWeight: FontWeight.w800, fontSize: 18)),
                Text('Added to your balance',
                    style: TextStyle(color: const Color(0xFF9A6516), fontSize: 11)),
              ]),
            ]),
          ),
        ]),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: xColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size(double.infinity, 44),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('CONTINUE', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
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
    final dayOfMonth = DateTime.now().day;
    final monthName = _getMonthName(DateTime.now().month);
    
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
                  decoration: BoxDecoration(
                    color: surfaceColor, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: lineColor), boxShadow: [shadowSm],
                  ),
                  child: Icon(Icons.arrow_back_rounded, color: inkColor, size: 20),
                ),
              ),
              const Spacer(),
              Column(children: [
                Text('DAILY CHALLENGE',
                    style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2, 
                           fontSize: 13, color: inkColor)),
                Row(children: [
                  Text('$monthName ', style: TextStyle(color: xColor, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('${dayOfMonth.toString().padLeft(2, '0')}',
                      style: TextStyle(color: ink2Color, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ]),
              const Spacer(),
              // Streak indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(colors: [goldColor, const Color(0xFFFFB74D)]),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text('${_getStreak()}',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                ]),
              ),
            ]),
          ),

          const SizedBox(height: 12),

          // Progress bar (calendar streak style)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildProgressBar(),
          ),

          const SizedBox(height: 12),

          // Hint card
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [surfaceColor, surface2Color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: lineColor),
              boxShadow: [shadowSm],
            ),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: goldSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.lightbulb_outline_rounded, color: goldColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('PUZZLE HINT',
                      style: TextStyle(color: ink3Color, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text(_puzzle.hint,
                      style: TextStyle(color: inkColor, fontSize: 13, fontWeight: FontWeight.w500)),
                ]),
              ),
              if (!_completed && !_alreadyDoneToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: xSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Win line: ${_puzzle.lineName}',
                      style: TextStyle(color: xColor, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
            ]),
          ),

          // Attempts counter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('ATTEMPTS',
                  style: TextStyle(color: ink3Color, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1)),
              Text('$_attempts',
                  style: TextStyle(color: _attempts == 0 ? ink2Color : xColor, 
                         fontSize: 16, fontWeight: FontWeight.w800)),
            ]),
          ),

          // Board
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, 
                  crossAxisSpacing: 12, 
                  mainAxisSpacing: 12,
                ),
                itemCount: 9,
                itemBuilder: (_, i) {
                  final cell = _puzzle.board[i];
                  final isCorrectCell = i == _correctCell && !_completed && !_alreadyDoneToday;
                  final isWinHighlight = _completed && i == _correctCell && !_alreadyDoneToday;
                  
                  return AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (ctx, child) {
                      double scale = 1.0;
                      if (isCorrectCell && !_completed && !_alreadyDoneToday) {
                        scale = _pulseAnim.value;
                      }
                      return Transform.scale(
                        scale: scale,
                        child: GestureDetector(
                          onTap: () => _onTap(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isWinHighlight 
                                  ? goodColor.withValues(alpha: 0.15) 
                                  : surfaceColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isCorrectCell && !_completed
                                    ? xColor.withValues(alpha: 0.8)
                                    : isWinHighlight
                                        ? goodColor.withValues(alpha: 0.6)
                                        : (cell.isEmpty ? lineColor : xSoft),
                                width: isCorrectCell && !_completed ? 2.5 : 1.5,
                              ),
                              boxShadow: isWinHighlight
                                  ? [BoxShadow(color: goodColor.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2)]
                                  : (isCorrectCell && !_completed
                                      ? [BoxShadow(color: xColor.withValues(alpha: 0.3), blurRadius: 12)]
                                      : [shadowSm]),
                            ),
                            child: cell.isNotEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: getSvgImage(
                                      imageName: cell == 'X' ? 'cross_skin' : 'circle_skin',
                                      fit: BoxFit.contain,
                                      imageColor: cell == 'X' ? xColor : oColor,
                                    ),
                                  )
                                : (_completed && i == _correctCell)
                                    ? Center(
                                        child: Icon(Icons.check_circle_rounded, 
                                            color: goodColor, size: 32))
                                    : null,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // Result message with animation
          if (_resultMsg.isNotEmpty)
            ScaleTransition(
              scale: _celebrationAnim,
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _completed && !_alreadyDoneToday
                      ? goodColor.withValues(alpha: 0.12)
                      : (_resultMsg.contains('Wrong') ? red.withValues(alpha: 0.08) : surfaceColor),
                  border: Border.all(
                    color: _completed && !_alreadyDoneToday
                        ? goodColor.withValues(alpha: 0.4)
                        : (_resultMsg.contains('Wrong') ? red.withValues(alpha: 0.3) : lineColor),
                    width: 1.5,
                  ),
                ),
                child: Row(children: [
                  Icon(
                    _completed && !_alreadyDoneToday ? Icons.emoji_events_rounded
                        : (_resultMsg.contains('Wrong') ? Icons.sentiment_dissatisfied_rounded : Icons.info_outline_rounded),
                    color: _completed && !_alreadyDoneToday ? goodColor
                        : (_resultMsg.contains('Wrong') ? red : ink2Color),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _resultMsg,
                      style: TextStyle(
                        color: _completed && !_alreadyDoneToday ? goodColor
                            : (_resultMsg.contains('Wrong') ? red : ink2Color),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ]),
              ),
            ),

          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Widget _buildProgressBar() {
    // Get completed days count for current month
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: surface2Color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (_, snap) {
          if (!snap.hasData) return const SizedBox();
          final prefs = snap.data!;
          final today = DateTime.now();
          final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
          int completed = 0;
          for (int d = 1; d <= daysInMonth; d++) {
            final key = 'daily_${today.year}_${today.month}_$d';
            if (prefs.getBool(key) == true) completed++;
          }
          final progress = completed / daysInMonth;
          return LayoutBuilder(builder: (_, constraints) {
            return Stack(children: [
              Container(
                width: constraints.maxWidth * progress,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [xColor, oColor]),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              if (progress > 0)
                Positioned(
                  right: 4, top: -10,
                  child: Text('${(progress * 100).toInt()}%',
                      style: TextStyle(color: xColor, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
            ]);
          });
        },
      ),
    );
  }

  Future<int> _getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    int streak = 0;
    for (int i = 0; i < 30; i++) {
      final d = today.subtract(Duration(days: i));
      final key = 'daily_${d.year}_${d.month}_${d.day}';
      if (prefs.getBool(key) == true) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}