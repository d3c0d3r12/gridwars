import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../functions/arcade_service.dart';
import '../../helpers/color.dart';
import '../../helpers/constant.dart';
import '../../helpers/utils.dart';
import '../../screens/splash.dart' show utils;
import 'game_widgets.dart';
import '../../screens/arcade_lobby.dart';

// 10×10 grid. Ships: 5,4,3,3,2 → 17 total cells.
// Phase 1: placement (both players randomize/ready)
// Phase 2: attack (take turns, 0=water,1=ship,2=hit,3=miss)
class BattleshipGameScreen extends StatefulWidget {
  final GameArgs args;
  const BattleshipGameScreen({super.key, required this.args});
  @override
  State<BattleshipGameScreen> createState() => _BattleshipGameScreenState();
}

class _BattleshipGameScreenState extends State<BattleshipGameScreen> {
  List<int> _myShips    = List.filled(100, 0);
  List<int> _myAttacks  = List.filled(100, 0); // attacks on MY grid
  List<int> _oppAttacks = List.filled(100, 0); // my attacks on OPP grid
  String _phase = 'placement';
  int _turn = 1, _myHits = 0, _oppHits = 0;
  bool _myReady = false, _oppReady = false, _gameOver = false;
  StreamSubscription? _sub;
  StreamSubscription? _statusSub;
  late int _myNum;

  static const int _totalShipCells = 17;

  @override
  void initState() {
    super.initState();
    _myNum = widget.args.isP1 ? 1 : 2;
    _myShips = ArcadeService.randomShipPlacement();

    _sub = ArcadeService.stateRef(widget.args.type, widget.args.gameId)
        .child('state')
        .onValue
        .listen((ev) {
      if (!mounted || ev.snapshot.value == null) return;
      final st = Map<String, dynamic>.from(ev.snapshot.value as Map);
      setState(() {
        _phase = st['phase']?.toString() ?? 'placement';
        _turn  = int.parse(st['turn'].toString());
        _myReady  = int.parse(st[widget.args.isP1 ? 'p1Ready' : 'p2Ready'].toString()) == 1;
        _oppReady = int.parse(st[widget.args.isP1 ? 'p2Ready' : 'p1Ready'].toString()) == 1;
        _myHits  = int.parse(st['p${widget.args.isP1 ? 1 : 2}Hits'].toString());
        _oppHits = int.parse(st['p${widget.args.isP1 ? 2 : 1}Hits'].toString());
        // My ships (always loaded from local — opponent can't see them)
        final p1Ships = List<int>.from((st['p1Ships'] as List).map((e) => int.parse(e.toString())));
        final p2Ships = List<int>.from((st['p2Ships'] as List).map((e) => int.parse(e.toString())));
        // My attacks on opp grid
        final p1A = List<int>.from((st['p1Attacks'] as List).map((e) => int.parse(e.toString())));
        final p2A = List<int>.from((st['p2Attacks'] as List).map((e) => int.parse(e.toString())));
        if (widget.args.isP1) {
          _myShips    = p1Ships;
          _myAttacks  = p2A;  // attacks ON my grid = p2's attacks
          _oppAttacks = p1A;  // MY attacks on opp = p1's attacks
        } else {
          _myShips    = p2Ships;
          _myAttacks  = p1A;
          _oppAttacks = p2A;
        }
      });
      if (_myHits >= _totalShipCells) _endGame(false); // I've been sunk
      if (_oppHits >= _totalShipCells) _endGame(true);  // I sank all opp ships
    });
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
    if (_gameOver) return;
    setState(() => _gameOver = true);
    _sub?.cancel();
    _statusSub?.cancel();
    await ArcadeService.endGame(widget.args.type, widget.args.gameId, widget.args.oppId, widget.args.entryFee);
    if (mounted) Navigator.pop(context);
  }

  void _handleExit() => showLeaveConfirmDialog(context, _abandonGame);

  bool get _myTurn => _turn == _myNum && _phase == 'attack' && !_gameOver;

  Future<void> _readyUp() async {
    setState(() => _myReady = true);
    final myKey   = widget.args.isP1 ? 'p1Ready' : 'p2Ready';
    final shipsKey = widget.args.isP1 ? 'p1Ships' : 'p2Ships';
    final updates = {myKey: 1, shipsKey: _myShips};
    await ArcadeService.updateState(widget.args.type, widget.args.gameId, updates);
    // If both ready, start attack phase
    if (_oppReady) {
      await ArcadeService.updateState(widget.args.type, widget.args.gameId, {'phase': 'attack', 'turn': 1});
    }
  }

