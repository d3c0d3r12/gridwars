import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'liars_deck_engine.dart';
import 'liars_dice_engine.dart';
import '../widgets/liars_art.dart';

// ════════════════════════════════════════════════════════════════════════════
// Liar's Bar multiplayer over Firebase RTDB (Liar's Deck).
//   liarsRooms/{code}   : lobby — host, players, entryFee, ruleset, status, gameId
//   liarsGames/{gameId} : LiarsDeckState.toMap() + entryFee/pot/paid/roomCode/...
//
// Turn actions (play / callLiar) and the paced shoot resolution all go through a
// single _mutate runTransaction on the game node. Shots and round-advance are
// driven by any client's watchdog, gated on lastActionAt so they pace out and
// only one commit wins per interval.
// ════════════════════════════════════════════════════════════════════════════

class LiarsService {
  static final _db = FirebaseDatabase.instance;
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static const int maxPlayers = 4;
  static const int shotPaceMs = 1300;   // gap between successive shots
  static const int revealDwellMs = 2000;
  static const int turnTimeoutMs = 30000;

  static String? lastError;

  static String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(5, (_) => chars[r.nextInt(chars.length)]).join();
  }

  // ── Lobby ──────────────────────────────────────────────────────────────────
  static Future<String?> createRoom(int entryFee, String name, String pic,
      {String ruleset = 'basic', String mode = 'deck'}) async {
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
      final ref = _db.ref().child('liarsRooms').child(code);
      await ref.set({
        'host': _uid,
        'entryFee': entryFee,
        'ruleset': ruleset,
        'mode': mode,
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
      final ref = _db.ref().child('liarsRooms').child(code);
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
      final ref = _db.ref().child('liarsRooms').child(code);
      final snap = await ref.get();
      if (!snap.exists) return;
      final m = Map<String, dynamic>.from(snap.value as Map);
      final players = Map<String, dynamic>.from(m['players'] ?? {});
      final entryFee = (m['entryFee'] as int?) ?? 0;
      await ref.child('players').child(_uid).remove();
      if (players.containsKey(_uid) && m['status'] != 'started' && entryFee > 0) {
        _db.ref().child('users').child(_uid).child('coin')
            .runTransaction((v) => Transaction.success(((v as int?) ?? 0) + entryFee)).ignore();
      }
      if (m['host'] == _uid && m['status'] == 'waiting') {
        await ref.child('status').set('closed');
      }
    } catch (_) {}
  }

  static Stream<DatabaseEvent> roomStream(String code) =>
      _db.ref().child('liarsRooms').child(code).onValue;

  static Future<String?> startGame(String code, int entryFee) async {
    lastError = null;
    try {
      final roomRef = _db.ref().child('liarsRooms').child(code);
      final snap = await roomRef.get();
      if (!snap.exists) { lastError = 'Room not found'; return null; }
      final m = Map<String, dynamic>.from(snap.value as Map);
      if (m['host'] != _uid) { lastError = 'Only the host can start'; return null; }
      final playersMap = Map<String, dynamic>.from(m['players'] ?? {});
      if (playersMap.length < 2) { lastError = 'Need at least 2 players'; return null; }
      final ruleset = (m['ruleset'] ?? 'basic').toString();
      final mode = (m['mode'] ?? 'deck').toString();

      final ids = playersMap.keys.toList()
        ..sort((a, b) {
          final pa = playersMap[a], pb = playersMap[b];
          final ta = (pa is Map ? pa['joinedAt'] : 0) as int? ?? 0;
          final tb = (pb is Map ? pb['joinedAt'] : 0) as int? ?? 0;
          return ta.compareTo(tb);
        });
      final names = {
        for (final id in ids)
          id: (playersMap[id] is Map ? playersMap[id]['name'] : null)?.toString() ?? 'Player'
      };
      final pool = List.of(kLiarsCharIds)..shuffle();
      final chars = {for (int i = 0; i < ids.length; i++) ids[i]: pool[i % pool.length]};

      final Map<String, dynamic> stateMap = mode == 'dice'
          ? LiarsDiceState.create(playerIds: ids, names: names, chars: chars, ruleset: ruleset).toMap()
          : LiarsDeckState.create(playerIds: ids, names: names, chars: chars, ruleset: ruleset).toMap();
      final gameRef = _db.ref().child('liarsGames').push();
      final gameId = gameRef.key!;
      await gameRef.set({
        ...stateMap,
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
      _db.ref().child('liarsGames').child(gameId).onValue;

  static Future<bool> _mutate(String gameId, bool Function(LiarsDeckState s) apply) async {
    final ref = _db.ref().child('liarsGames').child(gameId);
    try {
      final res = await ref.runTransaction((cur) {
        if (cur == null) return Transaction.abort();
        final map = Map<String, dynamic>.from(cur as Map);
        final s = LiarsDeckState.fromMap(map);
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

  static Future<bool> play(String gameId, List<String> cards) =>
      _mutate(gameId, (s) => s.play(_uid, cards));

  static Future<bool> callLiar(String gameId) =>
      _mutate(gameId, (s) => s.callLiar(_uid));

  /// Watchdog: pace out the shoot queue (any client; gated on lastActionAt).
  static Future<bool> autoResolveShot(String gameId, int lastActionAt) {
    if (DateTime.now().millisecondsSinceEpoch - lastActionAt < shotPaceMs) {
      return Future.value(false);
    }
    return _mutate(gameId, (s) {
      if (s.phase != 'shoot') return false;
      return s.resolveNextShot(Random());
    });
  }

  /// Watchdog: deal the next round after the reveal dwell.
  static Future<bool> advanceRound(String gameId, int lastActionAt) {
    if (DateTime.now().millisecondsSinceEpoch - lastActionAt < revealDwellMs) {
      return Future.value(false);
    }
    return _mutate(gameId, (s) {
      if (s.phase != 'reveal') return false;
      s.nextRound(Random());
      return true;
    });
  }

  /// Watchdog: if the player to act is idle/absent past the timeout, auto-act
  /// (call Liar if there's a standing play & no cards, else play one card).
  static Future<bool> turnTimeout(String gameId, String expectTurnId, int lastActionAt) {
    if (DateTime.now().millisecondsSinceEpoch - lastActionAt < turnTimeoutMs) {
      return Future.value(false);
    }
    return _mutate(gameId, (s) {
      if (s.phase != 'play' || s.currentId != expectTurnId) return false;
      final hand = s.hands[expectTurnId] ?? const [];
      if (hand.isEmpty && s.hasStandingPlay) return s.callLiar(expectTurnId);
      if (hand.isNotEmpty) return s.play(expectTurnId, [hand.first]);
      return false;
    });
  }

  // ── Liar's Dice actions ──────────────────────────────────────────────────────
  static Future<bool> _mutateDice(String gameId, bool Function(LiarsDiceState s) apply) async {
    final ref = _db.ref().child('liarsGames').child(gameId);
    try {
      final res = await ref.runTransaction((cur) {
        if (cur == null) return Transaction.abort();
        final map = Map<String, dynamic>.from(cur as Map);
        final s = LiarsDiceState.fromMap(map);
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

  static Future<bool> diceBid(String gameId, int count, int face) =>
      _mutateDice(gameId, (s) => s.bid(_uid, count, face));

  static Future<bool> diceCall(String gameId) =>
      _mutateDice(gameId, (s) => s.callLiar(_uid));

  static Future<bool> diceSpot(String gameId) =>
      _mutateDice(gameId, (s) => s.spotOn(_uid));

  static Future<bool> diceAdvanceRound(String gameId, int lastActionAt) {
    if (DateTime.now().millisecondsSinceEpoch - lastActionAt < revealDwellMs) {
      return Future.value(false);
    }
    return _mutateDice(gameId, (s) {
      if (s.phase != 'reveal') return false;
      s.nextRound(Random());
      return true;
    });
  }

  static Future<bool> diceTurnTimeout(String gameId, String expectTurnId, int lastActionAt) {
    if (DateTime.now().millisecondsSinceEpoch - lastActionAt < turnTimeoutMs) {
      return Future.value(false);
    }
    return _mutateDice(gameId, (s) {
      if (s.phase != 'bid' || s.currentId != expectTurnId) return false;
      // auto-act: call if there's a bid, else open with a minimal bid.
      if (s.hasBid) return s.callLiar(expectTurnId);
      return s.bid(expectTurnId, 1, 2);
    });
  }

  static Future<void> claimPot(String gameId) async {
    final ref = _db.ref().child('liarsGames').child(gameId);
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
