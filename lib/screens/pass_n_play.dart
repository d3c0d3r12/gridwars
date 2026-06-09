import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../widgets/xo_logo.dart';

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
  final String matrixSize;

  PassNPLay(this.player1, this.player2, this.player1Skin, this.player2Skin,
      this.matrixSize);

  @override
  _PassNPLayState createState() => _PassNPLayState();
}

class _PassNPLayState extends State<PassNPLay> {
  Timer? _gameTimer;
  final _timerNotifier = ValueNotifier<int>(0);

  // State management
  String gameStatus = "started";
  Map buttons = {};
  String? currentMove;
  late Random randomValue;
  String? player; // "X" or "O"
  String? winner = "0";
  bool _isGameOverHandled = false;
  bool _isDialogShowing = false;
  bool _isDisposed = false;

  Utils u = Utils();

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  void _initGame() {
    _isGameOverHandled = false;
    gameStatus = "started";
    winner = "0";

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

    // Fix skin paths
    if (widget.player1Skin.endsWith('.png')) {
      widget.player1Skin = widget.player1Skin.split('.png').first.split('images/').last;
    }
    if (widget.player2Skin.endsWith('.png')) {
      widget.player2Skin = widget.player2Skin.split('.png').first.split('images/').last;
    }

    _updateCurrentMove();
    _startTimer();
  }

  void _startTimer() {
    _stopTimer();
    if (_isDisposed) return;
    _timerNotifier.value = countdowntime;
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_isDisposed || !mounted) {
        t.cancel();
        return;
      }
      if (_timerNotifier.value <= 1) {
        t.cancel();
        if (gameStatus == "started" && !_isGameOverHandled) {
          _onTimerExpired();
        }
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
    if (_isDisposed || !mounted) return;
    if (gameStatus != "started" || _isGameOverHandled) return;

    _isGameOverHandled = true;
    gameStatus = "over";
    _stopTimer();
    music.play(losegame);

    // FIXED: Correct winner on timeout
    // Current player missed their turn, so opponent wins
    final winnerPlayer = (player == "X")
        ? widget.player2.toString()
        : widget.player1.toString();

    if (mounted) {
      Dialogue.winner(context, winnerPlayer, "", "", "", "");
      // Navigate back after dialog closes
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
    }
  }

  void _updateCurrentMove() {
    if (_isDisposed) return;
    if (player == "X") {
      currentMove = "${widget.player1} Turn";
    } else {
      currentMove = "${widget.player2} Turn";
    }
    setState(() {});
  }

