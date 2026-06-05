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
import '../widgets/xo_logo.dart';
import '../functions/admin_service.dart';
import 'admin_panel.dart';
import 'arcade.dart';
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

class HomeScreenActivityState extends State<HomeScreenActivity>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
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
  StreamSubscription? _banSub;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminAndBan();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _entryOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeIn));
    _entrySlide =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
            CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();
    getSkinvalues();
    _getSavedLanguage();
    coins();
    canP();
    deleteOldGames();
  }

  Future<void> _checkAdminAndBan() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Check admin status
    final admin = await AdminService.isAdmin(uid);
    if (mounted) setState(() => _isAdmin = admin);

    // Real-time ban listener — kicks user instantly if banned while in app
    _banSub = AdminService.bannedStream(uid).listen((banned) {
      if (!mounted || !banned) return;
      FirebaseAuth.instance.signOut();
      Navigator.of(context).pushNamedAndRemoveUntil(
          '/authscreen', (_) => false);
      // Show ban reason
      FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(uid)
          .child('banReason')
          .once()
          .then((s) {
        final reason = s.snapshot.value?.toString() ?? '';
        if (context.mounted) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BannedScreen(reason: reason)));
        }
      });
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _coinSub?.cancel();
    _banSub?.cancel();
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
    setState(() {
      canPlay = b;
    });
  }

  void coins() {
    try {
      _coinSub?.cancel();
      _coinSub = GetUserInfo().detectChange("coin", (val) {
        if (mounted) setState(() => coin = val ?? 0);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    getSkinvalues();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        body: FadeTransition(
          opacity: _entryOpacity,
          child: SlideTransition(
            position: _entrySlide,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildTopBar()),
                SliverToBoxAdapter(child: _buildHeroCard()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                    child: _SectionLabel(label: 'Game Modes'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _ModeCard(
                        icon: Icons.person,
                        iconColor: xColor,
                        iconBg: xSoft,
                        title: utils.getTranslated(context, "OFFLINE_PLAY"),
                        sub: utils.getTranslated(
                            context, "Play_with_the_Clever_Fox_DORA"),
                        onTap: () => playButtonPressed(0),
                      ),
                      const SizedBox(height: 11),
                      _ModeCard(
                        icon: Icons.public,
                        iconColor: goldColor,
                        iconBg: goldSoft,
                        title: 'RANKED MATCH',
                        sub: utils.getTranslated(
                            context, "Find_your_match_around_the_world"),
                        onTap: () => playButtonPressed(1),
                        accent: true,
                      ),
                      const SizedBox(height: 11),
                      _ModeCard(
                        icon: Icons.people,
                        iconColor: oColor,
                        iconBg: oSoft,
                        title: utils.getTranslated(context, "PASS_N_PLAY"),
                        sub: utils.getTranslated(
                            context, "Pass_N_Play_With_your_Friend"),
                        onTap: () => playButtonPressed(2),
                      ),
                      const SizedBox(height: 11),
                      _ModeCard(
                        icon: Icons.lock_open,
                        iconColor: const Color(0xFF00BCD4),
                        iconBg: const Color(0xFF00BCD4).withValues(alpha: 0.12),
                        title: 'PRIVATE ROOM',
                        sub: 'Create or join a room with a friend',
                        onTap: () => _openPrivateRoom(),
                      ),
                      const SizedBox(height: 11),
                      _ModeCard(
                        icon: Icons.bolt,
                        iconColor: const Color(0xFFFF5252),
                        iconBg:
                            const Color(0xFFFF5252).withValues(alpha: 0.12),
                        title: 'BLITZ MODE',
                        sub: '7 seconds per move — think fast!',
                        onTap: () => _openBlitz(),
                      ),
                      const SizedBox(height: 11),
                      _ModeCard(
                        icon: Icons.local_fire_department,
                        iconColor: const Color(0xFF66BB6A),
                        iconBg:
                            const Color(0xFF66BB6A).withValues(alpha: 0.12),
                        title: 'STREAK CHALLENGE',
                        sub: 'Beat STRIKER in a row, earn coins',
                        onTap: () => _openStreak(),
                      ),
                      const SizedBox(height: 16),
                      _buildDailyStrip(),
                      const SizedBox(height: 12),
                      _buildArcadeBanner(),
                      const SizedBox(height: 96),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Top bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Row(
          children: [
            // Wordmark
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                XOBattleLogo(size: 32),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('CHILLING',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: inkColor,
                            letterSpacing: 1.5,
                            height: 1.1)),
                    Text('ZONE',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Color(0xFF00B8D4),
                            letterSpacing: 3.5,
                            height: 1.1)),
                  ],
                ),
              ],
            ),
            const Spacer(),
            // Admin button — only visible to admins
            if (_isAdmin) ...[
              GestureDetector(
                onTap: () => Navigator.push(context,
                    CupertinoPageRoute(
                        builder: (_) => const AdminPanelScreen())),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFE53935).withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: Color(0xFFE53935), size: 18),
                ),
              ),
              const SizedBox(width: 8),
            ],
            // Coin chip
            _CoinChip(coin: coin),
            const SizedBox(width: 10),
            // Profile button
            GestureDetector(
              onTap: () {
                music.play(click);
                Navigator.pushNamed(context, "/profile").then((_) {
                  _getSavedLanguage();
                  getSkinvalues();
                  setState(() {});
                });
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: lineColor),
                  boxShadow: [shadowSm],
                ),
                child: Icon(Icons.person_outline_rounded,
                    color: inkColor, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Hero card ────────────────────────────────────────────────────────────

  Widget _buildHeroCard() {
    final user = FirebaseAuth.instance.currentUser;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      child: Container(
        decoration: cardDecoration(radius: 22),
        padding: const EdgeInsets.all(18),
        child: Stack(
          children: [
            // Decorative marks
            Positioned(
              right: -20,
              top: -20,
              child: Opacity(
                opacity: 0.06,
                child: _XMark(size: 120, color: xColor),
              ),
            ),
            Positioned(
              right: 50,
              bottom: -28,
              child: Opacity(
                opacity: 0.05,
                child: _OMark(size: 100, color: oColor),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Avatar(
                        label: ((user?.displayName ?? '').isNotEmpty
                            ? user!.displayName![0]
                            : 'Y').toUpperCase()),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'Player',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: inkColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          _UserRankBadge(
                              score: coin is int ? 0 : 0, size: 'sm'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Quick play button
                GestureDetector(
                  onTap: () => _showModeSheet(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: xColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: xColor.withValues(alpha: 0.38),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'Quick Play',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Daily strip ──────────────────────────────────────────────────────────

  Widget _buildDailyStrip() {
    return GestureDetector(
      onTap: () => _openDaily(),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: lineColor),
          boxShadow: [shadowSm],
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [goldSoft, surfaceColor],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(13),
                boxShadow: [shadowSm],
              ),
              child: Icon(Icons.calendar_today_rounded,
                  color: goldColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Challenge',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: inkColor)),
                  const SizedBox(height: 2),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                          fontSize: 12, color: ink2Color, fontFamily: 'Poppins'),
                      children: [
                        const TextSpan(text: "Solve today's puzzle · win "),
                        TextSpan(
                          text: '50 coins',
                          style: TextStyle(
                              color: goldColor, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: lineColor),
              ),
              child: Text('Play',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: inkColor)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Arcade banner ────────────────────────────────────────────────────────

  Widget _buildArcadeBanner() {
    return GestureDetector(
      onTap: () {
        music.play(click);
        Navigator.push(context,
            CupertinoPageRoute(builder: (_) => const ArcadeScreen()));
      },
      child: Container(
        decoration: cardDecoration(radius: 22),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Arcade',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: inkColor)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: xSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('6 GAMES',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: xColor,
                              letterSpacing: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('RPS · Connect 4 · Checkers & more',
                    style: TextStyle(fontSize: 12, color: ink2Color)),
              ],
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: ink3Color),
          ],
        ),
      ),
    );
  }

  // ─── Quick-play bottom sheet ───────────────────────────────────────────────

  void _showModeSheet() {
    music.play(click);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickPlaySheet(
        onSinglePlayer: () {
          Navigator.pop(context);
          playButtonPressed(0);
        },
        onPassNPlay: () {
          Navigator.pop(context);
          playButtonPressed(2);
        },
        onRanked: () {
          Navigator.pop(context);
          playButtonPressed(1);
        },
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

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
    Navigator.push(
        context,
        CupertinoPageRoute(
            builder: (_) => const PrivateRoomScreen()));
  }

  void _openBlitz() {
    music.play(click);
    selectedMatrixIndex = "Three";
    showLevelDialog(isBlitz: true);
  }

  void _openStreak() {
    music.play(click);
    Navigator.push(
        context,
        CupertinoPageRoute(
            builder: (_) => StreakModeScreen(
                  playerSkin:
                      userSkin.isNotEmpty ? userSkin : 'cross_skin',
                  opponentSkin:
                      opponentSkin.isNotEmpty ? opponentSkin : 'circle_skin',
                )));
  }

  void _openDaily() {
    music.play(click);
    Navigator.push(
        context,
        CupertinoPageRoute(
            builder: (_) => const DailyChallengeScreen()));
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
      builder: (context) => Dialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                utils.getTranslated(context, "selectLevel"),
                style: TextStyle(
                    color: inkColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 17),
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (BuildContext context, StateSetter setDialogState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: typeOfLevel
                        .map((levelName) => GestureDetector(
                              onTap: () {
                                music.play(dice);
                                setDialogState(() {
                                  selectedLevelIndex =
                                      typeOfLevel.indexOf(levelName);
                                });
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 5),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 180),
                                  decoration: BoxDecoration(
                                    color: selectedLevelIndex ==
                                            typeOfLevel.indexOf(levelName)
                                        ? xColor
                                        : surface2Color,
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    border: Border.all(
                                      color: selectedLevelIndex ==
                                              typeOfLevel.indexOf(levelName)
                                          ? xColor
                                          : lineColor,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Center(
                                      child: Text(
                                        utils.getTranslated(
                                            context, levelName),
                                        style: TextStyle(
                                          color: selectedLevelIndex ==
                                                  typeOfLevel
                                                      .indexOf(levelName)
                                              ? Colors.white
                                              : inkColor,
                                          fontWeight: FontWeight.w600,
                                        ),
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
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: xColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  minimumSize: const Size(double.infinity, 48),
                  elevation: 0,
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
                        timerSeconds:
                            isBlitz ? blitzCountdown : countdowntime,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(utils.getTranslated(context, "next")),
              ),
            ],
          ),
        ),
      ),
    );
  }

  selectPassNPlayDialog() {
    player1controller.clear();
    player2controller.clear();
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                utils.getTranslated(context, "passNplayDialoge"),
                style: TextStyle(
                    color: inkColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 17),
              ),
              const SizedBox(height: 16),
              _nameField(player1controller, userSkin),
              const SizedBox(height: 10),
              _nameField(player2controller, opponentSkin),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: xColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  minimumSize: const Size(double.infinity, 48),
                  elevation: 0,
                ),
                onPressed: () async {
                  music.play(click);
                  if (player1controller.text.isNotEmpty &&
                      player2controller.text.isNotEmpty) {
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
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(utils.getTranslated(context, "start")),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nameField(TextEditingController ctrl, String skinName) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: surface2Color,
        border: Border.all(color: lineColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: ctrl,
        style: TextStyle(fontSize: 14, color: inkColor),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: utils.getTranslated(context, "playerName"),
          hintStyle: TextStyle(color: ink3Color),
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
        var diff = DateTime.now()
            .difference(DateTime.parse(value["time"]))
            .inMinutes;
        if (diff > 15) Dialogue.removeChild("Game", key);
      });
    }
  }
}

// ── Coin chip ─────────────────────────────────────────────────────────────────

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
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: goldSoft,
      border: Border.all(color: goldColor.withValues(alpha: 0.3), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.monetization_on_rounded, color: goldColor, size: 16),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: const Color(0xFF9A6516),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins')),
      ],
    ),
  );
}

// ── Mode card ──────────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String sub;
  final VoidCallback onTap;
  final bool accent;

  const _ModeCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.sub,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: accent ? xColor.withValues(alpha: 0.06) : surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: accent ? xColor.withValues(alpha: 0.3) : lineColor),
          boxShadow: [shadowSm],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 23),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: inkColor)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style:
                          TextStyle(fontSize: 12, color: ink2Color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: ink3Color, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: ink3Color,
          )),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String label;
  static const double size = 46;
  const _Avatar({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: surface2Color,
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: lineColor),
      ),
      child: Center(
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: size * 0.4,
                color: inkColor)),
      ),
    );
  }
}

