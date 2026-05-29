import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../helpers/string.dart';
import '../helpers/utils.dart';
import '../functions/dialoges.dart';
import '../functions/getCoin.dart';
import '../models/sound_effect.dart';
import 'arcade.dart';
import '../widgets/xo_logo.dart';
import 'daily_challenge.dart';
import 'finding_player.dart';
import 'offline_play.dart';
import 'pass_n_play.dart';
import 'private_room.dart';
import 'splash.dart';
import 'streak_mode.dart';

class HomeScreenActivity extends StatefulWidget {
  const HomeScreenActivity({super.key});

  @override
  HomeScreenActivityState createState() => HomeScreenActivityState();
}

class HomeScreenActivityState extends State<HomeScreenActivity> with TickerProviderStateMixin {
  late AnimationController _floatCtrl;
  late AnimationController _entryCtrl;
  late Animation<double> _floatAnim;
  late Animation<double> _entryOpacity;
  late Animation<Offset> _entrySlide;

  Utils localValue = Utils();
  late String userSkin = '', opponentSkin = '';
  late String selectedMatrixIndex = "Three";
  late String clickAudioUrl;
  late SoundEffect loadedSound;
  var coin;
  late bool canPlay;
  TextEditingController player1controller = TextEditingController();
  TextEditingController player2controller = TextEditingController();
  String? getlanguage;
  StreamSubscription? _coinSub;

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _floatAnim = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );
    _entryOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeIn),
    );
    _entrySlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic),
    );

    _entryCtrl.forward();
    getSkinvalues();
    _getSavedLanguage();
    coins();
    canP();
    deleteOldGames();
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _entryCtrl.dispose();
    _coinSub?.cancel();
    super.dispose();
  }

  _getSavedLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    getlanguage = prefs.getString(LAGUAGE_CODE) ?? "";
    if (mounted) setState(() {});
  }

  void getSkinvalues() async {
    userSkin = await localValue.getSkinValue("user_skin");
    opponentSkin = await localValue.getSkinValue("opponent_skin");
  }

  canP() async {
    var b = await utils.getSfxValue();
    setState(() { canPlay = b; });
  }

  void coins() {
    try {
      // detectChange uses onValue which fires immediately with the current value
      // AND on every future change — no separate getCoin() call needed.
      // Store the subscription so we can cancel it in dispose() to prevent leaks.
      _coinSub?.cancel();
      _coinSub = GetUserInfo().detectChange("coin", (val) {
        if (mounted) setState(() => coin = val ?? 0);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    getSkinvalues();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: primaryColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (b) => LinearGradient(
                colors: [white, secondarySelectedColor],
              ).createShader(b),
              child: Text(
                appName,
                style: const TextStyle(
                  fontFamily: 'DISPLATTER',
                  fontSize: 22,
                  color: Colors.white,
                  letterSpacing: 3,
                ),
              ),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () {
              music.play(click);
              Navigator.pushNamed(context, "/leaderboard");
            },
            child: getSvgImage(imageName: 'leaderboard_dark', height: 20, width: 20),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              music.play(click);
              Navigator.pushNamed(context, "/profile").then((_) {
                _getSavedLanguage();
                getSkinvalues();
                setState(() {});
              });
            },
            child: getSvgImage(imageName: 'menu_button', width: 52, height: 52),
          ),
        ],
      ),
      body: Container(
        width: size.width,
        height: size.height,
        decoration: utils.gradBack(),
        child: FadeTransition(
          opacity: _entryOpacity,
          child: SlideTransition(
            position: _entrySlide,
            child: Column(
              children: [
                // Coin chip row
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, right: 16, left: 16),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _CoinChip(coin: coin),
                    ),
                  ),
                ),

                // Mascot section
                Expanded(
                  flex: 5,
                  child: _buildMascotSection(size),
                ),

                // Game mode cards (scrollable)
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 4),
                        _GameCard(
                          icon: 'offline_white',
                          title: utils.getTranslated(context, "OFFLINE_PLAY"),
                          subtitle: utils.getTranslated(context, "Play_with_the_Clever_Fox_DORA"),
                          accentColor: const Color(0xFF7C5CBF),
                          onTap: () => playButtonPressed(0),
                        ),
                        const SizedBox(height: 10),
                        _GameCard(
                          icon: 'play_random',
                          title: 'RANKED MATCH',
                          subtitle: utils.getTranslated(context, "Find_your_match_around_the_world"),
                          accentColor: secondarySelectedColor,
                          isHighlighted: true,
                          onTap: () => playButtonPressed(1),
                        ),
                        const SizedBox(height: 10),
                        _GameCard(
                          icon: 'passnplay_white',
                          title: utils.getTranslated(context, "PASS_N_PLAY"),
                          subtitle: utils.getTranslated(context, "Pass_N_Play_With_your_Friend"),
                          accentColor: const Color(0xFF5B8ED6),
                          onTap: () => playButtonPressed(2),
                        ),
                        const SizedBox(height: 10),
                        _GameCard(
                          icon: 'play_random',
                          title: 'PRIVATE ROOM',
                          subtitle: 'Create or join a room with a friend',
                          accentColor: const Color(0xFF00BCD4),
                          onTap: () => _openPrivateRoom(),
                        ),
                        const SizedBox(height: 10),
                        _GameCard(
                          icon: 'offline_white',
                          title: 'BLITZ MODE',
                          subtitle: '7 seconds per move — think fast!',
                          accentColor: const Color(0xFFFF5252),
                          onTap: () => _openBlitz(),
                        ),
                        const SizedBox(height: 10),
                        _GameCard(
                          icon: 'offline_dark',
                          title: 'STREAK CHALLENGE',
                          subtitle: 'Beat STRIKER in a row, earn coins',
                          accentColor: const Color(0xFF66BB6A),
                          onTap: () => _openStreak(),
                        ),
                        const SizedBox(height: 10),
                        _GameCard(
                          icon: 'leaderboard_dark',
                          title: 'DAILY CHALLENGE',
                          subtitle: 'One puzzle per day — win 50 coins',
                          accentColor: const Color(0xFFFFB300),
                          onTap: () => _openDaily(),
                        ),
                        const SizedBox(height: 10),
                        // Arcade banner
                        GestureDetector(
                          onTap: () { music.play(click); Navigator.push(context, CupertinoPageRoute(builder: (_) => const ArcadeScreen())); },
                          child: Container(
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: LinearGradient(
                                colors: [const Color(0xFF6A1B9A).withValues(alpha: 0.6), const Color(0xFF00ACC1).withValues(alpha: 0.4)],
                                begin: Alignment.centerLeft, end: Alignment.centerRight,
                              ),
                              border: Border.all(color: const Color(0xFFCE93D8).withValues(alpha: 0.55), width: 1.2),
                            ),
                            child: Row(children: [
                              Container(width: 4, height: 72,
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), bottomLeft: Radius.circular(18)),
                                  gradient: const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFF9C27B0)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Container(width: 40, height: 40,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFE91E63).withValues(alpha: 0.2)),
                                child: const Center(child: Text('🕹️', style: TextStyle(fontSize: 22))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('ARCADE', style: TextStyle(color: white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.5)),
                                Text('6 games: RPS, Connect 4, Checkers…', style: TextStyle(color: white.withValues(alpha: 0.5), fontSize: 11)),
                              ])),
                              Padding(padding: const EdgeInsets.only(right: 16),
                                child: Container(width: 32, height: 32,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFE91E63).withValues(alpha: 0.2)),
                                  child: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFCE93D8), size: 14),
                                ),
                              ),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMascotSection(Size size) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow ring beneath mascot
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: secondarySelectedColor.withValues(alpha: 0.25),
                blurRadius: 60,
                spreadRadius: 20,
              ),
            ],
          ),
        ),

        // Floating logo + STRIKER label
        AnimatedBuilder(
          animation: _floatCtrl,
          builder: (_, child) => Transform.translate(
            offset: Offset(0, _floatAnim.value),
            child: child,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              XOBattleLogo(size: 160),
              const SizedBox(height: 18),
              ShaderMask(
                shaderCallback: (b) => LinearGradient(
                  colors: [white, secondarySelectedColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(b),
                child: Text(
                  'STRIKER',
                  style: TextStyle(
                    fontFamily: 'DISPLATTER',
                    fontSize: 28,
                    color: white,
                    letterSpacing: 6,
                    shadows: [Shadow(color: secondarySelectedColor.withValues(alpha: 0.8), blurRadius: 16)],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      secondarySelectedColor.withValues(alpha: 0.2),
                      secondarySelectedColor.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: secondarySelectedColor.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Your AI Rival  •  Beat if you can',
                  style: TextStyle(
                    color: secondarySelectedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Game logic helpers (unchanged) ──────────────────────────────────────

  void playButtonPressed(int pos) {
    music.play(click);
    if (pos == 0) {
      selectedMatrixIndex = "Three";
      showLevelDialog();
    } else if (pos == 1) {
      _startMultiplayer();
    } else {
      selectPassNPlayDialog();
    }
  }

  void _openPrivateRoom() {
    music.play(click);
    Navigator.push(context, CupertinoPageRoute(builder: (_) => const PrivateRoomScreen()));
  }

  void _openBlitz() {
    music.play(click);
    selectedMatrixIndex = "Three";
    showLevelDialog(isBlitz: true);
  }

  void _openStreak() {
    music.play(click);
    Navigator.push(context, CupertinoPageRoute(builder: (_) => StreakModeScreen(
      playerSkin: userSkin.isNotEmpty ? userSkin : 'cross_skin',
      opponentSkin: opponentSkin.isNotEmpty ? opponentSkin : 'circle_skin',
    )));
  }

  void _openDaily() {
    music.play(click);
    Navigator.push(context, CupertinoPageRoute(builder: (_) => const DailyChallengeScreen()));
  }

  void _startMultiplayer() async {
    try {
      await InternetAddress.lookup('google.com');
      if (coin >= fixedEntryFee) {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => FindingPlayerScreen(
              selected: fixedEntryFee,
              round: fixedRounds,
              matrixSize: "Three",
            ),
          ),
        );
      } else {
        Dialogue.lessMoney(context);
      }
    } on SocketException catch (_) {
      Dialogue().error(context);
    }
  }

  void showLevelDialog({bool isBlitz = false}) {
    int selectedLevelIndex = 0;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: primaryColor,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20.0))),
        title: Center(
          child: Text(
            utils.getTranslated(context, "selectLevel"),
            style: Theme.of(context).textTheme.titleSmall!.copyWith(color: white),
          ),
        ),
        content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: typeOfLevel
                    .map((levelName) => GestureDetector(
                          onTap: () {
                            music.play(dice);
                            setDialogState(() {
                              selectedLevelIndex = typeOfLevel.indexOf(levelName);
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: selectedLevelIndex == typeOfLevel.indexOf(levelName)
                                    ? secondarySelectedColor
                                    : back,
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Center(
                                  child: Text(
                                    utils.getTranslated(context, levelName),
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ),
        actions: [
          ElevatedButton.icon(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(back),
              shape: WidgetStateProperty.all(const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20.0)))),
            ),
            onPressed: () {
              music.play(click);
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => SinglePlayerScreenActivity(
                    userSkin,
                    opponentSkin,
                    selectedLevelIndex,
                    "Three",
                    timerSeconds: isBlitz ? blitzCountdown : countdowntime,
                  ),
                ),
              );
            },
            icon: Icon(Icons.skip_next, color: primaryColor, size: 20),
            label: Text(
              utils.getTranslated(context, "next"),
              style: TextStyle(color: primaryColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  selectPassNPlayDialog() {
    player1controller.clear();
    player2controller.clear();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: primaryColor,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20.0))),
        title: Center(
          child: Text(
            utils.getTranslated(context, "passNplayDialoge"),
            style: Theme.of(context).textTheme.titleSmall!.copyWith(color: white),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _nameField(player1controller, userSkin),
            const SizedBox(height: 10),
            _nameField(player2controller, opponentSkin),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(back),
                shape: WidgetStateProperty.all(const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20.0))))),
            onPressed: () async {
              music.play(click);
              if (player1controller.text.isNotEmpty && player2controller.text.isNotEmpty) {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => PassNPLay(
                      player1controller.text,
                      player2controller.text,
                      userSkin,
                      opponentSkin,
                      "Three",
                    ),
                  ),
                );
              }
            },
            icon: Icon(Icons.skip_next, color: primaryColor, size: 20),
            label: Text(
              utils.getTranslated(context, "start"),
              style: TextStyle(color: primaryColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nameField(TextEditingController ctrl, String skinName) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: white),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: getSvgImage(imageName: skinName, height: 10, width: 10),
          ),
          hintText: utils.getTranslated(context, "playerName"),
          hintStyle: TextStyle(color: grey),
        ),
      ),
    );
  }

  void deleteOldGames() async {
    FirebaseDatabase ins = FirebaseDatabase.instance;
    DatabaseEvent gameRef = await ins.ref().child("Game").once();
    if (gameRef.snapshot.value != null) {
      Map gameData = gameRef.snapshot.value as Map;
      gameData.forEach((key, value) {
        if (value["status"] == "closed") {
          Dialogue.removeChild("Game", key);
          return;
        }
        var diff = DateTime.now().difference(DateTime.parse(value["time"])).inMinutes;
        if (diff > 15) Dialogue.removeChild("Game", key);
      });
    }
  }
}

