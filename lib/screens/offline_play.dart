import 'dart:async';
import 'dart:math';

import 'package:xobattle/functions/ai.dart';
import 'package:xobattle/widgets/xo_logo.dart';
import 'package:flutter/cupertino.dart';
import 'package:circular_countdown_timer/circular_countdown_timer.dart';
import 'package:flutter/material.dart';

import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../helpers/utils.dart';
import '../functions/dialoges.dart';
import '../functions/getCoin.dart';
import '../widgets/alert_dialogue.dart';
import 'splash.dart';

// ignore: must_be_immutable
class SinglePlayerScreenActivity extends StatefulWidget {
  String? playerSkin, doraSkin;
  final int? levelType;
  final String matrixSize;
  final int timerSeconds;

  SinglePlayerScreenActivity(
      this.playerSkin, this.doraSkin, this.levelType, this.matrixSize,
      {this.timerSeconds = 60});

  @override
  _SinglePlayerScreenActivityState createState() =>
      _SinglePlayerScreenActivityState();
}

class _SinglePlayerScreenActivityState
    extends State<SinglePlayerScreenActivity> {
  CountDownController _countDownPlayer = CountDownController();

  // Custom reliable timer (replaces buggy circular_countdown_timer logic)
  Timer? _gameTimer;
  final _timerNotifier = ValueNotifier<int>(0);

  void _startTimer() {
    _stopTimer();
    _timerNotifier.value = widget.timerSeconds;
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

  void _onTimerExpired() {
    if (gameStatus != "started") return;
    // Only penalize human when it's their turn
    if (currentMove == utils.getTranslated(context, "yourTurn")) {
      gameStatus = "over";
      music.play(losegame);
      Dialogue.winner(context, utils.getTranslated(context, "dora"), "", "", "", "");
      setState(() {});
    } else {
      // AI's turn - just restart timer, don't penalize human
      _startTimer();
    }
  }

  String? player;
  TicTacToeAI doraAI = TicTacToeAI();
  int _consecutiveDraws = 0;

  String gameStatus = "";

  String? winner = "0";
  int calledCount = 0;
  int tieCalled = 0;
  Utils u = Utils();
  Map buttons = Map();
  late Random rnd;
  String? currentMove, _profilePic = "", _username = "";

  void check() {
    // Check for 3x3 matrix
    if (widget.matrixSize == "Three") {
      for (var i = 0; i < buttons.length; i++) {
        for (var j = 0; j < utils.winningCondition.length; j++) {
          if (buttons[utils.winningCondition[j][0]]["player"] ==
                  buttons[utils.winningCondition[j][1]]["player"] &&
              buttons[utils.winningCondition[j][1]]["player"] ==
                  buttons[utils.winningCondition[j][2]]["player"] &&
              buttons[utils.winningCondition[j][1]]["player"] != "0") {
            // Declare winner for 3x3
            winner = buttons[utils.winningCondition[j][1]]["player"];
            gameStatus = "over";
            calledCount += 1;
            setState(() {});
          }
        }
      }

      checkTie(9);

      if (gameStatus == "over" && mounted && winner != "0") {
        handleGameOver(winner!, 9);
      }
    }
    // Check for 4x4 matrix
    else if (widget.matrixSize == "Four") {
      for (var i = 0; i < buttons.length; i++) {
        for (var j = 0; j < utils.winningConditionFour.length; j++) {
          if (buttons[utils.winningConditionFour[j][0]]["player"] ==
                  buttons[utils.winningConditionFour[j][1]]["player"] &&
              buttons[utils.winningConditionFour[j][1]]["player"] ==
                  buttons[utils.winningConditionFour[j][2]]["player"] &&
              buttons[utils.winningConditionFour[j][2]]["player"] ==
                  buttons[utils.winningConditionFour[j][3]]["player"] &&
              buttons[utils.winningConditionFour[j][1]]["player"] != "0") {
            // Declare winner for 4x4
            winner = buttons[utils.winningConditionFour[j][1]]["player"];
            gameStatus = "over";
            calledCount += 1;
            setState(() {});
          }
        }
      }

      checkTie(16);

      if (gameStatus == "over" && mounted && winner != "0") {
        handleGameOver(winner!, 16);
      }
    }

    // Check for 5x5 matrix
    else if (widget.matrixSize == "Five") {
      for (var j = 0; j < utils.winningConditionFive.length; j++) {
        if (buttons[utils.winningConditionFive[j][0]]["player"] ==
                buttons[utils.winningConditionFive[j][1]]["player"] &&
            buttons[utils.winningConditionFive[j][1]]["player"] ==
                buttons[utils.winningConditionFive[j][2]]["player"] &&
            buttons[utils.winningConditionFive[j][2]]["player"] ==
                buttons[utils.winningConditionFive[j][3]]["player"] &&
            buttons[utils.winningConditionFive[j][3]]["player"] ==
                buttons[utils.winningConditionFive[j][4]]["player"] &&
            buttons[utils.winningConditionFive[j][1]]["player"] != "0") {
          // Declare winner for 5x5
          winner = buttons[utils.winningConditionFive[j][1]]["player"];
          gameStatus = "over";
          calledCount += 1;
          setState(() {});
          break;
        }
      }

      checkTie(25);

      if (gameStatus == "over" && mounted && winner != "0") {
        handleGameOver(winner!, 25);
      }
    }
  }

// Function to check for a tie based on the matrix size
  void checkTie(int totalBoxes) {
    int _count = 0;
    for (var k = 0; k < buttons.length; k++) {
      if (buttons[k]["state"] != "" && winner == "0") {
        _count++;
      }
    }

    // If all boxes are filled and no winner, declare a tie
    if (_count == totalBoxes && winner == "0") {
      gameStatus = "tie";
      _stopTimer();
      tieCalled += 1;
      _consecutiveDraws++;
      if (mounted) setState(() {});

      music.play(tiegame);

      Future.delayed(const Duration(seconds: 1)).then((_) async {
        if (!mounted || winner != "0" || gameStatus != "tie") return;
        _countDownPlayer.pause();

        if (_consecutiveDraws >= 2) {
          // Trigger Sudden Death
          await Dialogue.suddenDeath(context);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            CupertinoPageRoute(
              builder: (_) => SinglePlayerScreenActivity(
                widget.playerSkin,
                widget.doraSkin,
                widget.levelType,
                widget.matrixSize,
                timerSeconds: blitzCountdown,
              ),
            ),
          );
        } else {
          Dialogue().tie(context, "Singleplayer", "", "", widget.playerSkin,
              widget.doraSkin, widget.levelType, widget.matrixSize);
          setState(() {});
        }
      });
    }
  }

  void handleGameOver(String winner, int totalBoxes) {
    _stopTimer(); // Stop custom timer
    winner == "1" ? music.play(wingame) : music.play(losegame);
    _countDownPlayer.pause();
    setState(() {});

    Dialogue.winner(
      context,
      winner == "1" ? _username : utils.getTranslated(context, "dora"),
      winner == "1" ? _profilePic : "",
      "",
      "",
      "",
    );
  }

  playGame([i]) async {
    var seconds = 1;
    rnd = Random();
    seconds = rnd.nextInt(3) + 1; // AI delay: 0.5s to 1.5s (was up to 14s!)

    if (gameStatus == "started") {
      currentMove = player == "X"
          ? utils.getTranslated(context, "doraTurn")
          : utils.getTranslated(context, "yourTurn");

      setState(() {});
      if (gameStatus == "started") {
        check();
      }

      if (player == "X") {
        await Future.delayed(Duration(milliseconds: seconds * 500))
            .then((_) async {
          if (!mounted) return;

          final int boardSize = widget.matrixSize == "Four"
              ? 4
              : widget.matrixSize == "Five"
                  ? 5
                  : 3;
          final int totalCells = boardSize * boardSize;

          final List currentBoardState = List.generate(totalCells, (i) {
            if (buttons[i]["state"] == "") return i;
            return buttons[i]["player"] == "2" ? "X" : "O";
          });

          final int r = doraAI.getBestMove(
              currentBoardState, boardSize, widget.levelType ?? 0);

          if (r >= 0 && r < totalCells && buttons[r]["state"] == "") {
            music.play(dice);

            buttons[r]["state"] = "true";
            buttons[r]["player"] = "2";

            _countDownPlayer.restart(duration: widget.timerSeconds); // Visual timer
            _startTimer(); // Custom reliable timer starts for human's turn
            currentMove = utils.getTranslated(context, "yourTurn");

            player = "O";
            if (gameStatus == "started") {
              check();
            }
            setState(() {});
          } else {
            if (gameStatus == "started" && mounted) playGame();
          }
        });
        if (gameStatus == "started") {
          check();
        }
      }

      if (player == "O" && i != null) {
        if (buttons[i]["state"] == "") {
          music.play(dice);

          buttons[i]["state"] = "true";

          buttons[i]["player"] = "1";
          player = "X";
          _stopTimer(); // Stop timer when human plays - AI's turn now

          currentMove = utils.getTranslated(context, "doraTurn");

          setState(() {});
          playGame();
          if (gameStatus == "started") {
            check();
          }
        }
        if (gameStatus == "started") {
          check();
        }
      }
    }
  }


  @override
  void initState() {
    super.initState();

    if (widget.matrixSize == "Four") {
      buttons = u.gameButtonsFour;
    } else if (widget.matrixSize == "Five") {
      buttons = u.gameButtonsFive;
    } else {
      buttons = u.gameButtons;
    }

    rnd = Random();

    int rndVal = rnd.nextInt(2);

    player = rndVal == 0 ? "X" : "O";
    gameStatus = "started";
    getFieldValue("profilePic", (e) => _profilePic = e, (e) => _profilePic = e);
    getFieldValue("username", (e) => _username = e, (e) => _username = e);

    // For Compatibility with older versions, as we have changed to use svg instead of png.
    if (widget.doraSkin!.endsWith('.png')) {
      widget.doraSkin =
          widget.doraSkin!.split('.png').first.split('images/').last;
    }
    if (widget.playerSkin!.endsWith('.png')) {
      widget.playerSkin =
          widget.playerSkin!.split('.png').first.split('images/').last;
    }

    // Start custom timer only when human goes first
    if (player == "O") {
      Future.delayed(const Duration(milliseconds: 500), _startTimer);
    }

    Future.delayed(Duration.zero, playGame);
  }

  @override
  void dispose() {
    _stopTimer();
    _timerNotifier.dispose();
    super.dispose();
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

  @override
  void didChangeDependencies() {
    currentMove = player == "X"
        ? utils.getTranslated(context, "doraTurn")
        : utils.getTranslated(context, "yourTurn");
    super.didChangeDependencies();
  }

  bool _isDialogShowing = false;

  void showQuitGameDialog() async {
    if (_isDialogShowing) return; // Prevent multiple calls
    _isDialogShowing = true;

    music.play(click);
    showDialog(
      context: context,
      builder: (context) {
        var color = secondaryColor;
        return Alert(
          title: Text(
            utils.getTranslated(context, "aleart"),
            style: TextStyle(color: white),
          ),
          isMultipleAction: true,
          defaultActionButtonName: utils.getTranslated(context, "ok"),
          onTapActionButton: () {},
          content: Text(
            utils.getTranslated(context, "areYouSure"),
            style: TextStyle(color: white),
          ),
          multipleAction: [
            TextButton(
              style:
                  ButtonStyle(backgroundColor: WidgetStateProperty.all(color)),
              onPressed: () async {
                music.play(click);
                Navigator.popUntil(context, ModalRoute.withName("/home"));
                _isDialogShowing = false; // Reset the state
              },
              child: Text(
                utils.getTranslated(context, "ok"),
                style: TextStyle(color: white),
              ),
            ),
            TextButton(
              style:
                  ButtonStyle(backgroundColor: WidgetStateProperty.all(color)),
              onPressed: () async {
                music.play(click);
                Navigator.pop(context);
                _isDialogShowing = false; // Reset the state
              },
              child: Text(
                utils.getTranslated(context, "cancel"),
                style: TextStyle(color: white),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      _isDialogShowing =
          false; // Ensure we reset state after dialog is dismissed
    });
  }

  @override
  Widget build(BuildContext context) {
    int gridSize;
    if (widget.matrixSize == "Three") {
      gridSize = 3; // 3x3
    } else if (widget.matrixSize == "Four") {
      gridSize = 4; // 4x4
    } else if (widget.matrixSize == "Five") {
      gridSize = 5; // 5x5
    } else {
      gridSize = 3; // Default to 3x3 or handle it as needed
    }

    return PopScope(
        canPop: false,
        child: Scaffold(
          body: Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            decoration: utils.gradBack(),
            child: Column(
              children: [
                Expanded(
                  flex: 1,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            // ValueListenableBuilder: only timer rebuilds each second
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
                                      color: secs <= 10 ? Colors.red : white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                  start: 8.0, end: 8.0),
                              child: Text("$currentMove"),
                            )
                          ],
                        ),
                      ),
                      Spacer(),
                      IconButton(
                          padding: EdgeInsets.only(),
                          onPressed: () {
                            showQuitGameDialog();
                          },
                          icon: Icon(
                            Icons.logout,
                            color: back,
                          )),
                    ],
                  ),
                ),
                Expanded(
                  flex: 8,
                  child: Container(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30.0),
                      child: Center(
                        child: Stack(
                          children: [
                            GridView.builder(
                              physics: NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: gridSize,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: gridSize * gridSize,
                              itemBuilder: (context, i) {
                                return GestureDetector(
                                  onTap: () {
                                    if (gameStatus == "started" &&
                                        currentMove ==
                                            utils.getTranslated(
                                                context, "yourTurn")) {
                                      playGame(i);
                                    }
                                  },
                                  child: Stack(fit: StackFit.expand, children: [
                                    Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        margin: EdgeInsets.only(
                                          left: 2,
                                          right: 2,
                                          top: 30,
                                        ),
                                        decoration: BoxDecoration(
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.white54,
                                              offset: Offset(0, 4),
                                              spreadRadius: 1.5,
                                              blurRadius: 7,
                                            ),
                                          ],
                                          borderRadius:
                                              BorderRadius.circular(40),
                                        ),
                                      ),
                                    ),
                                    getSvgImage(
                                        imageName: 'grid_box',
                                        fit: BoxFit.fill),
                                    buttons[i]['state'] == ""
                                        ? const SizedBox()
                                        : Padding(
                                            padding: EdgeInsets.all(
                                                MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.05),
                                            child: getSvgImage(
                                              imageName: utils.returnImage(
                                                i,
                                                buttons,
                                                widget.playerSkin,
                                                widget.doraSkin,
                                              ),
                                              height: double.maxFinite,
                                              width: double.maxFinite,
                                              fit: BoxFit.fill,
                                            ),
                                          ),
                                  ]),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(
                        left: 20.0, right: 20, bottom: 20),
                    child: Row(
                      children: [
                        Row(
                          children: [
                            (_profilePic ?? "") != ""
                                ? CircleAvatar(
                                    backgroundImage: NetworkImage(_profilePic!),
                                    radius: 25,
                                  )
                                : const CircleAvatar(
                                    backgroundColor: Colors.transparent,
                                    child: XOBattleLogo(size: 50),
                                    radius: 25,
                                  ),
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        "${utils.getTranslated(context, "sign")} : ",
                                      ),
                                      // HERE
                                      getSvgImage(
                                        imageName: widget.playerSkin!,
                                        height: 12,
                                        imageColor: secondarySelectedColor,
                                      ),
                                      // Image.asset(
                                      //   widget.playerSkin!,
                                      //   height: 12,
                                      //   color: secondarySelectedColor,
                                      // )
                                    ],
                                  ),
                                  Text(
                                    "${utils.limitChar(_username!, 7)}",
                                    style: TextStyle(color: white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Expanded(
                          child: getSvgImage(
                              imageName: "vs_small", width: 22, height: 21),
                        ),
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    getSvgImage(
                                      imageName: widget.doraSkin!,
                                      height: 12,
                                    ),
                                    // Image.asset(
                                    //   widget.doraSkin!,
                                    //   height: 12,
                                    // ),
                                    Text(
                                      " : ${utils.getTranslated(context, "sign")}",
                                    ),
                                  ],
                                ),
                                Text(
                                  utils.getTranslated(context, "dora"),
                                  style: TextStyle(color: white),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: XOBattleLogo(size: 50),
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
        ));
  }
}
