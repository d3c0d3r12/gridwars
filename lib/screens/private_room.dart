import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../functions/game_launcher.dart';
import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../widgets/xo_logo.dart';
import '../screens/splash.dart';

// ── Game catalogue ──────────────────────────────────────────────────────────

class _G {
  final String type, name;
  final IconData icon;
  final Color color;
  const _G(this.type, this.name, this.icon, this.color);
}

const _kGames = <_G>[
  _G('xo',         'XO Battle',          Icons.grid_3x3_rounded, Color(0xFF4B4EE6)),
  _G('rps',        'Rock Paper Scissors', Icons.sports_mma,       Color(0xFFE53935)),
  _G('connect4',   'Connect 4',          Icons.grid_on,          Color(0xFFFF7043)),
  _G('gomoku',     'Gomoku',             Icons.circle_outlined,  Color(0xFF7B1FA2)),
  _G('dotsboxes',  'Dots & Boxes',       Icons.grid_3x3,         Color(0xFF1565C0)),
  _G('checkers',   'Checkers',           Icons.apps,             Color(0xFF2E7D32)),
  _G('battleship', 'Battleship',         Icons.sailing,          Color(0xFF00838F)),
];

_G _meta(String type) =>
    _kGames.firstWhere((g) => g.type == type, orElse: () => _kGames[0]);

// ── Root screen ─────────────────────────────────────────────────────────────

class PrivateRoomScreen extends StatefulWidget {
  const PrivateRoomScreen({super.key});
  @override
  State<PrivateRoomScreen> createState() => _PrivateRoomScreenState();
}

class _PrivateRoomScreenState extends State<PrivateRoomScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: lineColor),
                    boxShadow: [shadowSm],
                  ),
                  child: Icon(Icons.arrow_back_rounded, color: inkColor, size: 20),
                ),
              ),
              const Spacer(),
              Text('PRIVATE ROOM',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                      color: inkColor, letterSpacing: 1.5)),
              const Spacer(),
              const SizedBox(width: 42),
            ]),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14), color: surface2Color),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _tabs,
              indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  color: surfaceColor,
                  boxShadow: [shadowSm]),
              labelColor: inkColor,
              unselectedLabelColor: ink3Color,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
        ]),
      ),
    );
  }
}

// ── Create Room ──────────────────────────────────────────────────────────────

class _CreateRoom extends StatefulWidget {
  const _CreateRoom();
  @override
  State<_CreateRoom> createState() => _CreateRoomState();
}

class _CreateRoomState extends State<_CreateRoom> {
  // 'initial' | 'select' | 'creating' | 'waiting' | 'found'
  String _stage = 'initial';
  String _error = '';
  String? _code, _gameKey, _gameType;
  bool _disposed = false;
  StreamSubscription? _sub;
  Timer? _timeoutTimer;
  String? _imagex, _imageo;

  @override
  void initState() {
    super.initState();
    _loadSkins();
  }

