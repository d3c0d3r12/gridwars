import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../helpers/utils.dart';

/// Brain Tricks leaderboard — ranks every player by `brainScore` (the number of
/// puzzles they've solved), highest at the top. Mirrors the data-access pattern
/// of the main leaderboard (`users` ordered by a score field).
class BrainLeaderboardScreen extends StatefulWidget {
  const BrainLeaderboardScreen({super.key});

  @override
  State<BrainLeaderboardScreen> createState() => _BrainLeaderboardScreenState();
}

class _BrainLeaderboardScreenState extends State<BrainLeaderboardScreen> {
  final _auth = FirebaseAuth.instance;
  late final Future<List<Map>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map>> _load() async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .orderByChild('brainScore')
          .limitToLast(100)
          .once();
      if (snap.snapshot.value == null) return [];
      final raw = Map<String, dynamic>.from(snap.snapshot.value as Map);
      final list = raw.entries
          .where((e) {
            final v = (e.value as Map)['brainScore'];
            return v != null && (v is int ? v : int.tryParse('$v') ?? 0) > 0;
          })
          .map((e) => {
                ...Map<String, dynamic>.from(e.value as Map),
                'userid': e.key,
              })
          .toList();
      list.sort((a, b) =>
          (_score(b)).compareTo(_score(a)));
      return list;
    } catch (e) {
      return [];
    }
  }

  int _score(Map p) {
    final v = p['brainScore'];
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: FutureBuilder<List<Map>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Center(
                        child: CircularProgressIndicator(color: xColor));
                  }
                  final data = snap.data ?? [];
                  final myUid = _auth.currentUser?.uid ?? '';
                  final myIdx =
                      data.indexWhere((p) => p['userid'] == myUid);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    children: [
                      if (myIdx >= 0) ...[
                        _myRankCard(myIdx + 1, data[myIdx]),
                        const SizedBox(height: 16),
                      ],
                      if (data.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Text(
                              'No scores yet.\nSolve puzzles to claim the top spot!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: ink3Color, height: 1.5),
                            ),
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
                            children: [
                              for (int i = 0; i < data.length; i++)
                                _row(i, data[i], data[i]['userid'] == myUid,
                                    i == data.length - 1),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
                Text('Brain Tricks',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: inkColor)),
                Text('Most puzzles solved · top of the pack',
                    style: TextStyle(fontSize: 12.5, color: ink2Color)),
              ],
            ),
          ),
          Icon(Icons.emoji_events_rounded, color: goldColor, size: 28),
        ],
      ),
    );
  }

  Widget _myRankCard(int rank, Map p) {
    final pic = p['profilePic']?.toString() ?? guestProfilePic;
    final name = p['username']?.toString() ?? 'You';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [xColor, const Color(0xFF8E24AA)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [shadow],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text('#$rank',
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(width: 14),
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white24,
            backgroundImage:
                NetworkImage(pic.isEmpty ? guestProfilePic : pic),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Utils().limitChar(name),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Colors.white)),
                const Text('You',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_score(p)}',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const Text('solved',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(int i, Map p, bool isYou, bool isLast) {
    final pic = p['profilePic']?.toString() ?? guestProfilePic;
    final name = p['username']?.toString() ?? '';
    const medals = [
      Color(0xFFE0A92B),
      Color(0xFF9AA3B2),
      Color(0xFFB0794B),
    ];
    return Container(
      color: isYou ? xSoft : Colors.transparent,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: i < 3
                      ? Icon(Icons.emoji_events_rounded,
                          color: medals[i], size: 20)
                      : Text('${i + 1}',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: ink3Color)),
                ),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: surface2Color,
                  backgroundImage:
                      NetworkImage(pic.isEmpty ? guestProfilePic : pic),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name.isEmpty ? 'Player' : Utils().limitChar(name, 18),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: inkColor),
                  ),
                ),
                Text('${_score(p)}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: inkColor)),
                const SizedBox(width: 4),
                Text('solved',
                    style: TextStyle(fontSize: 11, color: ink3Color)),
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
