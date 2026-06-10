import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../helpers/utils.dart';
import 'arcade_lobby.dart';
import 'games/uno_game.dart';
import 'games/parchi_game.dart';
import 'games/liars_game.dart';
import 'games/liars_dice_game.dart';
import 'uno_lobby.dart';
import 'parchi_lobby.dart';
import 'liars_lobby.dart';
import 'home_screen.dart';
import 'brain_levels.dart';

class GameMeta {
  final String type, name, desc;
  final IconData icon;
  final Color accent;
  const GameMeta(this.type, this.name, this.desc, this.icon, this.accent);
}

const kArcadeGames = [
  GameMeta('rps', 'Rock Paper\nScissors', 'Best of 5 — pick fast!',
      Icons.sports_mma, Color(0xFFE53935)),
  GameMeta('connect4', 'Connect 4', 'Drop pieces, align 4 to win',
      Icons.grid_on, Color(0xFFFF7043)),
  GameMeta('gomoku', 'Gomoku', '5 in a row on 11×11 grid',
      Icons.circle_outlined, Color(0xFF7B1FA2)),
  GameMeta('dotsboxes', 'Dots & Boxes', 'Draw lines, claim boxes',
      Icons.grid_3x3, Color(0xFF1565C0)),
  GameMeta('checkers', 'Checkers', 'Classic draughts battle',
      Icons.apps, Color(0xFF2E7D32)),
  GameMeta('battleship', 'Battleship', 'Place ships, fire torpedoes',
      Icons.sailing, Color(0xFF00838F)),
  GameMeta('uno', 'UNO', 'Classic card game — vs AI or friends',
      Icons.style_rounded, Color(0xFFD32F2F)),
  GameMeta('parchi', '16 Parchi', 'Dhapp! Collect 4, slap the fastest',
      Icons.front_hand_rounded, Color(0xFF00897B)),
  GameMeta('liars', "Liar's Bar", 'Bluff or get shot — cards & dice',
      Icons.casino_rounded, Color(0xFF8E1D2C)),
  GameMeta('braintest', 'Brain Tricks', 'Tricky puzzles — outsmart them all',
      Icons.psychology_rounded, Color(0xFF8E24AA)),
];

/// Opens the right mode chooser for any arcade game. UNO and Brain Tricks have
/// their own flows. Public so the home screen's unified game grid can reuse it.
void openArcadeModeSheet(BuildContext context, GameMeta game) {
  if (game.type == 'uno') {
    _showUnoModeSheet(context, game);
  } else if (game.type == 'parchi') {
    _showParchiModeSheet(context, game);
  } else if (game.type == 'liars') {
    _showLiarsModeSheet(context, game);
  } else if (game.type == 'braintest') {
    // Single-player puzzle game — go straight to the level select.
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const BrainLevelsScreen(),
    ));
  } else {
    _showModeSheet(context, game);
  }
}

class ArcadeScreen extends StatefulWidget {
  const ArcadeScreen({super.key});

  @override
  State<ArcadeScreen> createState() => _ArcadeScreenState();
}

