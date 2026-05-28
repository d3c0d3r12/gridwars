# Scalability Optimization Design — XO Battle

**Date:** 2026-05-28  
**Scope:** Firebase RTDB restructure + Dart client optimizations  
**Target:** 10,000–15,000 concurrent users  
**Firebase Plan:** Spark (no Cloud Functions)  
**Status:** Approved

---

## Problem Statement

The app has three critical bottlenecks that will break under concurrent load:

1. **Matchmaking O(N) full collection scan** — `joinGame()` downloads the entire `Game/` node and loops through every game client-side to find a pending match. At 10k users this downloads megabytes of data per join attempt.
2. **Non-atomic coin/score writes** — `updateMatchWonCount`, `updateMatchPlayedCount`, `updateCoin`, `updateTieCoin` all use read-then-write. Under concurrent load, two writers read the same value and one increment is silently dropped.
3. **Redundant sequential reads** — `gameStatusListener()` fires 3 separate round-trips when a single parent read would suffice. Leaderboard downloads all users client-side for sorting.

---

## Firebase DB Structure

### Current (problematic)

```
Game/
  {gameKey}/
    status, buttons/, player1/, player2/, try, entryFee, round, matrixSize
users/
  {uid}/
    username, score, matchwon, matchplayed, coin, ...
```

### New

```
Game/
  {gameKey}/                        ← unchanged
    status, buttons/, player1/, player2/, try, entryFee, round, matrixSize

lobby/                              ← NEW
  {matrixSize}_{round}_{entryFee}/  ← e.g. "Three_1_25"
    {gameKey}: {creatorUid}         ← single entry per waiting game

users/                              ← unchanged
  {uid}/
    username, score, matchwon, matchplayed, coin, ...
```

**RTDB Security Rules addition:**
```json
{
  "rules": {
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

---

## Change 1: Matchmaking — `lib/functions/findGame.dart`

**Full rewrite of `joinGame()` and `createGames()`.**

### Logic

```
lobbyKey = "${matrixSize}_${round}_${entryFee}"

1. Read lobby/{lobbyKey}/ with limitToFirst(1)

2a. Empty (no waiting game):
    - Push new game to Game/ node
    - Write gameKey → lobby/{lobbyKey}/{gameKey}
    - Register onDisconnect().remove() on that lobby entry
    - Return JoinStatus.created

2b. Entry found:
    - runTransaction on lobby/{lobbyKey}/{gameKey} to atomically claim it
      (prevents two players grabbing the same slot simultaneously)
    - If transaction succeeds:
        - Update Game/{gameKey}/player2 with current user id + won: 0
        - Update Game/{gameKey}/status = "preparing"
        - Return JoinStatus.joined
    - If transaction fails (already claimed by another player simultaneously):
        - Skip joining; create a new game instead (same path as 2a)
        - No infinite retry — one attempt only
```

### Why `runTransaction` on lobby claim

Without it, two players searching simultaneously could both read the same lobby entry and both try to join the same game. The transaction makes the claim atomic — only one succeeds, the other falls through to create a new game.

### `onDisconnect()` auto-cleanup

Registered immediately after writing to lobby. If the creator exits the app or loses connectivity before anyone joins, Firebase auto-deletes the lobby entry. This prevents stale "phantom" pending games from accumulating over time.

---

## Change 2: Atomic Writes — `lib/functions/multiplayer.dart`

**Replace all read-then-write patterns with `runTransaction()`.**

### Affected methods

| Method | Fields updated | Change |
|---|---|---|
| `updateMatchWonCount` | `matchwon`, `matchplayed` | Merged + transactional |
| `updateMatchPlayedCount` | `matchplayed`, `score` | Merged + transactional |
| `updateCoin` | `coin` | Transactional |
| `updateTieCoin` | `coin` | Transactional |

### Merge strategy

`updateMatchWonCount` and `updateMatchPlayedCount` are always called together at game end. They are merged into a single method `updateMatchResult(String id, String result)` that:
- Atomically increments `matchplayed` via transaction
- Atomically increments `matchwon` (if win) via transaction
- Atomically updates `score` (+10 win / -4 lose / +5 tie) via transaction
- All 3 field transactions fire in parallel via `Future.wait()`

### Transaction pattern

```dart
ref.child(field).runTransaction((mutableData) {
  mutableData.value = (mutableData.value as int? ?? 0) + delta;
  return Transaction.success(mutableData);
});
```

---

## Change 3: Collapsed Reads — `lib/screens/multiplayer.dart`

### 3a. `gameStatusListener()` — status change handler

Currently fires 3 sequential reads on `status == "closed"` / `status == "running"` events:
```dart
// 3 reads, sequential, ~150-300ms total
await _gameRef.child(widget.gameKey).once();           // entryFee
await _gameRef.child(widget.gameKey).child("player1").once();
await _gameRef.child(widget.gameKey).child("player2").once();
```

Replaced with one read of the game root node, extracting all fields locally:
```dart
// 1 read
final snap = await _gameRef.child(widget.gameKey).once();
final data = snap.snapshot.value as Map;
final entryFee = data["entryFee"];
final player1  = (data["player1"] as Map)["id"];
final player2  = (data["player2"] as Map)["id"];
```

### 3b. Call-site cleanup in `multiplayer.dart` (screen)

Everywhere `multi.updateMatchWonCount(id)` and `multi.updateMatchPlayedCount(...)` are called back-to-back, replace with single `multi.updateMatchResult(id, result)` call.

---

## Change 4: Leaderboard Query — `lib/screens/leaderboard.dart`

### Current

Fetches all documents under `users/`, sorts client-side, loops to find current user's rank.

### New

```dart
final snap = await FirebaseDatabase.instance
    .ref()
    .child("users")
    .orderByChild("score")
    .limitToLast(100)
    .once();
```

- Server returns top 100 by score only — no full user dump
- Requires `".indexOn": ["score"]` in RTDB rules (see DB Structure section)
- Current user's rank displayed as "Top 100" or their position within the returned list; if not in top 100, show their score without rank

---

## Files Changed Summary

| File | Change |
|---|---|
| `lib/functions/findGame.dart` | Full rewrite — lobby-based O(1) matchmaking |
| `lib/functions/multiplayer.dart` | Transactions on all coin/score writes; merge updateMatchWonCount + updateMatchPlayedCount |
| `lib/screens/multiplayer.dart` | Collapse 3 reads → 1 in status listener; update call sites for merged method |
| `lib/screens/leaderboard.dart` | Server-side sorted query with limitToLast(100) |
| Firebase RTDB Rules | Add `lobby/` rules + `users/.indexOn: score` |

## Files NOT Changed

- `lib/screens/offline_play.dart` — no Firebase, no scale concern
- `lib/screens/pass_n_play.dart` — local only
- `lib/functions/ai.dart` — local compute
- `lib/functions/authentication.dart` — Firebase Auth handles scale itself
- `lib/screens/finding_player.dart` — UI only, logic is in findGame.dart
- All widget/helper/constant files

---

## Success Criteria

- `joinGame()` makes exactly 1 RTDB read to find a match (not N)
- No concurrent coin/score corruption under load
- `gameStatusListener()` fires 1 read per event (not 3)
- Leaderboard never fetches more than 100 user records
- Abandoned pending games auto-delete via `onDisconnect()`