  void check() {
    if (_isDisposed || _isGameOverHandled) return;

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

        if (!_isGameOverHandled && mounted) {
          _isGameOverHandled = true;
          _stopTimer();

          // FIXED: Correct winner assignment
          // player "2" means Player 1 (X) won
          // player "1" means Player 2 (O) won
          final isPlayer1Winner = (winner == "2");
          final winnerName = isPlayer1Winner ? widget.player1 : widget.player2;

          if (isPlayer1Winner) {
            music.play(wingame);
          } else {
            music.play(losegame);
          }

          Dialogue.winner(context, winnerName, "", "", "", "");
          // Navigate back after dialog closes
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          });
        }
        setState(() {});
        return;
      }
    }

    // Check for tie
    _checkTie(totalBoxes);
  }

  void _checkTie(int totalBoxes) {
    if (_isDisposed || _isGameOverHandled) return;

    int filledCount = 0;
    for (var k = 0; k < buttons.length; k++) {
      if (buttons[k]["state"] != "" && winner == "0") {
        filledCount++;
      }
    }

    if (filledCount == totalBoxes && winner == "0") {
      _isGameOverHandled = true;
      gameStatus = "tie";
      _stopTimer();
      music.play(tiegame);

      if (mounted) {
        Dialogue().tie(
          context,
          "passnplay",
          widget.player1.toString(),
          widget.player2.toString(),
          widget.player1Skin,
          widget.player2Skin,
        );
        // Navigate back after tie dialog closes
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });
      }
      setState(() {});
    }
  }

  void playGame([int? index]) async {
    if (_isDisposed || gameStatus != "started" || _isGameOverHandled) return;
    if (index == null) return;

    // Check if cell is already filled
    if (buttons[index]["state"] != "") return;

    // FIXED: Correct player assignment
    // Player "X" (Player 1) -> assign "2"
    // Player "O" (Player 2) -> assign "1"
    if (player == "X") {
      music.play(dice);
      buttons[index]["state"] = "true";
      buttons[index]["player"] = "2"; // Player 1's mark
      player = "O";
      _stopTimer();
      _startTimer();
      _updateCurrentMove();
      setState(() {});
      check();
    }
    else if (player == "O") {
      music.play(dice);
      buttons[index]["state"] = "true";
      buttons[index]["player"] = "1"; // Player 2's mark
      player = "X";
      _stopTimer();
      _startTimer();
      _updateCurrentMove();
      setState(() {});
      check();
    }
  }

  void showQuitGameDialog() async {
    if (_isDialogShowing || _isDisposed) return;
    _isDialogShowing = true;

    music.play(click);
    await showDialog(
      context: context,
      barrierDismissible: false,
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
              style: ButtonStyle(backgroundColor: WidgetStateProperty.all(color)),
              onPressed: () async {
                music.play(click);
                _stopTimer();
                if (mounted) {
                  Navigator.popUntil(context, ModalRoute.withName("/home"));
                }
                _isDialogShowing = false;
              },
              child: Text(
                utils.getTranslated(context, "ok"),
                style: TextStyle(color: white),
              ),
            ),
            TextButton(
              style: ButtonStyle(backgroundColor: WidgetStateProperty.all(color)),
              onPressed: () {
                music.play(click);
                if (mounted) Navigator.pop(context);
                _isDialogShowing = false;
              },
              child: Text(
                utils.getTranslated(context, "cancel"),
                style: TextStyle(color: white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int gridSize;
    if (widget.matrixSize == "Three") {
      gridSize = 3;
    } else if (widget.matrixSize == "Four") {
      gridSize = 4;
    } else if (widget.matrixSize == "Five") {
      gridSize = 5;
    } else {
      gridSize = 3;
    }

    int totalCells = gridSize * gridSize;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isDisposed) {
          showQuitGameDialog();
        }
      },
      child: Scaffold(
        body: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: utils.gradBack(),
          child: Column(
            children: [
              // Header with timer and quit button
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
                              width: 35,
                              height: 35,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: secs <= 10 ? Colors.red : secondarySelectedColor,
                                  width: 3,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$secs',
                                  style: TextStyle(
                                    color: secs <= 10 ? Colors.red : white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "$currentMove",
                            style: TextStyle(
                              color: white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: showQuitGameDialog,
                        icon: Icon(Icons.logout, color: back),
                      ),
                    ],
                  ),
                ),
              ),

              // Game Board
              Expanded(
                flex: 8,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: Center(
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridSize,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: totalCells,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            if (gameStatus == "started" && !_isGameOverHandled) {
                              playGame(index);
                            }
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  margin: const EdgeInsets.only(
                                    left: 2,
                                    right: 2,
                                    top: 30,
                                  ),
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white54,
                                        offset: const Offset(0, 4),
                                        spreadRadius: 1.5,
                                        blurRadius: 7,
                                      ),
                                    ],
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                ),
                              ),
                              getSvgImage(
                                imageName: 'grid_box',
                                fit: BoxFit.fill,
                              ),
                              if (buttons[index]['state'] != "")
                                Padding(
                                  padding: EdgeInsets.all(
                                    MediaQuery.of(context).size.width * 0.05,
                                  ),
                                  child: getSvgImage(
                                    imageName: u.returnImage(
                                      index,
                                      buttons,
                                      widget.player2Skin,
                                      widget.player1Skin,
                                    ),
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
                  ),
                ),
              ),

              // Players Info Footer
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 20.0,
                    right: 20,
                    bottom: 20,
                  ),
                  child: Row(
                    children: [
                      // Player 1 (X)
                      Row(
                        children: [
                          CircleAvatar(
                            child: const XOBattleLogo(size: 50),
                            radius: 25,
                            backgroundColor: Colors.transparent,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "${utils.getTranslated(context, "sign")} : ",
                                    style: TextStyle(color: white),
                                  ),
                                  getSvgImage(
                                    imageName: widget.player1Skin,
                                    height: 12,
                                    imageColor: secondarySelectedColor,
                                  ),
                                ],
                              ),
                              Text(
                                widget.player1.toString(),
                                style: TextStyle(color: white),
                              ),
                            ],
                          ),
                        ],
                      ),

                      Expanded(
                        child: Center(
                          child: getSvgImage(
                            imageName: "vs_small",
                            width: 22,
                            height: 21,
                          ),
                        ),
                      ),

                      // Player 2 (O)
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
                                    style: TextStyle(color: white),
                                  ),
                                ],
                              ),
                              Text(
                                widget.player2.toString(),
                                style: TextStyle(color: white),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: Colors.transparent,
                            child: const XOBattleLogo(size: 50),
                            radius: 25,
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
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopTimer();
    _timerNotifier.dispose();
    super.dispose();
  }
}