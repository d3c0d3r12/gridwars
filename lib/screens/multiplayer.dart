import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../helpers/utils.dart';
import '../functions/dialoges.dart';
import '../functions/gameHistory.dart';
import '../functions/getCoin.dart';
import '../functions/multiplayer.dart';
import '../widgets/alert_dialogue.dart';
import 'splash.dart';

class MultiplayerScreen extends StatelessWidget {
  final firstTry;
  final gameKey;
  final oppornentName;
  final oppornentPic;
  final int? round;
  final imagex;
  final imageo;
  final String matrixSize;

  const MultiplayerScreen(
      {super.key,
        this.gameKey,
        this.firstTry,
        this.oppornentName,
        this.oppornentPic,
        this.round,
        this.imagex,
        this.imageo,
        required this.matrixSize});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
          body: MultiplayerScreenActivity(
            firstTry: firstTry,
            gameKey: gameKey,
            oppornentName: oppornentName,
            oppornentPic: oppornentPic,
            round: round,
            imagex: imagex,
            imageo: imageo,
            matrixSize: matrixSize,
          )),
    );
  }
}

// ignore: must_be_immutable
class MultiplayerScreenActivity extends StatefulWidget {
  final firstTry;
  final gameKey;
  final oppornentName;
  final oppornentPic;
  final round;
  String? imagex;
  String? imageo;
  final String matrixSize;

  MultiplayerScreenActivity(
      {super.key,
        this.gameKey,
        this.firstTry,
        this.oppornentName,
        this.oppornentPic,
        this.round,
        this.imagex,
        this.imageo,
        required this.matrixSize});

  @override
  _MultiplayerScreenActivityState createState() =>
      _MultiplayerScreenActivityState();
}

class _MultiplayerScreenActivityState extends State<MultiplayerScreenActivity> {
  int? winVar1, winVar2, winVar3;
  bool? winGame;

  //-----//
  FirebaseDatabase _ins = FirebaseDatabase.instance;
  FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _gameTimer;
  final _timerNotifier = ValueNotifier<int>(0);

  int _getCurrentTimerDuration() {
    return _suddenDeathShowing ? blitzCountdown : countdowntime;
  }

