import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../functions/arcade_service.dart';
import '../helpers/color.dart';
import '../helpers/constant.dart';
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
  bool _foundOpp = false; // shows brief "Found!" state before navigating
  String _oppName = '';
  StreamSubscription? _sub;
  StreamSubscription? _lobbySub;
  Timer? _timeout;
  Timer? _navDelay;
  bool _navigated = false;
  bool _disposed = false;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _find();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _lobbySub?.cancel();
    _timeout?.cancel();
    _navDelay?.cancel();
    super.dispose();
  }

  Future<void> _find() async {
    if (_disposed) return;
    _navigated = false;
    final result = await ArcadeService.findOrCreate(widget.gameType, entryFee: fixedEntryFee);
    if (_disposed || !mounted) return;

    // 'waiting' means we already had a game in the lobby — re-use its gameId.
    final gameId = result['gameId'] as String? ?? '';
    if (gameId.isEmpty) return;
    setState(() => _gameId = gameId);

    if (result['status'] == 'joined') {
      final oppId = result['opponentId'] as String;
      final info  = await ArcadeService.userInfo(oppId);
      if (mounted && !_navigated && !_disposed) {
        _navigated = true;
        _flashAndNavigate(gameId, isP1: false, oppId: oppId, oppName: info['username'] ?? 'Opponent');
      }
      return;
    }

    _timeout = Timer(const Duration(seconds: 60), () {
      if (_disposed || !mounted) return;
      // Cancel subs so no late-arriving 'active' events sneak through.
      _sub?.cancel();
      _lobbySub?.cancel();
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
      if (_disposed || _navigated || ev.snapshot.value != 'active' || !mounted) return;
      _navigated = true;
      _timeout?.cancel();
      _sub?.cancel();
      _lobbySub?.cancel();

      // Fire-and-forget coin deduction
      FirebaseDatabase.instance.ref()
          .child('users').child(_uid).child('coin')
          .runTransaction((v) => Transaction.success((v as int? ?? 0) - fixedEntryFee));

      final snap = await FirebaseDatabase.instance.ref()
          .child('arcadeGames').child(widget.gameType).child(gameId).once();
      if (_disposed || !mounted) return;
      final data = Map<String, dynamic>.from(snap.snapshot.value as Map? ?? {});
      final oppId = data['p2'] as String? ?? '';
      if (oppId.isEmpty) {
        _navigated = false;
        return;
      }
      final info  = await ArcadeService.userInfo(oppId);
      if (mounted && !_disposed) _flashAndNavigate(gameId, isP1: true, oppId: oppId, oppName: info['username'] ?? 'Opponent');
    });

    _lobbySub = FirebaseDatabase.instance
        .ref()
        .child('arcadeLobby')
        .child(widget.gameType)
        .onChildAdded
        .listen((ev) async {
      if (_disposed || _navigated || !mounted) return;
      final otherKey = ev.snapshot.key!;
      final hostUid  = ev.snapshot.value?.toString() ?? '';
      if (otherKey == gameId || hostUid == _uid || otherKey.compareTo(gameId) >= 0) return;

      final ok = await ArcadeService.tryJoinExisting(widget.gameType, otherKey, fixedEntryFee);
      if (!ok || _disposed || !mounted || _navigated) return;
      _navigated = true;
      _timeout?.cancel();
      _sub?.cancel();
      _lobbySub?.cancel();
      ArcadeService.cancelGame(widget.gameType, gameId);
      final info = await ArcadeService.userInfo(hostUid);
      if (mounted && !_disposed) _flashAndNavigate(otherKey, isP1: false, oppId: hostUid, oppName: info['username'] ?? 'Opponent');
    });
  }

  void _flashAndNavigate(String gameId, {required bool isP1, required String oppId, required String oppName}) {
    if (_disposed || !mounted) return;
    setState(() {
      _foundOpp = true;
      _oppName = oppName;
      _searching = false;
      _status = 'Opponent found!';
    });
    _navDelay = Timer(const Duration(milliseconds: 1200), () {
      if (!_disposed && mounted) _navigate(gameId, isP1: isP1, oppId: oppId, oppName: oppName);
    });
  }

  void _navigate(String gameId, {required bool isP1, required String oppId, required String oppName}) {
    if (_disposed) return;
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
    if (_disposed) return;
    _sub?.cancel();
    _lobbySub?.cancel();
    _timeout?.cancel();
    _navDelay?.cancel();
    setState(() {
      _searching = true;
      _foundOpp = false;
      _oppName = '';
      _status = 'Finding opponent…';
      _gameId = '';
      _navigated = false;
    });
    _find();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () async {
                  _sub?.cancel();
                  _lobbySub?.cancel();
                  _timeout?.cancel();
                  if (_gameId.isNotEmpty && _searching) {
                    await ArcadeService.cancelGame(widget.gameType, _gameId);
                  }
                  if (mounted) Navigator.pop(context);
                },
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
              Text(widget.gameName.toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: inkColor, letterSpacing: 1.5)),
              const Spacer(),
              const SizedBox(width: 42),
            ]),
          ),

          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            // Icon / spinner
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Container(
                key: ValueKey(_foundOpp),
                width: 110, height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _foundOpp
                      ? const Color(0xFF43A047).withValues(alpha: 0.12)
                      : widget.accent.withValues(alpha: 0.10),
                  border: Border.all(
                    color: _foundOpp
                        ? const Color(0xFF43A047).withValues(alpha: 0.5)
                        : widget.accent.withValues(alpha: 0.35),
                    width: 2,
                  ),
                  boxShadow: [BoxShadow(
                    color: (_foundOpp ? const Color(0xFF43A047) : widget.accent).withValues(alpha: 0.20),
                    blurRadius: 30, spreadRadius: 5,
                  )],
                ),
                child: Center(child: _searching
                    ? CircularProgressIndicator(color: widget.accent, strokeWidth: 3)
                    : Icon(
                        _foundOpp ? Icons.check_circle_rounded : Icons.person_search_rounded,
                        color: _foundOpp ? const Color(0xFF43A047) : widget.accent,
                        size: 48,
                      )),
              ),
            ),

            const SizedBox(height: 28),

            Text(_status,
                style: TextStyle(
                  color: _foundOpp ? const Color(0xFF2E7D32) : inkColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center),

            if (_foundOpp && _oppName.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('vs $_oppName', style: TextStyle(color: ink2Color, fontSize: 13, fontWeight: FontWeight.w500)),
            ],

            const SizedBox(height: 8),
            if (_searching)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: goldSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: goldColor.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.monetization_on_rounded, color: goldColor, size: 14),
                  const SizedBox(width: 4),
                  Text('Entry: $fixedEntryFee • Win: ${fixedEntryFee * 2}',
                      style: TextStyle(color: const Color(0xFF9A6516), fontWeight: FontWeight.w600, fontSize: 12)),
                ]),
              ),

            const SizedBox(height: 32),

            if (!_searching && !_foundOpp)
              GestureDetector(
                onTap: _retry,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: widget.accent,
                    boxShadow: [BoxShadow(color: widget.accent.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
                  ),
                  child: const Text('Try Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
          ])),
        ]),
      ),
    );
  }
}

class _GameArgs {
  final String gameId, type, oppId, oppName;
  final bool isP1;
  final int entryFee;
  const _GameArgs({required this.gameId, required this.type, required this.isP1, required this.oppId, required this.oppName, required this.entryFee});
}

typedef GameArgs = _GameArgs;