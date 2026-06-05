import 'package:flutter/material.dart';

// A game tag — used both as an in-app game identifier (challengeable) and as a
// discovery interest tag (external multiplayer titles).
class GameTag {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool inApp; // true = playable in-app & challengeable, false = interest only

  const GameTag(this.id, this.name, this.icon, this.color, {this.inApp = false});
}

// ── In-app games (challengeable) ─ mirror of private_room.dart _kGames ─────────
const List<GameTag> kInAppTags = [
  GameTag('xo',         'XO Battle',           Icons.grid_3x3_rounded, Color(0xFF4B4EE6), inApp: true),
  GameTag('rps',        'Rock Paper Scissors', Icons.sports_mma,       Color(0xFFE53935), inApp: true),
  GameTag('connect4',   'Connect 4',           Icons.grid_on,          Color(0xFFFF7043), inApp: true),
  GameTag('gomoku',     'Gomoku',              Icons.circle_outlined,  Color(0xFF7B1FA2), inApp: true),
  GameTag('dotsboxes',  'Dots & Boxes',        Icons.grid_3x3,         Color(0xFF1565C0), inApp: true),
  GameTag('checkers',   'Checkers',            Icons.apps,             Color(0xFF2E7D32), inApp: true),
  GameTag('battleship', 'Battleship',          Icons.sailing,          Color(0xFF00838F), inApp: true),
];

// ── External multiplayer titles (interest tags for discovery only) ────────────
const List<GameTag> kExternalTags = [
  GameTag('valorant',   'Valorant',        Icons.sports_esports_rounded, Color(0xFFFF4655)),
  GameTag('csgo',       'CS2 / CS:GO',     Icons.sports_esports_rounded, Color(0xFFF0A500)),
  GameTag('bgmi',       'BGMI / PUBG',     Icons.sports_esports_rounded, Color(0xFFE8A33D)),
  GameTag('freefire',   'Free Fire',       Icons.sports_esports_rounded, Color(0xFFFF6D00)),
  GameTag('codm',       'COD Mobile',      Icons.sports_esports_rounded, Color(0xFF4A5568)),
  GameTag('fortnite',   'Fortnite',        Icons.sports_esports_rounded, Color(0xFF7B2FF7)),
  GameTag('apex',       'Apex Legends',    Icons.sports_esports_rounded, Color(0xFFDA292A)),
  GameTag('minecraft',  'Minecraft',       Icons.sports_esports_rounded, Color(0xFF5B8731)),
  GameTag('gta',        'GTA Online',      Icons.sports_esports_rounded, Color(0xFF6FA32A)),
  GameTag('clashroyale','Clash Royale',    Icons.sports_esports_rounded, Color(0xFF2196F3)),
  GameTag('coc',        'Clash of Clans',  Icons.sports_esports_rounded, Color(0xFFE6A817)),
  GameTag('amongus',    'Among Us',        Icons.sports_esports_rounded, Color(0xFFC51111)),
  GameTag('rocket',     'Rocket League',   Icons.sports_esports_rounded, Color(0xFF1565C0)),
  GameTag('mlbb',       'Mobile Legends',  Icons.sports_esports_rounded, Color(0xFF3F51B5)),
  GameTag('brawl',      'Brawl Stars',     Icons.sports_esports_rounded, Color(0xFFFFB300)),
  GameTag('fallguys',   'Fall Guys',       Icons.sports_esports_rounded, Color(0xFFEC407A)),
  GameTag('lol',        'League of Legends',Icons.sports_esports_rounded,Color(0xFF0AC8B9)),
  GameTag('dota2',      'Dota 2',          Icons.sports_esports_rounded, Color(0xFFC23C2A)),
  GameTag('genshin',    'Genshin Co-op',   Icons.sports_esports_rounded, Color(0xFF4FC3F7)),
  GameTag('roblox',     'Roblox',          Icons.sports_esports_rounded, Color(0xFF616161)),
];

// All tags combined.
const List<GameTag> kAllTags = [...kInAppTags, ...kExternalTags];

// Lookup by id; falls back to a neutral placeholder if unknown.
GameTag tagById(String id) {
  for (final t in kAllTags) {
    if (t.id == id) return t;
  }
  return GameTag(id, id, Icons.videogame_asset_rounded, const Color(0xFF9A9EAC));
}

// Only the in-app, challengeable game tags.
List<GameTag> get challengeableTags =>
    kAllTags.where((t) => t.inApp).toList();
