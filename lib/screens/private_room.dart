import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../screens/multiplayer.dart';
import '../widgets/xo_logo.dart';
import '../screens/splash.dart';

class PrivateRoomScreen extends StatefulWidget {
  const PrivateRoomScreen({super.key});

  @override
  State<PrivateRoomScreen> createState() => _PrivateRoomScreenState();
}

class _PrivateRoomScreenState extends State<PrivateRoomScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
            Text('PRIVATE ROOM', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: inkColor, letterSpacing: 1.5)),
            const Spacer(),
            const SizedBox(width: 42),
          ]),
        ),

        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: surface2Color,
          ),
          padding: const EdgeInsets.all(4),
          child: TabBar(
            controller: _tabs,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: surfaceColor,
              boxShadow: [shadowSm],
            ),
            labelColor: inkColor,
            unselectedLabelColor: ink3Color,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            tabs: const [Tab(text: 'Create Room'), Tab(text: 'Join Room')],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [_CreateRoom(), _JoinRoom()],
          ),
        ),
      ])),
    );
  }
}

// ── Create Room Tab ────────────────────────────────────────────────────────

class _CreateRoom extends StatefulWidget {
  const _CreateRoom();
  @override
  State<_CreateRoom> createState() => _CreateRoomState();
}

class _CreateRoomState extends State<_CreateRoom> {
  String? _code;
  String? _gameKey;
  bool _waiting = false;
  bool _found = false;
  StreamSubscription? _sub;
  String? _imagex, _imageo;

  @override
  void initState() {
    super.initState();
    _loadSkins();
  }

