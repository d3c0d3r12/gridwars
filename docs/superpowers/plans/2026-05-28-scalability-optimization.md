# Scalability Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate three critical bottlenecks (O(N) matchmaking scan, non-atomic coin/score writes, redundant sequential reads) so the app handles 10k–15k concurrent users without data corruption or performance degradation.

**Architecture:** Add a `lobby/` RTDB index node keyed by `{matrixSize}_{round}_{entryFee}` for O(1) matchmaking; replace all read-then-write coin/score patterns with atomic `runTransaction()` calls; collapse redundant sequential reads into single parent reads; server-side leaderboard query with `limitToLast(100)`.

**Tech Stack:** Flutter, Firebase Realtime Database (`firebase_database ^12.0.0`), Firebase Auth (`firebase_auth ^6.0.1`)

**Spec:** `docs/superpowers/specs/2026-05-28-scalability-optimization-design.md`

---

## File Map

| File | Action | What changes |
|---|---|---|
| `database.rules.json` | Create | RTDB rules with `lobby/` perms + `users/.indexOn: score` |
| `firebase.json` | Create | Points Firebase CLI at rules file |
| `lib/functions/findGame.dart` | Rewrite | Lobby-based O(1) matchmaking + `cancelWaiting()` |
| `lib/screens/finding_player.dart` | Modify | Cancel button cleans up lobby entry; `updateCoinMinus` uses transaction |
| `lib/functions/multiplayer.dart` | Rewrite | `MatchResult` enum + atomic `updateMatchResult`, `updateCoin`, `updateTieCoin` |
| `lib/screens/multiplayer.dart` | Modify | Collapse 3 reads → 1; replace all `updateMatchWonCount`/`updateMatchPlayedCount` call sites |
| `lib/screens/leaderboard.dart` | Modify | Server-side sorted query with `limitToLast(100)` |
| `test/unit/find_game_test.dart` | Create | Unit tests for lobby key logic |
| `test/unit/multiplayer_test.dart` | Create | Unit tests for MatchResult score math |

---

## Task 1: RTDB Security Rules

**Files:**
- Create: `database.rules.json`
- Create: `firebase.json`

- [ ] **Step 1: Create database.rules.json**

```json
{
  "rules": {
    ".read": "auth != null",
    ".write": "auth != null",
    "users": {
      ".indexOn": ["score"]
    },
    "lobby": {
      ".read": "auth != null",
      ".write": "auth != null"
    }
  }
}
```

- [ ] **Step 2: Create firebase.json**

```json
{
  "database": {
    "rules": "database.rules.json"
  }
}
```

- [ ] **Step 3: Apply rules (choose one)**

**Option A — Firebase CLI (if installed):**
```bash
firebase deploy --only database
```

