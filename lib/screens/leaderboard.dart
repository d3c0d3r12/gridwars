import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../helpers/utils.dart';
import '../functions/advertisement.dart';
import '../functions/getCoin.dart';
import 'splash.dart';

class LeaderBoardScreen extends StatefulWidget {
  LeaderBoardScreen({super.key});

  @override
  _LeaderBoardScreenState createState() => _LeaderBoardScreenState();
}

class _LeaderBoardScreenState extends State<LeaderBoardScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int? yourRank = 0, yourScore = 0;
  String profilePic = guestProfilePic, username = "";
  var ins = GetUserInfo();
  late final Future<List<Map>> _leaderboardFuture;
  String _tab = 'global';

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    Advertisement.loadAd();
    _leaderboardFuture = leaderBoard();
    fetchUserDetails();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> fetchUserDetails() async {
    profilePic = await ins.getFieldValue("profilePic");
    username = await ins.getFieldValue("username");
    List<Map> result = await _leaderboardFuture;
    int count = 1;
    for (final element in result) {
      if (_auth.currentUser!.uid == element["userid"]) {
        if (mounted) {
          setState(() {
            yourRank = count;
            yourScore = element["score"];
          });
        }
      }
      count++;
    }
  }

  Future<List<Map>> leaderBoard() async {
    final snap = await FirebaseDatabase.instance
        .ref()
        .child("users")
        .orderByChild("score")
        .limitToLast(100)
        .once();

    if (snap.snapshot.value == null) return [];

    final raw = Map<String, dynamic>.from(snap.snapshot.value as Map);
    final result = raw.entries
        .where((e) {
          final score = (e.value as Map)["score"];
          return score != null && score != 0;
        })
        .map((e) => {
              ...Map<String, dynamic>.from(e.value as Map),
              "userid": e.key,
            })
        .toList();

    result.sort((a, b) => (b["score"] as int).compareTo(a["score"] as int));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) => music.play(click),
      child: Scaffold(
        backgroundColor: bgColor,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                music.play(click);
                Navigator.pop(context);
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
                child: Icon(Icons.arrow_back_rounded, color: inkColor, size: 20),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Leaderboard',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                          color: inkColor)),
                  Text('Top strategists this season.',
                      style: TextStyle(fontSize: 13, color: ink2Color)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _showRankHelp(context),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: lineColor),
                  boxShadow: [shadowSm],
                ),
                child: Icon(Icons.help_outline_rounded,
                    color: ink2Color, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return FutureBuilder<List<Map<dynamic, dynamic>>>(
      future: _leaderboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(
                  color: xColor, strokeWidth: 2.5));
        }

        final data = snapshot.data ?? [];

        final myRankIdx = data.indexWhere((p) =>
            (_auth.currentUser?.uid ?? '') == p['userid']);
        final myRank = myRankIdx >= 0 ? myRankIdx + 1 : null;
        final myScore =
            myRank != null ? (data[myRankIdx]['score'] as int? ?? 0) : 0;
        final myName =
            myRank != null ? (data[myRankIdx]['username'] ?? '') : username;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            // Your rank card
            if (myRank != null) ...[
              _buildMyRankCard(
                  myRank, myName.toString(), myScore, profilePic),
              const SizedBox(height: 18),
            ],

            // Tab segmented control
            _buildTabSegment(),
            const SizedBox(height: 16),

            // Leaderboard list
            if (data.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text('No players yet.',
                      style: TextStyle(color: ink3Color)),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: lineColor),
                  boxShadow: [shadowSm],
                ),
                clipBehavior: Clip.hardEdge,
                child: Column(
                  children: data
                      .asMap()
                      .entries
                      .where((e) => e.value['score'] != 0)
                      .map((e) {
                    final i = e.key;
                    final p = e.value;
                    final isYou = (_auth.currentUser?.uid ?? '') == p['userid'];
                    return _buildPlayerRow(i, p, isYou,
                        i == data.length - 1 ||
                            data[i + 1 < data.length ? i + 1 : i]['score'] ==
                                0);
                  }).toList(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMyRankCard(
      int rank, String name, int score, String pic) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: xSoft),
        boxShadow: [shadowSm],
        gradient: LinearGradient(
          colors: [xSoft, surfaceColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text('#$rank',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: xColor)),
          const SizedBox(width: 12),
          CircleAvatar(
            backgroundImage: NetworkImage(
                pic.isEmpty ? guestProfilePic : pic),
            radius: 22,
            backgroundColor: surface2Color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(utils.limitChar(name),
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: inkColor)),
                    ),
                    const SizedBox(width: 6),
                    Text('· you',
                        style:
                            TextStyle(color: ink3Color, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                _RankBadge(score: score, size: 'sm'),
              ],
            ),
          ),
          Text(score.toString(),
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: inkColor)),
        ],
      ),
    );
  }

  Widget _buildTabSegment() {
    return Container(
      decoration: BoxDecoration(
        color: surface2Color,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _TabBtn(label: 'Global', active: _tab == 'global',
              onTap: () => setState(() => _tab = 'global')),
          _TabBtn(label: 'Friends', active: _tab == 'friends',
              onTap: () => setState(() => _tab = 'friends')),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(
      int i, Map p, bool isYou, bool isLast) {
    final score = p['score'] as int? ?? 0;
    final name = p['username']?.toString() ?? '';
    final pic = p['profilePic']?.toString() ?? guestProfilePic;
    final medals = [
      const Color(0xFFE0A92B),
      const Color(0xFF9AA3B2),
      const Color(0xFFB0794B)
    ];

    return Container(
      color: isYou ? xSoft : Colors.transparent,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 13),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: i < 3
                      ? Icon(Icons.emoji_events_rounded,
                          color: medals[i], size: 18)
                      : Text('${i + 1}',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: ink3Color)),
                ),
                CircleAvatar(
                  backgroundImage: NetworkImage(
                      pic.isEmpty ? guestProfilePic : pic),
                  radius: 18,
                  backgroundColor: surface2Color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(utils.limitChar(name, 18),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: inkColor)),
                      Text('${p['matchwon'] ?? 0} wins',
                          style: TextStyle(
                              fontSize: 11.5, color: ink3Color)),
                    ],
                  ),
                ),
                _RankBadge(score: score, size: 'sm'),
                const SizedBox(width: 8),
                Text(
                  score >= 1000
                      ? '${(score / 1000).toStringAsFixed(1)}k'
                      : '$score',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: inkColor),
                ),
              ],
            ),
          ),
          if (!isLast)
            Divider(height: 1, color: line2Color, indent: 16, endIndent: 16),
        ],
      ),
    );
  }
}