// ── Rank badge (simple) ────────────────────────────────────────────────────────

class _UserRankBadge extends StatelessWidget {
  final int score;
  final String size;
  const _UserRankBadge({required this.score, this.size = 'md'});

  static const _tiers = [
    {'label': 'Diamond', 'min': 7000, 'color': 0xFF5C8DF6},
    {'label': 'Platinum', 'min': 3500, 'color': 0xFF42B8B0},
    {'label': 'Gold', 'min': 1500, 'color': 0xFFE0A92B},
    {'label': 'Silver', 'min': 500, 'color': 0xFF9AA3B2},
    {'label': 'Bronze', 'min': 0, 'color': 0xFFB0794B},
  ];

  Map<String, dynamic> get _tier {
    for (final t in _tiers) {
      if (score >= (t['min'] as int)) return t;
    }
    return _tiers.last;
  }

  @override
  Widget build(BuildContext context) {
    final t = _tier;
    final col = Color(t['color'] as int);
    final small = size == 'sm';
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 9 : 11, vertical: small ? 4 : 6),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: small ? 6 : 7,
            height: small ? 6 : 7,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: col),
          ),
          const SizedBox(width: 5),
          Text(t['label'] as String,
              style: TextStyle(
                  color: col,
                  fontWeight: FontWeight.w700,
                  fontSize: small ? 11 : 12.5)),
        ],
      ),
    );
  }
}

