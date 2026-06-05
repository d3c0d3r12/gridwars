import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../helpers/string.dart';
import '../helpers/utils.dart';
import '../widgets/xo_logo.dart';
import '../functions/dialoges.dart';
import '../functions/findGame.dart';
import '../functions/getCoin.dart';
import 'multiplayer.dart';
import 'splash.dart';

class FindingPlayerScreen extends StatefulWidget {
  final int? selected;
  final int? round;
  final String matrixSize; // Add the matrixSize parameter

  FindingPlayerScreen({this.selected, this.round, required this.matrixSize});

  @override
  _FindingPlayerScreenState createState() => _FindingPlayerScreenState();
}

class _FindingPlayerScreenState extends State<FindingPlayerScreen> {
  FirebaseAuth _auth = FirebaseAuth.instance;
  FirebaseDatabase _ins = FirebaseDatabase.instance;
  String? _profilePic;
  String? _displayName;
  String? _opporentName;
  String? _opporentPic;
  String? firstTry;
  String? opponentPlayerName;
  String? _temp = "";
  String? _createdGameKey;
  String _lobbyKey = "";
  int count = 30;
  String? gameKey = "";
  var ins = GetUserInfo();
  Timer? t, oppTimer;
  var firstuid;

  StreamSubscription<DatabaseEvent>? listen;
  final Map<String, StreamSubscription> _fieldSubs = {};
  late ValueNotifier oppositPlayerName;
  late ValueNotifier keyOfGame;
  bool canPlayGame = false;
  bool isplaying = false;
  bool canUpdateUi = false;
  bool isCoinAndCountValueUpdated = false;
  String oppMsg = findingOpp, img = "dora_findopponent", btnTxtKey = "cancel";
  String? imagex, imageo;
  late DatabaseReference _userSkinRef;

  @override
  void initState() {
    super.initState();
    oppositPlayerName = ValueNotifier("");
    keyOfGame = ValueNotifier("");

    _userSkinRef = _ins.ref().child("userSkins");

    getFieldValue("profilePic", (e) => _profilePic = e, (e) => _profilePic = e);
    getFieldValue("username", (e) => _displayName = e, (e) => _displayName = e);

    findGame();
    getImage();

    Future.delayed(const Duration(seconds: 0)).then((value) {
      opponentPlayerName = utils.getTranslated(context, "waitForOpponent");
    });
    oppTimer = Timer(const Duration(seconds: 60), () {
      setState(() {
        if (_temp != null) {
          Dialogue.removeChild("Game", _temp);
        }
        oppMsg = utils.getTranslated(context, "notFoundOpp");
        opponentPlayerName = utils.getTranslated(context, "noOpponentOnline");
        img = "dora_noopponent";
        btnTxtKey = "tryAgain";
      });
    });
  }

  void getFieldValue(
    String fieldName,
    void Function(dynamic count) callback,
    void Function(dynamic count) update,
  ) {
    GetUserInfo().getFieldValue(fieldName).then((init) {
      if (mounted) setState(() => callback(init));
    }).catchError((_) {});
    _fieldSubs[fieldName]?.cancel();
    _fieldSubs[fieldName] = GetUserInfo().detectChange(fieldName, (val) {
      if (mounted) setState(() => update(val));
    });
  }

  Future<void> getImage() async {
    DatabaseEvent userSkins =
        await _userSkinRef.child(FirebaseAuth.instance.currentUser!.uid).once();
    Map map = userSkins.snapshot.value as Map;

    map.forEach((key, value) {
      if (value["selectedStatus"] == "Active") {
        setState(() {
          imagex = value["itemx"].toString();
          imageo = value["itemo"].toString();
        });
        return;
      }
    });

    setState(() {});
  }

//get opponent user details
  oppornentDetails(String key) async {
    DatabaseEvent oppornentDetail =
        await _ins.ref().child("users").child(key).once();
    return oppornentDetail.snapshot.value;
  }

