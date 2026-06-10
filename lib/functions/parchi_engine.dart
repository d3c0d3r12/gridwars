import 'dart:math';

// ════════════════════════════════════════════════════════════════════════════
// 16 Parchi / Dhapp engine — pure, serializable. Drives local vs-Computer AND
// Firebase multiplayer.
//
// Rules:
//   • N players (2–4) sit in a circle. Each round uses N distinct symbols × 4
//     cards = N*4 cards; everyone is dealt 4.
//   • PASSING phase: simultaneously every player passes one unwanted card to the
//     next seat (and receives one from the previous seat). Repeat.
//   • The instant a player holds 4-of-a-kind a SET is formed → SLAM phase.
//   • SLAM phase: everyone slaps the pile ("Dhapp!"). The LAST to slam loses the
//     round and earns one letter of the word D-H-A-P-P.
//   • Spell all of "DHAPP" (5 letters) and you're OUT. Last player standing wins.
//
// A round is self-contained: when someone is eliminated the next round is dealt
// fresh for the remaining players, so #symbols always equals #players and there
// is always exactly one full set available per symbol.
// ════════════════════════════════════════════════════════════════════════════

const String kDhappWord = 'DHAPP'; // 5 letters → 5 round losses = out
const int kDhappMaxLetters = kDhappWord.length;

/// Visual symbol pool — a round draws the first [playerCount] of a shuffled copy
/// so each game/round looks different.
const List<String> kParchiSymbols = [
  '🦁', '🐯', '🐵', '🐼', '🦊', '🐨', '🐸', '🐷',
];

/// Phases of play.
///   passing  — collecting one pass card from every alive player
///   slam     — a set exists; collecting slam reactions from every alive player
///   reveal   — round resolved, showing who lost a letter (UI dwell)
///   over      — game finished, [winner] set
class ParchiState {
  List<String> order;                 // alive players, seat order (clockwise)
  Map<String, List<String>> hands;    // playerId → 4 symbol cards
  Map<String, String> names;
  Map<String, bool> bots;
  List<String> symbols;               // symbols in play this round
  int dir;                            // pass direction (1 = to next seat)
  int round;

  String phase;
  Map<String, String> pendingPass;    // playerId → symbol chosen to pass
  Map<String, int> slamTimes;         // playerId → reaction ms (lower = faster)
  String? setOwner;                   // who first completed a set this round
  Map<String, int> letters;           // playerId → DHAPP letters earned (0..5)
  String? roundLoser;                 // who earned a letter last round (reveal)
  bool roundLoserOut;                 // did that letter eliminate them
  String? winner;
  bool over;

  ParchiState({
    required this.order,
    required this.hands,
    required this.names,
    required this.bots,
    required this.symbols,
    this.dir = 1,
    this.round = 1,
    this.phase = 'passing',
    Map<String, String>? pendingPass,
    Map<String, int>? slamTimes,
    this.setOwner,
    Map<String, int>? letters,
    this.roundLoser,
    this.roundLoserOut = false,
    this.winner,
    this.over = false,
  })  : pendingPass = pendingPass ?? <String, String>{},
        slamTimes = slamTimes ?? <String, int>{},
        letters = letters ?? <String, int>{};

  bool isBot(String id) => bots[id] ?? false;
  int letterCount(String id) => letters[id] ?? 0;
  bool isOut(String id) => letterCount(id) >= kDhappMaxLetters;
  int handCount(String id) => hands[id]?.length ?? 0;

  /// The full set held by [id], or null. A set is 4 cards of one symbol.
  String? completedSymbol(String id) {
    final h = hands[id];
    if (h == null || h.length < 4) return null;
    final first = h.first;
    return h.every((c) => c == first) ? first : null;
  }

  /// Any player currently holding a full set (the trigger for the slam phase).
  bool get anySetExists => order.any((id) => completedSymbol(id) != null);

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  /// Deal a brand-new game.
  factory ParchiState.create({
    required List<String> playerIds,
    required Map<String, String> names,
    required Map<String, bool> bots,
    Random? rng,
  }) {
    final s = ParchiState(
      order: List.of(playerIds),
      hands: {},
      names: names,
      bots: bots,
      symbols: const [],
      letters: {for (final id in playerIds) id: 0},
    );
    s._deal(rng ?? Random());
    return s;
  }

  /// Deal a fresh round for the current alive [order].
  void _deal(Random rng) {
    final n = order.length;
    final pool = List.of(kParchiSymbols)..shuffle(rng);
    symbols = pool.take(n).toList();
    final deck = <String>[];
    for (final sym in symbols) {
      for (int i = 0; i < 4; i++) deck.add(sym);
    }
    deck.shuffle(rng);
    hands = {};
    for (final id in order) {
      hands[id] = [for (int i = 0; i < 4; i++) deck.removeLast()];
    }
    pendingPass = {};
    slamTimes = {};
    setOwner = null;
    phase = anySetExists ? 'slam' : 'passing';
  }

  // ── Passing ───────────────────────────────────────────────────────────────

  /// Record a player's chosen pass [symbol]. Returns true if accepted.
  bool submitPass(String id, String symbol) {
    if (phase != 'passing') return false;
    if (!order.contains(id)) return false;
    if (!(hands[id]?.contains(symbol) ?? false)) return false;
    pendingPass[id] = symbol;
    return true;
  }

  bool get allPassesIn =>
      phase == 'passing' && order.every((id) => pendingPass.containsKey(id));

