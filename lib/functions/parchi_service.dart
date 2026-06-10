import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'parchi_engine.dart';

// ════════════════════════════════════════════════════════════════════════════
// 16 Parchi / Dhapp multiplayer over Firebase RTDB.
//   parchiRooms/{code}   : lobby — host, players, entryFee, status, gameId
//   parchiGames/{gameId} : ParchiState.toMap() + entryFee/pot/paid/roomCode/...
//
// Simultaneous passing and the slam race are resolved inside runTransaction on
// the game node: each player submits their pass/slam, and the transaction that
// completes the set resolves the round atomically (first commit wins).
// ════════════════════════════════════════════════════════════════════════════

class ParchiService {
  static final _db = FirebaseDatabase.instance;
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static const int maxPlayers = 4;
  static const int slamWindowMs = 5000;  // idle slammers auto-lose after this
  static const int revealDwellMs = 2600; // reveal → next round

  static String? lastError;

  // ── Lobby ──────────────────────────────────────────────────────────────────

  static String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(5, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static Future<String?> createRoom(int entryFee, String name, String pic) async {
    lastError = null;
    final coinRef = _db.ref().child('users').child(_uid).child('coin');
    TransactionResult tx;
    try {
      tx = await coinRef.runTransaction((v) {
        final c = (v as int?) ?? 0;
        return c < entryFee ? Transaction.abort() : Transaction.success(c - entryFee);
      });
    } catch (e) {
      lastError = e.toString();
      return null;
    }
    if (!tx.committed) { lastError = 'Not enough coins to host'; return null; }
    try {
      final code = _genCode();
      final ref = _db.ref().child('parchiRooms').child(code);
      await ref.set({
        'host': _uid,
        'entryFee': entryFee,
        'status': 'waiting',
        'createdAt': ServerValue.timestamp,
        'players': {
          _uid: {'name': name, 'pic': pic, 'joinedAt': ServerValue.timestamp},
        },
      });
      ref.child('players').child(_uid).onDisconnect().remove();
      return code;
    } catch (e) {
      coinRef.runTransaction((v) => Transaction.success(((v as int?) ?? 0) + entryFee)).ignore();
      lastError = e.toString();
      return null;
    }
  }

  static Future<String?> joinRoom(String code, String name, String pic) async {
    try {
      final ref = _db.ref().child('parchiRooms').child(code);
      final snap = await ref.get();
      if (!snap.exists) return 'Room not found';
      final m = Map<String, dynamic>.from(snap.value as Map);
      if (m['status'] != 'waiting') return 'Game already started';
      final players = Map<String, dynamic>.from(m['players'] ?? {});
      if (players.containsKey(_uid)) return null;
      if (players.length >= maxPlayers) return 'Room is full';

      final entryFee = (m['entryFee'] as int?) ?? 0;
      final coinRef = _db.ref().child('users').child(_uid).child('coin');
      if (entryFee > 0) {
        final tx = await coinRef.runTransaction((v) {
          final c = (v as int?) ?? 0;
          return c < entryFee ? Transaction.abort() : Transaction.success(c - entryFee);
        });
        if (!tx.committed) return 'Not enough coins';
      }
      try {
        await ref.child('players').child(_uid).set({
          'name': name, 'pic': pic, 'joinedAt': ServerValue.timestamp,
        });
        ref.child('players').child(_uid).onDisconnect().remove();
        return null;
      } catch (_) {
        if (entryFee > 0) {
          coinRef.runTransaction((v) => Transaction.success(((v as int?) ?? 0) + entryFee)).ignore();
        }
        return 'Could not join';
      }
    } catch (_) {
      return 'Could not join';
    }
  }

  static Future<void> leaveRoom(String code) async {
    try {
      final ref = _db.ref().child('parchiRooms').child(code);
      final snap = await ref.get();
      if (!snap.exists) return;
      final m = Map<String, dynamic>.from(snap.value as Map);
      final players = Map<String, dynamic>.from(m['players'] ?? {});
      final entryFee = (m['entryFee'] as int?) ?? 0;
      await ref.child('players').child(_uid).remove();
      if (players.containsKey(_uid) && m['status'] != 'started' && entryFee > 0) {
        _db.ref().child('users').child(_uid).child('coin')
            .runTransaction((v) => Transaction.success(((v as int?) ?? 0) + entryFee))
            .ignore();
      }
      if (m['host'] == _uid && m['status'] == 'waiting') {
        await ref.child('status').set('closed');
      }
    } catch (_) {}
  }

  static Stream<DatabaseEvent> roomStream(String code) =>
      _db.ref().child('parchiRooms').child(code).onValue;

  static Future<String?> startGame(String code, int entryFee) async {
    lastError = null;
    try {
      final roomRef = _db.ref().child('parchiRooms').child(code);
      final snap = await roomRef.get();
      if (!snap.exists) { lastError = 'Room not found'; return null; }
      final m = Map<String, dynamic>.from(snap.value as Map);
      if (m['host'] != _uid) { lastError = 'Only the host can start'; return null; }
      final playersMap = Map<String, dynamic>.from(m['players'] ?? {});
      if (playersMap.length < 2) { lastError = 'Need at least 2 players'; return null; }

      final ids = playersMap.keys.toList()
        ..sort((a, b) {
          final pa = playersMap[a];
          final pb = playersMap[b];
          final ta = (pa is Map ? pa['joinedAt'] : 0) as int? ?? 0;
          final tb = (pb is Map ? pb['joinedAt'] : 0) as int? ?? 0;
          return ta.compareTo(tb);
        });
      final names = {
        for (final id in ids)
          id: (playersMap[id] is Map ? playersMap[id]['name'] : null)?.toString() ?? 'Player'
      };
      final bots = {for (final id in ids) id: false};

      final state = ParchiState.create(playerIds: ids, names: names, bots: bots);
      final gameRef = _db.ref().child('parchiGames').push();
      final gameId = gameRef.key!;
      await gameRef.set({
        ...state.toMap(),
        'entryFee': entryFee,
        'pot': entryFee * ids.length,
        'paid': false,
        'roomCode': code,
        'lastActionAt': ServerValue.timestamp,
      });
      await roomRef.update({'status': 'started', 'gameId': gameId});
      return gameId;
    } catch (e) {
      lastError = e.toString();
      return null;
    }
  }

  // ── Game ───────────────────────────────────────────────────────────────────

  static Stream<DatabaseEvent> gameStream(String gameId) =>
      _db.ref().child('parchiGames').child(gameId).onValue;

  static Future<bool> _mutate(String gameId, bool Function(ParchiState s) apply) async {
    final ref = _db.ref().child('parchiGames').child(gameId);
    try {
      final res = await ref.runTransaction((cur) {
        if (cur == null) return Transaction.abort();
        final map = Map<String, dynamic>.from(cur as Map);
        final s = ParchiState.fromMap(map);
        if (s.over) return Transaction.abort();
        if (!apply(s)) return Transaction.abort();
        final out = Map<String, dynamic>.from(map)
          ..addAll(s.toMap())
          ..['lastActionAt'] = DateTime.now().millisecondsSinceEpoch;
        return Transaction.success(out);
      });
      return res.committed;
    } catch (_) {
      return false;
    }
  }

  /// Submit my pass; resolve the round if every player has now passed.
  static Future<bool> submitPass(String gameId, String symbol) {
    return _mutate(gameId, (s) {
      if (!s.submitPass(_uid, symbol)) return false;
      if (s.allPassesIn) s.resolvePasses();
      return true;
    });
  }

  /// Submit my slam reaction; resolve the round if everyone has slammed.
  static Future<bool> submitSlam(String gameId, int ms) {
    return _mutate(gameId, (s) {
      if (!s.submitSlam(_uid, ms)) return false;
      if (s.allSlamsIn) s.resolveSlam(Random());
      return true;
    });
  }

  /// Watchdog (any client): after the slam window, auto-slam idle players so a
  /// disconnect can't freeze the table; the slowest still loses.
  static Future<bool> autoResolveSlam(String gameId) {
    return _mutate(gameId, (s) {
      if (s.phase != 'slam') return false;
      bool changed = false;
      for (final id in s.order) {
        if (!s.slamTimes.containsKey(id)) {
          s.submitSlam(id, 999999);
          changed = true;
        }
      }
      if (!changed) return false;
      if (s.allSlamsIn) s.resolveSlam(Random());
      return true;
    });
  }

  /// Watchdog (any client): after the reveal dwell, deal the next round.
  static Future<bool> advanceRound(String gameId) {
    return _mutate(gameId, (s) {
      if (s.phase != 'reveal') return false;
      s.nextRound(Random());
      return true;
    });
  }

  static Future<void> claimPot(String gameId) async {
    final ref = _db.ref().child('parchiGames').child(gameId);
    try {
      Map? committed;
      final res = await ref.runTransaction((cur) {
        if (cur == null) return Transaction.abort();
        final map = Map<String, dynamic>.from(cur as Map);
        if (map['over'] != true) return Transaction.abort();
        if (map['paid'] == true) return Transaction.abort();
        if (map['winner'] != _uid) return Transaction.abort();
        map['paid'] = true;
        committed = map;
        return Transaction.success(map);
      });
      if (res.committed && committed != null) {
        final pot = (committed!['pot'] as int?) ?? 0;
        await _db.ref().child('users').child(_uid).child('coin')
            .runTransaction((v) => Transaction.success(((v as int?) ?? 0) + pot));
      }
    } catch (_) {}
  }
}