class _ArcadeScreenState extends State<ArcadeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                        child: Icon(Icons.arrow_back_rounded,
                            color: inkColor, size: 20),
                      ),
                    ),
                    const Spacer(),
                    Column(
                      children: [
                        Text('ARCADE',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: inkColor,
                                letterSpacing: 2.5)),
                        Text('6 multiplayer games',
                            style: TextStyle(
                                color: ink3Color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const Spacer(),
                    CoinWidget(),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Banner strip
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: xSoft),
                    boxShadow: [shadowSm],
                    gradient: LinearGradient(
                      colors: [xSoft, surfaceColor],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [shadowSm],
                        ),
                        child: Icon(Icons.public_rounded,
                            color: xColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Play online for coins',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: inkColor)),
                            Text('Win matches to climb & earn rewards',
                                style: TextStyle(
                                    fontSize: 11.5, color: ink2Color)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: goldSoft,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: goldColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.monetization_on_rounded,
                                color: goldColor, size: 14),
                            const SizedBox(width: 4),
                            Text('$fixedEntryFee',
                                style: TextStyle(
                                    color: const Color(0xFF9A6516),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('CHOOSE A GAME',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                          color: ink3Color)),
                ),
              ),

              const SizedBox(height: 10),

              // Game grid
              Expanded(
                child: GridView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.88,
                  ),
                  itemCount: kArcadeGames.length,
                  itemBuilder: (_, i) => _GameCard(game: kArcadeGames[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final GameMeta game;
  const _GameCard({required this.game});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        music.play(click);
        openArcadeModeSheet(context, game);
      },
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
            // Icon box
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: game.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(game.icon, color: game.accent, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              game.name,
              style: TextStyle(
                  color: inkColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 1.2),
            ),
            const SizedBox(height: 5),
            Expanded(
              child: Text(
                game.desc,
                style:
                    TextStyle(color: ink2Color, fontSize: 11.5, height: 1.4),
              ),
            ),
            // Bottom row: coin + play
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.monetization_on_rounded,
                        color: goldColor, size: 15),
                    const SizedBox(width: 3),
                    Text('$fixedEntryFee',
                        style: TextStyle(
                            color: const Color(0xFF9A6516),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            fontFamily: 'Poppins')),
                  ],
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: game.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.play_arrow_rounded,
                      color: game.accent, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Mode chooser: Play Online (ranked, costs coins) or free vs-Computer practice
// with an Easy/Medium/Hard difficulty pick.
void _showModeSheet(BuildContext context, GameMeta game) {
  showModalBottomSheet(
    context: context,
    backgroundColor: surfaceColor,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: lineColor, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: game.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(game.icon, color: game.accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(game.name.replaceAll('\n', ' '),
                style: TextStyle(
                    color: inkColor, fontWeight: FontWeight.w800, fontSize: 17)),
          ),
        ]),
        const SizedBox(height: 20),

        // Play Online
        GestureDetector(
          onTap: () {
            music.play(click);
            Navigator.pop(ctx);
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (_) => ArcadeLobbyScreen(
                  gameType: game.type,
                  gameName: game.name,
                  accent: game.accent,
                ),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: game.accent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: game.accent.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8))
              ],
            ),
            child: Row(children: [
              const Icon(Icons.public_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Play Online',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ),
              Row(children: [
                const Icon(Icons.monetization_on_rounded,
                    color: Colors.white, size: 15),
                const SizedBox(width: 3),
                Text('$fixedEntryFee',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ]),
            ]),
          ),
        ),

        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Divider(color: lineColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('or practice vs Computer',
                style: TextStyle(color: ink3Color, fontSize: 12)),
          ),
          Expanded(child: Divider(color: lineColor)),
        ]),
        const SizedBox(height: 14),

        Row(children: [
          _diffButton(context, ctx, game, 'Easy', 0, const Color(0xFF43A047)),
          const SizedBox(width: 10),
          _diffButton(context, ctx, game, 'Medium', 1, const Color(0xFFECA13A)),
          const SizedBox(width: 10),
          _diffButton(context, ctx, game, 'Hard', 2, const Color(0xFFE53935)),
        ]),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text('Free practice — no coins won or lost',
              style: TextStyle(color: ink3Color, fontSize: 11.5)),
        ),
      ]),
    ),
  );
}