  void _startTimer() {
    _stopTimer();
    if (!mounted) return;
    _timerNotifier.value = _getCurrentTimerDuration();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_timerNotifier.value <= 0) {
        t.cancel();
        _onTimerExpired();
      } else {
        _timerNotifier.value--;
      }
    });
  }

  void _stopTimer() {
    _gameTimer?.cancel();
    _gameTimer = null;
  }

  void _onTimerExpired() async {
    if (!mounted) return;

    final statusSnap = await _ins
        .ref()
        .child("Game")
        .child(widget.gameKey)
        .child("status")
        .once();

    if (statusSnap.snapshot.value != "running") return;

    final trySnap = await _ins
        .ref()
        .child("Game")
        .child(widget.gameKey)
        .child("try")
        .once();

    final currentTurn = trySnap.snapshot.value.toString();

    final uidSnap = await _ins
        .ref()
        .child("Game")
        .child(widget.gameKey)
        .child(currentTurn)
        .child("id")
        .once();

    if (uidSnap.snapshot.value != _auth.currentUser!.uid) return;

    whoseTimeout = currentTurn;
    final winnerPlayer = currentTurn == "player1" ? "player2" : "player1";

    final winCountSnap = await _ins
        .ref()
        .child("Game")
        .child(widget.gameKey)
        .child(winnerPlayer)
        .child("won")
        .once();

    final currentWins = winCountSnap.snapshot.value != null
        ? int.parse(winCountSnap.snapshot.value.toString())
        : 0;

    await _ins
        .ref()
        .child("Game")
        .child(widget.gameKey)
        .child(winnerPlayer)
        .update({"won": currentWins + 1});

    if (mounted) {
      setState(() {
        istimerCompleted = true;
      });
    }
  }

  StateSetter? dialogState;

  String? playerValue;
  String gameStatus = "";
  bool? yourTry;
  String? username, profilePic;
  String? uid;
  Map buttons = Map();
  List timerButtons = [];
  String? player1Id, player2Id;
  late DatabaseReference _gameRef;
  late DatabaseReference _userRef;
  int playcountdown = 3;
  Duration animationDuration = Duration(seconds: 3);
  double itemSize = 0;
  double opacity = 1;
  Timer? playclocktimer;

  late String timerUpof;
  var gameIns;
  var diceSound;
  var diceIns;
  bool istimerCompleted = false;
  String whoseTimeout = "";

  StreamSubscription? subs;
  StreamSubscription? _doubleSub;
  Multiplayer multi = Multiplayer();
  int curRound = 1;
  bool closedByUs = false;
  Future<DatabaseEvent>? _gameSnapshot;
  int win1Count = 0, win2Count = 0, tieCount = 0;

  // Coin Doubler state
  bool _doubleUsed = false;
  bool _doubleDialogShowing = false;

  // Sudden Death state
  int _consecutiveDraws = 0;
  bool _suddenDeathShowing = false;

  // Prevents onWin from double-firing within the same round
  bool _roundOver = false;

  @override
  void initState() {
    super.initState();

    if (widget.imagex!.endsWith('.png')) {
      widget.imagex = widget.imagex!.split('.png').first.split('images/').last;
    }
    if (widget.imageo!.endsWith('.png')) {
      widget.imageo = widget.imageo!.split('.png').first.split('images/').last;
    }

    winVar1 = null;
    winVar2 = null;
    winVar3 = null;
    winGame = null;

    yourTry = widget.firstTry;
    _gameRef = _ins.ref().child("Game");
    _userRef = _ins.ref().child("users");

    _gameSnapshot = _gameRef.child(widget.gameKey).once();

    initializeButtons();
    getGamebuttons();

    _ins
        .ref()
        .child("Game")
        .child(widget.gameKey)
        .update({"status": "running"});

    getFieldValue("profilePic", (e) => profilePic = e, (e) => profilePic = e);
    getFieldValue("username", (e) => username = e, (e) => username = e);

    _ins.ref().child("Game").child(widget.gameKey).child("suddenDeath")
        .onValue.listen((ev) {
      if (ev.snapshot.value == true && mounted && !_suddenDeathShowing) {
        _triggerSuddenDeath();
      }
    });

    _doubleSub = _ins
        .ref()
        .child("Game")
        .child(widget.gameKey)
        .child("doubleRequest")
        .onValue
        .listen((ev) {
      final requestFrom = ev.snapshot.value as String?;
      if (requestFrom == null || requestFrom == _auth.currentUser!.uid) return;
      if (_doubleDialogShowing || !mounted) return;
      _doubleDialogShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: secondaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: secondarySelectedColor.withValues(alpha: 0.4), width: 1.5),
          ),
          title: Text('Double Down?', style: TextStyle(color: inkColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          content: Text(
            'Opponent wants to double the stake!\nWinner gets 4× the entry fee.',
            style: TextStyle(color: ink2Color),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                _doubleDialogShowing = false;
                final feeSnap = await _ins.ref().child("Game").child(widget.gameKey).child("entryFee").once();
                final fee = (feeSnap.snapshot.value as int? ?? 0);
                await _ins.ref().child("Game").child(widget.gameKey).update({
                  "entryFee": fee * 2,
                  "doubleRequest": null,
                });
                if (mounted) setState(() => _doubleUsed = true);
                utils.setSnackbar(context, '🔥 Stake doubled! Winner takes 4×');
              },
              child: Text('Accept 🔥', style: TextStyle(color: secondarySelectedColor, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                _doubleDialogShowing = false;
                await _ins.ref().child("Game").child(widget.gameKey).update({"doubleRequest": null});
              },
              child: Text('Decline', style: TextStyle(color: ink2Color)),
            ),
          ],
        ),
      ).then((_) => _doubleDialogShowing = false);
    });

    Multiplayer.updateLocalList(widget.gameKey, _ins, (ev) {
      final idx = int.parse(ev.snapshot.key.trim());
      final incoming = ev.snapshot.value;
      if (incoming == null) return;
      final incomingMap = Map<String, dynamic>.from(incoming as Map);

      // If we already set this button locally (optimistic update), skip the
      // extra setState — the UI is already correct, no rebuild needed.
      final alreadySet = buttons[idx] != null &&
          buttons[idx]['state'] == incomingMap['state'] &&
          buttons[idx]['player'] == incomingMap['player'];

      buttons[idx] = incomingMap;
      status();

      if (!alreadySet && mounted) {
        music.play(dice);
        setState(() {});
      }
    });

    getuserDetails();
    gameStatusListener();
  }

  void initializeButtons() {
    if (widget.matrixSize == "Five") {
      buttons = new Map<int, dynamic>.from(utils.gameButtonsFive);
      buttons = copyDeepMap(utils.gameButtonsFive);
    } else if (widget.matrixSize == "Four") {
      buttons = new Map<int, dynamic>.from(utils.gameButtonsFour);
      buttons = copyDeepMap(utils.gameButtonsFour);
    } else {
      buttons = new Map<int, dynamic>.from(utils.gameButtons);
      buttons = copyDeepMap(utils.gameButtons);
    }
  }

  getFieldValue(
      String fieldName,
      void Function(dynamic count) callback,
      void Function(dynamic count) update,
      ) async {
    var init;
    try {
      var ins = GetUserInfo();
      init = await ins.getFieldValue(fieldName);
      if (mounted) {
        setState(() {
          callback(init);
        });
      }

      ins.detectChange(fieldName, (val) {
        if (mounted) {
          setState(() {
            update(val);
          });
        }
      });
    } catch (err) {}
  }

  Future<void> getuserDetails() async {
    await getPlayerValue();
  }

  Map copyDeepMap(Map map) {
    Map newMap = {};

    map.forEach((key, value) {
      newMap[key] = (value is Map) ? copyDeepMap(value) : value;
    });

    return newMap;
  }

  void status() {
    List<dynamic> winningConditionToUse;

    switch (widget.matrixSize) {
      case "Three":
        winningConditionToUse = utils.winningCondition;
        break;
      case "Four":
        winningConditionToUse = utils.winningConditionFour;
        break;
      case "Five":
        winningConditionToUse = utils.winningConditionFive;
        break;
      default:
        throw Exception("Invalid matrix size");
    }

    Multiplayer.checkStatus(
      context,
      widget.gameKey,
      buttons,
      widget.matrixSize,
      gameStatus,
      onWin: (int currentIndex) async {
        // Guard: only the first caller per round proceeds.
        if (_roundOver || !mounted) return;
        _roundOver = true;

        // Use the winner's actual slot from buttons (not playerValue which may
        // have already been updated by a concurrent 'try' change event).
        final winnerSlot =
            buttons[winningConditionToUse[currentIndex][1]]["player"] as String;

        uid = await getUidByPlayer(winnerSlot);
        if (!mounted) return;

        final kUid = _auth.currentUser!.uid;
        final iWon = uid == kUid;
        winGame = iWon;

        // Update local win counts immediately on both sides.
        if (winnerSlot == "player1") {
          win1Count++;
        } else {
          win2Count++;
        }

        iWon ? music.play(wingame) : music.play(losegame);
        _stopTimer();
        if (mounted) setState(() {});

        // Winner atomically records the win in Firebase — fire-and-forget.
        // The game-end sequence no longer depends on this write succeeding.
        if (iWon) {
          _consecutiveDraws = 0;
          _gameRef
              .child(widget.gameKey)
              .child(winnerSlot)
              .child("won")
              .runTransaction(
                  (v) => Transaction.success((v as int? ?? 0) + 1))
              .ignore();
        }

        // Both sides drive the round-end sequence after the 3s win animation.
        // This removes the dependency on the Firebase 'player1/player2' event
        // that was previously the only trigger — if the write above failed,
        // both devices would be stuck indefinitely.
        final capturedUid = uid!;
        Timer(const Duration(seconds: 3), () async {
          if (!mounted) return;
          winVar1 = null;
          winVar2 = null;
          winVar3 = null;
          winGame = null;

          final r = await _gameRef
              .child(widget.gameKey)
              .child("entryFee")
              .once();
          if (!mounted) return;
          final entryFee = int.parse(r.snapshot.value.toString());

          if (curRound != widget.round) {
            // Reset board in Firebase for the next round.
            initializeButtons();
            for (int i = 0; i < buttons.length; i++) {
              _gameRef
                  .child(widget.gameKey)
                  .child("buttons")
                  .child("$i")
                  .update({"player": "0", "state": ""}).catchError((_) {});
            }
          }

          if (widget.round == curRound) {
            // ── Final round ──────────────────────────────────────────
            _gameRef
                .child(widget.gameKey)
                .update({"status": "closed"});
            closedByUs = true;
            if (mounted) setState(() {});

            DatabaseEvent playersData =
                await _gameRef.child(widget.gameKey).once();
            if (!mounted) return;

            String winnerId, looserId;
            if (win1Count > win2Count) {
              winnerId = (playersData.snapshot.value
                  as Map)["player1"]["id"] as String;
              looserId = (playersData.snapshot.value
                  as Map)["player2"]["id"] as String;
            } else if (win2Count > win1Count) {
              winnerId = (playersData.snapshot.value
                  as Map)["player2"]["id"] as String;
              looserId = (playersData.snapshot.value
                  as Map)["player1"]["id"] as String;
            } else {
              winnerId = "";
              looserId = "";
            }

            if (winnerId.isEmpty) {
              await updateTieCoin(_auth.currentUser!.uid, entryFee);
              Dialogue().tieMultiplayer(context, widget.gameKey);
            } else {
              final winText = winnerId == kUid
                  ? utils.getTranslated(context, "priceWin")
                  : utils.getTranslated(context, "youLose");
              final point = winnerId == kUid
                  ? (entryFee * 2).toString()
                  : entryFee.toString();
              Dialogue.winner(
                context,
                winnerId == kUid
                    ? username
                    : utils.limitChar(widget.oppornentName, 15),
                winnerId == kUid ? profilePic : widget.oppornentPic,
                winText,
                point,
                widget.gameKey,
              );
              if (winnerId == kUid) {
                History().update(
                    uid: winnerId,
                    date: DateTime.now().toString(),
                    gameid: widget.gameKey,
                    gotcoin: entryFee * 2,
                    oppornentId: looserId,
                    status: "Won",
                    type: "GAME");
                History().update(
                    uid: looserId,
                    date: DateTime.now().toString(),
                    gameid: widget.gameKey,
                    gotcoin: -entryFee,
                    oppornentId: winnerId,
                    status: "Lose",
                    type: "GAME");
                await Future.wait([
                  multi.updateMatchResult(winnerId, MatchResult.win),
                  multi.updateMatchResult(looserId, MatchResult.lose),
                  updateCoin(winnerId, entryFee),
                ]);
              }
            }
            if (widget.gameKey != null) {
              Dialogue.removeChild("Game", widget.gameKey);
            }
          } else if (win1Count > (widget.round / 2) ||
              win2Count > (widget.round / 2)) {
            // ── Early decisive win ───────────────────────────────────
            final winnerId =
                win1Count > win2Count ? player1Id! : player2Id!;
            final looserId =
                winnerId == player1Id ? player2Id! : player1Id!;

            _gameRef
                .child(widget.gameKey)
                .update({"status": "closed"});
            closedByUs = true;
            if (mounted) setState(() {});

            final winText = winnerId == kUid
                ? utils.getTranslated(context, "priceWin")
                : utils.getTranslated(context, "youLose");
            final point = winnerId == kUid
                ? (entryFee * 2).toString()
                : entryFee.toString();
            Dialogue.winner(
              context,
              winnerId == kUid
                  ? username
                  : utils.limitChar(widget.oppornentName, 15),
              winnerId == kUid ? profilePic : widget.oppornentPic,
              winText,
              point,
              widget.gameKey,
            );
            if (winnerId == kUid) {
              History().update(
                  uid: winnerId,
                  date: DateTime.now().toString(),
                  gameid: widget.gameKey,
                  gotcoin: entryFee * 2,
                  oppornentId: looserId,
                  status: "Won",
                  type: "GAME");
              History().update(
                  uid: looserId,
                  date: DateTime.now().toString(),
                  gameid: widget.gameKey,
                  gotcoin: -entryFee,
                  oppornentId: winnerId,
                  status: "Lose",
                  type: "GAME");
              await Future.wait([
                multi.updateMatchResult(winnerId, MatchResult.win),
                multi.updateMatchResult(looserId, MatchResult.lose),
                updateCoin(winnerId, entryFee),
              ]);
            }
            if (widget.gameKey != null) {
              Dialogue.removeChild("Game", widget.gameKey);
            }
          } else {
            // ── More rounds to play ───────────────────────────────────
            _stopTimer();
            nextRoundDialog(
              capturedUid == kUid
                  ? "$username won"
                  : "${utils.limitChar(widget.oppornentName, 15)} won",
            );
          }
        });
      },
      onTie: (i) {
        tieCount += 1;
        _consecutiveDraws++;
        final newSuddenDeath = _consecutiveDraws >= 2;
        _ins.ref().child("Game").child(widget.gameKey).update({
          "tie": tieCount,
          "consecutiveDraws": _consecutiveDraws,
          if (newSuddenDeath) "suddenDeath": true,
        });
        if (newSuddenDeath && !_suddenDeathShowing && mounted) {
          _triggerSuddenDeath();
        }
      },
    );
  }

  void playGame(int i) async {
    if (buttons[i]["state"] != "") return;
    if (yourTry != true) return;
    if (winVar1 != null || winVar2 != null || winVar3 != null || winGame != null) return;

    final currentPlayerValue = playerValue;
    final currentGameKey = widget.gameKey;
    final nextTry = currentPlayerValue == "player1" ? "player2" : "player1";

    // Optimistic local update — instant visual response before Firebase confirms.
    buttons[i]["state"] = "true";
    buttons[i]["player"] = "$currentPlayerValue";
    yourTry = false;
    if (mounted) setState(() {});

    music.play(dice);

    try {
      // Single atomic write: button + turn switch in one round trip.
      await _gameRef.child(currentGameKey).update({
        "buttons/$i/player": currentPlayerValue,
        "buttons/$i/state": "true",
        "try": nextTry,
      });
    } catch (e) {
      if (mounted) {
        buttons[i]["state"] = "";
        buttons[i]["player"] = "0";
        yourTry = true;
        setState(() {});
        utils.setSnackbar(context, "Network error! Please try again.");
      }
    }
  }

  Future<void> getPlayerValue() async {
    final results = await Future.wait([
      _gameRef.child(widget.gameKey).once(),
      _gameRef.child(widget.gameKey).child("player1").child("id").once(),
      _gameRef.child(widget.gameKey).child("player2").child("id").once(),
    ]);

    final find = results[0];
    final player1snap = results[1];
    final player2snap = results[2];

    String tryy = (find.snapshot.value as Map)["try"];

    DatabaseEvent uid = await _gameRef.child(widget.gameKey).child(tryy).once();

    if ((uid.snapshot.value as Map)["id"] == _auth.currentUser!.uid) {
      yourTry = true;
    } else {
      yourTry = false;
    }

    player1Id = player1snap.snapshot.value.toString();
    player2Id = player2snap.snapshot.value.toString();

    _startTimer();
    playerValue = tryy;
  }

  Future<void> updateCoin(String winnerId, int entryFee) async {
    await _userRef.child(winnerId).child("coin").runTransaction((currentValue) {
      return Transaction.success((currentValue as int? ?? 0) + (entryFee * 2));
    });
  }

  Future<void> updateTieCoin(String uid, int entryFee) async {
    await _userRef.child(uid).child("coin").runTransaction((currentValue) {
      return Transaction.success((currentValue as int? ?? 0) + entryFee);
    });
  }

  gameStatusListener() {
    subs = _ins
        .ref()
        .child("Game")
        .child(widget.gameKey)
        .onChildChanged
        .listen((event) async {
      if (event.snapshot.key == 'try') {
        DatabaseEvent uid2 = await _gameRef
            .child(widget.gameKey)
            .child(event.snapshot.value.toString())
            .child("id")
            .once();

        if (uid2.snapshot.value == _auth.currentUser!.uid) {
          yourTry = true;
        } else {
          yourTry = false;
        }
        _startTimer();
        playerValue = event.snapshot.value == "player1" ? "player1" : "player2";
        if (mounted) setState(() {});
      }
      if (event.snapshot.key == "status") {
        final gameSnap = await _gameRef.child(widget.gameKey).once();
        final gameData = gameSnap.snapshot.value as Map;
        int? entryfee = gameData["entryFee"] as int?;
        String? player1 = (gameData["player1"] as Map)["id"] as String?;
        String? player2 = (gameData["player2"] as Map)["id"] as String?;

        if (event.snapshot.value == "closed" && mounted) {
          Dialogue d = Dialogue();
          _stopTimer();

          await Future.delayed(Duration(seconds: 1));

          if (mounted && closedByUs == false) {
            await Future.wait([
              multi.updateMatchResult(_auth.currentUser!.uid, MatchResult.win),
              updateCoin(_auth.currentUser!.uid, entryfee!),
            ]);
            History().update(
                uid: FirebaseAuth.instance.currentUser!.uid,
                date: DateTime.now().toString(),
                gameid: widget.gameKey,
                gotcoin: entryfee * 2,
                oppornentId:
                player1 == _auth.currentUser!.uid ? player2 : player1,
                status: "Opponent disconnect",
                type: "OD");
            d.oppornentDisconnect(context, entryfee, widget.gameKey);
          }
          if (widget.gameKey != null) {
            Dialogue.removeChild("Game", widget.gameKey);
          }
        }
      }

      // player1/player2 'won' change — handled entirely by onWin() on both sides.
      // Removed: delayed Firebase writes would re-trigger this after _roundOver
      // reset, causing a second timer + dialog mid next-round (the stuck bug).
      if (event.snapshot.key == "tie") {
        if (widget.round == curRound) {
          DatabaseEvent idAndWinCountofPlayer1 = await _ins
              .ref()
              .child("Game")
              .child(widget.gameKey)
              .child("player1")
              .once();

          DatabaseEvent idAndWinCountofPlayer2 = await _ins
              .ref()
              .child("Game")
              .child(widget.gameKey)
              .child("player2")
              .once();

          DatabaseEvent entryFee = await FirebaseDatabase.instance
              .ref()
              .child("Game")
              .child(widget.gameKey)
              .child("entryFee")
              .once();

          var winCountOfPlayer1 =
          (idAndWinCountofPlayer1.snapshot.value as Map)['won'];
          var winCountOfPlayer2 =
          (idAndWinCountofPlayer2.snapshot.value as Map)['won'];
          var idOfPlayer1 =
          (idAndWinCountofPlayer1.snapshot.value as Map)['id'];
          var idOfPlayer2 =
          (idAndWinCountofPlayer2.snapshot.value as Map)['id'];

          var winnerId;
          String winText, earnedCoin;

          if (winCountOfPlayer1 > winCountOfPlayer2) {
            winnerId = idOfPlayer1;
          } else if (winCountOfPlayer2 > winCountOfPlayer1) {
            winnerId = idOfPlayer2;
          } else {
            winnerId = "";
          }

          winText = winnerId == _auth.currentUser!.uid
              ? utils.getTranslated(context, "priceWin")
              : utils.getTranslated(context, "youLose");
          earnedCoin = winnerId == _auth.currentUser!.uid
              ? (int.parse(entryFee.snapshot.value.toString()) * 2).toString()
              : entryFee.snapshot.value.toString();

          _gameRef.child(widget.gameKey).update({"status": "closed"});
          closedByUs = true;
          _stopTimer();
          setState(() {});

          if (winnerId == "") {
            final d = Dialogue();
            d.tieMultiplayer(context, widget.gameKey);
            await updateTieCoin(_auth.currentUser!.uid, int.parse(entryFee.snapshot.value.toString()));

            var _tempData = (await _gameSnapshot)!.snapshot.value;
            if (idOfPlayer1 == _auth.currentUser!.uid) {
              History().update(
                  uid: idOfPlayer2,
                  date: DateTime.now().toString(),
                  gameid: widget.gameKey,
                  gotcoin: (_tempData as Map)["entryFee"],
                  oppornentId: idOfPlayer1,
                  status: "Tie",
                  type: "TIE GAME");

              History().update(
                  uid: idOfPlayer1,
                  date: DateTime.now().toString(),
                  gameid: widget.gameKey,
                  gotcoin: _tempData["entryFee"],
                  oppornentId: idOfPlayer2,
                  status: "Tie",
                  type: "TIE GAME");

              await Future.wait([
                multi.updateMatchResult(idOfPlayer1, MatchResult.tie),
                multi.updateMatchResult(idOfPlayer2, MatchResult.tie),
              ]);
            }
          } else {
            var looserId =
            (winnerId == idOfPlayer1) ? idOfPlayer2 : idOfPlayer1;

            Dialogue.winner(
                context,
                winnerId == _auth.currentUser!.uid
                    ? username
                    : utils.limitChar(widget.oppornentName, 15),
                winnerId == _auth.currentUser!.uid
                    ? profilePic
                    : widget.oppornentPic,
                winText,
                earnedCoin,
                widget.gameKey);

            var _tempData = (await _gameSnapshot)!.snapshot.value;

            if (winnerId == _auth.currentUser!.uid) {
              History().update(
                  uid: winnerId,
                  date: DateTime.now().toString(),
                  gameid: widget.gameKey,
                  gotcoin: (_tempData as Map)["entryFee"] * 2,
                  oppornentId: looserId,
                  status: "Won",
                  type: "GAME");

              History().update(
                  uid: looserId,
                  date: DateTime.now().toString(),
                  gameid: widget.gameKey,
                  gotcoin: -_tempData["entryFee"],
                  oppornentId: winnerId,
                  status: "Lose",
                  type: "GAME");

              await Future.wait([
                multi.updateMatchResult(winnerId, MatchResult.win),
                multi.updateMatchResult(looserId, MatchResult.lose),
                updateCoin(winnerId, int.parse(entryFee.snapshot.value.toString())),
              ]);
            }
          }

          if (widget.gameKey != null) {
            Dialogue.removeChild("Game", widget.gameKey);
          }
        }

        if (widget.round != curRound && curRound < widget.round) {
          _stopTimer();
          for (int i = 0; i < buttons.length; i++) {
            _gameRef
                .child(widget.gameKey)
                .child("buttons")
                .child("$i")
                .update({"player": "0", "state": ""});
          }
          nextRoundDialog(
            utils.getTranslated(context, "tie"),
          );
        }

        _stopTimer();
      }
    });
  }

  void nextRoundDialog(String subtitle) {
    itemSize = 90;
    playcountdown = 3;

    playclocktimer?.cancel();

    playclocktimer = Timer.periodic(Duration(seconds: 1), (Timer t) {
      if (mounted && dialogState != null) {
        dialogState!(() {
          if (playcountdown > 0) playcountdown--;
        });
      }

      if (playcountdown <= 0) {
        t.cancel();
        playclocktimer = null;

        if (mounted) {
          _startTimer();
          _roundOver = false; // allow next round's win to be detected
          curRound = curRound + 1;

          if (widget.matrixSize == "Three") {
            buttons = copyDeepMap(utils.gameButtons);
          } else if (widget.matrixSize == "Four") {
            buttons = copyDeepMap(utils.gameButtonsFour);
          } else if (widget.matrixSize == "Five") {
            buttons = copyDeepMap(utils.gameButtonsFive);
          }

          setState(() {
            winVar1 = null;
            winVar2 = null;
            winVar3 = null;
            winGame = null;
            istimerCompleted = false;
          });

          if (Navigator.canPop(context)) Navigator.pop(context);
        }
      }
    });

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(builder: (context, setStateDialog) {
          dialogState = setStateDialog;
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) {
                playclocktimer?.cancel();
                playclocktimer = null;
                if (Navigator.canPop(context)) Navigator.pop(context);
              }
            },
            child: AlertDialog(
                backgroundColor: bgColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20.0))),
                title: Text(utils.getTranslated(context, "nextRound"),
                    style: TextStyle(color: white),
                    textAlign: TextAlign.center),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(subtitle,
                        style: TextStyle(color: white),
                        textAlign: TextAlign.center),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: new BoxDecoration(
                          color: white,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                            child: Text(
                              playcountdown.toString(),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32),
                            )),
                      ),
                    )
                  ],
                )),
          );
        })).then((_) {
      playclocktimer?.cancel();
      playclocktimer = null;
    });
  }

  Future<String?> getUidByPlayer(String target) async {
    DatabaseEvent ref =
    await _gameRef.child(widget.gameKey).child(target).child("id").once();
    String? result = ref.snapshot.value.toString();
    return result;
  }

  returnImage(i) {
    final myXImage = widget.imagex ?? 'cross_skin';
    final myOImage = widget.imageo ?? 'circle_skin';

    if (istimerCompleted) {
      if (buttons[i]["player"] == whoseTimeout) {
        return "cross_skin";
      } else {
        return myOImage;
      }
    } else if (winVar1 != null &&
        winVar2 != null &&
        winVar3 != null &&
        winGame != null &&
        winGame! &&
        (i == winVar1 || i == winVar2 || i == winVar3))
      return "cross_skin";
    else if (winVar1 != null &&
        winVar2 != null &&
        winVar3 != null &&
        winGame != null &&
        !winGame! &&
        (i == winVar1 || i == winVar2 || i == winVar3))
      return "circle_skin";
    else if (buttons[i]["player"] == "player1" && buttons[i]["player"] != "0") {
      if (player1Id == _auth.currentUser!.uid) {
        return myXImage;
      }
      return myOImage;
    } else if (buttons[i]["player"] == "player2" &&
        buttons[i]["player"] != "0") {
      if (player2Id == _auth.currentUser!.uid) {
        return myXImage;
      }
      return myOImage;
    }
    return myXImage;
  }

  @override
  void dispose() {
    _stopTimer();
    _timerNotifier.dispose();
    playclocktimer?.cancel();
    subs?.cancel();
    _doubleSub?.cancel();
    Multiplayer.dispose();
    super.dispose();
  }

  Future<void> _triggerSuddenDeath() async {
    if (_suddenDeathShowing) return;
    _suddenDeathShowing = true;
    _stopTimer();
    await Dialogue.suddenDeath(context);
    if (!mounted) return;
    setState(() {
      _consecutiveDraws = 0;
      _suddenDeathShowing = false;
    });
    await _ins.ref().child("Game").child(widget.gameKey).update({"suddenDeath": null, "consecutiveDraws": 0});
    _startTimer();
  }

  Future<void> getGamebuttons() async {
    try {
      DatabaseEvent snap = await _gameRef.child(widget.gameKey).child("buttons").once();
      final data = snap.snapshot.value;

      if (data == null) return;

      buttons.clear();

      if (data is List) {
        for (var i = 0; i < data.length; i++) {
          if (data[i] is Map) {
            buttons[i] = copyDeepMap(data[i] as Map);
          } else {
            buttons[i] = {"player": "0", "state": ""};
          }
        }
      } else if (data is Map) {
        data.forEach((key, value) {
          buttons[int.parse(key.toString())] = copyDeepMap(value as Map);
        });
      }

      if (mounted) setState(() {});
    } catch (e) {
      initializeButtons();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    int gridSize;
    int totalCells;

    if (widget.matrixSize == "Four") {
      gridSize = 4;
      totalCells = 16;
    } else if (widget.matrixSize == "Five") {
      gridSize = 5;
      totalCells = 25;
    } else {
      gridSize = 3;
      totalCells = 9;
    }

    return PopScope(
      canPop: false,
      child: Container(
        color: bgColor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Row(
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: _timerNotifier,
                        builder: (_, secs, __) => Container(
                          width: 25,
                          height: 25,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: secs <= 10
                                  ? Colors.red
                                  : secondarySelectedColor,
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$secs',
                              style: TextStyle(
                                color: secs <= 10 ? Colors.red : inkColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8.0),
                        child: Text(yourTry!
                            ? utils.getTranslated(context, "yourMove")
                            : utils.getTranslated(context, "opponentMove")),
                      )
                    ],
                  ),
                  Spacer(),
                  if (!_doubleUsed)
                    GestureDetector(
                      onTap: () async {
                        setState(() => _doubleUsed = true);
                        await _ins.ref().child("Game").child(widget.gameKey).update({
                          "doubleRequest": _auth.currentUser!.uid,
                        });
                        utils.setSnackbar(context, 'Double request sent! Waiting for opponent…');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: xColor,
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('2×', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 3),
                          Icon(Icons.bolt_rounded, color: Colors.white, size: 14),
                        ]),
                      ),
                    ),
                  IconButton(
                      onPressed: () async {
                        showDialog(
                            context: context,
                            builder: (context) {
                              var color = secondaryColor;
                              return Alert(
                                title: Text(
                                  utils.getTranslated(context, "aleart"),
                                  style: TextStyle(color: inkColor),
                                ),
                                isMultipleAction: true,
                                defaultActionButtonName:
                                utils.getTranslated(context, "yes"),
                                onTapActionButton: () {},
                                content: Text(
                                  utils.getTranslated(context, "areYouSure"),
                                  style: TextStyle(color: white),
                                ),
                                multipleAction: [
                                  TextButton(
                                      style: ButtonStyle(
                                          backgroundColor:
                                          WidgetStateProperty.all(color)),
                                      onPressed: () async {
                                        music.play(click);

                                        _gameRef.child(widget.gameKey).update(
                                            {"status": "closed"}).then((value) {
                                          closedByUs = true;
                                          setState(() {});
                                        });
                                        var snap = await _gameRef
                                            .child(widget.gameKey)
                                            .once();
                                        var player1snap = await _gameRef
                                            .child(widget.gameKey)
                                            .child("player1")
                                            .child("id")
                                            .once();
                                        var player2snap = await _gameRef
                                            .child(widget.gameKey)
                                            .child("player2")
                                            .child("id")
                                            .once();
                                        History().update(
                                            uid: FirebaseAuth
                                                .instance.currentUser!.uid,
                                            date: DateTime.now().toString(),
                                            gameid: widget.gameKey,
                                            gotcoin: -(snap.snapshot.value
                                            as Map)["entryFee"],
                                            oppornentId: player1snap
                                                .snapshot.value ==
                                                FirebaseAuth.instance
                                                    .currentUser!.uid
                                                ? player2snap.snapshot.value
                                                : player1snap.snapshot.value,
                                            status: "Closed Game",
                                            type: "CLOSEDGAME");

                                        music.play(click);

                                        multi.updateMatchResult(
                                            _auth.currentUser!.uid,
                                            MatchResult.lose);

                                        Navigator.popUntil(context,
                                            ModalRoute.withName("/home"));
                                      },
                                      child: Text(
                                          utils.getTranslated(context, "yes"),
                                          style: TextStyle(color: white))),
                                  TextButton(
                                      style: ButtonStyle(
                                          backgroundColor:
                                          WidgetStateProperty.all(color)),
                                      onPressed: () async {
                                        music.play(click);

                                        if (widget.gameKey != null) {
                                          Dialogue.removeChild(
                                              "Game", widget.gameKey);
                                        }
                                        Navigator.pop(context);
                                      },
                                      child: Text(
                                          utils.getTranslated(context, "no"),
                                          style: TextStyle(color: white)))
                                ],
                              );
                            });
                      },
                      icon: Icon(
                        Icons.logout,
                        color: white,
                      ))
                ],
              ),
            ),
            Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28.0),
                  child: Text(
                    "${utils.getTranslated(context, "roundLbl")} $curRound",
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall!
                        .copyWith(color: inkColor, fontWeight: FontWeight.bold),
                  ),
                )),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: Center(
                  child: Builder(builder: (context) {
                    // Compute once — not inside the item builder.
                    final cellPad = MediaQuery.of(context).size.width * 0.05;
                    return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridSize,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10),
                    itemCount: totalCells,
                    itemBuilder: (context, i) {
                      final isEmpty = buttons[i] == null || buttons[i]['state'] == "";
                      return RepaintBoundary(
                        child: GestureDetector(
                        onTap: () {
                          if (buttons[i] != null &&
                              (buttons[i]['state'] == '' ||
                                  buttons[i]['state'] == null) &&
                              (winVar1 == null &&
                                  winVar2 == null &&
                                  winVar3 == null &&
                                  winGame == null)) {
                            if (yourTry == true) {
                              playGame(i);
                            }
                          }
                        },
                        child: Stack(fit: StackFit.expand, children: [
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              margin: const EdgeInsets.only(
                                left: 2,
                                right: 2,
                                top: 30,
                              ),
                              decoration: const BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white54,
                                    offset: Offset(0, 4),
                                    spreadRadius: 1.5,
                                    blurRadius: 7,
                                  ),
                                ],
                                borderRadius: BorderRadius.all(Radius.circular(40)),
                              ),
                            ),
                          ),
                          getSvgImage(imageName: 'grid_box', fit: BoxFit.fill),
                          isEmpty
                              ? const SizedBox()
                              : Padding(
                            padding: EdgeInsets.all(cellPad),
                            child: getSvgImage(
                              imageName: returnImage(i),
                              height: double.maxFinite,
                              width: double.maxFinite,
                              fit: BoxFit.fill,
                            ),
                          ),
                        ]),
                      ));
                    },
                  );
                  }),
                ),
              ),
            ),
            Container(
              width: MediaQuery.of(context).size.width,
              child: Padding(
                padding:
                const EdgeInsets.only(left: 20.0, right: 20, bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: secondaryColor,
                          backgroundImage: profilePic == null
                              ? null
                              : NetworkImage(profilePic!),
                          radius: 25,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "${utils.getTranslated(context, "sign")} :",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(color: inkColor),
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: true,
                                  ),
                                  getSvgImage(
                                    imageName: widget.imagex!,
                                    height: 12,
                                    imageColor: secondarySelectedColor,
                                  )
                                ],
                              ),
                              Text(
                                "${utils.limitChar(username ?? '-', 7)}",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .copyWith(color: inkColor),
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                              ),
                              Text(
                                _auth.currentUser!.uid == player1Id
                                    ? "${utils.getTranslated(context, "win")} : $win1Count/${widget.round}"
                                    : "${utils.getTranslated(context, "win")} : $win2Count/${widget.round}",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .copyWith(color: inkColor),
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          getSvgImage(
                              imageName: "vs_small", width: 22, height: 21),
                          Text(
                            "${utils.getTranslated(context, "draw")} : $tieCount/${widget.round}",
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .copyWith(color: inkColor),
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                getSvgImage(
                                  imageName: widget.imageo!,
                                  height: 12,
                                ),
                                Text(
                                  "  : ${utils.getTranslated(context, "sign")}",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .copyWith(color: inkColor),
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: true,
                                ),
                              ],
                            ),
                            Text(
                              "${utils.limitChar(widget.oppornentName, 7)}",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(color: inkColor),
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                            ),
                            Text(
                              _auth.currentUser!.uid == player1Id
                                  ? "$win2Count/${widget.round} : ${utils.getTranslated(context, "win")}"
                                  : "$win1Count/${widget.round} : ${utils.getTranslated(context, "win")}",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(color: inkColor),
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: CircleAvatar(
                            backgroundImage: NetworkImage(
                              "${widget.oppornentPic}",
                            ),
                            radius: 25,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}