  findGame() async {
    //-- this method will create or join a game if there are any games available, then it will join; otherwise, it will create a new game
    FindGame()
      ..joinGame(widget.selected ?? 0, widget.round ?? 1, widget.matrixSize)
          .then((Map data) async {
        //-- if game created
        if (data['JoinStatus'] == JoinStatus.created) {
          _temp = data["roomKey"];
          _createdGameKey = data["roomKey"];
          _lobbyKey = data["lobbyKey"] ?? "";

          // Change listener for the created game
          listen = _ins
              .ref()
              .child("Game")
              .child(data["roomKey"])
              .onChildChanged
              .listen((DatabaseEvent ev) async {
            if (ev.snapshot.key == "status" &&
                ev.snapshot.value != "closed" &&
                ev.snapshot.value != "pending") {
              //-- update coin value oldcoin - entryamount
              if (!isCoinAndCountValueUpdated) {
                // Uncomment or implement your update logic
                // temp: await updateCoinAndCount();
                isCoinAndCountValueUpdated = true;
              }

              // Fetch opponent details
              DatabaseEvent _player2snap = await _ins
                  .ref()
                  .child("Game")
                  .child(data["roomKey"])
                  .child("player2")
                  .once();
              if (_player2snap.snapshot.value != null) {
                var _snapkey = (_player2snap.snapshot.value as Map)["id"];

                var oppornentDetail = await oppornentDetails(_snapkey);
                if (!mounted) return;
                var getFirstTry = await _ins
                    .ref()
                    .child("Game")
                    .child(data["roomKey"])
                    .once();
                if (!mounted) return;
                firstTry = (getFirstTry.snapshot.value as Map)["try"];

                var getFirstTryId = await _ins
                    .ref()
                    .child("Game")
                    .child(data["roomKey"])
                    .child(firstTry!)
                    .child("id")
                    .once();
                if (!mounted) return;
                firstuid = getFirstTryId.snapshot.value;

                // Cancel the no-opponent timer — we found one.
                oppTimer?.cancel();

                _opporentName = oppornentDetail["username"];
                oppositPlayerName.value = _opporentName;

                _opporentPic = oppornentDetail["profilePic"];
                gameKey = data["roomKey"];
                keyOfGame.value = data["roomKey"];

                oppMsg = utils.getTranslated(context, "foundOpp");
                img = "dora_oppentfind";
                btnTxtKey = "cancel";
                if (mounted) setState(() {});
              }
            }
          });
        }

        // If the player joined an existing game
        if (data['JoinStatus'] == JoinStatus.joined) {
          var details = await oppornentDetails(data["oppornentKey"]);
          if (!mounted) return;

          var getFirstTry =
              await _ins.ref().child("Game").child(data["roomKey"]).once();
          if (!mounted) return;
          firstTry = (getFirstTry.snapshot.value as Map)["try"];

          var getFirstTryId = await _ins
              .ref()
              .child("Game")
              .child(data["roomKey"])
              .child(firstTry!)
              .child("id")
              .once();
          if (!mounted) return;
          firstuid = getFirstTryId.snapshot.value;

          // Cancel the no-opponent timer — we already found one.
          oppTimer?.cancel();

          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;

          if (details != null) {
            _opporentName = details["username"];
            _opporentPic = details["profilePic"];
            gameKey = data["roomKey"];
            oppositPlayerName.value = _opporentName;
            keyOfGame.value = data["roomKey"];
          }

          setState(() {});
        }

        // If the game is still pending, attempt to find a game again
        if (data['JoinStatus'] == JoinStatus.pending) {
          findGame();
        }
      });
  }

  Future<void> updateCoinMinus() async {
    await FirebaseDatabase.instance
        .ref()
        .child("users")
        .child(_auth.currentUser!.uid)
        .child("coin")
        .runTransaction((currentValue) {
      final current = currentValue as int? ?? 0;
      return Transaction.success(current - (widget.selected ?? 0));
    });
  }