  void _randomize() {
    setState(() => _myShips = ArcadeService.randomShipPlacement());
  }

  Future<void> _fire(int idx) async {
    if (!_myTurn || _oppAttacks[idx] != 0) return;
    final oppShipsKey = widget.args.isP1 ? 'p2Ships' : 'p1Ships';
    final myAtkKey    = widget.args.isP1 ? 'p1Attacks' : 'p2Attacks';
    final oppHitsKey  = widget.args.isP1 ? 'p1Hits' : 'p2Hits';

    // Read opponent ships
    final snap = await ArcadeService.stateRef(widget.args.type, widget.args.gameId).child('state').once();
    final st   = Map<String, dynamic>.from(snap.snapshot.value as Map);
    final oppShips = List<int>.from((st[oppShipsKey] as List).map((e) => int.parse(e.toString())));
    final myAtks   = List<int>.from((st[myAtkKey]    as List).map((e) => int.parse(e.toString())));

    final isHit = oppShips[idx] == 1;
    myAtks[idx] = isHit ? 2 : 3;
    music.play(dice);

    final newHits = int.parse(st[oppHitsKey].toString()) + (isHit ? 1 : 0);
    final next    = _turn == 1 ? 2 : 1;

    await ArcadeService.updateState(widget.args.type, widget.args.gameId,
        {myAtkKey: myAtks, oppHitsKey: newHits, 'turn': newHits >= _totalShipCells ? _turn : next});

    if (newHits >= _totalShipCells) {
      _endGame(true);
    }
  }

  void _endGame(bool won) async {
    if (_gameOver) return;
    setState(() => _gameOver = true);
    await ArcadeService.endGame(widget.args.type, widget.args.gameId,
        won ? FirebaseAuth.instance.currentUser!.uid : null, widget.args.entryFee);
    if (mounted) _showResult(won);
  }

  void _showResult(bool won) {
    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      backgroundColor: secondaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: secondarySelectedColor.withValues(alpha: 0.4))),
      title: Text(won ? '🏆 All Ships Sunk!' : '💥 Fleet Destroyed!', style: TextStyle(color: white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      content: Text(won ? 'You Win!\n+${widget.args.entryFee * 2} coins' : 'You Lose!', style: TextStyle(color: secondarySelectedColor, fontSize: 18), textAlign: TextAlign.center),
      actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: Text('Back', style: TextStyle(color: secondarySelectedColor)))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _handleExit(); },
      child: Scaffold(
      body: Container(
        decoration: utils.gradBack(),
        child: SafeArea(child: Column(children: [
          gameHeader(context, 'BATTLESHIP',
              _phase == 'placement' ? 'Setup Phase' : (_myTurn ? 'Your Turn — Fire!' : "${widget.args.oppName}'s Turn"),
              _oppHits, _myHits, onExit: _handleExit),
          const SizedBox(height: 6),

          if (_phase == 'placement') ...[
            gamePill(_myReady ? 'Waiting for ${widget.args.oppName}…' : 'Place your fleet and press READY!', secondarySelectedColor),
            const SizedBox(height: 8),
            // My grid (placement)
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(children: [
                Text('YOUR FLEET', style: TextStyle(color: white.withValues(alpha: 0.6), fontSize: 11, letterSpacing: 2)),
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
            // Attack phase: two grids
            if (_myTurn) gamePill('Tap opponent\'s grid to fire! 🎯', secondarySelectedColor),
            if (!_myTurn && !_gameOver) gamePill("${widget.args.oppName} is firing…", white.withValues(alpha: 0.5)),
            const SizedBox(height: 6),
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(children: [
                Text('OPPONENT WATERS', style: TextStyle(color: white.withValues(alpha: 0.6), fontSize: 10, letterSpacing: 2)),
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
                Text('YOUR FLEET', style: TextStyle(color: white.withValues(alpha: 0.6), fontSize: 10, letterSpacing: 2)),
                const SizedBox(height: 4),
                SizedBox(height: MediaQuery.of(context).size.height * 0.22,
                  child: _gridWithAttacks(_myShips, _myAttacks)),
              ]),
            )),
          ],
          const SizedBox(height: 8),
        ])),
      ),
      ), // Scaffold
    ); // PopScope
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
            border: Border.all(color: white.withValues(alpha: 0.08), width: 0.5),
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
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(2), border: Border.all(color: white.withValues(alpha: 0.08), width: 0.5)),
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
