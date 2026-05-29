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
    // Guard: once the game is over, never re-enter (prevents duplicate dialogs
    // from the multiple check() calls per move sequence).
    if (gameStatus != "started") return;

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
    // Prevent showing the dialog more than once if check() fires multiple times.
    if (calledCount > 1) return;
    if (!mounted) return;
    _stopTimer();
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
      }

      if (player == "O" && i != null) {
        if (buttons[i]["state"] == "") {
          music.play(dice);
          buttons[i]["state"] = "true";
          buttons[i]["player"] = "1";
          player = "X";
          _stopTimer();
          currentMove = utils.getTranslated(context, "doraTurn");
          setState(() {});
          // check() is called inside playGame() — no need to call it again here.
          playGame();
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
          backgroundColor: bgColor,
          body: SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      // Timer ring
                      ValueListenableBuilder<int>(
                        valueListenable: _timerNotifier,
                        builder: (_, secs, __) {
                          final isDanger = secs <= 10;
                          final col = isDanger ? red : xColor;
                          return Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: col, width: 2.5),
                              color: col.withValues(alpha: 0.08),
                            ),
                            child: Center(
                              child: Text(
                                '$secs',
                                style: TextStyle(
                                  color: isDanger ? red : inkColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: lineColor),
                          ),
                          child: Text(
                            "$currentMove",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: inkColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => showQuitGameDialog(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: lineColor),
                          ),
                          child: Icon(Icons.flag_outlined, color: red, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 8,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Center(
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
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
                            child: Container(
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: lineColor),
                                boxShadow: [shadowSm],
                              ),
                              child: buttons[i]['state'] == ""
                                  ? const SizedBox()
                                  : Padding(
                                      padding: EdgeInsets.all(
                                          MediaQuery.of(context).size.width *
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
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                // Player footer
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: surface2Color,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: lineColor),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        // Player side
                        Expanded(
                          child: Row(
                            children: [
                              (_profilePic ?? "") != ""
                                  ? CircleAvatar(backgroundImage: NetworkImage(_profilePic!), radius: 18, backgroundColor: surface2Color)
                                  : CircleAvatar(backgroundColor: xSoft, radius: 18, child: Icon(Icons.person, color: xColor, size: 18)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(children: [
                                      Text("${utils.getTranslated(context, "sign")}: ", style: TextStyle(fontSize: 10, color: ink3Color)),
                                      getSvgImage(imageName: widget.playerSkin!, height: 11, imageColor: xColor),
                                    ]),
                                    Text(utils.limitChar(_username!, 8), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: inkColor)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // VS
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(7), border: Border.all(color: lineColor)),
                          child: Text('VS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: ink3Color, letterSpacing: 1)),
                        ),
                        // Dora side
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                      getSvgImage(imageName: widget.doraSkin!, height: 11, imageColor: oColor),
                                      Text(" :${utils.getTranslated(context, "sign")}", style: TextStyle(fontSize: 10, color: ink3Color)),
                                    ]),
                                    Text(utils.getTranslated(context, "dora"), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: inkColor)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const XOBattleLogo(size: 36),
                            ],
                          ),
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
