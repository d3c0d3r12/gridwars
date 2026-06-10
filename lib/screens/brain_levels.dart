import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../helpers/utils.dart';
import '../helpers/puzzle_models.dart';
import '../functions/hint_service.dart';
import '../functions/rewarded_ad_service.dart';
import '../functions/puzzle_repository.dart';
import 'brain_puzzle.dart';
import 'brain_leaderboard.dart';

/// Level-select hub for Brain Tricks: shows the bulb balance, a "continue"
/// shortcut, a watch-ad-for-bulbs button, and the grid of unlockable levels.
class BrainLevelsScreen extends StatefulWidget {
  const BrainLevelsScreen({super.key});

  @override
  State<BrainLevelsScreen> createState() => _BrainLevelsScreenState();
}

class _BrainLevelsScreenState extends State<BrainLevelsScreen> {
  int _bulbs = 0;
  int _reached = 1;
  Set<int> _completed = {};
  bool _ready = false;
  List<PuzzleLevel> _levels = const [];

  @override
  void initState() {
    super.initState();
    RewardedAdService.preload();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await HintService.init();
    _levels = await PuzzleRepository.getLevels();
    await _refresh();
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _refresh() async {
    final b = await HintService.getBulbs();
    final r = await HintService.getCurrentLevel();
    final c = await HintService.completedLevels();
    if (mounted) {
      setState(() {
        _bulbs = b;
        _reached = r;
        _completed = c;
      });
    }
  }

  Future<void> _openLevel(int index) async {
    music.play(click);
    await Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => BrainPuzzleScreen(levels: _levels, startIndex: index),
    ));
    await _refresh();
  }

  Future<void> _watchAd() async {
    final res = await RewardedAdService.showForReward(onReward: () async {
      await HintService.addBulbs(kAdBulbReward);
      await _refresh();
      _snack('+$kAdBulbReward bulbs! 💡');
    });
    if (!res.shown) {
      _snack(res.reason == 'limit'
          ? "You've hit today's ad limit. Come back tomorrow!"
          : 'No ad available right now — try again shortly.');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: inkColor,
      behavior: SnackBarBehavior.floating,
      content: Text(msg, style: TextStyle(color: surfaceColor)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Guard: until levels load, _levels is empty so length-1 is -1 and clamp
    // would throw ArgumentError(0) ("Invalid argument(s): 0" red screen).
    final continueIndex = _levels.isEmpty
        ? 0
        : (_reached - 1).clamp(0, _levels.length - 1);
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: (!_ready || _levels.isEmpty)
            ? Center(child: CircularProgressIndicator(color: xColor))
            : Column(
                children: [
                  _header(),
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _continueCard(continueIndex)),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => _levelTile(i),
                              childCount: _levels.length,
                            ),
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

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              music.play(click);
              Navigator.of(context).pop();
            },
            icon: Icon(Icons.arrow_back_rounded, color: inkColor),
          ),
          Expanded(
            child: Text('Brain Tricks',
                style: TextStyle(
                    color: inkColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
          ),
          GestureDetector(
            onTap: () {
              music.play(click);
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const BrainLeaderboardScreen()));
            },
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: goldSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: goldColor.withValues(alpha: 0.4)),
              ),
              child: Icon(Icons.emoji_events_rounded,
                  color: goldColor, size: 20),
            ),
          ),
          GestureDetector(
            onTap: _watchAd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: goldSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: goldColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lightbulb_rounded, color: goldColor, size: 18),
                  const SizedBox(width: 5),
                  Text('$_bulbs',
                      style: TextStyle(
                          color: inkColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                        color: goldColor, shape: BoxShape.circle),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _continueCard(int index) {
    final levelNo = _levels[index].id;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [xColor, const Color(0xFF8E24AA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [shadow],
      ),
      child: Row(
        children: [
          const Icon(Icons.psychology_rounded, color: Colors.white, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _completed.isEmpty ? 'Start playing' : 'Continue',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text('Level $levelNo',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _openLevel(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded, color: xColor),
                  const SizedBox(width: 4),
                  Text('Play',
                      style: TextStyle(
                          color: xColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelTile(int i) {
    final lvl = _levels[i];
    final unlocked = lvl.id <= _reached;
    final done = _completed.contains(lvl.id);
    return GestureDetector(
      onTap: unlocked ? () => _openLevel(i) : null,
      child: Container(
        decoration: BoxDecoration(
          color: done
              ? goodColor.withValues(alpha: 0.12)
              : unlocked
                  ? surfaceColor
                  : surface2Color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: done ? goodColor.withValues(alpha: 0.5) : lineColor,
            width: done ? 1.5 : 1,
          ),
          boxShadow: unlocked ? [shadowSm] : null,
        ),
        child: Center(
          child: !unlocked
              ? Icon(Icons.lock_rounded, color: ink3Color, size: 22)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${lvl.id}',
                        style: TextStyle(
                            color: inkColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    if (done)
                      Icon(Icons.check_circle_rounded,
                          color: goodColor, size: 16),
                  ],
                ),
        ),
      ),
    );
  }
}