// ── X / O decorative marks ────────────────────────────────────────────────────

class _XMark extends StatelessWidget {
  final double size;
  final Color color;
  const _XMark({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        size: Size(size, size), painter: _XPainter(color: color));
  }
}

class _XPainter extends CustomPainter {
  final Color color;
  _XPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round;
    final pad = size.width * 0.22;
    canvas.drawLine(Offset(pad, pad), Offset(size.width - pad, size.height - pad), paint);
    canvas.drawLine(Offset(size.width - pad, pad), Offset(pad, size.height - pad), paint);
  }

  @override
  bool shouldRepaint(_XPainter old) => old.color != color;
}

class _OMark extends StatelessWidget {
  final double size;
  final Color color;
  const _OMark({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        size: Size(size, size), painter: _OPainter(color: color));
  }
}

class _OPainter extends CustomPainter {
  final Color color;
  _OPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.width * 0.3, paint);
  }

  @override
  bool shouldRepaint(_OPainter old) => old.color != color;
}

// ── Quick play bottom sheet ────────────────────────────────────────────────────

class _QuickPlaySheet extends StatelessWidget {
  final VoidCallback onSinglePlayer;
  final VoidCallback onPassNPlay;
  final VoidCallback onRanked;

  const _QuickPlaySheet({
    required this.onSinglePlayer,
    required this.onPassNPlay,
    required this.onRanked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [shadowLg],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: lineColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 20),
          Text('Choose Mode',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  color: inkColor)),
          const SizedBox(height: 6),
          Text('Pick an opponent to get started',
              style: TextStyle(fontSize: 13.5, color: ink2Color)),
          const SizedBox(height: 20),
          _SheetTile(
            icon: Icons.smart_toy_outlined,
            color: xColor,
            bg: xSoft,
            title: 'vs Computer',
            sub: 'Play DORA across Easy → Hard',
            onTap: onSinglePlayer,
          ),
          const SizedBox(height: 11),
          _SheetTile(
            icon: Icons.people_alt_outlined,
            color: oColor,
            bg: oSoft,
            title: 'Pass & Play',
            sub: 'Two players, one device',
            onTap: onPassNPlay,
          ),
          const SizedBox(height: 11),
          _SheetTile(
            icon: Icons.public,
            color: goldColor,
            bg: goldSoft,
            title: 'Online Ranked',
            sub: 'Matchmake & earn rank points',
            onTap: onRanked,
          ),
        ],
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final String title;
  final String sub;
  final VoidCallback onTap;

  const _SheetTile({
    required this.icon,
    required this.color,
    required this.bg,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: lineColor),
          boxShadow: [shadowSm],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: inkColor)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(fontSize: 13, color: ink2Color)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: ink3Color, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Chip grid (kept for compatibility with dialogs) ───────────────────────────

class ChipGrid extends StatefulWidget {
  final List list;
  final Function(int i) onChange;
  final bool avatar;

  const ChipGrid(
      {super.key,
      required this.list,
      required this.onChange,
      required this.avatar});

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
              setState(() {
                selectedIndex = i;
              });
              if (widget.avatar == false) {
                widget.onChange(selectedIndex);
              } else {
                widget.onChange(widget.list[selectedIndex]);
              }
            },
            child: Chip(
              backgroundColor:
                  selectedIndex == i ? xColor : surface2Color,
              side: BorderSide(color: lineColor),
              label: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: widget.avatar ? 0 : 8.0),
                child: Text(widget.list[i].toString(),
                    style: TextStyle(
                        color:
                            selectedIndex == i ? Colors.white : inkColor,
                        fontWeight: FontWeight.w600)),
              ),
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