// ── Tab button ─────────────────────────────────────────────────────────────────

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? surfaceColor : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: active ? [shadowSm] : [],
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: active ? inkColor : ink2Color)),
        ),
      ),
    );
  }
}

// ── Rank badge ────────────────────────────────────────────────────────────────

class _RankBadge extends StatelessWidget {
  final int score;
  final String size;
  const _RankBadge({required this.score, this.size = 'md'});

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
    final sm = size == 'sm';
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: sm ? 9 : 11, vertical: sm ? 4 : 6),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: sm ? 6 : 7,
              height: sm ? 6 : 7,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: col)),
          const SizedBox(width: 5),
          Text(t['label'] as String,
              style: TextStyle(
                  color: col,
                  fontWeight: FontWeight.w700,
                  fontSize: sm ? 11 : 12.5)),
        ],
      ),
    );
  }
}

// ── Help overlay ──────────────────────────────────────────────────────────────

void _showRankHelp(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
          const SizedBox(height: 18),
          Text('Rank Tiers',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: inkColor)),
          const SizedBox(height: 16),
          ...const [
            _TierRow(
                label: 'Diamond',
                min: 7000,
                color: Color(0xFF5C8DF6)),
            _TierRow(
                label: 'Platinum',
                min: 3500,
                color: Color(0xFF42B8B0)),
            _TierRow(
                label: 'Gold',
                min: 1500,
                color: Color(0xFFE0A92B)),
            _TierRow(
                label: 'Silver',
                min: 500,
                color: Color(0xFF9AA3B2)),
            _TierRow(
                label: 'Bronze',
                min: 0,
                color: Color(0xFFB0794B)),
          ],
        ],
      ),
    ),
  );
}

class _TierRow extends StatelessWidget {
  final String label;
  final int min;
  final Color color;
  const _TierRow(
      {required this.label, required this.min, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  color: inkColor)),
          const Spacer(),
          Text(min == 0 ? '0+' : '$min+ pts',
              style: TextStyle(fontSize: 13, color: ink2Color)),
        ],
      ),
    );
  }
}