// UNO has its own flow: free vs-Computer (Easy/Medium/Hard) or a friends lobby.
// A mode (Classic / All Wild / No Mercy) applies to both.
void _showUnoModeSheet(BuildContext context, GameMeta game) {
  String mode = 'classic';
  showModalBottomSheet(
    context: context,
    backgroundColor: surfaceColor,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(color: lineColor, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: game.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(game.icon, color: game.accent, size: 24),
          ),
          const SizedBox(width: 12),
          Text('UNO', style: TextStyle(color: inkColor, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
        ]),
        const SizedBox(height: 16),

        // Mode selector
        Align(alignment: Alignment.centerLeft, child: Text('Mode', style: TextStyle(color: ink3Color, fontSize: 12, fontWeight: FontWeight.w600))),
        const SizedBox(height: 8),
        Row(children: [
          _unoModeChip('Classic', 'classic', mode, (m) => setSheet(() => mode = m)),
          const SizedBox(width: 8),
          _unoModeChip('All Wild', 'allWild', mode, (m) => setSheet(() => mode = m)),
          const SizedBox(width: 8),
          _unoModeChip('No Mercy', 'noMercy', mode, (m) => setSheet(() => mode = m)),
        ]),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(_unoModeDesc(mode), style: TextStyle(color: ink3Color, fontSize: 11.5)),
        ),
        const SizedBox(height: 18),

        Text('Play vs Computer', style: TextStyle(color: ink3Color, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(children: [
          _unoDiffButton(context, ctx, 'Easy', 0, const Color(0xFF43A047), () => mode),
          const SizedBox(width: 10),
          _unoDiffButton(context, ctx, 'Medium', 1, const Color(0xFFECA13A), () => mode),
          const SizedBox(width: 10),
          _unoDiffButton(context, ctx, 'Hard', 2, const Color(0xFFE53935), () => mode),
        ]),

        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Divider(color: lineColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('or', style: TextStyle(color: ink3Color, fontSize: 12)),
          ),
          Expanded(child: Divider(color: lineColor)),
        ]),
        const SizedBox(height: 14),

        // Play with friends (lobby up to 6) — Phase 2.
        GestureDetector(
          onTap: () {
            music.play(click);
            Navigator.pop(ctx);
            Navigator.push(context, CupertinoPageRoute(builder: (_) => const UnoLobbyScreen()));
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
            decoration: BoxDecoration(
              color: game.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: game.accent.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              Icon(Icons.groups_rounded, color: game.accent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Play with Friends (up to 6)',
                    style: TextStyle(color: game.accent, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: game.accent.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.monetization_on_rounded, color: game.accent, size: 12),
                  const SizedBox(width: 3),
                  Text('$fixedEntryFee', style: TextStyle(color: game.accent, fontWeight: FontWeight.w800, fontSize: 11)),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    )),
  );
}

// 16 Parchi: free vs-Computer (Easy/Medium/Hard, 2–4 players) or a friends lobby.
void _showParchiModeSheet(BuildContext context, GameMeta game) {
  int players = 4;
  showModalBottomSheet(
    context: context,
    backgroundColor: surfaceColor,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(color: lineColor, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: game.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(game.icon, color: game.accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('16 Parchi · Dhapp',
                  style: TextStyle(color: inkColor, fontWeight: FontWeight.w900, fontSize: 17)),
              Text('Collect 4 of a kind, then slap the fastest!',
                  style: TextStyle(color: ink3Color, fontSize: 11.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 18),

        Align(alignment: Alignment.centerLeft, child: Text('Players', style: TextStyle(color: ink3Color, fontSize: 12, fontWeight: FontWeight.w600))),
        const SizedBox(height: 8),
        Row(children: [
          for (final p in [2, 3, 4])
            Expanded(child: Padding(
              padding: EdgeInsets.only(right: p == 4 ? 0 : 8),
              child: GestureDetector(
                onTap: () => setSheet(() => players = p),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: players == p ? game.accent : surface2Color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: players == p ? game.accent : lineColor),
                  ),
                  child: Center(child: Text('$p',
                      style: TextStyle(
                          color: players == p ? Colors.white : ink2Color,
                          fontWeight: FontWeight.w800, fontSize: 14))),
                ),
              ),
            )),
        ]),
        const SizedBox(height: 18),

        Text('Play vs Computer', style: TextStyle(color: ink3Color, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(children: [
          _parchiDiffButton(context, ctx, 'Easy', 0, const Color(0xFF43A047), () => players),
          const SizedBox(width: 10),
          _parchiDiffButton(context, ctx, 'Medium', 1, const Color(0xFFECA13A), () => players),
          const SizedBox(width: 10),
          _parchiDiffButton(context, ctx, 'Hard', 2, const Color(0xFFE53935), () => players),
        ]),

        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Divider(color: lineColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('or', style: TextStyle(color: ink3Color, fontSize: 12)),
          ),
          Expanded(child: Divider(color: lineColor)),
        ]),
        const SizedBox(height: 14),

        GestureDetector(
          onTap: () {
            music.play(click);
            Navigator.pop(ctx);
            Navigator.push(context, CupertinoPageRoute(builder: (_) => const ParchiLobbyScreen()));
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
            decoration: BoxDecoration(
              color: game.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: game.accent.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              Icon(Icons.groups_rounded, color: game.accent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Play with Friends (2–4)',
                    style: TextStyle(color: game.accent, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: game.accent.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.monetization_on_rounded, color: game.accent, size: 12),
                  const SizedBox(width: 3),
                  Text('$fixedEntryFee', style: TextStyle(color: game.accent, fontWeight: FontWeight.w800, fontSize: 11)),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    )),
  );
}

Widget _parchiDiffButton(BuildContext context, BuildContext sheetCtx, String label, int level, Color color, int Function() players) {
  return Expanded(
    child: GestureDetector(
      onTap: () {
        music.play(click);
        Navigator.pop(sheetCtx);
        Navigator.push(context, CupertinoPageRoute(
            builder: (_) => ParchiGameScreen(aiLevel: level, playerCount: players())));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(children: [
          Icon(Icons.smart_toy_rounded, color: color, size: 22),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
        ]),
      ),
    ),
  );
}

// Liar's Bar: pick ruleset + players, then Easy/Medium/Hard vs Computer.
// (Liar's Dice mode + Play with Friends are wired in later build steps.)
void _showLiarsModeSheet(BuildContext context, GameMeta game) {
  String mode = 'deck';
  String ruleset = 'basic';
  int players = 4;
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1A100C),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      void pickMode(String m) => setSheet(() { mode = m; ruleset = 'basic'; });
      final deckRulesets = ['basic', 'devil', 'chaos'];
      final diceRulesets = ['basic', 'traditional'];
      return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: game.accent.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(13)),
            child: Icon(game.icon, color: const Color(0xFFE05A4A), size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text("Liar's Bar",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
          ),
        ]),
        const SizedBox(height: 18),

        const Align(alignment: Alignment.centerLeft, child: Text('Game', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600))),
        const SizedBox(height: 8),
        Row(children: [
          _liarsChip("Liar's Deck", 'deck', mode, pickMode),
          const SizedBox(width: 8),
          _liarsChip("Liar's Dice", 'dice', mode, pickMode),
        ]),
        const SizedBox(height: 16),

        const Align(alignment: Alignment.centerLeft, child: Text('Ruleset', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600))),
        const SizedBox(height: 8),
        Row(children: [
          for (final r in (mode == 'dice' ? diceRulesets : deckRulesets)) ...[
            _liarsChip(_liarsRulesetLabel(r), r, ruleset, (v) => setSheet(() => ruleset = v)),
            if (r != (mode == 'dice' ? diceRulesets : deckRulesets).last) const SizedBox(width: 8),
          ],
        ]),
        const SizedBox(height: 6),
        Align(alignment: Alignment.centerLeft, child: Text(_liarsRulesetDesc(mode, ruleset), style: const TextStyle(color: Colors.white38, fontSize: 11.5))),
        const SizedBox(height: 16),

        const Align(alignment: Alignment.centerLeft, child: Text('Players', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600))),
        const SizedBox(height: 8),
        Row(children: [
          for (final p in [2, 3, 4])
            Expanded(child: Padding(
              padding: EdgeInsets.only(right: p == 4 ? 0 : 8),
              child: GestureDetector(
                onTap: () => setSheet(() => players = p),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: players == p ? game.accent : Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text('$p', style: TextStyle(color: players == p ? Colors.white : Colors.white60, fontWeight: FontWeight.w800, fontSize: 14))),
                ),
              ),
            )),
        ]),
        const SizedBox(height: 18),

        const Text('Play vs Computer', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(children: [
          _liarsDiff(context, ctx, 'Easy', 0, const Color(0xFF43A047), () => mode, () => ruleset, () => players),
          const SizedBox(width: 10),
          _liarsDiff(context, ctx, 'Medium', 1, const Color(0xFFECA13A), () => mode, () => ruleset, () => players),
          const SizedBox(width: 10),
          _liarsDiff(context, ctx, 'Hard', 2, const Color(0xFFE53935), () => mode, () => ruleset, () => players),
        ]),

        const SizedBox(height: 18),
        Row(children: const [
          Expanded(child: Divider(color: Colors.white24)),
          Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('or', style: TextStyle(color: Colors.white54, fontSize: 12))),
          Expanded(child: Divider(color: Colors.white24)),
        ]),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () {
            music.play(click);
            Navigator.pop(ctx);
            Navigator.push(context, CupertinoPageRoute(builder: (_) => LiarsLobbyScreen(mode: mode)));
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
            decoration: BoxDecoration(
              color: game.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: game.accent),
            ),
            child: Row(children: [
              const Icon(Icons.groups_rounded, color: Color(0xFFE05A4A), size: 22),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Play with Friends (2–4)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: game.accent.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.monetization_on_rounded, color: Color(0xFFECA13A), size: 12),
                  const SizedBox(width: 3),
                  Text('$fixedEntryFee', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
    }),
  );
}

