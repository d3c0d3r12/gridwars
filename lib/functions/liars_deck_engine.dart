import 'dart:math';

// ════════════════════════════════════════════════════════════════════════════
// Liar's Deck engine — pure, serializable. Drives offline vs-Computer AND
// Firebase multiplayer. Card-bluffing + Russian roulette.
//
// Card codes: 'A' 'K' 'Q'  · 'J' joker (wild, always valid) · specials played
//   ALONE: 'D' devil, 'M' master, 'C' chaos.
//
// Rulesets:
//   basic — 20-card deck (6A 6K 6Q 2J), hand 5, play 1–3, claim the table rank.
//   devil — basic + one Devil card. If you play Devil and get CALLED, everyone
//           except you shoots.
//   chaos — 12-card deck (3A 3K 3Q 1J 1Master 1Chaos), hand 3, play exactly 1.
//           Master called → the thrower picks who shoots (bot/auto → the caller).
//           Chaos called → EVERYONE shoots.
//
// A play is a LIE if any played card isn't the table rank / a Joker (specials
// played alone count as truthful — so challenging them backfires on the caller,
// plus their nasty effect). Loser(s) play Russian roulette with their own gun
// (6 chambers, odds rise each pull). Last player alive wins.
// ════════════════════════════════════════════════════════════════════════════

const List<String> kDeckRanks = ['A', 'K', 'Q'];
const Set<String> kDeckSpecials = {'D', 'M', 'C'};
const int kGunChambers = 6;

class LiarsDeckState {
  List<String> order;                 // alive players, seat order
  Map<String, List<String>> hands;
  Map<String, String> names;
  Map<String, String> chars;          // playerId → character id
  int turn;
  String tableRank;                   // 'A' | 'K' | 'Q'
  String ruleset;                     // basic | devil | chaos
  String? lastPlayer;                 // who made the standing play
  List<String> lastCards;             // their face-down cards (revealed on call)
  int lastCount;
  String phase;                       // play | shoot | reveal | over
  Map<String, int> gunBullet;         // chamber holding the live round
  Map<String, int> gunPos;            // chambers already fired
  List<String> pendingShooters;       // queue of players who must shoot
  // reveal/last-event info for the UI
  String? revChallenger;
  String? revAccused;
  List<String> revCards;
  bool revWasLie;
  String? lastShotPlayer;
  bool lastShotDead;
  int round;
  String? winner;
  bool over;

  LiarsDeckState({
    required this.order,
    required this.hands,
    required this.names,
    required this.chars,
    required this.turn,
    required this.tableRank,
    required this.ruleset,
    this.lastPlayer,
    List<String>? lastCards,
    this.lastCount = 0,
    this.phase = 'play',
    Map<String, int>? gunBullet,
    Map<String, int>? gunPos,
    List<String>? pendingShooters,
    this.revChallenger,
    this.revAccused,
    List<String>? revCards,
    this.revWasLie = false,
    this.lastShotPlayer,
    this.lastShotDead = false,
    this.round = 1,
    this.winner,
    this.over = false,
  })  : lastCards = lastCards ?? <String>[],
        gunBullet = gunBullet ?? <String, int>{},
        gunPos = gunPos ?? <String, int>{},
        pendingShooters = pendingShooters ?? <String>[],
        revCards = revCards ?? <String>[];

  String get currentId => order[turn % order.length];
  int handCount(String id) => hands[id]?.length ?? 0;
  bool get hasStandingPlay => lastPlayer != null && order.contains(lastPlayer);
  int get handSize => ruleset == 'chaos' ? 3 : 5;
  int get playMax => ruleset == 'chaos' ? 1 : 3;

  bool isValidCard(String card) =>
      card == tableRank || card == 'J' || kDeckSpecials.contains(card);

