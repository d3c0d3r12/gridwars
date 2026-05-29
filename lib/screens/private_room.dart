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
      body: Container(
        decoration: utils.gradBack(),
        child: SafeArea(child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(children: [
              IconButton(icon: Icon(Icons.arrow_back, color: white), onPressed: () => Navigator.pop(context)),
              const Spacer(),
              Text('PRIVATE ROOM', style: TextStyle(color: white, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 14)),
              const Spacer(),
              const SizedBox(width: 48),
            ]),
          ),

          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: secondaryColor,
              border: Border.all(color: secondarySelectedColor.withValues(alpha: 0.25)),
            ),
            child: TabBar(
              controller: _tabs,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(colors: [secondarySelectedColor, const Color(0xFFFF8800)]),
              ),
              labelColor: primaryColor,
              unselectedLabelColor: white.withValues(alpha: 0.6),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
      ),
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
    _imagex = await utils.getSkinValue("user_skin");
    _imageo = await utils.getSkinValue("opponent_skin");
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

    // Create the game node
    final gameRef = db.ref().child('Game').push();
    final gameKey = gameRef.key!;
    final firstTry = Random().nextBool() ? 'player1' : 'player2';

    await gameRef.set({
      'player1': {'id': uid, 'won': 0},
      'status': 'pending',
      'entryFee': fixedEntryFee,
      'round': fixedRounds,
      'matrixSize': 'Three',
      'try': firstTry,
      'time': DateTime.now().toUtc().toString(),
    });

    // Register private lobby
    await db.ref().child('privateLobbies').child(code).set({
      'gameKey': gameKey,
      'hostUid': uid,
      'status': 'waiting',
    });

    setState(() { _code = code; _gameKey = gameKey; _waiting = true; });

    // Listen for opponent to join
    _sub = db.ref().child('privateLobbies').child(code).child('status').onValue.listen((ev) async {
      if (ev.snapshot.value == 'ready' && mounted) {
        _sub?.cancel();
        setState(() { _found = true; _waiting = false; });
        await _loadAndNavigate(code, gameKey, uid, isHost: true);
      }
    });
  }

  Future<void> _loadAndNavigate(String code, String gameKey, String uid, {required bool isHost}) async {
    final db = FirebaseDatabase.instance;
    final lobbySnap = await db.ref().child('privateLobbies').child(code).once();
    final lobbyData = lobbySnap.snapshot.value as Map;

    String? oppUid;
    if (isHost) {
      final p2Snap = await db.ref().child('Game').child(gameKey).child('player2').once();
      oppUid = (p2Snap.snapshot.value as Map?)?['id'];
    } else {
      oppUid = lobbyData['hostUid'];
    }

    String oppName = 'Opponent', oppPic = guestProfilePic;
    if (oppUid != null) {
      final u = await db.ref().child('users').child(oppUid).once();
      final m = u.snapshot.value as Map?;
      oppName = m?['username'] ?? 'Opponent';
      oppPic  = m?['profilePic'] ?? guestProfilePic;
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
    }
    if (_code != null) {
      await FirebaseDatabase.instance.ref().child('privateLobbies').child(_code!).remove();
    }
    if (mounted) setState(() { _code = null; _gameKey = null; _waiting = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (!_waiting && _code == null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const XOBattleLogo(size: 120),
        const SizedBox(height: 24),
        Text('Create a private room\nand share the code with a friend', style: TextStyle(color: white.withValues(alpha: 0.7), height: 1.6), textAlign: TextAlign.center),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: _createRoom,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: [secondarySelectedColor, const Color(0xFFFF8800)]),
            ),
            child: Text('Create Room', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ]));
    }

    // Waiting state — intercept back to auto-cancel the room.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelRoom();
      },
      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('Share this code', style: TextStyle(color: white.withValues(alpha: 0.6), fontSize: 14)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: secondaryColor,
          border: Border.all(color: secondarySelectedColor.withValues(alpha: 0.5), width: 2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_code!, style: TextStyle(color: secondarySelectedColor, fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: 8)),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _code!));
              utils.setSnackbar(context, 'Code copied!');
            },
            child: Icon(Icons.copy_rounded, color: secondarySelectedColor.withValues(alpha: 0.7)),
          ),
        ]),
      ),
      const SizedBox(height: 24),
      if (_waiting) ...[
        SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: secondarySelectedColor, strokeWidth: 2.5)),
        const SizedBox(height: 12),
        Text('Waiting for opponent…', style: TextStyle(color: white.withValues(alpha: 0.6))),
        const SizedBox(height: 20),
        TextButton(onPressed: _cancelRoom, child: Text('Cancel', style: TextStyle(color: red))),
      ],
      if (_found) Text('Opponent found! Loading game…', style: TextStyle(color: Colors.greenAccent)),
    ])),
    ); // PopScope
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
    _imagex = await utils.getSkinValue("user_skin");
    _imageo = await utils.getSkinValue("opponent_skin");
  }

  @override
  void dispose() { _codeCtrl.dispose(); super.dispose(); }

  Future<void> _joinRoom() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) { setState(() => _error = 'Enter a 6-character code'); return; }

    setState(() { _loading = true; _error = ''; });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final db = FirebaseDatabase.instance;
    final lobbySnap = await db.ref().child('privateLobbies').child(code).once();

    if (lobbySnap.snapshot.value == null) {
      setState(() { _loading = false; _error = 'Room not found. Check the code.'; });
      return;
    }

    final lobby = lobbySnap.snapshot.value as Map;

    // Prevent joining your own room
    if (lobby['hostUid'] == uid) {
      setState(() { _loading = false; _error = 'This is your own room — share the code with a friend!'; });
      return;
    }

    if (lobby['status'] != 'waiting') {
      setState(() { _loading = false; _error = 'Room is no longer available.'; });
      return;
    }

    final gameKey = lobby['gameKey'] as String;
    final hostUid  = lobby['hostUid'] as String;

    // Join the game — single atomic multi-path write so the host's status
    // listener always sees player2.id already set when it fires.
    await db.ref().update({
      'Game/$gameKey/player2/id': uid,
      'Game/$gameKey/player2/won': 0,
      'Game/$gameKey/status': 'preparing',
      'privateLobbies/$code/status': 'ready',
    });

    // Deduct entry fee
    await db.ref().child('users').child(uid).child('coin').runTransaction((v) => Transaction.success((v as int? ?? 0) - fixedEntryFee));

    // Fetch host info
    String oppName = 'Host', oppPic = guestProfilePic;
    final hostSnap = await db.ref().child('users').child(hostUid).once();
    final hMap = hostSnap.snapshot.value as Map?;
    oppName = hMap?['username'] ?? 'Host';
    oppPic  = hMap?['profilePic'] ?? guestProfilePic;

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const XOBattleLogo(size: 100),
        const SizedBox(height: 24),
        Text('Enter room code', style: TextStyle(color: white.withValues(alpha: 0.7), fontSize: 14)),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: white.withValues(alpha: 0.08),
            border: Border.all(color: white.withValues(alpha: 0.18)),
          ),
          child: TextField(
            controller: _codeCtrl,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: TextStyle(color: white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 8),
            decoration: InputDecoration(
              counterText: '',
              border: InputBorder.none,
              hintText: 'XXXXXX',
              hintStyle: TextStyle(color: white.withValues(alpha: 0.2), letterSpacing: 8, fontSize: 28),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_error, style: TextStyle(color: red, fontSize: 12)),
        ],
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _loading ? null : _joinRoom,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: [secondarySelectedColor, const Color(0xFFFF8800)]),
            ),
            child: Center(child: _loading
                ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2.5))
                : Text('Join Room', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16))),
          ),
        ),
      ]),
    );
  }
}
