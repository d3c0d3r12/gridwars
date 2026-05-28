import 'dart:async';

import 'package:xobattle/helpers/constant.dart';
import 'package:xobattle/screens/splash.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';

enum MatchResult { win, lose, tie }

class Multiplayer {
  final _userRef = FirebaseDatabase.instance.ref().child("users");

  static StreamSubscription? _stream;

  static updateLocalList(
      String? gameKey, dynamic dbIns, void Function(dynamic b) update) {
    _stream = dbIns
        .ref()
        .child("Game")
        .child(gameKey)
        .child("buttons")
        .onChildChanged
        .listen((DatabaseEvent ev) {
      update(ev);
    });
  }

  static Future<void> checkStatus(
    BuildContext context,
    String gameKey,
    Map<dynamic, dynamic> buttons,
    String matrixSize,
    dynamic gameStatus, {
    void Function(int index)? onWin,
    void Function(int index)? onTie,
  }) async {
    int called = 0;
    String? winner = "0";
    var tieCalled = 0;
    int _count = 0;

    final List<dynamic> currentWinningCondition = (matrixSize == "Four")
        ? utils.winningConditionFour
        : (matrixSize == "Five")
            ? utils.winningConditionFive
            : utils.winningCondition;

    for (var j = 0; j < currentWinningCondition.length; j++) {
      if (buttons[currentWinningCondition[j][0]] != null &&
          buttons[currentWinningCondition[j][1]] != null &&
          buttons[currentWinningCondition[j][2]] != null &&
          (matrixSize == "Four"
              ? buttons[currentWinningCondition[j][3]] != null
              : (matrixSize == "Five"
                  ? buttons[currentWinningCondition[j][3]] != null &&
                      buttons[currentWinningCondition[j][4]] != null
                  : true)) &&
          buttons[currentWinningCondition[j][0]]["player"] ==
              buttons[currentWinningCondition[j][1]]["player"] &&
          buttons[currentWinningCondition[j][1]]["player"] ==
              buttons[currentWinningCondition[j][2]]["player"] &&
          (matrixSize == "Four"
              ? buttons[currentWinningCondition[j][2]]["player"] ==
                  buttons[currentWinningCondition[j][3]]["player"]
              : (matrixSize == "Five"
                  ? buttons[currentWinningCondition[j][2]]["player"] ==
                          buttons[currentWinningCondition[j][3]]["player"] &&
                      buttons[currentWinningCondition[j][3]]["player"] ==
                          buttons[currentWinningCondition[j][4]]["player"]
                  : true)) &&
          buttons[currentWinningCondition[j][0]]["player"] != "0") {
        winner = buttons[currentWinningCondition[j][0]]["player"];
        if (called == 0 && winner != "0") {
          onWin!(j);
          called += 1;
        }
      }
    }

    for (int i = 0; i < buttons.length; i++) {
      if (buttons[i] != null && buttons[i]["player"] != "0") {
        _count++;
      }
    }

    if (_count ==
            (matrixSize == "Three" ? 9 : (matrixSize == "Four" ? 16 : 25)) &&
        winner == "0" &&
        tieCalled == 0) {
      tieCalled++;
      if (onTie != null) onTie(0);
    }
  }

  getPlayerNameByUid(uid) async {
    DatabaseEvent ref = await _userRef.child(uid).once();
    var result = (ref.snapshot.value as Map)["username"];
    return result;
  }

  // Atomic, merged replacement for updateMatchWonCount + updateMatchPlayedCount.
  // Fires all field transactions in parallel — no sequential reads.
  Future<void> updateMatchResult(String uid, MatchResult result) async {
    final ref = _userRef.child(uid);

    final futures = <Future>[
      ref.child("matchplayed").runTransaction((currentValue) {
        return Transaction.success((currentValue as int? ?? 0) + 1);
      }),
      ref.child("score").runTransaction((currentValue) {
        final current = currentValue as int? ?? 0;
        switch (result) {
          case MatchResult.win:
            return Transaction.success(current + winScore);
          case MatchResult.lose:
            return Transaction.success(current - loseScore);
          case MatchResult.tie:
            return Transaction.success(current + tieScore);
        }
      }),
    ];

    if (result == MatchResult.win) {
      futures.add(ref.child("matchwon").runTransaction((currentValue) {
        return Transaction.success((currentValue as int? ?? 0) + 1);
      }));
    }

    await Future.wait(futures);
  }

  // Atomically adds entryFee * 2 to winner's coin balance.
  Future<void> updateCoin(String winnerId, int entryFee) async {
    await _userRef.child(winnerId).child("coin").runTransaction((currentValue) {
      return Transaction.success((currentValue as int? ?? 0) + (entryFee * 2));
    });
  }

  // Atomically adds entryFee to the tied player's coin balance.
  Future<void> updateTieCoin(String uid, int entryFee) async {
    await _userRef.child(uid).child("coin").runTransaction((currentValue) {
      return Transaction.success((currentValue as int? ?? 0) + entryFee);
    });
  }

  static dispose() {
    _stream?.cancel();
  }
}