  // ── Setup ───────────────────────────────────────────────────────────────────
  factory LiarsDeckState.create({
    required List<String> playerIds,
    required Map<String, String> names,
    required Map<String, String> chars,
    String ruleset = 'basic',
    Random? rng,
  }) {
    final s = LiarsDeckState(
      order: List.of(playerIds),
      hands: {},
      names: names,
      chars: chars,
      turn: 0,
      tableRank: 'K',
      ruleset: ruleset,
    );
    final r = rng ?? Random();
    for (final id in playerIds) {
      s.gunBullet[id] = r.nextInt(kGunChambers);
      s.gunPos[id] = 0;
    }
    s._deal(r, startTurn: 0);
    return s;
  }

  static List<String> _buildDeck(String ruleset) {
    final d = <String>[];
    if (ruleset == 'chaos') {
      for (final rank in kDeckRanks) {
        for (int i = 0; i < 3; i++) d.add(rank);
      }
      d..add('J')..add('M')..add('C'); // 12
    } else {
      for (final rank in kDeckRanks) {
        for (int i = 0; i < 6; i++) d.add(rank);
      }
      d..add('J')..add('J');
      if (ruleset == 'devil') d.add('D');
    }
    return d;
  }

  void _deal(Random rng, {required int startTurn}) {
    final deck = _buildDeck(ruleset)..shuffle(rng);
    hands = {for (final id in order) id: <String>[]};
    for (int i = 0; i < handSize; i++) {
      for (final id in order) {
        if (deck.isNotEmpty) hands[id]!.add(deck.removeLast());
      }
    }
    tableRank = kDeckRanks[rng.nextInt(kDeckRanks.length)];
    lastPlayer = null;
    lastCards = [];
    lastCount = 0;
    pendingShooters = [];
    revChallenger = revAccused = null;
    revCards = [];
    revWasLie = false;
    lastShotPlayer = null;
    lastShotDead = false;
    phase = 'play';
    turn = order.isEmpty ? 0 : startTurn % order.length;
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  /// Current player plays [cards] (face down, claimed to be the table rank).
  bool play(String player, List<String> cards) {
    if (phase != 'play' || player != currentId) return false;
    if (cards.isEmpty || cards.length > playMax) return false;
    // specials must be played alone
    if (cards.any(kDeckSpecials.contains) && cards.length != 1) return false;
    final hand = hands[player]!;
    final tmp = List<String>.from(hand);
    for (final c in cards) {
      if (!tmp.remove(c)) return false; // doesn't actually hold it
    }
    hands[player] = tmp;
    lastPlayer = player;
    lastCards = List.of(cards);
    lastCount = cards.length;
    _advanceTurn();
    return true;
  }

  /// Current player challenges the standing play.
  bool callLiar(String challenger, {String? masterTarget}) {
    if (phase != 'play' || challenger != currentId) return false;
    if (!hasStandingPlay) return false;
    final accused = lastPlayer!;
    revChallenger = challenger;
    revAccused = accused;
    revCards = List.of(lastCards);

    final single = lastCards.length == 1 ? lastCards.first : null;
    if (single == 'D') {
      revWasLie = false; // devil is "truthful" — caller mis-called
      pendingShooters = order.where((id) => id != accused).toList();
    } else if (single == 'M') {
      revWasLie = false;
      pendingShooters = [masterTarget ?? challenger];
    } else if (single == 'C') {
      revWasLie = false;
      pendingShooters = List.of(order); // everyone
    } else {
      final lie = lastCards.any((c) => !(c == tableRank || c == 'J'));
      revWasLie = lie;
      pendingShooters = [lie ? accused : challenger];
    }
    phase = 'shoot';
    return true;
  }

  String? get nextShooter => pendingShooters.isEmpty ? null : pendingShooters.first;

  /// Fire the next pending shooter's revolver. Returns true if a shot happened.
  bool resolveNextShot(Random rng) {
    if (phase != 'shoot' || pendingShooters.isEmpty) return false;
    final id = pendingShooters.removeAt(0);
    final pos = gunPos[id] ?? 0;
    final bullet = gunBullet[id] ?? 0;
    final dead = (pos % kGunChambers) == bullet;
    gunPos[id] = pos + 1;
    lastShotPlayer = id;
    lastShotDead = dead;
    if (dead) {
      final idx = order.indexOf(id);
      if (idx >= 0) {
        order.removeAt(idx);
        if (idx < turn) turn--;
      }
    }
    if (pendingShooters.isEmpty) {
      phase = 'reveal';
      if (order.length <= 1) {
        over = true;
        winner = order.isNotEmpty ? order.first : id;
      }
    }
    return true;
  }

  /// Deal the next round. Start with the survivor of the shootout (or the player
  /// after the accused if they died).
  void nextRound(Random rng) {
    if (over) return;
    round++;
    int start = 0;
    final pivot = revAccused ?? lastPlayer;
    if (pivot != null && order.contains(pivot)) {
      start = order.indexOf(pivot);
    } else if (pivot != null) {
      // accused died — start with whoever now sits at their old seat
      start = 0;
    }
    _deal(rng, startTurn: start);
  }

  void _advanceTurn() {
    if (order.isEmpty) return;
    turn = (turn + 1) % order.length;
  }

  // ── Serialization ───────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
        'order': order,
        'hands': hands,
        'names': names,
        'chars': chars,
        'turn': turn,
        'tableRank': tableRank,
        'ruleset': ruleset,
        'lastPlayer': lastPlayer,
        'lastCards': lastCards,
        'lastCount': lastCount,
        'phase': phase,
        'gunBullet': gunBullet,
        'gunPos': gunPos,
        'pendingShooters': pendingShooters,
        'revChallenger': revChallenger,
        'revAccused': revAccused,
        'revCards': revCards,
        'revWasLie': revWasLie,
        'lastShotPlayer': lastShotPlayer,
        'lastShotDead': lastShotDead,
        'round': round,
        'winner': winner,
        'over': over,
      };

