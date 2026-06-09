import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../functions/arcade_service.dart';
import '../../helpers/color.dart';
import '../../screens/arcade_lobby.dart';
import 'game_widgets.dart';

class RpsGameScreen extends StatefulWidget {
  final GameArgs args;
  const RpsGameScreen({super.key, required this.args});
  @override
  State<RpsGameScreen> createState() => _RpsGameScreenState();
}

class _RpsGameScreenState extends State<RpsGameScreen>
    with TickerProviderStateMixin {
  Map _state = {};
  String _myChoice = '';
  bool _gameOver = false;
  bool _resultShown = false;
  bool _disposed = false;
  String _resultMsg = '';
  int? _roundResult; // 1=win, -1=loss, 0=draw
  StreamSubscription? _sub;
  bool _abandoned = false;

  // Timer
  static const _timerMax = 10;
  int _timerSecs = _timerMax;
  Timer? _countdownTimer;

  // Animation
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _resultCtrl;
  late Animation<double> _resultAnim;

  String get _p1Key => 'p1Choice';
  String get _p2Key => 'p2Choice';
  String get _myKey => widget.args.isP1 ? _p1Key : _p2Key;
  String get _oppKey => widget.args.isP1 ? _p2Key : _p1Key;

  static const _choices = ['rock', 'paper', 'scissors'];
  static const _emoji = {'rock': '✊', 'paper': '✋', 'scissors': '✌️'};
  static const _labels = {'rock': 'Rock', 'paper': 'Paper', 'scissors': 'Scissors'};
  static const _beats = {'rock': 'scissors', 'paper': 'rock', 'scissors': 'paper'};
  static const _btnColors = {
    'rock': Color(0xFFE53935),
    'paper': Color(0xFF1E88E5),
    'scissors': Color(0xFF43A047),
  };

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _resultCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _resultAnim = CurvedAnimation(parent: _resultCtrl, curve: Curves.elasticOut);

    _sub = ArcadeService.stateRef(widget.args.type, widget.args.gameId)
        .onValue
        .listen((ev) {
      if (_disposed || !mounted || ev.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(ev.snapshot.value as Map);
      if (data['status'] == 'finished' || data['status'] == 'cancelled') {
        if (!_gameOver && !_abandoned && mounted && !_disposed) {
          _stopTimer();
          setState(() => _gameOver = true);
          if (!_resultShown) {
            _resultShown = true;
            Future.delayed(Duration.zero, () => showOpponentLeftDialog(context));
          }
        }
        return;
      }
      final st = Map<String, dynamic>.from(data['state'] as Map);
      final myChoiceInState = st[_myKey] as String? ?? '';
      setState(() {
        _state = st;
        if (myChoiceInState.isEmpty) _myChoice = '';
      });
      _checkRound(st);
    });

    // Start timer after build
    _startTimer();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTimer();
    _pulseCtrl.dispose();
    _resultCtrl.dispose();
    _sub?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (_disposed || _gameOver || _myChoice.isNotEmpty) return;
    _stopTimer();
    setState(() {
      _timerSecs = _timerMax;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _disposed) { t.cancel(); return; }
      if (_timerSecs <= 1) {
        t.cancel();
        setState(() { _timerSecs = 0; });
        if (_myChoice.isEmpty && !_gameOver) {
          _pick(_choices[Random().nextInt(_choices.length)]);
        }
      } else {
        setState(() => _timerSecs--);
      }
    });
  }

  void _stopTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _abandonGame() async {
    if (_abandoned || _disposed) return;
    _abandoned = true;
    _stopTimer();
    setState(() => _gameOver = true);
    _sub?.cancel();
    await ArcadeService.endGame(widget.args.type, widget.args.gameId,
        widget.args.oppId, widget.args.entryFee);
    if (mounted && !_disposed) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _handleExit() {
    if (!mounted) return;
    if (_gameOver) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    showLeaveConfirmDialog(context, _abandonGame);
  }

  void _pick(String choice) async {
    if (_myChoice.isNotEmpty || _gameOver || _disposed) return;
    _stopTimer();
    setState(() => _myChoice = choice);
    await ArcadeService.updateState(
        widget.args.type, widget.args.gameId, {_myKey: choice});
  }

  void _checkRound(Map st) async {
    final p1 = st[_p1Key] as String? ?? '';
    final p2 = st[_p2Key] as String? ?? '';
    if (p1.isEmpty || p2.isEmpty) {
      if (_myChoice.isEmpty && !_gameOver && !_disposed) {
        _startTimer();
      }
      return;
    }

    if (_disposed) return;
    _stopTimer();

    int p1Score = (st['p1Score'] as int? ?? 0);
    int p2Score = (st['p2Score'] as int? ?? 0);
    final round = st['round'] as int? ?? 1;
    final maxR  = st['maxRounds'] as int? ?? 5;

    // FIXED: Proper round result tracking
    String roundResult;
    if (p1 == p2) {
      _roundResult = 0; // Draw
      roundResult = 'Draw! 🤝';
    } else if (_beats[p1] == p2) {
      p1Score++;
      _roundResult = widget.args.isP1 ? 1 : -1;
      roundResult = widget.args.isP1 ? 'You Win! 🎉' : 'You Lose! 😔';
    } else {
      p2Score++;
      _roundResult = widget.args.isP1 ? -1 : 1;
      roundResult = widget.args.isP1 ? 'You Lose! 😔' : 'You Win! 🎉';
    }

    setState(() {
      _resultMsg = roundResult;
    });
    _resultCtrl.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 1200));
    if (_disposed) return;

    final gameOver =
        (round >= maxR) || (p1Score > maxR ~/ 2) || (p2Score > maxR ~/ 2);

    if (gameOver) {
      String? winner;
      if (p1Score > p2Score) winner = await _getP1Id();
      else if (p2Score > p1Score) winner = await _getP2Id();

      setState(() { _gameOver = true; _resultMsg = ''; });

      await ArcadeService.updateState(widget.args.type, widget.args.gameId, {
        'p1Score': p1Score,
        'p2Score': p2Score,
        'round': round + 1,
        'p1Choice': '',
        'p2Choice': '',
      });
      await ArcadeService.endGame(
          widget.args.type, widget.args.gameId, winner, widget.args.entryFee);

      if (mounted && !_disposed && !_resultShown) {
        _resultShown = true;
        _showFinalResult(p1Score, p2Score);
      }
    } else {
      setState(() { 
        _myChoice = ''; 
        _resultMsg = '';
        _roundResult = null;
      });
      await ArcadeService.updateState(widget.args.type, widget.args.gameId, {
        'p1Score': p1Score,
        'p2Score': p2Score,
        'round': round + 1,
        'p1Choice': '',
        'p2Choice': '',
      });
      _startTimer();
    }
  }

  Future<String> _getP1Id() async {
    if (_disposed) return '';
    final s = await ArcadeService.stateRef(widget.args.type, widget.args.gameId).once();
    return ((s.snapshot.value as Map)['p1'] as String?) ?? '';
  }

  Future<String> _getP2Id() async {
    if (_disposed) return '';
    final s = await ArcadeService.stateRef(widget.args.type, widget.args.gameId).once();
    return ((s.snapshot.value as Map)['p2'] as String?) ?? '';
  }

  // FIXED: Better final result dialog
  void _showFinalResult(int p1Score, int p2Score) {
    final myScore  = widget.args.isP1 ? p1Score : p2Score;
    final oppScore = widget.args.isP1 ? p2Score : p1Score;
    final won  = myScore > oppScore;
    final draw = myScore == oppScore;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              draw ? '🤝' : won ? '🏆' : '😔',
              style: const TextStyle(fontSize: 52),
            ),
            const SizedBox(height: 10),
            Text(
              draw ? 'Match Draw' : won ? 'You Win!' : 'You Lose',
              style: TextStyle(
                color: draw ? ink2Color : won ? goodColor : red,
                fontWeight: FontWeight.w800, fontSize: 26,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: surface2Color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: lineColor),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _scoreCol('YOU', myScore, xColor),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(':', style: TextStyle(fontSize: 28, color: ink3Color, fontWeight: FontWeight.w700)),
                ),
                _scoreCol(widget.args.oppName, oppScore, oColor),
              ]),
            ),
            if (won) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: goldSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.monetization_on_rounded, color: goldColor, size: 18),
                  const SizedBox(width: 6),
                  Text('+${widget.args.entryFee * 2} coins',
                      style: TextStyle(color: const Color(0xFF9A6516), fontWeight: FontWeight.w700, fontSize: 15)),
                ]),
              ),
            ],
            const SizedBox(height: 22),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: xColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () {
                // FIXED: Proper navigation back
                Navigator.of(ctx).pop(); // Close dialog
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted && Navigator.canPop(context)) {
                    Navigator.of(context).pop(); // Close game screen
                  }
                });
              },
              child: const Text('Back to Arcade', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _scoreCol(String label, int score, Color col) {
    return Column(children: [
      Text(
        '$score',
        style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: col),
      ),
      Text(label, style: TextStyle(fontSize: 11, color: ink3Color, fontWeight: FontWeight.w600),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final round    = (_state['round'] as int? ?? 1).clamp(1, 999);
    final maxR     = _state['maxRounds'] as int? ?? 5;
    final myScore  = (widget.args.isP1 ? _state['p1Score'] : _state['p2Score']) as int? ?? 0;
    final oppScore = (widget.args.isP1 ? _state['p2Score'] : _state['p1Score']) as int? ?? 0;
    final oppPicked = (_state[_oppKey] as String? ?? '').isNotEmpty;
    final timerDanger = _timerSecs <= 3;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_disposed) _handleExit();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(children: [

            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: _handleExit,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: lineColor),
                    ),
                    child: Icon(Icons.close_rounded, color: ink2Color, size: 18),
                  ),
                ),
                const Spacer(),
                Column(children: [
                  Text('ROCK PAPER SCISSORS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: inkColor, letterSpacing: 1.5)),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: xSoft, borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('Round $round of $maxR',
                        style: TextStyle(fontSize: 11, color: xColor, fontWeight: FontWeight.w700)),
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
                        color: myScore >= oppScore ? goodColor : ink2Color,
                        fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(' — ', style: TextStyle(color: ink3Color, fontWeight: FontWeight.w700)),
                    Text('$oppScore', style: TextStyle(
                        color: oppScore > myScore ? red : ink2Color,
                        fontWeight: FontWeight.w800, fontSize: 16)),
                  ]),
                ),
              ]),
            ),

            const SizedBox(height: 12),

            // Round progress dots (FIXED)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(maxR, (i) {
                  final roundIdx = i + 1;
                  Color dotColor;
                  double dotSize;
                  if (roundIdx < round) {
                    dotColor = lineColor;
                    dotSize = 8;
                  } else if (roundIdx == round) {
                    dotColor = xColor;
                    dotSize = 12;
                  } else {
                    dotColor = lineColor;
                    dotSize = 8;
                  }
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: dotSize, height: dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                      boxShadow: roundIdx == round
                          ? [BoxShadow(color: xColor.withValues(alpha: 0.4), blurRadius: 8)]
                          : [],
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 16),

            // Timer ring
            if (!_gameOver && _myChoice.isEmpty)
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, child) => Transform.scale(
                  scale: timerDanger ? _pulseAnim.value : 1.0,
                  child: child,
                ),
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox(
                    width: 64, height: 64,
                    child: CircularProgressIndicator(
                      value: _timerSecs / _timerMax,
                      strokeWidth: 5,
                      backgroundColor: lineColor,
                      valueColor: AlwaysStoppedAnimation(
                          timerDanger ? red : xColor),
                    ),
                  ),
                  Text(
                    '$_timerSecs',
                    style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800,
                      color: timerDanger ? red : inkColor,
                    ),
                  ),
                ]),
              ),

            // Result flash
            if (_resultMsg.isNotEmpty)
              ScaleTransition(
                scale: _resultAnim,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _roundResult == 1 ? goodColor.withValues(alpha: 0.12) 
                        : _roundResult == -1 ? red.withValues(alpha: 0.10)
                        : ink2Color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _roundResult == 1 ? goodColor.withValues(alpha: 0.45) 
                          : _roundResult == -1 ? red.withValues(alpha: 0.35)
                          : ink3Color.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(_resultMsg,
                      style: TextStyle(
                        color: _roundResult == 1 ? goodColor 
                            : _roundResult == -1 ? red : ink3Color,
                        fontWeight: FontWeight.w700, fontSize: 15,
                      ), textAlign: TextAlign.center),
                ),
              ),

            const SizedBox(height: 12),

            // Player cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: _PlayerCard(
                  name: 'You',
                  choice: _myChoice,
                  hasPickedEmoji: _myChoice.isNotEmpty ? _emoji[_myChoice]! : null,
                  hasPicked: _myChoice.isNotEmpty,
                  color: xColor,
                  revealChoice: true,
                )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(children: [
                    Text('VS', style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900, color: ink3Color)),
                  ]),
                ),
                Expanded(child: _PlayerCard(
                  name: widget.args.oppName,
                  choice: _state[_oppKey] as String? ?? '',
                  hasPickedEmoji: (oppPicked && _myChoice.isNotEmpty)
                      ? _emoji[_state[_oppKey] as String? ?? '']
                      : null,
                  hasPicked: oppPicked,
                  color: oColor,
                  revealChoice: oppPicked && _myChoice.isNotEmpty,
                )),
              ]),
            ),

            const Spacer(),

            // Pick buttons
            if (_myChoice.isEmpty && !_gameOver) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('Pick your move!',
                    style: TextStyle(fontSize: 13, color: ink2Color, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Row(
                  children: _choices.map((c) {
                    final col = _btnColors[c]!;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: GestureDetector(
                          onTap: () => _pick(c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            height: 100,
                            decoration: BoxDecoration(
                              color: col.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: col.withValues(alpha: 0.45), width: 2),
                              boxShadow: [BoxShadow(color: col.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(_emoji[c]!, style: const TextStyle(fontSize: 36)),
                              const SizedBox(height: 4),
                              Text(_labels[c]!,
                                  style: TextStyle(color: col, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5)),
                            ]),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            if (_myChoice.isNotEmpty && !oppPicked && !_gameOver && _resultMsg.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: xColor),
                  ),
                  const SizedBox(width: 10),
                  Text('Waiting for ${widget.args.oppName}…',
                      style: TextStyle(color: ink2Color, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
            ],

            if (_myChoice.isNotEmpty && _resultMsg.isEmpty && oppPicked)
              const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }
}

// Player Card Widget
class _PlayerCard extends StatelessWidget {
  final String name;
  final String choice;
  final String? hasPickedEmoji;
  final bool hasPicked;
  final Color color;
  final bool revealChoice;

  const _PlayerCard({
    required this.name,
    required this.choice,
    required this.hasPickedEmoji,
    required this.hasPicked,
    required this.color,
    required this.revealChoice,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 120,
      decoration: BoxDecoration(
        color: hasPicked ? color.withValues(alpha: 0.10) : surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasPicked ? color.withValues(alpha: 0.45) : lineColor,
          width: hasPicked ? 2 : 1,
        ),
        boxShadow: hasPicked
            ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 14)]
            : [shadowSm],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (revealChoice && hasPickedEmoji != null)
          Text(hasPickedEmoji!, style: const TextStyle(fontSize: 40))
        else if (hasPicked && !revealChoice)
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, color: color, size: 26),
          )
        else
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: lineColor.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.help_outline_rounded, color: ink3Color, size: 24),
          ),
        const SizedBox(height: 8),
        Text(name,
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: hasPicked ? color : ink2Color,
            ),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(
          hasPicked ? (revealChoice ? '' : 'Picked ✓') : 'Waiting…',
          style: TextStyle(fontSize: 10, color: hasPicked ? color.withValues(alpha: 0.7) : ink3Color),
        ),
      ]),
    );
  }
}