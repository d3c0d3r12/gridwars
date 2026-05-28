import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../helpers/utils.dart';
import '../functions/dialoges.dart';
import '../widgets/alert_dialogue.dart';
import 'splash.dart';

// ignore: must_be_immutable
class PassNPLay extends StatefulWidget {
  final String player1, player2;
  String player1Skin, player2Skin;
  final String matrixSize; // Add the matrixSize parameter

  PassNPLay(this.player1, this.player2, this.player1Skin, this.player2Skin,
      this.matrixSize);

  @override
  _PassNPLayState createState() => _PassNPLayState();
}

class _PassNPLayState extends State<PassNPLay> {
  Timer? _gameTimer;
  final _timerNotifier = ValueNotifier<int>(0);

  void _startTimer() {
    _stopTimer();
    _timerNotifier.value = countdowntime;
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
    gameStatus = "over";
    music.play(losegame);
    final winnerPlayer = currentMove == widget.player1.toString() + " Turn"
        ? widget.player2.toString()
        : widget.player1.toString();
    Dialogue.winner(context, winnerPlayer, "", "", "", "");
    setState(() {});
  }

  String gameStatus = "";

  Utils u = Utils();
  Map buttons = Map();
  String? currentMove;
  late Random randomValue;
  String? player;
  String? winner = "0";
  int calledCount = 0;
  int tieCalled = 0;

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
    randomValue = Random();
    int randomNumber = randomValue.nextInt(2);

    player = randomNumber == 0 ? "X" : "O";
    gameStatus = "started";

    // For Compatibility with older versions, as we have changed to use svg instead of png.
    if (widget.player1Skin.endsWith('.png')) {
      widget.player1Skin =
          widget.player1Skin.split('.png').first.split('images/').last;
    }
    if (widget.player2Skin.endsWith('.png')) {
      widget.player2Skin =
          widget.player2Skin.split('.png').first.split('images/').last;
    }

    playGame();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _startTimer();
    });
  }

  void check() {
    // Set winning conditions and total boxes based on matrix size
    var winningCondition;
    int totalBoxes;
    if (widget.matrixSize == "Three") {
      winningCondition = utils.winningCondition;
      totalBoxes = 9;
    } else if (widget.matrixSize == "Four") {
      winningCondition = utils.winningConditionFour;
      totalBoxes = 16;
    } else if (widget.matrixSize == "Five") {
      winningCondition = utils.winningConditionFive;
      totalBoxes = 25;
    } else {
      return;
    }

    // Check for winning conditions
    for (var condition in winningCondition) {
      if (condition.every((index) =>
          buttons[index]["player"] == buttons[condition[0]]["player"] &&
          buttons[condition[0]]["player"] != "0")) {
        winner = buttons[condition[0]]["player"];
        gameStatus = "over";
        calledCount++;
        setState(() {});
        break;
      }
    }

    // Check for a tie and handle game over scenarios
    if (gameStatus == "over" && mounted && winner != "0") {
      handleGameOver(winner!, totalBoxes);
    } else {
      checkTie(totalBoxes);
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
      tieCalled += 1;
      if (mounted) {
        setState(() {});
      }

      // Play tie game sound
      music.play(tiegame);

      _stopTimer();
      Future.delayed(Duration(seconds: 1)).then((value) {
        if (winner == "0" && gameStatus == "tie") {
          Dialogue()
            ..tie(
                context,
                "passnplay",
                widget.player1.toString(),
                widget.player2.toString(),
                widget.player1Skin,
                widget.player2Skin);
        }
        setState(() {});
      });
    }
  }

  void handleGameOver(String winner, int totalBoxes) {
    winner == "1" ? music.play(wingame) : music.play(losegame);
    _stopTimer();
    setState(() {});

    // Show winner dialog
    Dialogue.winner(
      context,
      winner == "1" ? widget.player2.toString() : widget.player1.toString(),
      "",
      "",
      "",
      "",
    );
  }

  playGame([i]) async {
    if (gameStatus == "started") {
      currentMove = player == "X"
          ? widget.player1.toString() + " Turn"
          : widget.player2.toString() + " Turn";

      setState(() {});

      if (player == "X" && i != null) {
        if (buttons[i]["state"] == "") {
          music.play(dice);

          buttons[i]["state"] = "true";

          buttons[i]["player"] = "2";
          player = "O";
          _startTimer();

          currentMove = widget.player1.toString() + " Turn";

          setState(() {});

          playGame();
        }
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
          _startTimer();

          currentMove = widget.player1.toString() + " Turn";

          setState(() {});

          playGame();
        }
        if (gameStatus == "started") {
          check();
        }
      }
    }
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
      _isDialogShowing = false;
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
      gridSize = 3;
    }

    int totalCells = gridSize * gridSize;
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
                  child: Padding(
                    padding: const EdgeInsets.all(10),
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
                                      color: secs <= 10 ? Colors.red : white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsetsDirectional.only(start: 8.0),
                              child: Text("$currentMove"),
                            )
                          ],
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
                                      mainAxisSpacing: 10),
                              itemCount: totalCells,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () {
                                    if (gameStatus == "started") {
                                      playGame(index);
                                    }
                                  },
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
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
                                      buttons[index]['state'] == ""
                                          ? Container()
                                          : Padding(
                                              padding: EdgeInsets.all(
                                                  MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      0.05),
                                              child: getSvgImage(
                                                imageName: u.returnImage(
                                                    index,
                                                    buttons,
                                                    widget.player2Skin,
                                                    widget.player1Skin),
                                                height: double.maxFinite,
                                                width: double.maxFinite,
                                                fit: BoxFit.fill,
                                              ),
                                            ),
                                    ],
                                  ),
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
                            CircleAvatar(
                              child: getSvgImage(
                                  imageName: "signin_Dora",
                                  width: 154,
                                  height: 172),
                              radius: 25,
                              backgroundColor: Colors.transparent,
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
                                      getSvgImage(
                                        imageName: widget.player1Skin,
                                        height: 12,
                                        imageColor: secondarySelectedColor,
                                      )
                                    ],
                                  ),
                                  Text(
                                    "${widget.player1.toString()}",
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
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    getSvgImage(
                                      imageName: widget.player2Skin,
                                      height: 12,
                                    ),
                                    Text(
                                      " : ${utils.getTranslated(context, "sign")}",
                                    ),
                                  ],
                                ),
                                Text(
                                  "${widget.player2.toString()}",
                                  style: TextStyle(color: white),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: CircleAvatar(
                                backgroundColor: Colors.transparent,
                                child: getSvgImage(
                                    imageName: "signin_Dora",
                                    width: 154,
                                    height: 172),
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
        ));
  }

  @override
  void dispose() {
    _stopTimer();
    _timerNotifier.dispose();
    super.dispose();
  }
}
