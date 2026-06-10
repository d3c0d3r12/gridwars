import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'uno_engine.dart';

// ════════════════════════════════════════════════════════════════════════════
// UNO multiplayer over Firebase RTDB (Phase 2).
//   unoRooms/{code}   : lobby — host, players, entryFee, status, gameId
//   unoGames/{gameId} : UnoState.toMap() + entryFee/pot/paid/roomCode/lastActionAt
//
// All in-game actions go through a single runTransaction on the game node, so
// turn order and jump-in races are resolved atomically (the first commit wins).
// ════════════════════════════════════════════════════════════════════════════

class UnoService {
  static final _db = FirebaseDatabase.instance;
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static const int maxPlayers = 6;
  static const int turnTimeoutMs = 35000; // auto-advance a stuck/absent player

  /// Last failure reason, surfaced to the UI for debugging.
  static String? lastError;

  // ── Lobby ──────────────────────────────────────────────────────────────────

  static String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no easily-confused chars
    final r = Random();
    return List.generate(5, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// Create a room; returns the join code (or null on failure — see [lastError]).
  /// The entry fee is taken from everyone when the host starts the game.
  static Future<String?> createRoom(int entryFee, String name, String pic, {String mode = 'classic'}) async {
    lastError = null;
    // Each player pays their OWN entry fee (DB rules only allow writing your own
    // coin node, so the host can't debit others). Pay on create, refund on leave.
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
      // A 5-char code from a 31-char alphabet ≈ 28M combos — collisions among a
      // few live rooms are negligible, so we skip the (hang-prone) pre-check.
      final code = _genCode();
      final ref = _db.ref().child('unoRooms').child(code);
      await ref.set({
        'host': _uid,
        'entryFee': entryFee,
        'mode': mode,
        'status': 'waiting',
        'createdAt': ServerValue.timestamp,
        'players': {
          _uid: {'name': name, 'pic': pic, 'joinedAt': ServerValue.timestamp},
        },
      });
      // Clean up if the host disconnects before starting.
      ref.child('players').child(_uid).onDisconnect().remove();
      return code;
    } catch (e) {
      coinRef.runTransaction((v) => Transaction.success(((v as int?) ?? 0) + entryFee)).ignore();
      lastError = e.toString();
      debugPrint('UNO_CREATE_ERR: $e');
      return null;
    }
  }

  /// Join a waiting room. Returns an error string, or null on success.
  static Future<String?> joinRoom(String code, String name, String pic) async {
    try {
      final ref = _db.ref().child('unoRooms').child(code);
      final snap = await ref.get();
      if (!snap.exists) return 'Room not found';
      final m = Map<String, dynamic>.from(snap.value as Map);
      if (m['status'] != 'waiting') return 'Game already started';
      final players = Map<String, dynamic>.from(m['players'] ?? {});
      if (players.containsKey(_uid)) return null; // already in (already paid)
      if (players.length >= maxPlayers) return 'Room is full';

      // Pay own entry fee (self-debit, allowed by rules).
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
      final ref = _db.ref().child('unoRooms').child(code);
      final snap = await ref.get();
      if (!snap.exists) return;
      final m = Map<String, dynamic>.from(snap.value as Map);
      final players = Map<String, dynamic>.from(m['players'] ?? {});
      final entryFee = (m['entryFee'] as int?) ?? 0;
      await ref.child('players').child(_uid).remove();
      // Refund own fee if leaving before the game actually started.
      if (players.containsKey(_uid) && m['status'] != 'started' && entryFee > 0) {
        _db.ref().child('users').child(_uid).child('coin')
            .runTransaction((v) => Transaction.success(((v as int?) ?? 0) + entryFee))
            .ignore();
      }
      // If the host leaves while waiting, close the room.
      if (m['host'] == _uid && m['status'] == 'waiting') {
        await ref.child('status').set('closed');
      }
    } catch (_) {}
  }

  static Stream<DatabaseEvent> roomStream(String code) =>
      _db.ref().child('unoRooms').child(code).onValue;

