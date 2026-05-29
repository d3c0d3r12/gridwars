import 'dart:async';
import 'package:flutter/material.dart';
import '../../functions/arcade_service.dart';
import '../../helpers/color.dart';
import '../../screens/arcade_lobby.dart';
import '../../screens/splash.dart';
import 'game_widgets.dart';

class RpsGameScreen extends StatefulWidget {
  final GameArgs args;
  const RpsGameScreen({super.key, required this.args});
  @override
  State<RpsGameScreen> createState() => _RpsGameScreenState();
}

class _RpsGameScreenState extends State<RpsGameScreen> {
  Map _state = {};
  String _myChoice = '';
  bool _gameOver = false;
  bool _resultShown = false;
  bool _disposed = false;
  String _resultMsg = '';
  StreamSubscription? _sub;
  bool _abandoned = false;

  String get _p1Key => 'p1Choice';
  String get _p2Key => 'p2Choice';
  String get _myKey => widget.args.isP1 ? _p1Key : _p2Key;
  String get _oppKey => widget.args.isP1 ? _p2Key : _p1Key;

  static const _choices = ['rock', 'paper', 'scissors'];
  static const _emoji = {'rock': '✊', 'paper': '✋', 'scissors': '✌️'};
  static const _beats = {'rock': 'scissors', 'paper': 'rock', 'scissors': 'paper'};