  Future<void> _loadSkins() async {
    String? x = await utils.getSkinValue("user_skin");
    String? o = await utils.getSkinValue("opponent_skin");
    setState(() {
      _imagex = x ?? 'cross_skin';
      _imageo = o ?? 'circle_skin';
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<void> _createRoom() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final db = FirebaseDatabase.instance;
    final code = _generateCode();

    final gameRef = db.ref().child('Game').push();
    final gameKey = gameRef.key!;
    final firstTry = Random().nextBool() ? 'player1' : 'player2';

    // Deduct entry fee from host immediately
    try {
      await db.ref().child('users').child(uid).child('coin').runTransaction((v) => Transaction.success((v as int? ?? 0) - fixedEntryFee));
    } catch (e) {
      utils.setSnackbar(context, 'Insufficient coins to create room!');
      return;
    }

    await gameRef.set({
      'player1': {'id': uid, 'won': 0},
      'status': 'pending',
      'entryFee': fixedEntryFee,
      'round': fixedRounds,
      'matrixSize': 'Three',
      'try': firstTry,
      'time': DateTime.now().toUtc().toString(),
    });

    await db.ref().child('privateLobbies').child(code).set({
      'gameKey': gameKey,
      'hostUid': uid,
      'status': 'waiting',
    });

    setState(() { _code = code; _gameKey = gameKey; _waiting = true; });

    _sub = db.ref().child('privateLobbies').child(code).child('status').onValue.listen((ev) async {
      if (ev.snapshot.value == 'ready' && mounted) {
        _sub?.cancel();

        // Wait a moment for player2 data to be fully written
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          setState(() { _found = true; _waiting = false; });
          await _loadAndNavigate(code, gameKey, uid, isHost: true);
        }
      }
    });
  }

  Future<void> _loadAndNavigate(String code, String gameKey, String uid, {required bool isHost}) async {
    final db = FirebaseDatabase.instance;

    String oppUid;
    String oppName = 'Opponent';
    String oppPic = guestProfilePic;

    try {
      if (isHost) {
        final p2Snap = await db.ref().child('Game').child(gameKey).child('player2').once();
        final p2Data = p2Snap.snapshot.value;
        if (p2Data is Map && p2Data.containsKey('id')) {
          oppUid = p2Data['id'] as String;
        } else {
          // Fallback: get from lobby
          final lobbySnap = await db.ref().child('privateLobbies').child(code).once();
          final lobbyData = lobbySnap.snapshot.value as Map;
          oppUid = lobbyData['hostUid'] as String;
        }
      } else {
        final lobbySnap = await db.ref().child('privateLobbies').child(code).once();
        final lobbyData = lobbySnap.snapshot.value as Map;
        oppUid = lobbyData['hostUid'] as String;
      }

      if (oppUid != null) {
        final u = await db.ref().child('users').child(oppUid).once();
        final m = u.snapshot.value as Map?;
        oppName = m?['username'] ?? 'Opponent';
        oppPic = m?['profilePic'] ?? guestProfilePic;
      }
    } catch (e) {
      // Keep defaults
    }

    final gameSnap = await db.ref().child('Game').child(gameKey).once();
    final gMap = gameSnap.snapshot.value as Map;
    final firstTry = gMap['try'] as String;
    final firstUidSnap = await db.ref().child('Game').child(gameKey).child(firstTry).child('id').once();
    final firstUid = firstUidSnap.snapshot.value;

    if (!mounted) return;

    Navigator.pushReplacement(context, CupertinoPageRoute(builder: (_) => MultiplayerScreen(
      gameKey: gameKey,
      firstTry: uid == firstUid,
      oppornentName: oppName,
      oppornentPic: oppPic,
      round: fixedRounds,
      imagex: _imagex,
      imageo: _imageo,
      matrixSize: 'Three',
    )));
  }

  void _cancelRoom() async {
    _sub?.cancel();
    if (_gameKey != null) {
      await FirebaseDatabase.instance.ref().child('Game').child(_gameKey!).update({'status': 'closed'});
      await FirebaseDatabase.instance.ref().child('Game').child(_gameKey!).remove();
    }
    if (_code != null) {
      await FirebaseDatabase.instance.ref().child('privateLobbies').child(_code!).remove();
    }
    if (mounted) setState(() { _code = null; _gameKey = null; _waiting = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (!_waiting && _code == null) {
      return Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const XOBattleLogo(size: 110),
          const SizedBox(height: 24),
          Text('Create a private room\nand share the code with a friend',
              style: TextStyle(color: ink2Color, height: 1.6, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: _createRoom,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: xColor,
                boxShadow: [BoxShadow(color: xColor.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
              ),
              child: const Center(child: Text('Create Room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
            ),
          ),
        ]),
      ));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelRoom();
      },
      child: Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Share this code with your friend', style: TextStyle(color: ink2Color, fontSize: 13.5)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: surfaceColor,
              border: Border.all(color: xColor.withValues(alpha: 0.4), width: 2),
              boxShadow: [shadowSm],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_code!,
                  style: TextStyle(color: xColor, fontSize: 34, fontWeight: FontWeight.w800,
                      letterSpacing: 8, fontFamily: 'Poppins')),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _code!));
                  utils.setSnackbar(context, 'Code copied!');
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: xSoft, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.copy_rounded, color: xColor, size: 18),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          if (_waiting) ...[
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: xColor, strokeWidth: 2.5)),
            const SizedBox(height: 12),
            Text('Waiting for opponent…', style: TextStyle(color: ink2Color)),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _cancelRoom,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: red.withValues(alpha: 0.5)),
                foregroundColor: red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel'),
            ),
          ],
          if (_found)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: goodColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Opponent found! Loading game…', style: TextStyle(color: goodColor, fontWeight: FontWeight.w600)),
            ),
        ]),
      )),
    );
  }
}

// ── Join Room Tab ──────────────────────────────────────────────────────────

class _JoinRoom extends StatefulWidget {
  const _JoinRoom();
  @override
  State<_JoinRoom> createState() => _JoinRoomState();
}

