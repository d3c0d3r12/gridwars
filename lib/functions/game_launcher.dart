import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';

import '../helpers/constant.dart';
import '../screens/arcade_lobby.dart';
import '../screens/games/battleship_game.dart';
import '../screens/games/checkers_game.dart';
import '../screens/games/connect4_game.dart';
import '../screens/games/dots_boxes_game.dart';
import '../screens/games/gomoku_game.dart';
import '../screens/games/rps_game.dart';
import '../screens/multiplayer.dart';
import 'arcade_service.dart';

// Shared game create + navigation logic, reused by Private Room and the
// friend Challenge flow so both behave identically.
class GameLauncher {
  static final _db = FirebaseDatabase.instance;

  // Atomically deducts the entry fee from the host and creates the game node.
  // Returns the new gameKey, or null if the user lacks coins / a write failed
  // (coins are refunded on a node-create failure).
  static Future<String?> createGameNode(String gameType) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    TransactionResult? coinTx;
    try {
      coinTx = await _db.ref().child('users').child(uid).child('coin')
          .runTransaction((v) {
        final coins = v as int? ?? 0;
        if (coins < fixedEntryFee) return Transaction.abort();
        return Transaction.success(coins - fixedEntryFee);
      });
    } catch (_) {}
    if (coinTx == null || !coinTx.committed) return null;

    try {
      if (gameType == 'xo') {
        final ref = _db.ref().child('Game').push();
        final firstTry = Random().nextBool() ? 'player1' : 'player2';
        await ref.set({
          'player1': {'id': uid, 'won': 0},
          'player2': {'id': '', 'won': 0},
          'status': 'pending',
          'entryFee': fixedEntryFee,
          'round': fixedRounds,
          'matrixSize': 'Three',
          'try': firstTry,
          'time': DateTime.now().toUtc().toString(),
        });
        return ref.key;
      } else {
        final ref = _db.ref().child('arcadeGames').child(gameType).push();
        await ref.set({
          'type': gameType, 'p1': uid, 'p2': '',
          'status': 'waiting', 'entryFee': fixedEntryFee,
          'winner': '', 'state': ArcadeService.initialState(gameType),
          'createdAt': DateTime.now().toUtc().toString(),
        });
        return ref.key;
      }
    } catch (_) {
      // Refund on failure
      _db.ref().child('users').child(uid).child('coin')
          .runTransaction((v) => Transaction.success((v as int? ?? 0) + fixedEntryFee))
          .ignore();
      return null;
    }
  }

  // Joins an existing waiting game as player 2 (the challenged friend / guest).
  // Deducts the entry fee. Returns true on success.
  static Future<bool> joinGameNode(String gameType, String gameKey) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    TransactionResult? coinTx;
    try {
      coinTx = await _db.ref().child('users').child(uid).child('coin')
          .runTransaction((v) {
        final coins = v as int? ?? 0;
        if (coins < fixedEntryFee) return Transaction.abort();
        return Transaction.success(coins - fixedEntryFee);
      });
    } catch (_) {}
    if (coinTx == null || !coinTx.committed) return false;

    try {
      if (gameType == 'xo') {
        await _db.ref().update({
          'Game/$gameKey/player2/id': uid,
          'Game/$gameKey/player2/won': 0,
          'Game/$gameKey/status': 'preparing',
        });
      } else {
        await _db.ref().update({
          'arcadeGames/$gameType/$gameKey/p2': uid,
          'arcadeGames/$gameType/$gameKey/status': 'active',
        });
      }
      return true;
    } catch (_) {
      _db.ref().child('users').child(uid).child('coin')
          .runTransaction((v) => Transaction.success((v as int? ?? 0) + fixedEntryFee))
          .ignore();
      return false;
    }
  }

  // Navigates into the correct game screen. Mirrors private_room's _navigate.
  static Future<void> launchGame(
    BuildContext context, {
    required String gameType,
    required String gameKey,
    required bool isP1,
    required String myUid,
    required String oppUid,
    required String oppName,
    required String oppPic,
    String? imagex,
    String? imageo,
    bool replace = true,
  }) async {
    if (!context.mounted) return;

    if (gameType == 'xo') {
      bool goesFirst = isP1;
      try {
        final gs = await _db.ref().child('Game').child(gameKey).once();
        final gMap = (gs.snapshot.value as Map?) ?? {};
        final slot = gMap['try']?.toString() ?? 'player1';
        final us = await _db.ref().child('Game').child(gameKey).child(slot).child('id').once();
        goesFirst = us.snapshot.value?.toString() == myUid;
      } catch (_) {}
      if (!context.mounted) return;
      final route = CupertinoPageRoute(builder: (_) => MultiplayerScreen(
        gameKey: gameKey,
        firstTry: goesFirst,
        oppornentName: oppName,
        oppornentPic: oppPic,
        round: fixedRounds,
        imagex: imagex ?? 'cross_skin',
        imageo: imageo ?? 'circle_skin',
        matrixSize: 'Three',
      ));
      replace
          ? Navigator.pushReplacement(context, route)
          : Navigator.push(context, route);
      return;
    }

    final args = GameArgs(
      gameId: gameKey, type: gameType, isP1: isP1,
      oppId: oppUid, oppName: oppName, entryFee: fixedEntryFee,
    );
    Widget screen;
    switch (gameType) {
      case 'rps':        screen = RpsGameScreen(args: args); break;
      case 'connect4':   screen = Connect4GameScreen(args: args); break;
      case 'gomoku':     screen = GomokuGameScreen(args: args); break;
      case 'dotsboxes':  screen = DotsBoxesGameScreen(args: args); break;
      case 'checkers':   screen = CheckersGameScreen(args: args); break;
      case 'battleship': screen = BattleshipGameScreen(args: args); break;
      default: return;
    }
    final route = CupertinoPageRoute(builder: (_) => screen);
    replace
        ? Navigator.pushReplacement(context, route)
        : Navigator.push(context, route);
  }
}