  factory LiarsDeckState.fromMap(Map m) => LiarsDeckState(
        order: List<String>.from(m['order'] ?? const []),
        hands: ((m['hands'] as Map?) ?? {}).map(
            (k, v) => MapEntry(k as String, List<String>.from(v as List))),
        names: Map<String, String>.from(m['names'] ?? const {}),
        chars: Map<String, String>.from(m['chars'] ?? const {}),
        turn: (m['turn'] as int?) ?? 0,
        tableRank: (m['tableRank'] as String?) ?? 'K',
        ruleset: (m['ruleset'] as String?) ?? 'basic',
        lastPlayer: m['lastPlayer'] as String?,
        lastCards: List<String>.from(m['lastCards'] ?? const []),
        lastCount: (m['lastCount'] as int?) ?? 0,
        phase: (m['phase'] as String?) ?? 'play',
        gunBullet: ((m['gunBullet'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
        gunPos: ((m['gunPos'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
        pendingShooters: List<String>.from(m['pendingShooters'] ?? const []),
        revChallenger: m['revChallenger'] as String?,
        revAccused: m['revAccused'] as String?,
        revCards: List<String>.from(m['revCards'] ?? const []),
        revWasLie: m['revWasLie'] == true,
        lastShotPlayer: m['lastShotPlayer'] as String?,
        lastShotDead: m['lastShotDead'] == true,
        round: (m['round'] as int?) ?? 1,
        winner: m['winner'] as String?,
        over: m['over'] == true,
      );
}

// ── Bot AI ─────────────────────────────────────────────────────────────────
// FAIR PLAY: a bot only ever sees its OWN hand plus public info (each player's
// hand size, the table rank, and how many cards were claimed). It never peeks at
// opponents' cards or the face-down pile — it reasons from probability alone.
// Difficulty changes only HOW WELL it reasons:
//   easy   — sloppy: bluffs a lot, calls almost only on impossible claims (+ the
//            occasional random misfire).
//   medium — decent probability play.
//   hard   — sharp: accurate card-counting calls, disciplined bluffing, presses
//            opponents who are low on cards.
class LiarsDeckBot {
  static final _rng = Random();

  /// Returns either {action:'call'} or {action:'play', cards:[...]}.
  static Map<String, dynamic> decide(LiarsDeckState s, String botId, int level) {
    final hand = List<String>.from(s.hands[botId] ?? const []);
    final canCall = s.hasStandingPlay && s.lastPlayer != botId;

    // No cards → must challenge (can't play).
    if (hand.isEmpty && canCall) return {'action': 'call'};

    if (canCall) {
      final lieProb = _estimateLie(s, botId, hand);
      if (lieProb >= 1.0) return {'action': 'call'}; // claim is provably impossible

      if (level == 0) {
        // sloppy: only the obvious lies, plus rare random paranoia
        if (lieProb > 0.85 || _rng.nextDouble() < 0.07) return {'action': 'call'};
      } else if (level == 1) {
        if (lieProb > 0.55 - _rng.nextDouble() * 0.08) return {'action': 'call'};
      } else {
        // hard: call on a genuine edge; press harder when someone could go out
        final minOpp = s.order
            .where((id) => id != botId)
            .fold<int>(99, (a, id) => min(a, s.handCount(id)));
        final pressure = minOpp <= 1 ? 0.08 : 0.0; // don't let them dump & win
        if (lieProb > 0.42 - pressure) return {'action': 'call'};
      }
    }

    return {'action': 'play', 'cards': _choosePlay(s, botId, hand, level)};
  }

  /// Probability the standing claim is a lie, from the bot's own cards only.
  static double _estimateLie(LiarsDeckState s, String botId, List<String> hand) {
    final myValid = hand.where((c) => c == s.tableRank || c == 'J').length;
    final rankCopies = s.ruleset == 'chaos' ? 3 : 6;
    final jokers = s.ruleset == 'chaos' ? 1 : 2;
    final unknownValid = max(0, rankCopies + jokers - myValid);
    final othersCards =
        s.order.where((id) => id != botId).fold<int>(0, (a, id) => a + s.handCount(id));
    if (s.lastCount > unknownValid) return 1.0; // impossible to be all valid
    if (othersCards <= 0) return 0.5;
    final p = (unknownValid / othersCards).clamp(0.0, 1.0);
    final probAllValid = pow(p, s.lastCount).toDouble();
    return (1 - probAllValid).clamp(0.0, 1.0);
  }

  static List<String> _choosePlay(
      LiarsDeckState s, String botId, List<String> hand, int level) {
    final maxN = s.playMax;
    final specials = hand.where(kDeckSpecials.contains).toList();
    final valids = hand.where((c) => c == s.tableRank || c == 'J').toList();
    final bluffs = hand
        .where((c) => !(c == s.tableRank || c == 'J') && !kDeckSpecials.contains(c))
        .toList();

    // Bait with a special (played alone): hard only when it's running low on
    // honest cards; easy throws it out semi-randomly.
    if (specials.isNotEmpty) {
      final baitChance = level == 2 ? (valids.isEmpty ? 0.5 : 0.15) : (level == 1 ? 0.25 : 0.12);
      if (_rng.nextDouble() < baitChance) return [specials.first];
    }

    if (level == 0) {
      // sloppy: bluffs even when holding the real card, dumps multiples
      if (valids.isNotEmpty && _rng.nextDouble() < 0.55) {
        return valids.take(1 + _rng.nextInt(min(maxN, valids.length))).toList();
      }
      if (bluffs.isNotEmpty) {
        final n = (maxN > 1 && bluffs.length > 1 && _rng.nextBool()) ? 2 : 1;
        return bluffs.take(n).toList();
      }
      if (valids.isNotEmpty) return valids.take(1).toList();
    } else {
      // medium / hard: play the truth, bluff only when forced — and minimally.
      if (valids.isNotEmpty) {
        final cap = min(maxN, valids.length);
        final n = level == 2 ? ((cap >= 2 && _rng.nextDouble() < 0.35) ? 2 : 1) : 1 + _rng.nextInt(cap);
        return valids.take(n).toList();
      }
      if (bluffs.isNotEmpty) return [bluffs.first]; // single low-risk bluff
    }
    if (specials.isNotEmpty) return [specials.first];
    return [hand.first];
  }

  /// Bot reaction delay for the shoot animation pacing (ms).
  static int shootDelayMs() => 500 + _rng.nextInt(500);
}
