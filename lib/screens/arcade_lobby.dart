import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../functions/arcade_service.dart';
import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../screens/splash.dart';
import 'games/battleship_game.dart';
import 'games/checkers_game.dart';
import 'games/connect4_game.dart';
import 'games/dots_boxes_game.dart';
import 'games/gomoku_game.dart';
import 'games/rps_game.dart';

class ArcadeLobbyScreen extends StatefulWidget {
  final String gameType;
  final String gameName;
  final Color accent;
  const ArcadeLobbyScreen({super.key, required this.gameType, required this.gameName, required this.accent});

  @override
  State<ArcadeLobbyScreen> createState() => _ArcadeLobbyScreenState();
}

class _ArcadeLobbyScreenState extends State<ArcadeLobbyScreen> {
  String _status = 'Finding opponent…';
  String _gameId = '';
  bool _searching = true;
  StreamSubscription? _sub;
  StreamSubscription? _lobbySub;
  Timer? _timeout;
  bool _navigated = false; // guard against double navigation
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _find();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _lobbySub?.cancel();
    _timeout?.cancel();
    super.dispose();
  }

  Future<void> _find() async {
    _navigated = false;
    final result = await ArcadeService.findOrCreate(widget.gameType, entryFee: fixedEntryFee);
    if (!mounted) return;
    final gameId = result['gameId'] as String;
    setState(() => _gameId = gameId);

    if (result['status'] == 'joined') {
      final oppId = result['opponentId'] as String;
      final info  = await ArcadeService.userInfo(oppId);
      if (mounted && !_navigated) {
        _navigated = true;
        _navigate(gameId, isP1: false, oppId: oppId, oppName: info['username']!);
      }
      return;
    }

    // Created (or re-entering waiting state) — set up two parallel listeners:
    // 1. Watch OUR game for someone joining via the normal findOrCreate path.
    // 2. Watch the lobby for games created BEFORE ours (simultaneous-start fix).

    _timeout = Timer(const Duration(seconds: 60), () {
      if (!mounted) return;
      ArcadeService.cancelGame(widget.gameType, gameId);
      setState(() { _searching = false; _status = 'No opponent found.\nTap to try again.'; });
    });

    _sub = FirebaseDatabase.instance
        .ref()
        .child('arcadeGames')
        .child(widget.gameType)
        .child(gameId)
        .child('status')
        .onValue
        .listen((ev) async {
      if (_navigated || ev.snapshot.value != 'active' || !mounted) return;
      _navigated = true;
      _timeout?.cancel();
      _sub?.cancel();
      _lobbySub?.cancel();

      // Fire-and-forget coin deduction so we don't block navigation.
      FirebaseDatabase.instance.ref()
          .child('users').child(_uid).child('coin')
          .runTransaction((v) => Transaction.success((v as int? ?? 0) - fixedEntryFee));

      final snap = await FirebaseDatabase.instance.ref()
          .child('arcadeGames').child(widget.gameType).child(gameId).once();
      if (!mounted) return;
      final data = Map<String, dynamic>.from(snap.snapshot.value as Map? ?? {});
      final oppId = data['p2'] as String? ?? '';
      if (oppId.isEmpty) { _navigated = false; return; } // p2 not written yet, retry
      final info  = await ArcadeService.userInfo(oppId);
      if (mounted) _navigate(gameId, isP1: true, oppId: oppId, oppName: info['username']!);
    });

    // Secondary lobby watcher: if another player created a game BEFORE ours
    // (smaller Firebase push key = earlier timestamp), we join them. This fixes
    // the race where two players call findOrCreate simultaneously and both create.
    _lobbySub = FirebaseDatabase.instance
        .ref()
        .child('arcadeLobby')
        .child(widget.gameType)
        .onChildAdded
        .listen((ev) async {
      if (_navigated || !mounted) return;
      final otherKey = ev.snapshot.key!;
      final hostUid  = ev.snapshot.value?.toString() ?? '';
      // Only join a game that was created before ours and isn't ours.
      if (otherKey == gameId || hostUid == _uid || otherKey.compareTo(gameId) >= 0) return;

      final ok = await ArcadeService.tryJoinExisting(widget.gameType, otherKey, fixedEntryFee);
      if (!ok || !mounted || _navigated) return;
      _navigated = true;
      _timeout?.cancel();
      _sub?.cancel();
      _lobbySub?.cancel();
      // Cancel our own waiting game so it doesn't stay in the lobby.
      ArcadeService.cancelGame(widget.gameType, gameId);
      final info = await ArcadeService.userInfo(hostUid);
      if (mounted) _navigate(otherKey, isP1: false, oppId: hostUid, oppName: info['username']!);
    });
  }

  void _navigate(String gameId, {required bool isP1, required String oppId, required String oppName}) {
    Widget screen;
    final args = _GameArgs(gameId: gameId, type: widget.gameType, isP1: isP1, oppId: oppId, oppName: oppName, entryFee: fixedEntryFee);
    switch (widget.gameType) {
      case 'rps':        screen = RpsGameScreen(args: args); break;
      case 'connect4':   screen = Connect4GameScreen(args: args); break;
      case 'gomoku':     screen = GomokuGameScreen(args: args); break;
      case 'dotsboxes':  screen = DotsBoxesGameScreen(args: args); break;
      case 'checkers':   screen = CheckersGameScreen(args: args); break;
      case 'battleship': screen = BattleshipGameScreen(args: args); break;
      default: return;
    }
    Navigator.pushReplacement(context, CupertinoPageRoute(builder: (_) => screen));
  }

  void _retry() {
    _sub?.cancel();
    _lobbySub?.cancel();
    _timeout?.cancel();
    setState(() { _searching = true; _status = 'Finding opponent…'; _gameId = ''; });
    _find();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: utils.gradBack(),
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: white),
                  onPressed: () async {
                    _sub?.cancel();
                    _lobbySub?.cancel();
                    _timeout?.cancel();
                    if (_gameId.isNotEmpty && _searching) {
                      await ArcadeService.cancelGame(widget.gameType, _gameId);
                    }
                    if (mounted) Navigator.pop(context);
                  },
                ),
                const Spacer(),
                Text(widget.gameName.toUpperCase(), style: TextStyle(color: white, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const Spacer(),
                const SizedBox(width: 48),
              ]),
            ),

            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              // Animated icon
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accent.withValues(alpha: 0.12),
                  border: Border.all(color: widget.accent.withValues(alpha: 0.4), width: 2),
                  boxShadow: [BoxShadow(color: widget.accent.withValues(alpha: 0.25), blurRadius: 30, spreadRadius: 5)],
                ),
                child: Center(child: _searching
                    ? CircularProgressIndicator(color: widget.accent, strokeWidth: 3)
                    : Icon(Icons.person_search_rounded, color: widget.accent, size: 48)),
              ),

              const SizedBox(height: 28),

              Text(_status, style: TextStyle(color: white.withValues(alpha: 0.85), fontSize: 15), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              if (_searching)
                Text('Entry: $fixedEntryFee coins • Winner takes ${fixedEntryFee * 2}',
                    style: TextStyle(color: secondarySelectedColor, fontSize: 12)),

              const SizedBox(height: 32),

              if (!_searching)
                GestureDetector(
                  onTap: _retry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: widget.accent.withValues(alpha: 0.2),
                      border: Border.all(color: widget.accent.withValues(alpha: 0.5)),
                    ),
                    child: Text('Try Again', style: TextStyle(color: widget.accent, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
            ])),
          ]),
        ),
      ),
    );
  }
}

// ── Shared args passed to every game screen ────────────────────────────────

class _GameArgs {
  final String gameId, type, oppId, oppName;
  final bool isP1;
  final int entryFee;
  const _GameArgs({required this.gameId, required this.type, required this.isP1, required this.oppId, required this.oppName, required this.entryFee});
}

// Export so game screens can import it
typedef GameArgs = _GameArgs;