  @override
  void initState() {
    super.initState();
    _sub = ArcadeService.stateRef(widget.args.type, widget.args.gameId)
        .onValue
        .listen((ev) {
      if (_disposed || !mounted || ev.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(ev.snapshot.value as Map);
      if (data['status'] == 'finished' || data['status'] == 'cancelled') {
        if (!_gameOver && !_abandoned && mounted && !_disposed) {
          setState(() => _gameOver = true);
          if (!_resultShown) {
            _resultShown = true;
            Future.delayed(Duration.zero, () => showOpponentLeftDialog(context));
          }
        }
        return;
      }
      final st = Map<String, dynamic>.from(data['state'] as Map);
      setState(() => _state = st);
      _checkRound(st);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }

  void _abandonGame() async {
    if (_gameOver || _abandoned || _disposed) return;
    _abandoned = true;
    setState(() => _gameOver = true);
    _sub?.cancel();
    await ArcadeService.endGame(widget.args.type, widget.args.gameId, widget.args.oppId, widget.args.entryFee);
    if (mounted && !_disposed) Navigator.pop(context);
  }

  void _handleExit() => showLeaveConfirmDialog(context, _abandonGame);

  void _pick(String choice) async {
    if (_myChoice.isNotEmpty || _gameOver || _disposed) return;
    setState(() => _myChoice = choice);
    await ArcadeService.updateState(widget.args.type, widget.args.gameId, {_myKey: choice});
  }

  // FIXED: Better round resolution with proper end game handling
  void _checkRound(Map st) async {
    final p1 = st[_p1Key] as String? ?? '';
    final p2 = st[_p2Key] as String? ?? '';
    if (p1.isEmpty || p2.isEmpty) return;

    if (_disposed) return;

    int p1Score = (st['p1Score'] as int? ?? 0);
    int p2Score = (st['p2Score'] as int? ?? 0);
    final round  = st['round'] as int? ?? 1;
    final maxR   = st['maxRounds'] as int? ?? 5;

    String roundResult;
    if (p1 == p2) {
      roundResult = 'Draw!';
    } else if (_beats[p1] == p2) {
      p1Score++;
      roundResult = widget.args.isP1 ? 'You win this round! 🎉' : 'Opponent wins round';
    } else {
      p2Score++;
      roundResult = widget.args.isP1 ? 'Opponent wins round' : 'You win this round! 🎉';
    }

    setState(() { _resultMsg = roundResult; });

    // Clear choices after showing result
    await Future.delayed(const Duration(milliseconds: 800));

    if (_disposed) return;

    // Check if game is over
    final gameOver = (round >= maxR) || (p1Score > maxR ~/ 2) || (p2Score > maxR ~/ 2);

    if (gameOver) {
      String? winner;
      if (p1Score > p2Score) winner = await _getP1Id();
      else if (p2Score > p1Score) winner = await _getP2Id();

      setState(() { _gameOver = true; });

      await ArcadeService.updateState(widget.args.type, widget.args.gameId,
          {'p1Score': p1Score, 'p2Score': p2Score, 'round': round + 1, 'p1Choice': '', 'p2Choice': ''});
      await ArcadeService.endGame(widget.args.type, widget.args.gameId, winner, widget.args.entryFee);

      if (mounted && !_disposed && !_resultShown) {
        _resultShown = true;
        _showResult(p1Score, p2Score);
      }
    } else {
      setState(() { _myChoice = ''; });
      await ArcadeService.updateState(widget.args.type, widget.args.gameId,
          {'p1Score': p1Score, 'p2Score': p2Score, 'round': round + 1, 'p1Choice': '', 'p2Choice': ''});
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

  void _showResult(int p1Score, int p2Score) {
    final myScore  = widget.args.isP1 ? p1Score : p2Score;
    final oppScore = widget.args.isP1 ? p2Score : p1Score;
    final won = myScore > oppScore;
    final draw = myScore == oppScore;

    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: secondarySelectedColor.withValues(alpha: 0.4))),
      title: Text(draw ? '🤝 Draw!' : won ? '🏆 You Win!' : '😔 You Lose', style: TextStyle(color: inkColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      content: Text('$myScore — $oppScore', style: TextStyle(color: secondarySelectedColor, fontSize: 32, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      actions: [TextButton(onPressed: () {
        if (Navigator.canPop(context)) Navigator.pop(context);
        if (Navigator.canPop(context)) Navigator.pop(context);
      }, child: Text('Back', style: TextStyle(color: secondarySelectedColor)))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final round  = _state['round'] as int? ?? 1;
    final maxR   = _state['maxRounds'] as int? ?? 5;
    final myScore  = widget.args.isP1 ? (_state['p1Score'] ?? 0) : (_state['p2Score'] ?? 0);
    final oppScore = widget.args.isP1 ? (_state['p2Score'] ?? 0) : (_state['p1Score'] ?? 0);
    final oppPicked = (_state[_oppKey] as String? ?? '').isNotEmpty;

    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) { if (!didPop && !_disposed) _handleExit(); },
        child: Scaffold(
          body: Container(
            color: bgColor,
            child: SafeArea(child: Column(children: [
              _header(context, 'ROCK PAPER SCISSORS', 'Round $round / $maxR', myScore, oppScore, onExit: _handleExit),
              const SizedBox(height: 12),

              if (_resultMsg.isNotEmpty)
                _pill(_resultMsg, secondarySelectedColor),
              if (_myChoice.isNotEmpty && !oppPicked && !_gameOver)
                _pill('Waiting for ${widget.args.oppName}…', white.withValues(alpha: 0.6)),
              if (_myChoice.isEmpty && !_gameOver)
                _pill('Pick your move!', white.withValues(alpha: 0.7)),

              const SizedBox(height: 20),

              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _choiceCircle(
                  label: 'You',
                  emoji: _myChoice.isNotEmpty ? _emoji[_myChoice]! : '?',
                  color: secondarySelectedColor,
                  picked: _myChoice.isNotEmpty,
                ),
                Text('VS', style: TextStyle(color: white.withValues(alpha: 0.4), fontWeight: FontWeight.bold, fontSize: 18)),
                _choiceCircle(
                  label: widget.args.oppName,
                  emoji: oppPicked && _myChoice.isNotEmpty ? _emoji[_state[_oppKey]]! : '?',
                  color: const Color(0xFFE91E63),
                  picked: oppPicked,
                ),
              ]),

              const SizedBox(height: 32),

              if (_myChoice.isEmpty && !_gameOver)
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: _choices.map((c) =>
                    GestureDetector(
                      onTap: () => _pick(c),
                      child: Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: white.withValues(alpha: 0.08),
                          border: Border.all(color: white.withValues(alpha: 0.2), width: 1.5),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(_emoji[c]!, style: const TextStyle(fontSize: 34)),
                          Text(c[0].toUpperCase() + c.substring(1), style: TextStyle(color: white.withValues(alpha: 0.7), fontSize: 10)),
                        ]),
                      ),
                    )
                ).toList()),

              if (_myChoice.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Picked: ${_emoji[_myChoice]} ${_myChoice[0].toUpperCase()}${_myChoice.substring(1)}',
                      style: TextStyle(color: secondarySelectedColor, fontWeight: FontWeight.bold, fontSize: 18)),
                ),
            ])),
          ),
        ));
  }

  Widget _choiceCircle({required String label, required String emoji, required Color color, required bool picked}) {
    return Column(children: [
      Text(label, style: TextStyle(color: white.withValues(alpha: 0.6), fontSize: 11)),
      const SizedBox(height: 8),
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: picked ? 0.2 : 0.06),
          border: Border.all(color: color.withValues(alpha: picked ? 0.7 : 0.2), width: 2),
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 36))),
      ),
    ]);
  }
}

Widget _header(BuildContext ctx, String title, String sub, int myScore, int oppScore, {VoidCallback? onExit}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    child: Row(children: [
      GestureDetector(onTap: onExit ?? () {
        if (Navigator.canPop(ctx)) Navigator.pop(ctx);
      }, child: Icon(Icons.close, color: white.withValues(alpha: 0.7))),
      const Spacer(),
      Column(children: [
        Text(title, style: TextStyle(color: inkColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
        Text(sub, style: TextStyle(color: secondarySelectedColor, fontSize: 11)),
      ]),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: secondaryColor),
        child: Text('$myScore — $oppScore', style: TextStyle(color: inkColor, fontWeight: FontWeight.bold)),
      ),
    ]),
  );
}

Widget _pill(String text, Color color) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      color: color.withValues(alpha: 0.12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
  );
}