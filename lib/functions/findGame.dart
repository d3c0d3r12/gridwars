import 'dart:math' as f;

import 'package:xobattle/models/create_game_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class FindGame {
  final FirebaseDatabase _ins = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Creates a new game in Game/ and returns its key.
  Future<String> _createGame(int entryFee, int round, String matrixSize) async {
    final game = _ins.ref().child("Game").push();
    final key = game.key!;
    final firstTry = f.Random().nextInt(2) == 0 ? "player1" : "player2";
    await game.set(CreateGame(
      player1: _auth.currentUser!.uid,
      entryFee: entryFee,
      round: round,
      tryy: firstTry,
      matrixSize: matrixSize,
    ).toMap());
    return key;
  }

  // Creates a game and registers it in the lobby with onDisconnect cleanup.
  Future<Map<String, dynamic>> _createAndRegister(
    int entryFee,
    int round,
    String matrixSize,
    DatabaseReference lobbyRef,
  ) async {
    final gameKey = await _createGame(entryFee, round, matrixSize);
    final entryRef = lobbyRef.child(gameKey);
    await entryRef.set(_auth.currentUser!.uid);
    // Auto-removes lobby entry if creator disconnects before anyone joins.
    entryRef.onDisconnect().remove();
    return {
      "JoinStatus": JoinStatus.created,
      "roomKey": gameKey,
      "oppornentKey": "",
      "lobbyKey": "${matrixSize}_${round}_${entryFee}",
    };
  }

  // Cancels a waiting game: removes from Game/ and lobby/.
  Future<void> cancelWaiting(String gameKey, String matrixSize, int entryFee, int round) async {
    final lobbyKey = "${matrixSize}_${round}_${entryFee}";
    await Future.wait([
      _ins.ref().child("Game").child(gameKey).update({"status": "closed"}),
      _ins.ref().child("lobby").child(lobbyKey).child(gameKey).remove(),
    ]);
  }

  Future<Map<String, dynamic>> joinGame(int entryFee, int round, String matrixSize) async {
    final lobbyKey = "${matrixSize}_${round}_${entryFee}";
    final lobbyRef = _ins.ref().child("lobby").child(lobbyKey);

    // Single O(1) read — no full collection scan.
    final snap = await lobbyRef.limitToFirst(1).once();

    if (snap.snapshot.value == null) {
      // No one waiting — create and register in lobby.
      return _createAndRegister(entryFee, round, matrixSize, lobbyRef);
    }

    final entries = Map<String, dynamic>.from(snap.snapshot.value as Map);
    final gameKey = entries.keys.first;
    final opponentUid = entries.values.first as String;
    final lobbyEntryRef = lobbyRef.child(gameKey);

    // Atomically claim the lobby slot — prevents two joiners grabbing the same game.
    final txResult = await lobbyEntryRef.runTransaction((currentValue) {
      if (currentValue == null) {
        // Already claimed by another concurrent joiner.
        return Transaction.abort();
      }
      return Transaction.success(null); // null = delete in RTDB
    });

    if (!txResult.committed) {
      // Race lost — create a fresh game instead of retrying.
      return _createAndRegister(entryFee, round, matrixSize, lobbyRef);
    }

    // Claimed — join the game in parallel writes.
    await Future.wait([
      _ins.ref().child("Game").child(gameKey).child("player2").update({
        "id": _auth.currentUser!.uid,
        "won": 0,
      }),
      _ins.ref().child("Game").child(gameKey).update({"status": "preparing"}),
    ]);

    return {
      "JoinStatus": JoinStatus.joined,
      "roomKey": gameKey,
      "oppornentKey": opponentUid,
      "lobbyKey": lobbyKey,
    };
  }

  int timeDifferance(String time) {
    final gameCreatedDate = DateTime.parse(time);
    final nowDate = DateTime.now().toUtc();
    return gameCreatedDate.difference(nowDate).inMinutes;
  }
}

enum JoinStatus {
  created,
  joined,
  pending,
  error,
}