String _liarsRulesetLabel(String r) {
  switch (r) {
    case 'devil': return 'Devil';
    case 'chaos': return 'Chaos';
    case 'traditional': return 'Traditional';
    default: return 'Basic';
  }
}

String _liarsRulesetDesc(String mode, String r) {
  if (mode == 'dice') {
    return r == 'traditional'
        ? 'Bid dice counts; 1s are wild; "Spot On" makes others drink.'
        : 'Bid how many dice show a face; call the bluff. 2 drinks = out.';
  }
  switch (r) {
    case 'devil': return 'One Devil card — get called on it and everyone else shoots.';
    case 'chaos': return '12-card deck, Master & Chaos cards, play one at a time.';
    default: return 'Claim the table rank, play 1–3, bluff or call Liar.';
  }
}

Widget _liarsChip(String label, String value, String selected, void Function(String) onPick) {
  final active = selected == value;
  return Expanded(
    child: GestureDetector(
      onTap: () => onPick(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF8E1D2C) : Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.white60, fontWeight: FontWeight.w800, fontSize: 12.5))),
      ),
    ),
  );
}

Widget _liarsDiff(BuildContext context, BuildContext sheetCtx, String label, int level, Color color, String Function() mode, String Function() ruleset, int Function() players) {
  return Expanded(
    child: GestureDetector(
      onTap: () {
        music.play(click);
        Navigator.pop(sheetCtx);
        Navigator.push(context, CupertinoPageRoute(
            builder: (_) => mode() == 'dice'
                ? LiarsDiceScreen(aiLevel: level, ruleset: ruleset(), playerCount: players())
                : LiarsGameScreen(aiLevel: level, ruleset: ruleset(), playerCount: players())));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(children: [
          Icon(Icons.smart_toy_rounded, color: color, size: 22),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
        ]),
      ),
    ),
  );
}