  /// Resolve a complete pass round: every player gives their chosen card to the
  /// next seat. Then re-evaluate the phase (slam if a set appeared).
  void resolvePasses() {
    if (!allPassesIn) return;
    final n = order.length;
    final given = {for (final id in order) id: pendingPass[id]!};
    // Remove one instance of the given symbol from each hand.
    for (final id in order) {
      hands[id]!.remove(given[id]);
    }
    // Hand it to the next seat in the pass direction.
    for (int i = 0; i < n; i++) {
      final giver = order[i];
      final receiver = order[((i + dir) % n + n) % n];
      hands[receiver]!.add(given[giver]!);
    }
    pendingPass = {};
    if (anySetExists) {
      phase = 'slam';
      setOwner = order.firstWhere((id) => completedSymbol(id) != null,
          orElse: () => order.first);
    }
  }

  // ── Slam ────────────────────────────────────────────────────────────────────

  /// Record a player's slam reaction [ms] (time from the slam window opening).
  bool submitSlam(String id, int ms) {
    if (phase != 'slam') return false;
    if (!order.contains(id)) return false;
    slamTimes.putIfAbsent(id, () => ms);
    return true;
  }

  bool get allSlamsIn =>
      phase == 'slam' && order.every((id) => slamTimes.containsKey(id));

  /// Resolve the slam race: the slowest slammer earns a DHAPP letter. If that
  /// knocks them out, they're removed; then a new round is dealt (or the game
  /// ends with the last player standing).
  void resolveSlam(Random rng) {
    if (!allSlamsIn) return;
    // Slowest reaction (highest ms) loses; ties broken by seat order.
    String loser = order.first;
    int worst = -1;
    for (final id in order) {
      final t = slamTimes[id] ?? 1 << 30;
      if (t > worst) { worst = t; loser = id; }
    }
    letters[loser] = letterCount(loser) + 1;
    roundLoser = loser;
    roundLoserOut = isOut(loser);
    if (roundLoserOut) {
      order.remove(loser);
    }
    phase = 'reveal';
    if (order.length <= 1) {
      over = true;
      winner = order.isNotEmpty ? order.first : loser;
    }
  }

  /// Advance from the reveal dwell into the next round.
  void nextRound(Random rng) {
    if (over) return;
    round++;
    roundLoser = null;
    roundLoserOut = false;
    _deal(rng);
  }

  // ── Serialization ───────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'order': order,
        'hands': hands,
        'names': names,
        'bots': bots,
        'symbols': symbols,
        'dir': dir,
        'round': round,
        'phase': phase,
        'pendingPass': pendingPass,
        'slamTimes': slamTimes,
        'setOwner': setOwner,
        'letters': letters,
        'roundLoser': roundLoser,
        'roundLoserOut': roundLoserOut,
        'winner': winner,
        'over': over,
      };

  factory ParchiState.fromMap(Map m) => ParchiState(
        order: List<String>.from(m['order'] ?? const []),
        hands: ((m['hands'] as Map?) ?? {}).map(
            (k, v) => MapEntry(k as String, List<String>.from(v as List))),
        names: Map<String, String>.from(m['names'] ?? const {}),
        bots: ((m['bots'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, v == true)),
        symbols: List<String>.from(m['symbols'] ?? const []),
        dir: (m['dir'] as int?) ?? 1,
        round: (m['round'] as int?) ?? 1,
        phase: (m['phase'] as String?) ?? 'passing',
        pendingPass: ((m['pendingPass'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, v.toString())),
        slamTimes: ((m['slamTimes'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
        setOwner: m['setOwner'] as String?,
        letters: ((m['letters'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
        roundLoser: m['roundLoser'] as String?,
        roundLoserOut: m['roundLoserOut'] == true,
        winner: m['winner'] as String?,
        over: m['over'] == true,
      );
}

// ── Bot AI ─────────────────────────────────────────────────────────────────
class ParchiBot {
  static final _rng = Random();

  /// Which symbol a bot passes: keep the symbol it has most of, pass a card from
  /// the smallest pile (a singleton). Easy bots sometimes pass at random.
  static String choosePass(ParchiState s, String botId, int level) {
    final hand = s.hands[botId] ?? const [];
    if (hand.isEmpty) return '';
    final counts = <String, int>{};
    for (final c in hand) {
      counts[c] = (counts[c] ?? 0) + 1;
    }
    // Easy: 40% random; Medium: 15%; Hard: never.
    final randomChance = level == 0 ? 0.40 : (level == 1 ? 0.15 : 0.0);
    if (_rng.nextDouble() < randomChance) {
      return hand[_rng.nextInt(hand.length)];
    }
    // Pass a card from the rarest symbol (don't break your biggest pile).
    final sorted = counts.keys.toList()
      ..sort((a, b) => counts[a]!.compareTo(counts[b]!));
    return sorted.first;
  }

  /// A bot's slam reaction in ms (lower = faster). The player who completed the
  /// set reacts almost instantly; others react per difficulty. Higher bot
  /// difficulty = faster bots = harder for the human not to be last.
  static int reactionMs(ParchiState s, String botId, int level) {
    if (s.setOwner == botId) return 60 + _rng.nextInt(80); // 60–140ms
    switch (level) {
      case 0: // Easy — sluggish bots, human usually safe
        return 900 + _rng.nextInt(900); // 900–1800
      case 1: // Medium
        return 500 + _rng.nextInt(700); // 500–1200
      default: // Hard — sharp bots
        return 250 + _rng.nextInt(450); // 250–700
    }
  }
}
