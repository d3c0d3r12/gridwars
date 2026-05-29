import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../screens/splash.dart';
import 'arcade_lobby.dart';

class _GameMeta {
  final String type, name, emoji, desc;
  final Color accent;
  const _GameMeta(this.type, this.name, this.emoji, this.desc, this.accent);
}

const _games = [
  _GameMeta('rps',        'Rock Paper\nScissors', '✊',  'Best of 5 — pick fast!',          Color(0xFFE91E63)),
  _GameMeta('connect4',   'Connect 4',            '🔴',  'Drop pieces, align 4 to win',      Color(0xFFFF5722)),
  _GameMeta('gomoku',     'Gomoku',               '⚫',  '5 in a row on 11×11 grid',         Color(0xFF9C27B0)),
  _GameMeta('dotsboxes',  'Dots & Boxes',         '🟦',  'Draw lines, claim boxes',           Color(0xFF2196F3)),
  _GameMeta('checkers',   'Checkers',             '♟️',  'Classic draughts battle',           Color(0xFF4CAF50)),
  _GameMeta('battleship', 'Battleship',           '🚢',  'Place ships, fire torpedoes',       Color(0xFF00BCD4)),
];

class ArcadeScreen extends StatelessWidget {
  const ArcadeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: utils.gradBack(),
        child: SafeArea(child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: Row(children: [
              IconButton(icon: Icon(Icons.arrow_back, color: white), onPressed: () => Navigator.pop(context)),
              const Spacer(),
              Column(children: [
                Text('ARCADE', style: TextStyle(color: white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 3, fontFamily: 'DISPLATTER')),
                Text('6 Multiplayer Games', style: TextStyle(color: secondarySelectedColor, fontSize: 11)),
              ]),
              const Spacer(),
              // Entry fee chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: secondarySelectedColor.withValues(alpha: 0.15),
                  border: Border.all(color: secondarySelectedColor.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  getSvgImage(imageName: 'coin_symbol', height: 12),
                  Text(' $fixedEntryFee', style: TextStyle(color: yellow, fontWeight: FontWeight.bold, fontSize: 12)),
                ]),
              ),
            ]),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Container(width: 3, height: 16, color: secondarySelectedColor, margin: const EdgeInsets.only(right: 8)),
              Text('Choose a game to play online', style: TextStyle(color: white.withValues(alpha: 0.6), fontSize: 12)),
            ]),
          ),

          const SizedBox(height: 12),

          // Game grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85,
              ),
              itemCount: _games.length,
              itemBuilder: (_, i) => _GameCard(game: _games[i]),
            ),
          ),
        ])),
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
      onTap: () => Navigator.push(context, CupertinoPageRoute(
        builder: (_) => ArcadeLobbyScreen(gameType: game.type, gameName: game.name.replaceAll('\n', ' '), accent: game.accent),
      )),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              game.accent.withValues(alpha: 0.18),
              game.accent.withValues(alpha: 0.06),
            ],
          ),
          border: Border.all(color: game.accent.withValues(alpha: 0.4), width: 1.2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emoji icon in circle
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: game.accent.withValues(alpha: 0.2),
                ),
                child: Center(child: Text(game.emoji, style: const TextStyle(fontSize: 26))),
              ),
              const SizedBox(height: 12),
              Text(game.name, style: TextStyle(color: white, fontWeight: FontWeight.bold, fontSize: 14, height: 1.2)),
              const SizedBox(height: 6),
              Expanded(
                child: Text(game.desc, style: TextStyle(color: white.withValues(alpha: 0.55), fontSize: 11, height: 1.4)),
              ),
              const SizedBox(height: 10),
              // Play button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: game.accent.withValues(alpha: 0.25),
                  border: Border.all(color: game.accent.withValues(alpha: 0.5)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.play_arrow_rounded, color: game.accent, size: 16),
                  const SizedBox(width: 4),
                  Text('PLAY', style: TextStyle(color: game.accent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
