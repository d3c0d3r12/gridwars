import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../functions/friend_service.dart';
import '../functions/game_launcher.dart';
import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../helpers/game_tags.dart';
import 'splash.dart';

// Entry point: friend taps "Challenge". Shows a game picker, creates the game
// node, sends the challenge, and pushes a waiting screen.
Future<void> startChallenge(
    BuildContext context, String friendUid, String friendName) async {
  final gameType = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: surfaceColor,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _GamePickerSheet(friendName: friendName),
  );
  if (gameType == null || !context.mounted) return;

  // Create the game node (deducts entry fee, challenger is host/p1).
  final gameKey = await GameLauncher.createGameNode(gameType);
  if (gameKey == null) {
    if (context.mounted) {
      utils.setSnackbar(context, 'Not enough coins to challenge!');
    }
    return;
  }

  final challengeId =
      await FriendService.sendChallenge(friendUid, gameType, gameKey);
  if (!context.mounted) return;

  Navigator.push(context, CupertinoPageRoute(
    builder: (_) => ChallengeWaitScreen(
      friendUid: friendUid,
      friendName: friendName,
      gameType: gameType,
      gameKey: gameKey,
      challengeId: challengeId,
    ),
  ));
}

// Recipient accepts an incoming challenge: join the game node and launch.
Future<void> acceptIncomingChallenge(
    BuildContext context, Challenge c) async {
  final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  await FriendService.removeChallenge(c.id); // clear from my inbox

  final ok = await GameLauncher.joinGameNode(c.gameType, c.gameKey);
  if (!ok) {
    if (context.mounted) utils.setSnackbar(context, 'Could not join — not enough coins?');
    return;
  }
  if (!context.mounted) return;

  await GameLauncher.launchGame(
    context,
    gameType: c.gameType,
    gameKey: c.gameKey,
    isP1: false,
    myUid: myUid,
    oppUid: c.fromUid,
    oppName: c.fromName,
    oppPic: guestProfilePic,
    replace: false,
  );
}

// ── Game picker sheet (in-app challengeable games only) ───────────────────────

class _GamePickerSheet extends StatelessWidget {
  final String friendName;
  const _GamePickerSheet({required this.friendName});

  @override
  Widget build(BuildContext context) {
    final games = challengeableTags;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: lineColor, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 16),
        Text('Challenge ${utils.limitChar(friendName, 14)}',
            style: TextStyle(color: inkColor, fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 4),
        Text('Entry: $fixedEntryFee coins • Winner takes all',
            style: TextStyle(color: ink2Color, fontSize: 12)),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12, mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: games.map((g) => GestureDetector(
            onTap: () => Navigator.pop(context, g.id),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: surfaceColor,
                border: Border.all(color: g.color.withValues(alpha: 0.4)),
                boxShadow: [shadowSm],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: g.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(g.icon, color: g.color, size: 22),
                ),
                const SizedBox(height: 6),
                Text(g.name,
                    style: TextStyle(color: inkColor, fontWeight: FontWeight.w700, fontSize: 12),
                    textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
          )).toList(),
        ),
      ]),
    );
  }
}

// ── Challenger waiting screen ─────────────────────────────────────────────────

class ChallengeWaitScreen extends StatefulWidget {
  final String friendUid, friendName, gameType, gameKey, challengeId;
  const ChallengeWaitScreen({
    super.key,
    required this.friendUid,
    required this.friendName,
    required this.gameType,
    required this.gameKey,
    required this.challengeId,
  });
  @override
  State<ChallengeWaitScreen> createState() => _ChallengeWaitScreenState();
}

class _ChallengeWaitScreenState extends State<ChallengeWaitScreen> {
  final _db = FirebaseDatabase.instance;
  StreamSubscription? _sub;
  Timer? _timeout;
  bool _navigated = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _watchForJoin();
    // Auto-cancel after 60s if the friend never joins.
    _timeout = Timer(const Duration(seconds: 60), () {
      if (!_navigated) _cancel(expired: true);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _timeout?.cancel();
    super.dispose();
  }

  void _watchForJoin() {
    // Listen on the game node for the opponent joining.
    final ref = widget.gameType == 'xo'
        ? _db.ref().child('Game').child(widget.gameKey).child('player2').child('id')
        : _db.ref().child('arcadeGames').child(widget.gameType).child(widget.gameKey).child('p2');
    _sub = ref.onValue.listen((ev) {
      final v = ev.snapshot.value?.toString() ?? '';
      if (v.isNotEmpty && !_navigated && !_disposed && mounted) {
        _navigated = true;
        _sub?.cancel();
        _timeout?.cancel();
        final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        GameLauncher.launchGame(
          context,
          gameType: widget.gameType,
          gameKey: widget.gameKey,
          isP1: true,
          myUid: myUid,
          oppUid: widget.friendUid,
          oppName: widget.friendName,
          oppPic: guestProfilePic,
        );
      }
    });
  }

  Future<void> _cancel({bool expired = false}) async {
    _sub?.cancel();
    _timeout?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    // Remove the pending challenge from the friend's inbox.
    await FriendService.cancelSentChallenge(widget.friendUid, widget.challengeId);
    // Remove the game node + refund the entry fee.
    if (widget.gameType == 'xo') {
      _db.ref().child('Game').child(widget.gameKey).remove().ignore();
    } else {
      _db.ref().child('arcadeGames').child(widget.gameType).child(widget.gameKey).remove().ignore();
    }
    if (uid != null) {
      _db.ref().child('users').child(uid).child('coin')
          .runTransaction((v) => Transaction.success((v as int? ?? 0) + fixedEntryFee))
          .ignore();
    }
    if (mounted) {
      if (expired) utils.setSnackbar(context, '${utils.limitChar(widget.friendName, 14)} didn\'t respond.');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = tagById(widget.gameType);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop && !_navigated) _cancel(); },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: g.color.withValues(alpha: 0.10),
                    border: Border.all(color: g.color.withValues(alpha: 0.35), width: 2),
                  ),
                  child: Icon(g.icon, color: g.color, size: 46),
                ),
                const SizedBox(height: 26),
                Text('Challenge sent!',
                    style: TextStyle(color: inkColor, fontWeight: FontWeight.w800, fontSize: 20)),
                const SizedBox(height: 8),
                Text('Waiting for ${utils.limitChar(widget.friendName, 16)} to accept your ${g.name} challenge…',
                    style: TextStyle(color: ink2Color, fontSize: 14, height: 1.5),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                SizedBox(width: 28, height: 28,
                    child: CircularProgressIndicator(color: g.color, strokeWidth: 2.5)),
                const SizedBox(height: 28),
                OutlinedButton(
                  onPressed: () => _cancel(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: red.withValues(alpha: 0.5)),
                    foregroundColor: red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
