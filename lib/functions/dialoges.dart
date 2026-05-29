import 'dart:async';

import 'package:xobattle/helpers/color.dart';
import 'package:xobattle/helpers/constant.dart';
import 'package:xobattle/helpers/utils.dart';
import 'package:xobattle/screens/offline_play.dart';
import 'package:xobattle/widgets/xo_logo.dart';
import 'package:xobattle/screens/pass_n_play.dart';
import 'package:xobattle/screens/splash.dart';
import 'package:xobattle/widgets/alert_dialogue.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Dialogue {
  static winner(
    BuildContext context,
    String? playerName,
    String? pic,
    String winText, [
    String? point,
    String? gameKey,
  ]) {
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) => PopScope(
              canPop: false,
              child: AlertDialog(
                backgroundColor: Colors.transparent,
                content: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          secondaryColor,
                          primaryColor,
                          Color(0xFF06030F),
                        ]),
                    borderRadius: BorderRadius.all(Radius.circular(24.0)),
                    border: Border.all(
                      color: secondarySelectedColor.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18.0),
                        child: Text(
                          utils.getTranslated(context, "gameOver"),
                          style: TextStyle(
                            color: secondarySelectedColor,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Container(
                            height: 84.0,
                            width: 84.0,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: secondarySelectedColor,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: secondarySelectedColor.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  )
                                ]),
                            child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: Container(
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(50)),
                                    child: (pic == ""
                                        ? const XOBattleLogo(size: 74)
                                        : Image.network(pic!))))),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "$playerName" +
                              " " +
                              utils.getTranslated(context, "win"),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge!
                              .copyWith(
                                  color: white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          winText,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .copyWith(color: white.withValues(alpha: 0.8)),
                        ),
                      ),
                      point != ""
                          ? Chip(
                              backgroundColor: secondarySelectedColor.withValues(alpha: 0.2),
                              side: BorderSide(color: secondarySelectedColor.withValues(alpha: 0.5)),
                              label: Text(
                                point!,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall!
                                    .copyWith(color: secondarySelectedColor),
                              ),
                              avatar: getSvgImage(imageName: "coin_symbol"),
                            )
                          : Container(),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16, right: 16),
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: GestureDetector(
                            onTap: () async {
                              music.play(click);
                              if (gameKey != null) {
                                removeChild("Game", gameKey);
                              }
                              Navigator.popUntil(
                                  context, ModalRoute.withName("/home"));
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [secondarySelectedColor, Color(0xFFFF8800)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.all(Radius.circular(20.0)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 22.0, vertical: 8),
                                child: Text(
                                  utils.getTranslated(context, "ok"),
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ));
  }

  tie(BuildContext context, String fromScreen,
      [player1name,
      player2name,
      player1skin,
      player2skin,
      levelType,
      matrixSize]) {
    utils.alert(
        defaultActionButtonName: utils.getTranslated(context, "ok"),
        barrierDismissible: false,
        isMultipleAction: true,
        context: context,
        title: Text(
          utils.getTranslated(context, "gameOver"),
          style: TextStyle(color: white),
        ),
        onTapActionButton: () {},
        content: Text(
          "Game tie",
          style: TextStyle(color: white, fontSize: 25),
        ),
        multipleAction: <Widget>[
          Container(
            child: TextButton(
              onPressed: () async {
                music.play(click);
                Navigator.of(context).pushReplacementNamed("/home");
              },
              child: Text(
                utils.getTranslated(context, "ok"),
                style: TextStyle(color: white),
              ),
            ),
          ),
          Container(
            child: TextButton(
              onPressed: () {
                fromScreen == "Singleplayer"
                    ? Navigator.pushReplacement(
                        context,
                        CupertinoPageRoute(
                            builder: (BuildContext context) =>
                                SinglePlayerScreenActivity(player1skin,
                                    player2skin, levelType, matrixSize)))
                    : Navigator.pushReplacement(
                        context,
                        CupertinoPageRoute(
                            builder: (BuildContext context) => PassNPLay(
                                player1name,
                                player2name,
                                player1skin,
                                player2skin,
                                matrixSize)));
              },
              child: Text(utils.getTranslated(context, "restart"),
                  style: TextStyle(color: white)),
            ),
          )
        ]);
  }

  static lessMoney(context) {
    showDialog(
        context: context,
        builder: (context) {
          return Alert(
            title: Text(
              utils.getTranslated(context, "aleart"),
              style: TextStyle(color: white),
            ),
            isMultipleAction: true,
            defaultActionButtonName: utils.getTranslated(context, "ok"),
            onTapActionButton: () async {
              music.play(click);
              Navigator.pop(context);
            },
            content: Text(
              utils.getTranslated(context, "youDontHaveMoney"),
              style: TextStyle(color: white),
            ),
          );
        });
  }

  static loading(context) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
              backgroundColor: Colors.transparent,
              content: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(secondarySelectedColor),
                  ),
                ],
              ));
        });
  }

  tieMultiplayer(context, [gamekey]) {
    utils.alert(
        defaultActionButtonName: utils.getTranslated(context, "ok"),
        barrierDismissible: false,
        isMultipleAction: false,
        context: context,
        title: Text(
          utils.getTranslated(context, "gameOver"),
          style: TextStyle(color: white),
        ),
        onTapActionButton: () async {
          music.play(click);
          Navigator.popUntil(context, ModalRoute.withName("/home"));
        },
        content: Text(
          utils.getTranslated(context, "tie"),
          style: TextStyle(color: white),
        ),
        multipleAction: <Widget>[
          Container(
            child: TextButton(
              onPressed: () async {
                music.play(click);

                if (gamekey != null) {
                  removeChild("Game", gamekey);
                }

                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text(
                utils.getTranslated(context, "ok"),
                style: TextStyle(color: white),
              ),
            ),
          ),
        ]);
  }

  curentRoundResult(context, String subtitle) {
    utils.alert(
        defaultActionButtonName: utils.getTranslated(context, "ok"),
        barrierDismissible: false,
        isMultipleAction: false,
        context: context,
        title: Text(
          utils.getTranslated(context, "nextRound"),
          style: TextStyle(color: white),
          textAlign: TextAlign.center,
        ),
        onTapActionButton: () async {
          music.play(click);
        },
        content: Text(
          subtitle,
          style: TextStyle(color: white),
          textAlign: TextAlign.center,
        ),
        multipleAction: <Widget>[
          Container(
            child: TextButton(
              onPressed: () async {
                music.play(click);
                Navigator.pop(context);
              },
              child: Text(
                utils.getTranslated(context, "ok"),
                style: TextStyle(color: white),
              ),
            ),
          ),
        ]);
  }

  oppornentDisconnect(context, entryfee, [gamekey]) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return PopScope(
            canPop: false,
            child: Alert(
              defaultActionButtonName: utils.getTranslated(context, "ok"),
              title: Text(
                utils.getTranslated(context, "opponentDisconnected"),
                style: TextStyle(color: white),
              ),
              isMultipleAction: true,
              multipleAction: [
                MaterialButton(
                    onPressed: () {
                      music.play(click);
                      removeChild("Game", gamekey);
                      Navigator.popUntil(context, ModalRoute.withName("/home"));
                    },
                    child: Text(
                      utils.getTranslated(context, "ok"),
                      style: TextStyle(color: white),
                    ))
              ],
              onTapActionButton: () async {},
              content: Text(
                "You got  ${entryfee * 2} coins.",
                style: TextStyle(color: white),
              ),
            ),
          );
        });
  }

  error(context) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Alert(
            defaultActionButtonName: utils.getTranslated(context, "ok"),
            title: Text(
              utils.getTranslated(context, "error"),
              style: TextStyle(color: white),
              textAlign: TextAlign.center,
            ),
            isMultipleAction: true,
            multipleAction: [
              MaterialButton(
                  onPressed: () {
                    music.play(click);
                    Navigator.pop(context);
                  },
                  child: Text(
                    utils.getTranslated(context, "ok"),
                    style: TextStyle(color: white),
                  ))
            ],
            onTapActionButton: () async {},
            content: Text(
              utils.getTranslated(context, "checkYourInternet"),
              style: TextStyle(color: white),
              textAlign: TextAlign.center,
            ),
          );
        });
  }

  // ── Sudden Death Announcement ────────────────────────────────────────────
  // Shows a dramatic fullscreen overlay, counts down 3-2-1, then dismisses.
  // Returns after the countdown so caller can immediately start the game.
  static Future<void> suddenDeath(BuildContext context) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
      pageBuilder: (ctx, _, __) => const _SuddenDeathOverlay(),
    );
  }

  static removeChild(String parentNode, String? childNode) {
    Future.delayed(Duration(minutes: 2)).then((value) {
      FirebaseDatabase.instance
          .ref()
          .child(parentNode)
          .child(childNode!)
          .remove();
    });
  }
}