// ── Coin chip (private, used inside HomeScreen) ────────────────────────────

class _CoinChip extends StatelessWidget {
  final dynamic coin;
  const _CoinChip({required this.coin});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && !user.isAnonymous) {
          Navigator.pushNamed(context, "/shop");
        }
      },
      child: _coinPill('${coin ?? 0}'),
    );
  }
}

// ── CoinWidget (public, self-loading — used by other screens) ──────────────

class CoinWidget extends StatefulWidget {
  const CoinWidget({super.key});
  @override
  State<CoinWidget> createState() => _CoinWidgetState();
}

class _CoinWidgetState extends State<CoinWidget> {
  int _coin = 0;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = GetUserInfo().detectChange("coin", (v) {
      if (mounted) setState(() => _coin = (v as int?) ?? 0);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _coinPill('$_coin');
}

Widget _coinPill(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      color: secondaryColor,
      border: Border.all(color: secondarySelectedColor.withValues(alpha: 0.3), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        getSvgImage(imageName: 'coin_symbol', height: 14),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: yellow, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

// ── Game mode card ─────────────────────────────────────────────────────────

class _GameCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _GameCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: isHighlighted
              ? LinearGradient(
                  colors: [
                    secondarySelectedColor.withValues(alpha: 0.25),
                    secondarySelectedColor.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : LinearGradient(
                  colors: [
                    white.withValues(alpha: 0.07),
                    white.withValues(alpha: 0.03),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          border: Border.all(
            color: isHighlighted
                ? secondarySelectedColor.withValues(alpha: 0.55)
                : white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Left accent bar
            Container(
              width: 4,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
                color: accentColor,
              ),
            ),

            // Icon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.15),
                ),
                child: Center(
                  child: getSvgImage(
                    imageName: icon,
                    width: 22,
                    height: 22,
                    imageColor: isHighlighted ? accentColor : white,
                  ),
                ),
              ),
            ),

            // Text
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Arrow
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.2),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isHighlighted ? accentColor : white.withValues(alpha: 0.7),
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Kept for compatibility (ChipGrid used by dialogs elsewhere) ─────────────

class ChipGrid extends StatefulWidget {
  final List list;
  final Function(int i) onChange;
  final bool avatar;

  const ChipGrid({super.key, required this.list, required this.onChange, required this.avatar});

  @override
  _ChipGridState createState() => _ChipGridState();
}

class _ChipGridState extends State<ChipGrid> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).devicePixelRatio == 2.75 ? 120 : 95,
      child: GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3,
        ),
        itemCount: widget.list.length,
        itemBuilder: (context, i) {
          return GestureDetector(
            onTap: () async {
              music.play(dice);
              setState(() { selectedIndex = i; });
              if (widget.avatar == false) {
                widget.onChange(selectedIndex);
              } else {
                widget.onChange(widget.list[selectedIndex]);
              }
            },
            child: Chip(
              backgroundColor: selectedIndex == i ? secondarySelectedColor : back,
              label: Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.avatar ? 0 : 8.0),
                child: Text(widget.list[i].toString(),
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              avatar: widget.avatar ? getSvgImage(imageName: 'coin_symbol') : null,
            ),
          );
        },
      ),
    );
  }
}

class Item {
  String icon, name, desc;
  Item({required this.icon, required this.name, required this.desc});
}
