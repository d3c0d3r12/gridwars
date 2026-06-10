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
import '../functions/hint_service.dart';
import '../functions/friend_service.dart';
import '../functions/notification_service.dart';
import '../functions/push_service.dart';
import '../helpers/game_tags.dart';
import 'admin_panel.dart';
import 'arcade.dart';
import 'daily_challenge.dart';
import 'finding_player.dart';
import 'friend_challenge.dart';
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
  StreamSubscription? _challengeSub;
  bool _isAdmin = false;
  bool _challengePrimed = false;
  final Set<String> _seenChallenges = {};

  @override
  void initState() {
    super.initState();
    _checkAdminAndBan();
    _startNotifications();
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

    // Print the signed-in account so the owner UID can be granted admin in the
    // Firebase console (admins/{uid}: true).
    debugPrint(
        'ACCOUNT_UID=$uid EMAIL=${FirebaseAuth.instance.currentUser?.email}');

    // Owner account → unlimited coins + bulbs.
    HintService.ownerTopUp();

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

  // Start in-app notifications (badges + banners) and listen for game challenges.
  void _startNotifications() {
    FriendService.goOnline();
    // WhatsApp-style background push (FCM): register token + foreground banners.
    PushService.instance.start();
    NotificationService.instance.onBanner = (msg) {
      if (mounted) utils.setSnackbar(context, msg);
    };
    NotificationService.instance.start();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _challengeSub = FriendService.incomingChallenges().listen((list) {
      if (!mounted) return;
      // Prime on first load so existing challenges don't auto-pop a dialog.
      if (!_challengePrimed) {
        _challengePrimed = true;
        _seenChallenges.addAll(list.map((c) => c.id));
        return;
      }
      for (final c in list) {
        if (_seenChallenges.add(c.id)) {
          _showChallengeDialog(c);
          break; // one at a time
        }
      }
      _seenChallenges.retainWhere((id) => list.any((c) => c.id == id));
    });
  }

  void _showChallengeDialog(Challenge c) {
    final g = tagById(c.gameType);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(g.icon, color: g.color, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text('Game Challenge',
              style: TextStyle(color: inkColor, fontWeight: FontWeight.w800, fontSize: 17))),
        ]),
        content: Text(
          '${utils.limitChar(c.fromName, 16)} challenged you to ${g.name}!\nEntry: $fixedEntryFee coins.',
          style: TextStyle(color: ink2Color, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              FriendService.removeChallenge(c.id);
            },
            child: Text('Decline', style: TextStyle(color: ink2Color)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              acceptIncomingChallenge(context, c);
            },
            child: Text('Accept', style: TextStyle(color: g.color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _coinSub?.cancel();
    _banSub?.cancel();
    _challengeSub?.cancel();
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
                SliverToBoxAdapter(child: _buildFriendsRoomCard()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                    child: Row(
                      children: [
                        _SectionLabel(label: 'All Games'),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: goldSoft,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: goldColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.emoji_events_rounded,
                                color: goldColor, size: 13),
                            const SizedBox(width: 4),
                            Text('Ranked on every game',
                                style: TextStyle(
                                    color: const Color(0xFF9A6516),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10.5)),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.92,
                    ),
                    delegate: SliverChildListDelegate(_allGameTiles()),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 18),
                      _buildDailyStrip(),
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
                    Text('CHILL',
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
            // Profile button (with social notification badge)
            GestureDetector(
              onTap: () {
                music.play(click);
                Navigator.pushNamed(context, "/profile").then((_) {
                  _getSavedLanguage();
                  getSkinvalues();
                  setState(() {});
                });
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
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
                  Positioned(
                    right: -3, top: -3,
                    child: ValueListenableBuilder<int>(
                      valueListenable: NotificationService.instance.totalBadge,
                      builder: (_, n, __) {
                        if (n == 0) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          decoration: BoxDecoration(
                            color: red, shape: BoxShape.circle,
                            border: Border.all(color: bgColor, width: 1.5),
                          ),
                          child: Text(n > 9 ? '9+' : '$n',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 9, fontWeight: FontWeight.w800)),
                        );
                      },
                    ),
                  ),
                ],
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

  // ─── Play with Friends (private room: create / join by code) ────────────────

  Widget _buildFriendsRoomCard() {
    const teal = Color(0xFF00BCD4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: GestureDetector(
        onTap: _openPrivateRoom,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: teal.withValues(alpha: 0.35)),
            boxShadow: [shadowSm],
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [teal.withValues(alpha: 0.12), surfaceColor],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [shadowSm],
                ),
                child: const Icon(Icons.groups_rounded, color: teal, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Play with Friends',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: inkColor)),
                    const SizedBox(height: 2),
                    Text('Create or join a room with a code',
                        style: TextStyle(fontSize: 12, color: ink2Color)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: teal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 3),
                  Text('Create / Join',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ]),
              ),
            ],
          ),
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

  // ─── Unified game grid ─────────────────────────────────────────────────────

  // All games in one section — Tic Tac Toe sits alongside every arcade game,
  // no longer singled out. Tic Tac Toe opens its own modes sheet; the rest
  // reuse the arcade mode chooser (online ranked + free vs-Computer).
  List<Widget> _allGameTiles() {
    return [
      _HomeGameTile(
        name: 'Tic Tac Toe',
        desc: 'The classic 3-in-a-row',
        icon: Icons.close_rounded,
        accent: xColor,
        onTap: () {
          music.play(click);
          _showXoModeSheet();
        },
      ),
      for (final g in kArcadeGames)
        _HomeGameTile(
          name: g.name.replaceAll('\n', ' '),
          desc: g.desc,
          icon: g.icon,
          accent: g.accent,
          onTap: () {
            music.play(click);
            openArcadeModeSheet(context, g);
          },
        ),
    ];
  }

  // Tic-Tac-Toe modes (online ranked awards rank just like every other game).
  void _showXoModeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [shadowLg],
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: SingleChildScrollView(
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
              const SizedBox(height: 18),
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: xSoft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.close_rounded, color: xColor, size: 24),
                ),
                const SizedBox(width: 12),
                Text('Tic Tac Toe',
                    style: TextStyle(
                        color: inkColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 18)),
              ]),
              const SizedBox(height: 18),
              _SheetTile(
                icon: Icons.public,
                color: goldColor,
                bg: goldSoft,
                title: 'Online Ranked',
                sub: 'Matchmake & climb the leaderboard',
                onTap: () {
                  Navigator.pop(ctx);
                  playButtonPressed(1);
                },
              ),
              const SizedBox(height: 11),
              _SheetTile(
                icon: Icons.smart_toy_outlined,
                color: xColor,
                bg: xSoft,
                title: 'vs Computer',
                sub: 'Play DORA across Easy → Hard',
                onTap: () {
                  Navigator.pop(ctx);
                  playButtonPressed(0);
                },
              ),
              const SizedBox(height: 11),
              _SheetTile(
                icon: Icons.people_alt_outlined,
                color: oColor,
                bg: oSoft,
                title: 'Pass & Play',
                sub: 'Two players, one device',
                onTap: () {
                  Navigator.pop(ctx);
                  playButtonPressed(2);
                },
              ),
              const SizedBox(height: 11),
              _SheetTile(
                icon: Icons.bolt,
                color: const Color(0xFFFF5252),
                bg: const Color(0xFFFF5252).withValues(alpha: 0.12),
                title: 'Blitz Mode',
                sub: '7 seconds per move — think fast!',
                onTap: () {
                  Navigator.pop(ctx);
                  _openBlitz();
                },
              ),
              const SizedBox(height: 11),
              _SheetTile(
                icon: Icons.local_fire_department,
                color: const Color(0xFF66BB6A),
                bg: const Color(0xFF66BB6A).withValues(alpha: 0.12),
                title: 'Streak Challenge',
                sub: 'Beat STRIKER in a row, earn coins',
                onTap: () {
                  Navigator.pop(ctx);
                  _openStreak();
                },
              ),
            ],
          ),
        ),
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

// ── Home game tile (unified grid) ──────────────────────────────────────────────

class _HomeGameTile extends StatelessWidget {
  final String name;
  final String desc;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _HomeGameTile({
    required this.name,
    required this.desc,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: lineColor),
          boxShadow: [shadowSm],
        ),
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: accent, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: TextStyle(
                  color: inkColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 1.2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            Expanded(
              child: Text(
                desc,
                style: TextStyle(color: ink2Color, fontSize: 11.5, height: 1.4),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Play',
                    style: TextStyle(
                        color: ink3Color,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5)),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.play_arrow_rounded, color: accent, size: 18),
                ),
              ],
            ),
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