class _JoinRoomState extends State<_JoinRoom> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String _error = '';
  String? _imagex, _imageo;

  @override
  void initState() {
    super.initState();
    _loadSkins();
  }

  Future<void> _loadSkins() async {
    String? x = await utils.getSkinValue("user_skin");
    String? o = await utils.getSkinValue("opponent_skin");
    setState(() {
      _imagex = x ?? 'cross_skin';
      _imageo = o ?? 'circle_skin';
    });
  }

  @override
  void dispose() { _codeCtrl.dispose(); super.dispose(); }

  Future<void> _joinRoom() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) { setState(() => _error = 'Enter a 6-character code'); return; }

    setState(() { _loading = true; _error = ''; });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() { _loading = false; _error = 'Please login first'; });
      return;
    }

    final db = FirebaseDatabase.instance;
    final lobbySnap = await db.ref().child('privateLobbies').child(code).once();

    if (lobbySnap.snapshot.value == null) {
      setState(() { _loading = false; _error = 'Room not found. Check the code.'; });
      return;
    }

    final lobby = lobbySnap.snapshot.value as Map;

    if (lobby['hostUid'] == uid) {
      setState(() { _loading = false; _error = 'This is your own room — share the code with a friend!'; });
      return;
    }

    if (lobby['status'] != 'waiting') {
      setState(() { _loading = false; _error = 'Room is no longer available.'; });
      return;
    }

    final gameKey = lobby['gameKey'] as String;
    final hostUid = lobby['hostUid'] as String;

    // Check if user has enough coins
    final userCoinSnap = await db.ref().child('users').child(uid).child('coin').once();
    final userCoins = userCoinSnap.snapshot.value as int? ?? 0;
    if (userCoins < fixedEntryFee) {
      setState(() { _loading = false; _error = 'Insufficient coins to join! Need $fixedEntryFee coins.'; });
      return;
    }

    try {
      await db.ref().update({
        'Game/$gameKey/player2/id': uid,
        'Game/$gameKey/player2/won': 0,
        'Game/$gameKey/status': 'preparing',
        'privateLobbies/$code/status': 'ready',
      });

      await db.ref().child('users').child(uid).child('coin').runTransaction((v) => Transaction.success((v as int? ?? 0) - fixedEntryFee));

      // Wait a moment for host to detect the change
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      setState(() { _loading = false; _error = 'Failed to join room. Please try again.'; });
      return;
    }

    // Fetch host info
    String oppName = 'Host', oppPic = guestProfilePic;
    final hostSnap = await db.ref().child('users').child(hostUid).once();
    final hMap = hostSnap.snapshot.value as Map?;
    oppName = hMap?['username'] ?? 'Host';
    oppPic = hMap?['profilePic'] ?? guestProfilePic;

    final gameSnap = await db.ref().child('Game').child(gameKey).once();
    final gMap = gameSnap.snapshot.value as Map;
    final firstTry = gMap['try'] as String;
    final firstUidSnap = await db.ref().child('Game').child(gameKey).child(firstTry).child('id').once();
    final firstUid = firstUidSnap.snapshot.value;

    if (!mounted) return;

    Navigator.pushReplacement(context, CupertinoPageRoute(builder: (_) => MultiplayerScreen(
      gameKey: gameKey,
      firstTry: uid == firstUid,
      oppornentName: oppName,
      oppornentPic: oppPic,
      round: fixedRounds,
      imagex: _imagex,
      imageo: _imageo,
      matrixSize: 'Three',
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const XOBattleLogo(size: 90),
          const SizedBox(height: 24),
          Text('Enter the 6-letter room code', style: TextStyle(color: ink2Color, fontSize: 14)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: surfaceColor,
              border: Border.all(color: lineColor),
              boxShadow: [shadowSm],
            ),
            child: TextField(
              controller: _codeCtrl,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: TextStyle(color: xColor, fontSize: 28, fontWeight: FontWeight.w800,
                  letterSpacing: 8, fontFamily: 'Poppins'),
              decoration: InputDecoration(
                counterText: '',
                border: InputBorder.none,
                hintText: 'XXXXXX',
                hintStyle: TextStyle(color: ink3Color, letterSpacing: 8, fontSize: 28),
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_error, style: TextStyle(color: red, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _loading ? null : _joinRoom,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: _loading ? xColor.withValues(alpha: 0.5) : xColor,
                boxShadow: _loading ? [] : [BoxShadow(color: xColor.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
              ),
              child: Center(child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Join Room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
            ),
          ),
        ]),
      ),
    );
  }
}