String _unoModeDesc(String mode) {
  switch (mode) {
    case 'allWild': return 'Every card is a wild — pure colour-picking chaos.';
    case 'noMercy': return 'Draw 6 / Draw 10 / Skip-Everyone, stacking, 25 cards = OUT.';
    default: return 'Standard 108-card deck with house rules.';
  }
}

Widget _unoModeChip(String label, String value, String selected, void Function(String) onPick) {
  final active = selected == value;
  return Expanded(
    child: GestureDetector(
      onTap: () => onPick(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFD32F2F) : surface2Color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? const Color(0xFFD32F2F) : lineColor),
        ),
        child: Center(
          child: Text(label, style: TextStyle(
            color: active ? Colors.white : ink2Color,
            fontWeight: FontWeight.w800, fontSize: 12.5)),
        ),
      ),
    ),
  );
}

Widget _unoDiffButton(BuildContext context, BuildContext sheetCtx, String label, int level, Color color, String Function() mode) {
  return Expanded(
    child: GestureDetector(
      onTap: () {
        music.play(click);
        Navigator.pop(sheetCtx);
        Navigator.push(context, CupertinoPageRoute(builder: (_) => UnoGameScreen(aiLevel: level, mode: mode())));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(children: [
          Icon(Icons.smart_toy_rounded, color: color, size: 22),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
        ]),
      ),
    ),
  );
}

Widget _diffButton(BuildContext context, BuildContext sheetCtx, GameMeta game,
    String label, int level, Color color) {
  return Expanded(
    child: GestureDetector(
      onTap: () {
        music.play(click);
        Navigator.pop(sheetCtx);
        launchVsAi(context, game.type, level);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(children: [
          Icon(Icons.smart_toy_rounded, color: color, size: 22),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 13)),
        ]),
      ),
    ),
  );
}