  /// Host deals the game: deducts the entry fee from every player and writes the
  /// initial game state. Returns the gameId, or null on failure.
  static Future<String?> startGame(String code, int entryFee) async {
    lastError = null;
    try {
      final roomRef = _db.ref().child('unoRooms').child(code);
      final snap = await roomRef.get();
      if (!snap.exists) { lastError = 'Room not found'; return null; }
      final m = Map<String, dynamic>.from(snap.value as Map);
      if (m['host'] != _uid) { lastError = 'Only the host can start'; return null; }
      final playersMap = Map<String, dynamic>.from(m['players'] ?? {});
      if (playersMap.length < 2) { lastError = 'Need at least 2 players'; return null; }

      // Order players by join time for a stable seat order. Each player already
      // paid their own entry fee on join/create — no cross-user debit here (the
      // host isn't allowed to write other users' coin nodes).
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
      final mode = (m['mode'] ?? 'classic').toString();

      final state = UnoState.create(playerIds: ids, names: names, bots: bots, mode: mode);
      final gameRef = _db.ref().child('unoGames').push();
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
      debugPrint('UNO_START_ERR: $e');
      return null;
    }
  }

  // ── Game ───────────────────────────────────────────────────────────────────

  static Stream<DatabaseEvent> gameStream(String gameId) =>
      _db.ref().child('unoGames').child(gameId).onValue;

  /// Run an atomic mutation against the game node. [apply] mutates the decoded
  /// state and returns false to reject the move (transaction aborts).
  static Future<bool> _mutate(String gameId, bool Function(UnoState s) apply) async {
    final ref = _db.ref().child('unoGames').child(gameId);
    try {
      final res = await ref.runTransaction((cur) {
        if (cur == null) return Transaction.abort();
        final map = Map<String, dynamic>.from(cur as Map);
        final s = UnoState.fromMap(map);
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

  static Future<bool> play(String gameId, String card, {String? color, String? swapTarget}) {
    return _mutate(gameId, (s) {
      if (s.currentId != _uid) return false;
      if (!s.canPlay(card)) return false;
      if (!(s.hands[_uid]?.contains(card) ?? false)) return false;
      s.play(card, chosenColor: color, swapTarget: swapTarget);
      return true;
    });
  }

  static Future<bool> jumpIn(String gameId, String card, {String? color}) {
    return _mutate(gameId, (s) {
      if (!s.canJumpIn(_uid, card)) return false;
      s.jumpIn(_uid, card, chosenColor: color);
      return true;
    });
  }

  /// Draw: takes the pending penalty if one is stacked, otherwise draws one and
  /// passes unless the drawn card happens to be playable (then the turn stays).
  static Future<bool> drawOrPenalty(String gameId) {
    return _mutate(gameId, (s) {
      if (s.currentId != _uid) return false;
      if (s.pendingDraw > 0) { s.takePenaltyAndPass(); return true; }
      final d = s.drawOne();
      if (d == null || !s.canPlay(d)) s.passTurn();
      return true;
    });
  }

  static Future<bool> pass(String gameId) {
    return _mutate(gameId, (s) {
      if (s.currentId != _uid) return false;
      s.passTurn();
      return true;
    });
  }

  static Future<bool> callUno(String gameId) {
    return _mutate(gameId, (s) {
      if (s.handCount(_uid) > 2) return false;
      s.calledUno.add(_uid);
      return true;
    });
  }

  /// Any client may advance a player who has been idle past the timeout (covers
  /// disconnects). [expectTurnId] guards against advancing the wrong player.
  static Future<bool> timeoutAdvance(String gameId, String expectTurnId) {
    return _mutate(gameId, (s) {
      if (s.currentId != expectTurnId) return false;
      if (s.pendingDraw > 0) { s.takePenaltyAndPass(); return true; }
      s.drawOne();
      s.passTurn();
      return true;
    });
  }

  /// The winner claims the pot exactly once (idempotent via the `paid` flag).
  static Future<void> claimPot(String gameId) async {
    final ref = _db.ref().child('unoGames').child(gameId);
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
