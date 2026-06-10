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

class BattleshipGameScreen extends StatefulWidget {
  final GameArgs args;
  const BattleshipGameScreen({super.key, required this.args});
  @override
  State<BattleshipGameScreen> createState() => _BattleshipGameScreenState();
}

class _BattleshipGameScreenState extends State<BattleshipGameScreen> {
  List<int> _myShips    = List.filled(100, 0);
  List<int> _myAttacks  = List.filled(100, 0);
  List<int> _oppAttacks = List.filled(100, 0);
  String _phase = 'placement';
  int _turn = 1, _myHits = 0, _oppHits = 0;
  bool _myReady = false, _oppReady = false, _gameOver = false;
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
  final String _myUid = FirebaseAuth.instance.currentUser!.uid;

  static const int _totalShipCells = 17;

  bool get _vsAi => widget.args.vsAi;
  List<int> _aiShips = List.filled(100, 0); // bot's fleet (vs-AI only)

  @override
  void initState() {
    super.initState();
    _myNum = widget.args.isP1 ? 1 : 2;
    _myShips = ArcadeService.randomShipPlacement();

    // Local vs-Computer practice: bot gets its own fleet and is always "ready".
    if (_vsAi) {
      _aiShips = ArcadeService.randomShipPlacement();
      _oppReady = true;
      return;
    }

    _sub = ArcadeService.stateRef(widget.args.type, widget.args.gameId)
        .child('state')
        .onValue
        .listen((ev) {
      if (_disposed || !mounted || ev.snapshot.value == null) return;
      final st = Map<String, dynamic>.from(ev.snapshot.value as Map);
      setState(() {
        _phase = st['phase']?.toString() ?? 'placement';
        _turn  = int.parse(st['turn'].toString());
        _myReady  = int.parse(st[widget.args.isP1 ? 'p1Ready' : 'p2Ready'].toString()) == 1;
        _oppReady = int.parse(st[widget.args.isP1 ? 'p2Ready' : 'p1Ready'].toString()) == 1;
        _myHits  = int.parse(st['p${widget.args.isP1 ? 1 : 2}Hits'].toString());
        _oppHits = int.parse(st['p${widget.args.isP1 ? 2 : 1}Hits'].toString());

        final p1Ships = List<int>.from((st['p1Ships'] as List).map((e) => int.parse(e.toString())));
        final p2Ships = List<int>.from((st['p2Ships'] as List).map((e) => int.parse(e.toString())));
        final p1A = List<int>.from((st['p1Attacks'] as List).map((e) => int.parse(e.toString())));
        final p2A = List<int>.from((st['p2Attacks'] as List).map((e) => int.parse(e.toString())));

        if (widget.args.isP1) {
          _myShips    = p1Ships;
          _myAttacks  = p2A;
          _oppAttacks = p1A;
        } else {
          _myShips    = p2Ships;
          _myAttacks  = p1A;
          _oppAttacks = p2A;
        }
      });

      // Call _endGame AFTER setState so widget tree is consistent.
      if (_myHits >= _totalShipCells && !_gameOver) {
        Future.microtask(() => _endGame(false));
      } else if (_oppHits >= _totalShipCells && !_gameOver) {
        Future.microtask(() => _endGame(true));
      }
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
  // Covers the placement phase too: if the opponent never readies up because
  // they left, you still win instead of waiting forever.
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

  void _finish(String? winner) {
    if (_gameOver || _resultShown || _disposed || !mounted) return;
    setState(() => _gameOver = true);
    _showResult(winner != null && winner.isNotEmpty && winner == _myUid);
  }

  // True when the game is waiting on the OPPONENT to act: their attack turn, or
  // (during placement) I'm ready and they still haven't readied up.
  bool get _waitingOnOpp {
    if (_gameOver) return false;
    if (_phase == 'attack') return !_myTurn;
    return _myReady && !_oppReady;
  }

  // "Time over" watchdog: opponent forfeits if they stall (but stay connected)
  // past the limit while it's their move / ready-up. Never arms on my own turn.
  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (!_waitingOnOpp) return;
    _idleTimer = Timer(const Duration(seconds: 45), () {
      if (_gameOver || _disposed || !mounted || !_waitingOnOpp) return;
      ArcadeService.endGame(widget.args.type, widget.args.gameId, _myUid, widget.args.entryFee);
      _finish(_myUid);
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

  bool get _myTurn => _turn == _myNum && _phase == 'attack' && !_gameOver;

  Future<void> _readyUp() async {
    if (_disposed) return;
    if (_vsAi) {
      // Bot is already ready — go straight to the attack phase, human fires first.
      setState(() { _myReady = true; _phase = 'attack'; _turn = 1; });
      return;
    }
    setState(() => _myReady = true);
    final myKey   = widget.args.isP1 ? 'p1Ready' : 'p2Ready';
    final shipsKey = widget.args.isP1 ? 'p1Ships' : 'p2Ships';
    final updates = {myKey: 1, shipsKey: _myShips};
    await ArcadeService.updateState(widget.args.type, widget.args.gameId, updates);

    // Only P1 writes the phase transition to avoid the race condition where
    // both players detect _oppReady==true simultaneously and both write
    // 'attack', causing duplicate Firebase writes with potentially stale ready flags.
    if (_oppReady && widget.args.isP1) {
      await ArcadeService.updateState(widget.args.type, widget.args.gameId, {
        'phase': 'attack',
        'turn': 1,
      });
    }
  }

  void _randomize() {
    if (_disposed) return;
    setState(() => _myShips = ArcadeService.randomShipPlacement());
  }

  Future<void> _fire(int idx) async {
    if (!_myTurn || _gameOver || _disposed) return;
    if (_oppAttacks[idx] != 0) return; // _oppAttacks = MY shots on the enemy grid

    // ── Local vs-Computer practice ──
    if (_vsAi) {
      final isHit = _aiShips[idx] == 1;
      final shots = List<int>.from(_oppAttacks)..[idx] = isHit ? 2 : 3;
      final newHits = _myHits + (isHit ? 1 : 0);
      music.play(dice);
      setState(() { _oppAttacks = shots; _myHits = newHits; if (!isHit) _turn = 2; });
      if (newHits >= _totalShipCells) { _endGame(true); return; }
      if (!isHit) _scheduleAiFire();
      return;
    }

    final oppShipsKey = widget.args.isP1 ? 'p2Ships' : 'p1Ships';
    final myAtkKey    = widget.args.isP1 ? 'p1Attacks' : 'p2Attacks';
    final oppHitsKey  = widget.args.isP1 ? 'p1Hits' : 'p2Hits';

    final snap = await ArcadeService.stateRef(widget.args.type, widget.args.gameId).child('state').once();
    if (_disposed) return;
    final st   = Map<String, dynamic>.from(snap.snapshot.value as Map);
    final oppShips = List<int>.from((st[oppShipsKey] as List).map((e) => int.parse(e.toString())));
    final myAtks   = List<int>.from((st[myAtkKey]    as List).map((e) => int.parse(e.toString())));

    final isHit = oppShips[idx] == 1;
    myAtks[idx] = isHit ? 2 : 3;
    music.play(dice);

    final currentHits = int.parse(st[oppHitsKey].toString());
    final newHits = currentHits + (isHit ? 1 : 0);

    // FIXED: Proper turn switching
    int nextTurn = _turn;
    if (newHits >= _totalShipCells) {
      // Game over - no need to switch turn
      nextTurn = _turn;
    } else if (!isHit) {
      // Miss - switch turn
      nextTurn = _turn == 1 ? 2 : 1;
    } else {
      // Hit - same player gets another turn
      nextTurn = _turn;
    }

    await ArcadeService.updateState(widget.args.type, widget.args.gameId,
        {myAtkKey: myAtks, oppHitsKey: newHits, 'turn': nextTurn});

    if (newHits >= _totalShipCells) {
      _endGame(true);
    }
  }

  // Bot fires on the human's fleet (_myShips). Keeps firing while it hits.
  void _scheduleAiFire() {
    Future.delayed(const Duration(milliseconds: 750), () {
      if (!mounted || _gameOver || _disposed || _turn != 2) return;
      // _myAttacks = the opponent's shots on my board (the bot's attack history).
      final idx = BattleshipAi.nextAttack(_myShips, _myAttacks, widget.args.aiLevel);
      if (idx < 0) return;
      final isHit = _myShips[idx] == 1;
      final shots = List<int>.from(_myAttacks)..[idx] = isHit ? 2 : 3;
      final newOppHits = _oppHits + (isHit ? 1 : 0);
      music.play(dice);
      setState(() { _myAttacks = shots; _oppHits = newOppHits; if (!isHit) _turn = 1; });
      if (newOppHits >= _totalShipCells) { _endGame(false); return; }
      if (isHit) _scheduleAiFire(); // hit → fire again
    });
  }

  void _endGame(bool won) async {
    if (_gameOver || _disposed) return;
    // Loser must record the OPPONENT as winner (not null/draw) so both sides
    // agree on the result regardless of which write commits first.
    final winnerId = won ? _myUid : widget.args.oppId;
    if (!_vsAi) {
      await ArcadeService.endGame(widget.args.type, widget.args.gameId, winnerId, widget.args.entryFee);
    }
    _finish(winnerId);
  }

  void _showResult(bool won) {
    if (_resultShown) return;
    _resultShown = true;
    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: xColor.withValues(alpha: 0.4))),
      title: Text(won ? '🏆 All Ships Sunk!' : '💥 Fleet Destroyed!', style: TextStyle(color: inkColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      content: Text(_vsAi ? (won ? 'You beat the Computer!' : 'The Computer won!') : (won ? 'You Win!\n+${widget.args.entryFee * 2} coins' : 'You Lose!'), style: TextStyle(color: xColor, fontSize: 18), textAlign: TextAlign.center),
      actions: [TextButton(onPressed: () {
        if (Navigator.canPop(context)) Navigator.pop(context);
        if (Navigator.canPop(context)) Navigator.pop(context);
      }, child: Text('Back', style: TextStyle(color: xColor)))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) { if (!didPop && !_disposed) _handleExit(); },
        child: Scaffold(
          body: Container(
            color: bgColor,
            child: SafeArea(child: Column(children: [
              gameHeader(context, 'BATTLESHIP',
                  _phase == 'placement' ? 'Setup Phase' : (_myTurn ? 'Your Turn — Fire!' : "${widget.args.oppName}'s Turn"),
                  _oppHits, _myHits, onExit: _handleExit),
              const SizedBox(height: 6),

              if (_phase == 'placement') ...[
                gamePill(_myReady ? 'Waiting for ${widget.args.oppName}…' : 'Place your fleet and press READY!', secondarySelectedColor),
                const SizedBox(height: 8),
                Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(children: [
                    Text('YOUR FLEET', style: TextStyle(color: inkColor.withValues(alpha: 0.6), fontSize: 11, letterSpacing: 2)),
                    const SizedBox(height: 6),
                    Expanded(child: _grid(_myShips, isMyGrid: true, readonly: _myReady)),
                    const SizedBox(height: 12),
                    if (!_myReady) Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                      _btn('🔀 Randomize', _randomize, const Color(0xFF2196F3)),
                      _btn('✅ Ready!', _readyUp, const Color(0xFF4CAF50)),
                    ]),
                  ]),
                )),
              ] else ...[
                if (_myTurn) gamePill('Tap opponent\'s grid to fire! 🎯', secondarySelectedColor),
                if (!_myTurn && !_gameOver) gamePill("${widget.args.oppName} is firing…", inkColor.withValues(alpha: 0.5)),
                const SizedBox(height: 6),
                Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(children: [
                    Text('OPPONENT WATERS', style: TextStyle(color: inkColor.withValues(alpha: 0.6), fontSize: 10, letterSpacing: 2)),
                    const SizedBox(height: 4),
                    Expanded(child: GestureDetector(
                      onTapUp: (det) {
                        final size = (MediaQuery.of(context).size.width - 24) / 10;
                        final col = (det.localPosition.dx / size).floor().clamp(0, 9);
                        final row = (det.localPosition.dy / size).floor().clamp(0, 9);
                        _fire(row * 10 + col);
                      },
                      child: _grid(_oppAttacks, isMyGrid: false, readonly: !_myTurn),
                    )),
                    const SizedBox(height: 8),
                    Text('YOUR FLEET', style: TextStyle(color: inkColor.withValues(alpha: 0.6), fontSize: 10, letterSpacing: 2)),
                    const SizedBox(height: 4),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.22,
                        child: _gridWithAttacks(_myShips, _myAttacks)),
                  ]),
                )),
              ],
              const SizedBox(height: 8),
            ])),
          ),
        ));
  }

  Widget _grid(List<int> data, {required bool isMyGrid, required bool readonly}) {
    return AspectRatio(aspectRatio: 1, child: GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10, crossAxisSpacing: 2, mainAxisSpacing: 2),
      itemCount: 100,
      itemBuilder: (_, i) {
        final val = data[i];
        Color bg;
        String icon = '';
        if (isMyGrid) {
          bg = val == 1 ? const Color(0xFF37474F) : secondaryColor;
        } else {
          bg = val == 0 ? secondaryColor.withValues(alpha: 0.5) : val == 2 ? const Color(0xFFE53935) : const Color(0xFF455A64);
          if (val == 2) icon = '💥';
          if (val == 3) icon = '○';
        }
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: inkColor.withValues(alpha: 0.08), width: 0.5),
          ),
          child: Center(child: Text(icon, style: const TextStyle(fontSize: 8))),
        );
      },
    ));
  }

  Widget _gridWithAttacks(List<int> ships, List<int> attacks) {
    return AspectRatio(aspectRatio: 1, child: GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10, crossAxisSpacing: 2, mainAxisSpacing: 2),
      itemCount: 100,
      itemBuilder: (_, i) {
        final ship = ships[i];
        final atk  = attacks[i];
        Color bg;
        String icon = '';
        if (atk == 2) { bg = const Color(0xFFE53935); icon = '💥'; }
        else if (atk == 3) { bg = const Color(0xFF455A64); icon = '○'; }
        else if (ship == 1) bg = const Color(0xFF37474F);
        else bg = secondaryColor;
        return Container(
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(2), border: Border.all(color: inkColor.withValues(alpha: 0.08), width: 0.5)),
          child: Center(child: Text(icon, style: const TextStyle(fontSize: 8))),
        );
      },
    ));
  }

  Widget _btn(String label, VoidCallback onTap, Color color) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: color.withValues(alpha: 0.2), border: Border.all(color: color.withValues(alpha: 0.5))),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    ),
  );
}