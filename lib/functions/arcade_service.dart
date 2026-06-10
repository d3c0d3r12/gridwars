import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../helpers/constant.dart';

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

  // ── Matchmaking (FIXED: better race condition handling) ─────────────────

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
    // If the creator disconnects before anyone joins, drop the whole game node
    // too (not just the lobby entry) — otherwise `arcadeGames` accumulates dead
    // 'waiting' nodes forever. Cancelled once the game actually starts.
    gameRef.onDisconnect().remove();
    return {'status': 'created', 'gameId': gameId};
  }

  /// Cancel the creator's "remove whole node on disconnect" hook. Call this the
  /// moment a game becomes active so a mid-game disconnect is handled by the
  /// presence watchdog (opponent wins) instead of silently deleting the game.
  static Future<void> clearWaitingDisconnect(String type, String gameId) async {
    try {
      await _db.ref().child('arcadeGames').child(type).child(gameId)
          .onDisconnect().cancel();
    } catch (_) {}
  }

  static Future<bool> tryJoinExisting(String type, String gameId, int entryFee) async {
    final lobbyRef = _db.ref().child('arcadeLobby').child(type).child(gameId);

    // First check if user has enough coins
    final userCoinSnap = await _db.ref().child('users').child(_uid).child('coin').once();
    final userCoins = (userCoinSnap.snapshot.value as int? ?? 0);
    if (userCoins < entryFee) return false;

    final tx = await lobbyRef.runTransaction((v) {
      if (v == null) return Transaction.abort();
      return Transaction.success(null);
    });
    if (!tx.committed) return false;

    await Future.wait([
      _db.ref().update({
        'arcadeGames/$type/$gameId/p2': _uid,
        'arcadeGames/$type/$gameId/status': 'active',
      }),
      // Deduct atomically; never let coins go negative on a concurrent drain.
      _db.ref().child('users').child(_uid).child('coin').runTransaction((v) {
        final c = (v as int?) ?? 0;
        return Transaction.success(c >= entryFee ? c - entryFee : c);
      }),
    ]);
    return true;
  }

  /// Cancels a *waiting* game and removes its node + lobby entry. Transactional:
  /// if an opponent has already joined (status != 'waiting') the cancel is a
  /// no-op so a just-started game is never destroyed under the players.
  static Future<void> cancelGame(String type, String gameId) async {
    final gameRef = _db.ref().child('arcadeGames').child(type).child(gameId);
    try {
      final tx = await gameRef.runTransaction((current) {
        if (current == null) return Transaction.success(null);
        final m = Map<String, dynamic>.from(current as Map);
        if (m['status'] != 'waiting') return Transaction.abort(); // someone joined
        return Transaction.success(null); // delete the whole node
      });
      // Always clear the lobby entry regardless of the outcome.
      await _db.ref().child('arcadeLobby').child(type).child(gameId).remove();
      if (!tx.committed) {
        // Opponent joined in the meantime — leave the active game intact.
      }
    } catch (_) {
      await _db.ref().child('arcadeLobby').child(type).child(gameId).remove();
    }
  }

  // ── Presence / disconnect watchdog ───────────────────────────────────────
  // Each player marks themselves present under the game node. The mark is
  // removed automatically by the server if their connection drops (crash, swipe
  // away, network loss). The opponent watches this and claims the win after a
  // short grace period. Re-registers on every reconnect via `.info/connected`
  // so a brief network blip doesn't cost the game.

  static StreamSubscription<DatabaseEvent> keepPresence(String type, String gameId) {
    final uid = _uid;
    final ref = _db.ref()
        .child('arcadeGames').child(type).child(gameId).child('presence').child(uid);
    return _db.ref().child('.info/connected').onValue.listen((ev) async {
      if (ev.snapshot.value == true) {
        try {
          await ref.onDisconnect().remove();
          await ref.set(true);
        } catch (_) {}
      }
    });
  }

  /// Remove my presence mark and cancel its disconnect hook (graceful exit).
  static Future<void> goOffline(String type, String gameId) async {
    final ref = _db.ref()
        .child('arcadeGames').child(type).child(gameId).child('presence').child(_uid);
    try {
      await ref.onDisconnect().cancel();
      await ref.remove();
    } catch (_) {}
  }

  /// Best-effort removal of a finished game node to keep `arcadeGames` lean.
  /// Safe to call from both players; the second call is a harmless no-op.
  static Future<void> cleanup(String type, String gameId) async {
    try {
      await _db.ref().child('arcadeGames').child(type).child(gameId).remove();
    } catch (_) {}
  }

  // ── State updates ────────────────────────────────────────────────────────

  static Future<void> updateState(String type, String gameId, Map<String, dynamic> updates) async {
    final patch = <String, dynamic>{};
    updates.forEach((k, v) => patch['state/$k'] = v);
    await _db.ref().child('arcadeGames').child(type).child(gameId).update(patch);
  }

  static DatabaseReference stateRef(String type, String gameId) =>
      _db.ref().child('arcadeGames').child(type).child(gameId);

  // ── Game over (idempotent: only the first caller awards coins) ───────────

  static Future<void> endGame(String type, String gameId, String? winnerUid, int entryFee) async {
    try {
      final gameRef = _db.ref().child('arcadeGames').child(type).child(gameId);

      // Atomic claim: exactly one caller commits the finish, writing status AND
      // winner together in ONE transaction on the game node. This guarantees any
      // listener that sees status=='finished' also sees the correct winner in the
      // same snapshot — no race, no stale/missing winner.
      final tx = await gameRef.runTransaction((current) {
        if (current == null) return Transaction.abort();
        final m = Map<String, dynamic>.from(current as Map);
        if (m['status'] == 'finished' || m['status'] == 'cancelled') {
          return Transaction.abort();
        }
        m['status'] = 'finished';
        m['winner'] = winnerUid ?? 'draw';
        m['endedAt'] = DateTime.now().toUtc().toString();
        return Transaction.success(m);
      });

      if (!tx.committed) return; // Other player already finished — skip.

      // Pull both player ids from the committed snapshot so we can update the
      // loser too (rank symmetry with XO ranked: win +winScore, lose -loseScore,
      // draw +tieScore — and matchplayed +1 for both).
      final committed = Map<String, dynamic>.from(tx.snapshot.value as Map? ?? {});
      final p1 = committed['p1']?.toString() ?? '';
      final p2 = committed['p2']?.toString() ?? '';

      bool isReal(String uid) => uid.isNotEmpty && uid != '_ai_' && uid != 'draw';

      final futures = <Future>[];

      // matchplayed +1 for both real players.
      for (final uid in {p1, p2}) {
        if (!isReal(uid)) continue;
        futures.add(_db.ref().child('users').child(uid).child('matchplayed')
            .runTransaction((v) => Transaction.success((v as int? ?? 0) + 1)));
      }

      final isDraw = winnerUid == null || winnerUid.isEmpty || winnerUid == 'draw';

      if (!isDraw) {
        final loserUid = winnerUid == p1 ? p2 : p1;
        // Winner: coins (pot), +winScore rank, +1 win.
        futures.addAll([
          _db.ref().child('users').child(winnerUid).child('coin').runTransaction(
              (v) => Transaction.success((v as int? ?? 0) + entryFee * 2)),
          _db.ref().child('users').child(winnerUid).child('score').runTransaction(
              (v) => Transaction.success((v as int? ?? 0) + winScore)),
          _db.ref().child('users').child(winnerUid).child('matchwon').runTransaction(
              (v) => Transaction.success((v as int? ?? 0) + 1)),
        ]);
        // Loser: -loseScore rank (clamped at 0 so it never goes negative).
        if (isReal(loserUid)) {
          futures.add(_db.ref().child('users').child(loserUid).child('score')
              .runTransaction((v) {
            final c = (v as int? ?? 0) - loseScore;
            return Transaction.success(c < 0 ? 0 : c);
          }));
        }
      } else {
        // Draw: refund each player's entry fee + award tieScore rank to both.
        for (final uid in {p1, p2}) {
          if (!isReal(uid)) continue;
          futures.addAll([
            _db.ref().child('users').child(uid).child('coin').runTransaction(
                (v) => Transaction.success((v as int? ?? 0) + entryFee)),
            _db.ref().child('users').child(uid).child('score').runTransaction(
                (v) => Transaction.success((v as int? ?? 0) + tieScore)),
          ]);
        }
      }

      await Future.wait(futures);
    } catch (e) {
      // Silently ignore — game state is written; coin award is best-effort.
    }
  }

  // ── User info ────────────────────────────────────────────────────────────

  static Future<Map<String, String>> userInfo(String uid) async {
    try {
      final s = await _db.ref().child('users').child(uid).once();
      final m = (s.snapshot.value as Map?) ?? {};
      return {
        'username': m['username']?.toString() ?? 'Player',
        'pic': m['profilePic']?.toString() ?? ''
      };
    } catch (e) {
      return {'username': 'Player', 'pic': ''};
    }
  }

  // ── Battleship helpers ───────────────────────────────────────────────────

  static List<int> randomShipPlacement() {
    final grid = List.filled(100, 0);
    final rng  = Random();
    for (final size in [5, 4, 3, 3, 2]) {
      bool placed = false;
      int attempts = 0;
      while (!placed && attempts < 100) {
        attempts++;
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
      // If still not placed after 100 attempts, put it anywhere
      if (!placed) {
        for (int i = 0; i < 100; i++) {
          if (grid[i] == 0) {
            grid[i] = 1;
            break;
          }
        }
      }
    }
    return grid;
  }
}