  Future<void> _loadSkins() async {
    final x = await utils.getSkinValue('user_skin');
    final o = await utils.getSkinValue('opponent_skin');
    if (mounted) {
      setState(() {
        _imagex = x ?? 'cross_skin';
        _imageo = o ?? 'circle_skin';
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _timeoutTimer?.cancel();
    // Fire-and-forget cleanup so host coins are refunded if they navigate away
    if (_stage == 'waiting' && _gameKey != null && _code != null) {
      _doCleanup(_code!, _gameKey!, _gameType);
    }
    super.dispose();
  }

  String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<void> _createRoom(String gameType) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() { _stage = 'creating'; _error = ''; });

    final db = FirebaseDatabase.instance;

    // Atomic coin check + deduction + game-node creation (shared logic).
    final gameKey = await GameLauncher.createGameNode(gameType);
    if (gameKey == null) {
      if (mounted) setState(() { _stage = 'select'; _error = 'Not enough coins!'; });
      return;
    }

    final code = _genCode();

    try {
      await db.ref().child('privateLobbies').child(code).set({
        'gameKey': gameKey,
        'gameType': gameType,
        'hostUid': uid,
        'status': 'waiting',
        'createdAt': DateTime.now().toUtc().millisecondsSinceEpoch,
      });
    } catch (_) {
      // Refund on Firebase error
      db.ref().child('users').child(uid).child('coin')
          .runTransaction((v) => Transaction.success((v as int? ?? 0) + fixedEntryFee))
          .ignore();
      if (mounted) setState(() { _stage = 'select'; _error = 'Failed to create room. Try again.'; });
      return;
    }

    if (_disposed || !mounted) return;
    _code = code;
    _gameKey = gameKey;
    _gameType = gameType;
    setState(() { _stage = 'waiting'; });

    // Auto-cancel after 5 minutes
    _timeoutTimer = Timer(const Duration(minutes: 5), () {
      if (!mounted || _disposed || _stage != 'waiting') return;
      _cancelRoom(expired: true);
    });

    // Watch for guest joining
    _sub = db.ref().child('privateLobbies').child(code).child('status')
        .onValue
        .listen((ev) async {
      if (_disposed || !mounted) return;
      if (ev.snapshot.value?.toString() == 'ready') {
        _sub?.cancel();
        _timeoutTimer?.cancel();
        if (mounted) setState(() { _stage = 'found'; });
        await Future.delayed(const Duration(milliseconds: 600));
        if (_disposed || !mounted) return;
        await _navigateAsHost(code, gameKey, gameType, uid);
      }
    });
  }

  Future<void> _navigateAsHost(
      String code, String gameKey, String gameType, String myUid) async {
    final db = FirebaseDatabase.instance;
    String oppUid = '', oppName = 'Opponent', oppPic = guestProfilePic;

    try {
      if (gameType == 'xo') {
        final s = await db.ref().child('Game').child(gameKey).child('player2').child('id').once();
        oppUid = s.snapshot.value?.toString() ?? '';
      } else {
        final s = await db.ref().child('arcadeGames').child(gameType).child(gameKey).once();
        oppUid = ((s.snapshot.value as Map?)?['p2'])?.toString() ?? '';
      }
      if (oppUid.isNotEmpty) {
        final u = await db.ref().child('users').child(oppUid).once();
        final m = u.snapshot.value as Map? ?? {};
        oppName = m['username']?.toString() ?? 'Opponent';
        oppPic  = m['profilePic']?.toString() ?? guestProfilePic;
      }
    } catch (_) {}

    if (_disposed || !mounted) return;
    await _navigate(gameType: gameType, gameKey: gameKey, isP1: true,
        myUid: myUid, oppUid: oppUid, oppName: oppName, oppPic: oppPic);
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  Future<void> _cancelRoom({bool expired = false}) async {
    _sub?.cancel();
    _timeoutTimer?.cancel();
    final code = _code;
    final gameKey = _gameKey;
    final gameType = _gameType;
    // Reset UI first so user sees feedback immediately
    if (mounted) {
      setState(() {
        _stage = 'initial';
        _code = null; _gameKey = null; _gameType = null;
        _error = expired ? 'Room expired — no one joined in 5 minutes.' : '';
      });
    }
    if (code != null && gameKey != null) {
      await _doCleanup(code, gameKey, gameType);
    }
  }

  // Refunds host coins and removes the game + lobby.
  // Safe to call from dispose() (fire-and-forget) or from _cancelRoom (awaited).
  Future<void> _doCleanup(String code, String gameKey, String? gameType) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final db  = FirebaseDatabase.instance;

    // Only cancel if still in 'waiting' — prevents cancelling an active game
    // (guest may have joined right as host pressed cancel).
    TransactionResult? tx;
    try {
      tx = await db.ref().child('privateLobbies').child(code).child('status')
          .runTransaction((v) {
        if (v == 'waiting') return Transaction.success('cancelled');
        return Transaction.abort();
      });
    } catch (_) {}

    if (tx != null && tx.committed) {
      if (uid != null) {
        db.ref().child('users').child(uid).child('coin')
            .runTransaction((v) => Transaction.success((v as int? ?? 0) + fixedEntryFee))
            .ignore();
      }
      if (gameType == 'xo') {
        db.ref().child('Game').child(gameKey).remove().ignore();
      } else if (gameType != null) {
        db.ref().child('arcadeGames').child(gameType).child(gameKey).remove().ignore();
      }
      db.ref().child('privateLobbies').child(code).remove().ignore();
    }
    // If tx aborted (guest already joined), the game proceeds normally — no refund.
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _navigate({
    required String gameType,
    required String gameKey,
    required bool isP1,
    required String myUid,
    required String oppUid,
    required String oppName,
    required String oppPic,
  }) async {
    if (!mounted) return;
    await GameLauncher.launchGame(
      context,
      gameType: gameType,
      gameKey: gameKey,
      isP1: isP1,
      myUid: myUid,
      oppUid: oppUid,
      oppName: oppName,
      oppPic: oppPic,
      imagex: _imagex,
      imageo: _imageo,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case 'select':
      case 'creating':
        return _buildSelect();
      case 'waiting':
      case 'found':
        return _buildWaiting();
      default:
        return _buildInitial();
    }
  }

  Widget _buildInitial() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const XOBattleLogo(size: 110),
          const SizedBox(height: 24),
          Text('Create a private room and\nchallenge a friend to any game!',
              style: TextStyle(color: ink2Color, height: 1.6, fontSize: 14),
              textAlign: TextAlign.center),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: red.withValues(alpha: 0.3)),
              ),
              child: Text(_error,
                  style: TextStyle(color: red, fontSize: 13),
                  textAlign: TextAlign.center),
            ),
          ],
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () => setState(() { _stage = 'select'; _error = ''; }),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: xColor,
                boxShadow: [BoxShadow(
                    color: xColor.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8))],
              ),
              child: const Center(
                child: Text('Create Room',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSelect() {
    final isCreating = _stage == 'creating';
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(children: [
          Text('Choose a game',
              style: TextStyle(color: inkColor, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Entry: $fixedEntryFee coins each. Winner takes all.',
              style: TextStyle(color: ink2Color, fontSize: 12)),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_error,
                style: TextStyle(color: red, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ]),
      ),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemCount: _kGames.length,
          itemBuilder: (_, i) {
            final g = _kGames[i];
            return GestureDetector(
              onTap: isCreating ? null : () => _createRoom(g.type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: surfaceColor,
                  border: Border.all(color: g.color.withValues(alpha: 0.4)),
                  boxShadow: [BoxShadow(
                      color: g.color.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4))],
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: g.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle),
                    child: Icon(g.icon, color: g.color, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(g.name,
                      style: TextStyle(color: inkColor,
                          fontWeight: FontWeight.w700, fontSize: 12),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ]),
              ),
            );
          },
        ),
      ),
      if (isCreating)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 15, height: 15,
                child: CircularProgressIndicator(color: xColor, strokeWidth: 2)),
            const SizedBox(width: 8),
            Text('Creating room…', style: TextStyle(color: ink2Color, fontSize: 13)),
          ]),
        ),
      TextButton(
        onPressed: isCreating
            ? null
            : () => setState(() { _stage = 'initial'; _error = ''; }),
        child: Text('Back', style: TextStyle(color: ink2Color)),
      ),
      const SizedBox(height: 8),
    ]);
  }

  Widget _buildWaiting() {
    final found = _stage == 'found';
    final m = _gameType != null ? _meta(_gameType!) : null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !found) _cancelRoom();
      },
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            // Game badge
            if (m != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: m.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: m.color.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(m.icon, color: m.color, size: 15),
                  const SizedBox(width: 6),
                  Text(m.name,
                      style: TextStyle(color: m.color,
                          fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 20),
            ],
            Text('Share this code with your friend',
                style: TextStyle(color: ink2Color, fontSize: 13.5)),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: surfaceColor,
                border: Border.all(color: xColor.withValues(alpha: 0.4), width: 2),
                boxShadow: [shadowSm],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_code ?? '',
                    style: TextStyle(color: xColor, fontSize: 34,
                        fontWeight: FontWeight.w800, letterSpacing: 8,
                        fontFamily: 'Poppins')),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _code ?? ''));
                    utils.setSnackbar(context, 'Code copied!');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: xSoft,
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.copy_rounded, color: xColor, size: 18),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            if (!found) ...[
              SizedBox(
                  width: 28, height: 28,
                  child: CircularProgressIndicator(color: xColor, strokeWidth: 2.5)),
              const SizedBox(height: 12),
              Text('Waiting for opponent…',
                  style: TextStyle(color: ink2Color)),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _cancelRoom,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: red.withValues(alpha: 0.5)),
                  foregroundColor: red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel'),
              ),
            ] else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: goodColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Opponent found! Loading game…',
                    style: TextStyle(
                        color: goodColor, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
      ),
    );
  }
}

