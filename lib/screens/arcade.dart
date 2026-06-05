import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../helpers/utils.dart';
import 'arcade_lobby.dart';
import 'home_screen.dart';

class _GameMeta {
  final String type, name, desc;
  final IconData icon;
  final Color accent;
  const _GameMeta(this.type, this.name, this.desc, this.icon, this.accent);
}

const _games = [
  _GameMeta('rps', 'Rock Paper\nScissors', 'Best of 5 — pick fast!',
      Icons.sports_mma, Color(0xFFE53935)),
  _GameMeta('connect4', 'Connect 4', 'Drop pieces, align 4 to win',
      Icons.grid_on, Color(0xFFFF7043)),
  _GameMeta('gomoku', 'Gomoku', '5 in a row on 11×11 grid',
      Icons.circle_outlined, Color(0xFF7B1FA2)),
  _GameMeta('dotsboxes', 'Dots & Boxes', 'Draw lines, claim boxes',
      Icons.grid_3x3, Color(0xFF1565C0)),
  _GameMeta('checkers', 'Checkers', 'Classic draughts battle',
      Icons.apps, Color(0xFF2E7D32)),
  _GameMeta('battleship', 'Battleship', 'Place ships, fire torpedoes',
      Icons.sailing, Color(0xFF00838F)),
];

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
                  itemCount: _games.length,
                  itemBuilder: (_, i) => _GameCard(game: _games[i]),
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
  final _GameMeta game;
  const _GameCard({required this.game});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        music.play(click);
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