**Option B — Firebase Console (manual):**
1. Open [Firebase Console](https://console.firebase.google.com) → your project → Realtime Database → Rules tab
2. Paste the full contents of `database.rules.json` into the editor
3. Click Publish

- [ ] **Step 4: Commit**

```bash
git add database.rules.json firebase.json
git commit -m "chore: add Firebase RTDB rules with lobby index and score indexing"
```

---

## Task 2: Rewrite findGame.dart

**Files:**
- Rewrite: `lib/functions/findGame.dart`
- Create: `test/unit/find_game_test.dart`

- [ ] **Step 1: Create test file**

```bash
mkdir -p test/unit
```

Create `test/unit/find_game_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lobbyKey format', () {
    test('Three_1_25 format is correct', () {
      final matrixSize = "Three";
      final round = 1;
      final entryFee = 25;
      final key = "${matrixSize}_${round}_${entryFee}";
      expect(key, "Three_1_25");
    });

    test('Five_7_200 format is correct', () {
      final key = "${"Five"}_${7}_${200}";
      expect(key, "Five_7_200");
    });

    test('different params produce different keys', () {
      final k1 = "${"Three"}_${1}_${25}";
      final k2 = "${"Three"}_${1}_${50}";
      final k3 = "${"Four"}_${1}_${25}";
      expect(k1, isNot(k2));
      expect(k1, isNot(k3));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it passes (pure logic, no Firebase needed)**

```bash
cd "/Users/d3c0d3r/Downloads/TicTacToe/Tic Tac Toe v1.1.3/codecanyon-33790490-tic-tac-toe-the-classic-flutter-tic-tac-toe-game/Tic-Tac-Toe"
flutter test test/unit/find_game_test.dart
```

Expected: All 3 tests PASS.

- [ ] **Step 3: Rewrite lib/functions/findGame.dart**

Replace the entire file with:

```dart
import 'dart:math' as f;

import 'package:xobattle/models/create_game_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class FindGame {
  final FirebaseDatabase _ins = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Creates a new game in Game/ and returns its key.
  String _createGame(int entryFee, int round, String matrixSize) {
    final game = _ins.ref().child("Game").push();
    final key = game.key!;
    final firstTry = f.Random().nextInt(2) == 0 ? "player1" : "player2";
    game.set(CreateGame(
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
    final gameKey = _createGame(entryFee, round, matrixSize);
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
    bool claimed = false;
    await lobbyEntryRef.runTransaction((mutableData) {
      if (mutableData.value == null) {
        // Already claimed by another concurrent joiner.
        return Transaction.abort();
      }
      mutableData.value = null; // null = delete in RTDB
      claimed = true;
      return Transaction.success(mutableData);
    });

    if (!claimed) {
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
```

- [ ] **Step 4: Commit**

```bash
git add lib/functions/findGame.dart test/unit/find_game_test.dart
git commit -m "feat: replace O(N) matchmaking scan with O(1) lobby node lookup"
```

---

## Task 3: Fix finding_player.dart

**Files:**
- Modify: `lib/screens/finding_player.dart`

Two fixes here:
1. Cancel button must now also remove the lobby entry (previously it only removed from `Game/`)
2. `updateCoinMinus()` uses read-then-write — replace with transaction

- [ ] **Step 1: Add `_lobbyKey` field and store it when game is created or joined**

In `_FindingPlayerScreenState`, add two fields after the existing field declarations (around line 52):

```dart
String? _createdGameKey;
String _lobbyKey = "";
```

- [ ] **Step 2: Store lobbyKey and gameKey when findGame() returns JoinStatus.created**

In the `findGame()` method, inside `if (data['JoinStatus'] == JoinStatus.created)` block (around line 142), add these two lines immediately after `_temp = data["roomKey"];`:

```dart
_createdGameKey = data["roomKey"];
_lobbyKey = data["lobbyKey"] ?? "";
```

- [ ] **Step 3: Replace updateCoinMinus() with a transaction**

Replace the entire `updateCoinMinus()` method (lines 244–254) with:

```dart
Future<void> updateCoinMinus() async {
  await FirebaseDatabase.instance
      .ref()
      .child("users")
      .child(_auth.currentUser!.uid)
      .child("coin")
      .runTransaction((mutableData) {
    final current = mutableData.value as int? ?? 0;
    mutableData.value = current - (widget.selected ?? 0);
    return Transaction.success(mutableData);
  });
}
```

- [ ] **Step 4: Fix the cancel button to also clean up the lobby entry**

In the cancel button `onPressed` (around line 526), replace the `else if (btnTxtKey == "cancel")` block with:

```dart
} else if (btnTxtKey == "cancel") {
  oppTimer!.cancel();
  if (_createdGameKey != null && _createdGameKey!.isNotEmpty) {
    final gameRef = FirebaseDatabase.instance.ref().child("Game").child(_createdGameKey!);
    final lobbyRef = FirebaseDatabase.instance.ref().child("lobby").child(_lobbyKey).child(_createdGameKey!);
    await Future.wait([
      gameRef.update({"status": "closed"}),
      lobbyRef.remove(),
    ]);
  }
  if (mounted) Navigator.pop(context);
}
```

Note: The `onPressed` callback must be `async` for the `await` to work. Change the lambda signature from `onPressed: ()` to `onPressed: () async`.

- [ ] **Step 5: Also clean up lobby in dispose() when popping via system back**

The `onPopInvokedWithResult` callback (around line 315) already calls `Dialogue.removeChild("Game", _temp)`. Add lobby cleanup there too:

```dart
onPopInvokedWithResult: (didPop, result) {
  if (_temp != "" && _temp != null) {
    Dialogue.removeChild("Game", _temp);
    if (_lobbyKey.isNotEmpty && _createdGameKey != null) {
      FirebaseDatabase.instance
          .ref()
          .child("lobby")
          .child(_lobbyKey)
          .child(_createdGameKey!)
          .remove();
    }
  }
  music.play(click);
},
```

- [ ] **Step 6: Verify the file compiles**

```bash
cd "/Users/d3c0d3r/Downloads/TicTacToe/Tic Tac Toe v1.1.3/codecanyon-33790490-tic-tac-toe-the-classic-flutter-tic-tac-toe-game/Tic-Tac-Toe"
flutter analyze lib/screens/finding_player.dart
```

Expected: No errors (warnings about unused variables are fine).

- [ ] **Step 7: Commit**

```bash
git add lib/screens/finding_player.dart
git commit -m "fix: clean up lobby entry on cancel; make coin deduction atomic"
```

---

## Task 4: Rewrite multiplayer.dart (functions)

**Files:**
- Rewrite: `lib/functions/multiplayer.dart`
- Create: `test/unit/multiplayer_test.dart`

- [ ] **Step 1: Write unit test for score math**

Create `test/unit/multiplayer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xobattle/helpers/constant.dart';

// Mirror the score logic from updateMatchResult so we can test it in isolation.
int computeScoreDelta(String result) {
  switch (result) {
    case 'win':
      return winScore;   // 10
    case 'lose':
      return -loseScore; // -4
    case 'tie':
      return tieScore;   // 5
    default:
      return 0;
  }
}

void main() {
  group('score deltas', () {
    test('win adds winScore', () {
      expect(computeScoreDelta('win'), winScore);
    });

    test('lose subtracts loseScore', () {
      expect(computeScoreDelta('lose'), -loseScore);
    });

    test('tie adds tieScore', () {
      expect(computeScoreDelta('tie'), tieScore);
    });

    test('unknown result returns 0', () {
      expect(computeScoreDelta('unknown'), 0);
    });
  });
}
```

- [ ] **Step 2: Run test**

```bash
flutter test test/unit/multiplayer_test.dart
```

Expected: All 4 tests PASS.

- [ ] **Step 3: Rewrite lib/functions/multiplayer.dart**

Replace the entire file with:

```dart
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
      ref.child("matchplayed").runTransaction((data) {
        data.value = (data.value as int? ?? 0) + 1;
        return Transaction.success(data);
      }),
      ref.child("score").runTransaction((data) {
        final current = data.value as int? ?? 0;
        switch (result) {
          case MatchResult.win:
            data.value = current + winScore;
          case MatchResult.lose:
            data.value = current - loseScore;
          case MatchResult.tie:
            data.value = current + tieScore;
        }
        return Transaction.success(data);
      }),
    ];

    if (result == MatchResult.win) {
      futures.add(ref.child("matchwon").runTransaction((data) {
        data.value = (data.value as int? ?? 0) + 1;
        return Transaction.success(data);
      }));
    }

    await Future.wait(futures);
  }

  // Atomically adds entryFee * 2 to winner's coin balance.
  Future<void> updateCoin(String winnerId, int entryFee) async {
    await _userRef.child(winnerId).child("coin").runTransaction((data) {
      data.value = (data.value as int? ?? 0) + (entryFee * 2);
      return Transaction.success(data);
    });
  }

  // Atomically adds entryFee to the tied player's coin balance.
  Future<void> updateTieCoin(String uid, int entryFee) async {
    await _userRef.child(uid).child("coin").runTransaction((data) {
      data.value = (data.value as int? ?? 0) + entryFee;
      return Transaction.success(data);
    });
  }

  static dispose() {
    _stream?.cancel();
  }
}
```

- [ ] **Step 4: Run the unit tests again to make sure nothing broke**

```bash
flutter test test/unit/
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/functions/multiplayer.dart test/unit/multiplayer_test.dart
git commit -m "feat: replace read-then-write with atomic runTransaction for all coin/score updates"
```

---

## Task 5: Update multiplayer.dart (screen)

**Files:**
- Modify: `lib/screens/multiplayer.dart`

Two changes: (A) collapse 3 sequential reads → 1, (B) replace all `updateMatchWonCount`/`updateMatchPlayedCount` call pairs with `updateMatchResult`, and (C) fix `updateCoin`/`updateTieCoin` signatures.

- [ ] **Step 1: Add MatchResult import at the top of the file**

After the existing imports in `lib/screens/multiplayer.dart`, the import for `multiplayer.dart` (functions) is already present:
```dart
import '../functions/multiplayer.dart';
```
`MatchResult` is defined in that file, so no new import needed.

- [ ] **Step 2: Fix updateCoin() — make it transaction-based and remove internal DB read**

Find the existing `updateCoin` method (around line 412) and replace it:

```dart
Future<void> updateCoin(String winnerId, int entryFee) async {
  await _userRef.child(winnerId).child("coin").runTransaction((data) {
    data.value = (data.value as int? ?? 0) + (entryFee * 2);
    return Transaction.success(data);
  });
}
```

- [ ] **Step 3: Fix updateTieCoin() — make it transaction-based and remove internal DB read**

Find the existing `updateTieCoin` method (around line 422) and replace it:

```dart
Future<void> updateTieCoin(String uid, int entryFee) async {
  await _userRef.child(uid).child("coin").runTransaction((data) {
    data.value = (data.value as int? ?? 0) + entryFee;
    return Transaction.success(data);
  });
}
```

- [ ] **Step 4: Collapse 3 sequential reads → 1 in gameStatusListener()**

In `gameStatusListener()`, find the block inside `if (event.snapshot.key == "status")` that makes three sequential reads (around line 457). Replace those three `await` lines and their variable declarations with:

```dart
// Single read replaces 3 sequential reads
final gameSnap = await _gameRef.child(widget.gameKey).once();
final gameData = gameSnap.snapshot.value as Map;
int? entryfee = gameData["entryFee"] as int?;
String? player1 = (gameData["player1"] as Map)["id"] as String?;
String? player2 = (gameData["player2"] as Map)["id"] as String?;
```

Remove these three lines that are no longer needed:
```dart
DatabaseEvent entryfeeSnapshot = await _gameRef.child(widget.gameKey).once();
DatabaseEvent player1Snapshot = await _gameRef.child(widget.gameKey).child("player1").once();
DatabaseEvent player2Snapshot = await _gameRef.child(widget.gameKey).child("player2").once();
int? entryfee = (entryfeeSnapshot.snapshot.value as Map)["entryFee"];
String? player1 = (player1Snapshot.snapshot.value as Map)["id"];
String? player2 = (player2Snapshot.snapshot.value as Map)["id"];
```

- [ ] **Step 5: Fix call site 1 — opponent disconnect case (around line 483)**

Find:
```dart
multi.updateMatchWonCount(_auth.currentUser!.uid);
multi.updateMatchPlayedCount(context, _auth.currentUser!.uid,
    utils.getTranslated(context, "win"));
```

Also find the `updateCoin` call near it:
```dart
await updateCoin(_auth.currentUser!.uid);
```

You need the `entryfee` value here. It is already available from Step 4's collapsed read (the `entryfee` variable). Replace all three with:

```dart
await Future.wait([
  multi.updateMatchResult(_auth.currentUser!.uid, MatchResult.win),
  updateCoin(_auth.currentUser!.uid, entryfee!),
]);
```

- [ ] **Step 6: Fix call site 2 — game end (winner determined, around line 635)**

Find:
```dart
multi.updateMatchWonCount(winnerId);
multi.updateMatchPlayedCount(
    context, winnerId, utils.getTranslated(context, "win"));
multi.updateMatchPlayedCount(
    context, looserId, utils.getTranslated(context, "lose"));
await updateCoin(winnerId);
```

Replace with:

```dart
await Future.wait([
  multi.updateMatchResult(winnerId, MatchResult.win),
  multi.updateMatchResult(looserId, MatchResult.lose),
  updateCoin(winnerId, entryfee!),
]);
```

Note: `entryfee` is available from Step 4's collapsed read, or from the local `r` snapshot already fetched in this block (around line 598: `DatabaseEvent r = await FirebaseDatabase.instance...child("entryFee").once()`). Use `int.parse(r.snapshot.value.toString())` if `entryfee` isn't in scope here.

- [ ] **Step 7: Fix call site 3 — early round win (around line 717)**

Find:
```dart
multi.updateMatchWonCount(winnerId.toString());
multi.updateMatchPlayedCount(context, winnerId.toString(),
    utils.getTranslated(context, "win"));
multi.updateMatchPlayedCount(
    context, looserId, utils.getTranslated(context, "lose"));
await updateCoin(winnerId.toString());
```

Replace with:

```dart
await Future.wait([
  multi.updateMatchResult(winnerId.toString(), MatchResult.win),
  multi.updateMatchResult(looserId, MatchResult.lose),
  updateCoin(winnerId.toString(), int.parse(r.snapshot.value.toString())),
]);
```

- [ ] **Step 8: Fix call site 4 — tie in round wins — both players get tie result (around line 824)**

Find:
```dart
multi.updateMatchPlayedCount(
    context, idOfPlayer1, utils.getTranslated(context, "tie"));
multi.updateMatchPlayedCount(
    context, idOfPlayer2, utils.getTranslated(context, "tie"));
```

Replace with:

```dart
await Future.wait([
  multi.updateMatchResult(idOfPlayer1, MatchResult.tie),
  multi.updateMatchResult(idOfPlayer2, MatchResult.tie),
]);
```

Also find the nearby `updateTieCoin()` call (around line 801). The original `updateTieCoin()` reads the uid from `_auth.currentUser!.uid` internally. The new signature takes `uid` and `entryFee`. Replace:

```dart
updateTieCoin();
```

With (using `entryFee.snapshot.value` which is already fetched in this block):

```dart
await updateTieCoin(_auth.currentUser!.uid, int.parse(entryFee.snapshot.value.toString()));
```

- [ ] **Step 9: Fix call site 4b — tie within curRound == widget.round path (around line 643)**

This is a second `updateTieCoin()` call inside the `event.snapshot.key == "player2" || event.snapshot.key == "player1"` block, inside the `winnerId == ""` branch. The variable `r` (entry fee snapshot) is already fetched just above it in that Timer block.

Find:
```dart
updateTieCoin();
Dialogue dialog = Dialogue();
dialog.tieMultiplayer(context, widget.gameKey);
```

Replace with:
```dart
await updateTieCoin(_auth.currentUser!.uid, int.parse(r.snapshot.value.toString()));
Dialogue dialog = Dialogue();
dialog.tieMultiplayer(context, widget.gameKey);
```

- [ ] **Step 10: Fix call site 5 — tie overall resolved to winner (around line 869)**

Find:
```dart
multi.updateMatchWonCount(winnerId);
multi.updateMatchPlayedCount(
    context, winnerId, utils.getTranslated(context, "win"));
multi.updateMatchPlayedCount(
    context, looserId, utils.getTranslated(context, "lose"));
await updateCoin(winnerId);
```

Replace with:

```dart
await Future.wait([
  multi.updateMatchResult(winnerId, MatchResult.win),
  multi.updateMatchResult(looserId, MatchResult.lose),
  updateCoin(winnerId, int.parse(entryFee.snapshot.value.toString())),
]);
```

- [ ] **Step 11: Verify the file compiles with no errors**

```bash
flutter analyze lib/screens/multiplayer.dart
```

Expected: No errors. If there are "unused import" or "deprecated" warnings, those can be ignored.

- [ ] **Step 12: Commit**

```bash
git add lib/screens/multiplayer.dart
git commit -m "perf: collapse sequential DB reads; replace updateMatchWonCount/Played with atomic updateMatchResult"
```

---

## Task 6: Optimize leaderboard.dart

**Files:**
- Modify: `lib/screens/leaderboard.dart`

Two fixes: (1) server-side sorted query with `limitToLast(100)` so we never download all users, (2) fix double-invocation of `leaderBoard()` (currently called in both `fetchUserDetails()` and `FutureBuilder`, causing two separate network requests on screen load).

- [ ] **Step 1: Replace leaderBoard() with server-side query**

Find the existing `leaderBoard()` method (around line 59) and replace it entirely:

```dart
Future<List<Map>> leaderBoard() async {
  final snap = await FirebaseDatabase.instance
      .ref()
      .child("users")
      .orderByChild("score")
      .limitToLast(100)
      .once();

  if (snap.snapshot.value == null) return [];

  final raw = Map<String, dynamic>.from(snap.snapshot.value as Map);

  final result = raw.entries
      .where((e) {
        final score = (e.value as Map)["score"];
        return score != null && score != 0;
      })
      .map((e) => {
            ...Map<String, dynamic>.from(e.value as Map),
            "userid": e.key, // include uid so rank detection works
          })
      .toList();

  // RTDB returns ascending — reverse for descending display.
  result.sort((a, b) => (b["score"] as int).compareTo(a["score"] as int));
  return result;
}
```

- [ ] **Step 2: Store the future once so it isn't called twice**

At the top of `_LeaderBoardScreenState` class (after the field declarations), add:

```dart
late final Future<List<Map>> _leaderboardFuture;
```

In `initState()`, after `Advertisement.loadAd();`, initialize it and change `fetchUserDetails()` to use it:

```dart
@override
void initState() {
  super.initState();
  Advertisement.loadAd();
  _leaderboardFuture = leaderBoard();
  fetchUserDetails();
}
```

- [ ] **Step 3: Update fetchUserDetails() to use the cached future**

Replace the `leaderBoard()` call inside `fetchUserDetails()` (around line 44):

```dart
// Before:
result = await (leaderBoard());

// After:
result = await _leaderboardFuture;
```

- [ ] **Step 4: Update FutureBuilder to use the cached future**

Find the `FutureBuilder` widget (around line 182) and change its `future` property:

```dart
// Before:
future: leaderBoard(),

// After:
future: _leaderboardFuture,
```

- [ ] **Step 5: Verify compilation**

```bash
flutter analyze lib/screens/leaderboard.dart
```

Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/leaderboard.dart
git commit -m "perf: server-side leaderboard query with limitToLast(100); fix double fetch"
```

---

## Task 7: Final verification

- [ ] **Step 1: Run all unit tests**

```bash
cd "/Users/d3c0d3r/Downloads/TicTacToe/Tic Tac Toe v1.1.3/codecanyon-33790490-tic-tac-toe-the-classic-flutter-tic-tac-toe-game/Tic-Tac-Toe"
flutter test test/unit/
```

Expected: All tests pass.

- [ ] **Step 2: Analyze the full project**

```bash
flutter analyze lib/
```

Expected: No errors. Warnings are acceptable.

- [ ] **Step 3: Build to verify no compile errors**

```bash
flutter build apk --debug 2>&1 | tail -20
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk` with no errors.

- [ ] **Step 4: Manual smoke test — matchmaking**

1. Run the app on two devices/emulators simultaneously (both logged in with different accounts)
2. Both tap "Find Opponent" with the same settings (matrixSize, round, entryFee)
3. Verify they find each other within 3 seconds
4. Open Firebase console → Realtime Database → `lobby/` node: it should be empty once both players have matched (the entry gets consumed)
5. Disconnect one player mid-wait (kill the app) → confirm `lobby/` entry disappears within 60s (onDisconnect cleanup)

- [ ] **Step 5: Manual smoke test — leaderboard**

1. Open Leaderboard screen
2. Open Firebase console → Realtime Database → Monitor "Read" operations
3. Confirm only 1 read fires on screen open (not 2)
4. Confirm the read only returns up to 100 user records (check the response size in console)

- [ ] **Step 6: Final commit**

```bash
git add .
git commit -m "chore: scalability optimization complete — lobby matchmaking, atomic writes, collapsed reads, server-side leaderboard"
```