// ── Join Room ────────────────────────────────────────────────────────────────

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
    final x = await utils.getSkinValue('user_skin');
    final o = await utils.getSkinValue('opponent_skin');
    if (mounted) setState(() { _imagex = x ?? 'cross_skin'; _imageo = o ?? 'circle_skin'; });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Enter a 6-character code');
      return;
    }
    setState(() { _loading = true; _error = ''; });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() { _loading = false; _error = 'Please log in first.'; });
      return;
    }

    final db = FirebaseDatabase.instance;

    // ── Read lobby ──────────────────────────────────────────────────────────
    final lobbySnap =
        await db.ref().child('privateLobbies').child(code).once();
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

    // Expiry check (5 min)
    final createdAt = lobby['createdAt'] as int? ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - createdAt > 5 * 60 * 1000) {
      setState(() { _loading = false; _error = 'Room has expired.'; });
      return;
    }

    final gameKey  = lobby['gameKey']  as String;
    final gameType = (lobby['gameType'] as String?) ?? 'xo';
    final hostUid  = lobby['hostUid'] as String;

    // ── Atomic claim: 'waiting' → 'ready' ──────────────────────────────────
    // Prevents two guests joining simultaneously or joining a cancelled room.
    TransactionResult? claimTx;
    try {
      claimTx = await db.ref()
          .child('privateLobbies')
          .child(code)
          .child('status')
          .runTransaction((v) {
        if (v != 'waiting') return Transaction.abort();
        return Transaction.success('ready');
      });
    } catch (_) {}

    if (claimTx == null || !claimTx.committed) {
      setState(() { _loading = false; _error = 'Room is no longer available.'; });
      return;
    }

    // ── Deduct coins ────────────────────────────────────────────────────────
    TransactionResult? coinTx;
    try {
      coinTx = await db.ref().child('users').child(uid).child('coin')
          .runTransaction((v) {
        final coins = v as int? ?? 0;
        if (coins < fixedEntryFee) return Transaction.abort();
        return Transaction.success(coins - fixedEntryFee);
      });
    } catch (_) {}

    if (coinTx == null || !coinTx.committed) {
      // Rollback the lobby claim
      db.ref().child('privateLobbies').child(code)
          .update({'status': 'waiting'}).ignore();
      setState(() { _loading = false; _error = 'Not enough coins! Need $fixedEntryFee.'; });
      return;
    }

    // ── Write player 2 into the game node ──────────────────────────────────
    try {
      if (gameType == 'xo') {
        await db.ref().update({
          'Game/$gameKey/player2/id':  uid,
          'Game/$gameKey/player2/won': 0,
          'Game/$gameKey/status':      'preparing',
        });
      } else {
        await db.ref().update({
          'arcadeGames/$gameType/$gameKey/p2':     uid,
          'arcadeGames/$gameType/$gameKey/status': 'active',
        });
      }
    } catch (_) {
      // Rollback: restore lobby and refund coins
      db.ref().child('privateLobbies').child(code)
          .update({'status': 'waiting'}).ignore();
      db.ref().child('users').child(uid).child('coin')
          .runTransaction((v) => Transaction.success((v as int? ?? 0) + fixedEntryFee))
          .ignore();
      setState(() { _loading = false; _error = 'Network error. Please try again.'; });
      return;
    }

    // ── Fetch host info ─────────────────────────────────────────────────────
    String oppName = 'Host', oppPic = guestProfilePic;
    try {
      final u = await db.ref().child('users').child(hostUid).once();
      final m = u.snapshot.value as Map? ?? {};
      oppName = m['username']?.toString() ?? 'Host';
      oppPic  = m['profilePic']?.toString() ?? guestProfilePic;
    } catch (_) {}

    if (!mounted) return;
    await _navigate(gameType: gameType, gameKey: gameKey, isP1: false,
        myUid: uid, oppUid: hostUid, oppName: oppName, oppPic: oppPic);
  }

  Future<void> _navigate({
    required String gameType,
    required String gameKey,
    required bool isP1,
    required String myUid,
    required String oppUid,
    required String oppName,
    required String oppPic,
  }) async {
    if (!mounted) return;
    await GameLauncher.launchGame(
      context,
      gameType: gameType,
      gameKey: gameKey,
      isP1: isP1,
      myUid: myUid,
      oppUid: oppUid,
      oppName: oppName,
      oppPic: oppPic,
      imagex: _imagex,
      imageo: _imageo,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const XOBattleLogo(size: 90),
          const SizedBox(height: 24),
          Text('Enter the room code your friend shared',
              style: TextStyle(color: ink2Color, fontSize: 14),
              textAlign: TextAlign.center),
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
              style: TextStyle(color: xColor, fontSize: 28,
                  fontWeight: FontWeight.w800, letterSpacing: 8,
                  fontFamily: 'Poppins'),
              decoration: InputDecoration(
                counterText: '',
                border: InputBorder.none,
                hintText: 'XXXXXX',
                hintStyle: TextStyle(
                    color: ink3Color, letterSpacing: 8, fontSize: 28),
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_error,
                style: TextStyle(color: red, fontSize: 12,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
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
                boxShadow: _loading
                    ? []
                    : [BoxShadow(
                        color: xColor.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8))],
              ),
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('Join Room',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