  changeScreen(context) async {
    //FindGame.disposes();

    await updateCoinMinus();

    Timer(Duration(seconds: 2), () {
      Navigator.pushReplacement(context, CupertinoPageRoute(builder: (context) {
        return MultiplayerScreen(
          oppornentName: _opporentName,
          oppornentPic: _opporentPic,
          gameKey: gameKey,
          firstTry: _auth.currentUser!.uid == firstuid,
          round: widget.round,
          imageo: imageo,
          imagex: imagex,
          matrixSize: widget.matrixSize,
        );
      }));
    });
  }

  canPlay(key) async {
    if (!mounted || key == null || key.isEmpty) return;
    var _player1 =
        await _ins.ref().child("Game").child(key).child("player1").once();
    if (!mounted) return;
    var _player2 =
        await _ins.ref().child("Game").child(key).child("player2").once();
    if (!mounted) return;

    final p1Val = _player1.snapshot.value;
    final p2Val = _player2.snapshot.value;
    if (p1Val == null || p2Val == null) { isplaying = false; return; }

    var player1 = (p1Val as Map)["id"];
    var player2 = (p2Val as Map)["id"];

    if (player1 == FirebaseAuth.instance.currentUser!.uid ||
        player2 == FirebaseAuth.instance.currentUser!.uid) {
      canUpdateUi = true;
      if (mounted) setState(() {});
      changeScreen(context);
    } else {
      canUpdateUi = false;
      isplaying = false;
      findGame();
    }
  }