// ── Sudden Death overlay widget ────────────────────────────────────────────

class _SuddenDeathOverlay extends StatefulWidget {
  const _SuddenDeathOverlay();
  @override
  State<_SuddenDeathOverlay> createState() => _SuddenDeathOverlayState();
}

class _SuddenDeathOverlayState extends State<_SuddenDeathOverlay>
    with SingleTickerProviderStateMixin {
  int _count = 3;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Short delay before counting so the animation lands first
    Future.delayed(const Duration(milliseconds: 600), () {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        if (_count <= 1) {
          t.cancel();
          Navigator.of(context).pop();
        } else {
          setState(() => _count--);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8B0000), Color(0xFF1A0000), Color(0xFF06030F)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lightning icons
              Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                Text('⚡', style: TextStyle(fontSize: 36)),
                SizedBox(width: 12),
                Text('⚡', style: TextStyle(fontSize: 48)),
                SizedBox(width: 12),
                Text('⚡', style: TextStyle(fontSize: 36)),
              ]),
              const SizedBox(height: 20),

              // SUDDEN DEATH title
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, child) => Transform.scale(scale: _pulseAnim.value, child: child),
                child: ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFFD700), Color(0xFFFF6B6B)],
                  ).createShader(b),
                  child: const Text(
                    'SUDDEN\nDEATH',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'DISPLATTER',
                      fontSize: 52,
                      color: Colors.white,
                      letterSpacing: 4,
                      height: 1.1,
                      shadows: [Shadow(color: Color(0xFFFF0000), blurRadius: 20)],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Rule text
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(color: const Color(0xFFFF6B6B).withValues(alpha: 0.4)),
                ),
                child: const Text(
                  '2 consecutive draws!\nTimer: 5 seconds • No mercy!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                ),
              ),

              const SizedBox(height: 40),

              // Countdown number
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Text(
                  '$_count',
                  key: ValueKey(_count),
                  style: const TextStyle(
                    fontFamily: 'DISPLATTER',
                    fontSize: 88,
                    color: Color(0xFFFFD700),
                    shadows: [Shadow(color: Color(0xFFFF0000), blurRadius: 30)],
                  ),
                ),
              ),

              const SizedBox(height: 8),
              const Text(
                'GET READY…',
                style: TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
