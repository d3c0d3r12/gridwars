import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ArcadeService {
  static final _db   = FirebaseDatabase.instance;
  static final _auth = FirebaseAuth.instance;
  static String get _uid => _auth.currentUser!.uid;

  // ── Initial board states ────────────────────────────────────────────────

  static Map<String, dynamic> initialState(String type) {
    switch (type) {
      case 'rps':
        return {'round': 1, 'p1Choice': '', 'p2Choice': '', 'p1Score': 0, 'p2Score': 0, 'maxRounds': 5};
      case 'connect4':
        return {'board': List.filled(42, 0), 'turn': 1};
      case 'gomoku':
        return {'board': List.filled(121, 0), 'turn': 1};
      case 'dotsboxes':
        return {
          'hLines': List.filled(20, 0),
          'vLines': List.filled(20, 0),
          'boxes':  List.filled(16, 0),
          'p1Score': 0, 'p2Score': 0, 'turn': 1,
        };
      case 'checkers':
        return {'board': _checkersInit(), 'turn': 1, 'selected': -1};
      case 'battleship':
        return {
          'phase': 'placement',
          'p1Ships': List.filled(100, 0),
          'p2Ships': List.filled(100, 0),
          'p1Attacks': List.filled(100, 0),
          'p2Attacks': List.filled(100, 0),
          'p1Ready': 0, 'p2Ready': 0,
          'turn': 1, 'p1Hits': 0, 'p2Hits': 0,
        };
      default: return {};
    }
  }

  static List<int> _checkersInit() {
    final b = List.filled(64, 0);
    for (int r = 0; r < 3; r++)
      for (int c = 0; c < 8; c++)
        if ((r + c) % 2 == 1) b[r * 8 + c] = 2;
    for (int r = 5; r < 8; r++)
      for (int c = 0; c < 8; c++)
        if ((r + c) % 2 == 1) b[r * 8 + c] = 1;
    return b;
  }

  // ── Matchmaking ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> findOrCreate(String type, {int entryFee = 25}) async {
    final lobbyRef = _db.ref().child('arcadeLobby').child(type);
    final snap = await lobbyRef.limitToFirst(1).once();

    if (snap.snapshot.value != null) {
      final entries = Map<String, dynamic>.from(snap.snapshot.value as Map);
      final gameId  = entries.keys.first;
      final hostUid = entries.values.first as String;

      if (hostUid != _uid) {
        final joined = await tryJoinExisting(type, gameId, entryFee);
        if (joined) {
          return {'status': 'joined', 'gameId': gameId, 'opponentId': hostUid};
        }
      } else {
        return {'status': 'waiting', 'gameId': gameId};
      }
    }

    // Create new game
    final gameRef = _db.ref().child('arcadeGames').child(type).push();
    final gameId  = gameRef.key!;
    await gameRef.set({
      'type': type, 'p1': _uid, 'p2': '',
      'status': 'waiting', 'entryFee': entryFee,
      'winner': '', 'state': initialState(type),
      'createdAt': DateTime.now().toUtc().toString(),
    });
    await lobbyRef.child(gameId).set(_uid);
    lobbyRef.child(gameId).onDisconnect().remove();
    return {'status': 'created', 'gameId': gameId};
  }

  // Atomically claim a lobby slot and join that game.
  // Returns true if join succeeded, false if someone else grabbed it first.
  static Future<bool> tryJoinExisting(String type, String gameId, int entryFee) async {
    final lobbyRef = _db.ref().child('arcadeLobby').child(type).child(gameId);
    final tx = await lobbyRef.runTransaction((v) {
      if (v == null) return Transaction.abort();
      return Transaction.success(null); // delete the lobby entry atomically
    });
    if (!tx.committed) return false;

    // Atomic multi-path write: p2 and status together so the status listener
    // on the creator side always sees a valid p2 when it fires.
    await Future.wait([
      _db.ref().update({
        'arcadeGames/$type/$gameId/p2': _uid,
        'arcadeGames/$type/$gameId/status': 'active',
      }),
      _db.ref().child('users').child(_uid).child('coin')
          .runTransaction((v) => Transaction.success((v as int? ?? 0) - entryFee)),
    ]);
    return true;
  }

  static Future<void> cancelGame(String type, String gameId) async {
    await Future.wait([
      _db.ref().child('arcadeGames').child(type).child(gameId).update({'status': 'cancelled'}),
      _db.ref().child('arcadeLobby').child(type).child(gameId).remove(),
    ]);
  }

  // ── State updates ────────────────────────────────────────────────────────

  static Future<void> updateState(String type, String gameId, Map<String, dynamic> updates) async {
    final patch = <String, dynamic>{};
    updates.forEach((k, v) => patch['state/$k'] = v);
    await _db.ref().child('arcadeGames').child(type).child(gameId).update(patch);
  }

  static DatabaseReference stateRef(String type, String gameId) =>
      _db.ref().child('arcadeGames').child(type).child(gameId);

  // ── Game over ────────────────────────────────────────────────────────────

  static Future<void> endGame(String type, String gameId, String? winnerUid, int entryFee) async {
    await _db.ref().child('arcadeGames').child(type).child(gameId).update({
      'status': 'finished',
      'winner': winnerUid ?? 'draw',
    });
    if (winnerUid != null && winnerUid.isNotEmpty) {
      await Future.wait([
        _db.ref().child('users').child(winnerUid).child('coin').runTransaction(
          (v) => Transaction.success((v as int? ?? 0) + entryFee * 2)),
        _db.ref().child('users').child(winnerUid).child('score').runTransaction(
          (v) => Transaction.success((v as int? ?? 0) + 10)),
        _db.ref().child('users').child(winnerUid).child('matchwon').runTransaction(
          (v) => Transaction.success((v as int? ?? 0) + 1)),
      ]);
    }
  }

  // ── User info ────────────────────────────────────────────────────────────

  static Future<Map<String, String>> userInfo(String uid) async {
    final s = await _db.ref().child('users').child(uid).once();
    final m = (s.snapshot.value as Map?) ?? {};
    return {'username': m['username']?.toString() ?? 'Player', 'pic': m['profilePic']?.toString() ?? ''};
  }

  // ── Battleship helpers ───────────────────────────────────────────────────

  static List<int> randomShipPlacement() {
    final grid = List.filled(100, 0);
    final rng  = Random();
    for (final size in [5, 4, 3, 3, 2]) {
      bool placed = false;
      while (!placed) {
        final horiz = rng.nextBool();
        final row   = rng.nextInt(horiz ? 10 : 10 - size + 1);
        final col   = rng.nextInt(horiz ? 10 - size + 1 : 10);
        bool ok = true;
        for (int i = 0; i < size; i++) {
          final idx = horiz ? row * 10 + col + i : (row + i) * 10 + col;
          if (grid[idx] != 0) { ok = false; break; }
        }
        if (ok) {
          for (int i = 0; i < size; i++) {
            final idx = horiz ? row * 10 + col + i : (row + i) * 10 + col;
            grid[idx] = 1;
          }
          placed = true;
        }
      }
    }
    return grid;
  }
}