  @override
  void dispose() {
    t?.cancel();
    oppTimer?.cancel();
    listen?.cancel();
    for (final sub in _fieldSubs.values) { sub.cancel(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Guard: only trigger canPlay once per session. Without this, every rebuild
    // while oppositPlayerName != '' re-calls canPlay(), pushing duplicate screens.
    if (!isplaying && oppositPlayerName.value.isNotEmpty) {
      isplaying = true;
      Future.microtask(() => canPlay(keyOfGame.value));
    }

    return PopScope(
        canPop: true,
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
        child: Scaffold(
            backgroundColor: bgColor,
            body: SafeArea(
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: surfaceColor, borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: lineColor), boxShadow: [shadowSm],
                            ),
                            child: Icon(Icons.arrow_back_rounded, color: inkColor, size: 20),
                          ),
                        ),
                        const Spacer(),
                        Text('RANKED MATCH', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: inkColor, letterSpacing: 1.5)),
                        const Spacer(),
                        const SizedBox(width: 42),
                      ]),
                    ),
                    //find opponent image
                    Expanded(
                        flex: 5,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(
                                  color: xColor.withValues(alpha: img == "dora_oppentfind" ? 0.25 : 0.10),
                                  blurRadius: 30, spreadRadius: 6,
                                )],
                              ),
                              child: const XOBattleLogo(size: 120),
                            ),
                            const SizedBox(height: 16),
                            Text(oppMsg, style: TextStyle(color: ink2Color, fontSize: 14)),
                          ],
                        )),

                    Expanded(
                      flex: 5,
                      child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        //players profile pic
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: <Widget>[
                                  Container(
                                      height: 80.0,
                                      width: 80.0,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: xSoft2, width: 2.5),
                                          color: surface2Color),
                                      child: Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: CircleAvatar(
                                              radius: 50,
                                              backgroundColor: surface2Color,
                                              backgroundImage:
                                                  _profilePic == null
                                                      ? null
                                                      : NetworkImage(
                                                          _profilePic!)))),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Text('VS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: ink3Color, letterSpacing: 2)),
                              ),
                            ),
                            Expanded(
                                flex: 4,
                                child: Column(
                                  children: [
                                    Container(
                                      height: 80.0,
                                      width: 80.0,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: oSoft2, width: 2.5),
                                          color: surface2Color),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: CircleAvatar(
                                            radius: 50,
                                            backgroundColor: surface2Color,
                                            backgroundImage: oppositPlayerName
                                                            .value !=
                                                        "" &&
                                                    canUpdateUi == true
                                                ? NetworkImage("$_opporentPic")
                                                : null,
                                            child: oppositPlayerName.value !=
                                                        "" &&
                                                    canUpdateUi == true
                                                ? null
                                                : Center(
                                                    child: Text(
                                                    "?",
                                                    style: TextStyle(
                                                        fontSize: 28,
                                                        fontWeight: FontWeight.w700,
                                                        color: ink3Color),
                                                  ))),
                                      ),
                                    ),
                                  ],
                                )),
                          ],
                        ),
                        ),
                        //players name
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                                flex: 1,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      left: 10.0, top: 10.0),
                                  child: Text(
                                    "$_displayName \n",
                                    style: TextStyle(color: inkColor, fontWeight: FontWeight.w600),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    softWrap: true,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                            SizedBox(
                              width: MediaQuery.of(context).size.width / 4.5,
                            ),
                            Expanded(
                              flex: 1,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                    right: 10.0, top: 10.0),
                                child: Text(
                                  oppositPlayerName.value != "" &&
                                          canUpdateUi == true
                                      ? "${oppositPlayerName.value} \n"
                                      : "$opponentPlayerName \n",
                                  style: TextStyle(color: inkColor, fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                          ],
                        ),

                        const SizedBox(height: 8),
                        GestureDetector(
                            child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: btnTxtKey == "tryAgain" ? xColor : surfaceColor,
                                    border: Border.all(color: btnTxtKey == "tryAgain" ? xColor : lineColor),
                                    boxShadow: [shadowSm]),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      btnTxtKey == "tryAgain"
                                          ? Icons.replay_circle_filled
                                          : Icons.cancel_outlined,
                                      color: btnTxtKey == "tryAgain" ? Colors.white : red,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      utils.getTranslated(context, btnTxtKey),
                                      style: TextStyle(
                                        color: btnTxtKey == "tryAgain" ? Colors.white : red,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                )),
                            onTap: () async {
                              if (btnTxtKey == "tryAgain") {
                                setState(() {
                                  oppMsg = utils.getTranslated(
                                      context, "findingOpp");
                                  opponentPlayerName = utils.getTranslated(
                                      context, "waitForOpponent");
                                  img = "dora_findopponent";
                                  btnTxtKey = "cancel";
                                });
                                // Cancel old listener and timer before re-searching.
                                listen?.cancel();
                                listen = null;
                                oppTimer?.cancel();
                                isplaying = false;
                                oppositPlayerName.value = "";
                                findGame();
                                oppTimer = Timer(const Duration(seconds: 60), () {
                                  if (_temp != null) {
                                    Dialogue.removeChild("Game", _temp);
                                  }
                                  setState(() {
                                    oppMsg = utils.getTranslated(
                                        context, "notFoundOpp");
                                    opponentPlayerName = utils.getTranslated(
                                        context, "noOpponentOnline");
                                    img = "dora_noopponent";
                                    btnTxtKey = utils.getTranslated(
                                        context, "tryAgain");
                                  });
                                });
                              } else if (btnTxtKey == "cancel") {
                                oppTimer?.cancel();
                                if (_createdGameKey != null && _createdGameKey!.isNotEmpty) {
                                  await FindGame().cancelWaiting(
                                    _createdGameKey!,
                                    widget.matrixSize,
                                    widget.selected ?? 0,
                                    widget.round ?? 1,
                                  );
                                  _temp = "";
                                  _createdGameKey = null;
                                  _lobbyKey = "";
                                }
                                if (mounted) Navigator.pop(context);
                              }
                            }),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  ],
                ))));
  }
}
