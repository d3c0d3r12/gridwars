import 'dart:math';

// ════════════════════════════════════════════════════════════════════════════
// Liar's Dice engine — pure, serializable. Drives offline vs-Computer AND
// Firebase multiplayer.
//
// Each player has 5 hidden dice and 2 "poison" lives. Players bid "there are at
// least N dice showing face F across the whole table"; each bid must strictly
// raise (higher count, or same count + higher face). On your turn you Raise,
// Call (challenge the standing bid), or — Traditional only — Spot On (claim the
// count is exact).
//   Call  → reveal all: actual >= bid.count → the CALLER drinks; else the BIDDER.
//   SpotOn→ actual == bid.count → everyone ELSE drinks; else the caller drinks.
//   Traditional: 1s are WILD (count as the bid face, unless the bid face is 1).
// Drink twice → eliminated. Last player alive wins.
// ════════════════════════════════════════════════════════════════════════════

const int kDiceMaxLives = 2;
const int kDicePerPlayer = 5;

class LiarsDiceState {
  List<String> order;
  Map<String, List<int>> dice;        // playerId → 5 dice (hidden)
  Map<String, String> names;
  Map<String, String> chars;
  int turn;
  int bidCount;                       // 0 = no standing bid yet
  int bidFace;                        // 1..6
  String? lastBidder;
  String ruleset;                     // basic | traditional
  Map<String, int> lives;             // remaining lives (start 2)
  String phase;                       // bid | reveal | over
  // reveal info
  String? revCaller;
  int revActual;
  String? revLoser;
  bool revSpotOn;
  bool revWasSpotCall;
  int round;
  String? winner;
  bool over;

  LiarsDiceState({
    required this.order,
    required this.dice,
    required this.names,
    required this.chars,
    this.turn = 0,
    this.bidCount = 0,
    this.bidFace = 1,
    this.lastBidder,
    this.ruleset = 'basic',
    Map<String, int>? lives,
    this.phase = 'bid',
    this.revCaller,
    this.revActual = 0,
    this.revLoser,
    this.revSpotOn = false,
    this.revWasSpotCall = false,
    this.round = 1,
    this.winner,
    this.over = false,
  }) : lives = lives ?? <String, int>{};

  String get currentId => order[turn % order.length];
  int diceCount(String id) => dice[id]?.length ?? 0;
  int livesOf(String id) => lives[id] ?? 0;
  bool get hasBid => bidCount > 0 && lastBidder != null && order.contains(lastBidder);
  int get totalDice => order.fold(0, (a, id) => a + diceCount(id));

  /// Count of [face] across the table (1s wild in traditional, unless face==1).
  int countFace(int face) {
    int n = 0;
    final wild = ruleset == 'traditional' && face != 1;
    for (final id in order) {
      for (final d in dice[id] ?? const []) {
        if (d == face || (wild && d == 1)) n++;
      }
    }
    return n;
  }

  factory LiarsDiceState.create({
    required List<String> playerIds,
    required Map<String, String> names,
    required Map<String, String> chars,
    String ruleset = 'basic',
    Random? rng,
  }) {
    final s = LiarsDiceState(
      order: List.of(playerIds),
      dice: {},
      names: names,
      chars: chars,
      ruleset: ruleset,
      lives: {for (final id in playerIds) id: kDiceMaxLives},
    );
    s._roll(rng ?? Random(), startTurn: 0);
    return s;
  }

  void _roll(Random rng, {required int startTurn}) {
    dice = {
      for (final id in order)
        id: [for (int i = 0; i < kDicePerPlayer; i++) 1 + rng.nextInt(6)]
    };
    bidCount = 0;
    bidFace = 1;
    lastBidder = null;
    revCaller = revLoser = null;
    revActual = 0;
    revSpotOn = false;
    revWasSpotCall = false;
    phase = 'bid';
    turn = order.isEmpty ? 0 : startTurn % order.length;
  }

  bool isRaise(int count, int face) {
    if (face < 1 || face > 6 || count < 1) return false;
    if (count > totalDice) return false;
    if (!hasBid) return true;
    if (count > bidCount) return true;
    return count == bidCount && face > bidFace;
  }

  bool bid(String player, int count, int face) {
    if (phase != 'bid' || player != currentId) return false;
    if (!isRaise(count, face)) return false;
    bidCount = count;
    bidFace = face;
    lastBidder = player;
    _advance();
    return true;
  }

  bool callLiar(String challenger) {
    if (phase != 'bid' || challenger != currentId || !hasBid) return false;
    final actual = countFace(bidFace);
    revCaller = challenger;
    revActual = actual;
    revWasSpotCall = false;
    // bid good (actual >= count) → caller drinks; else bidder drinks
    final loser = actual >= bidCount ? challenger : lastBidder!;
    _applyDrink(loser);
    return true;
  }

  /// Traditional only: claim the standing bid is exactly right.
  bool spotOn(String caller) {
    if (ruleset != 'traditional') return false;
    if (phase != 'bid' || caller != currentId || !hasBid) return false;
    final actual = countFace(bidFace);
    revCaller = caller;
    revActual = actual;
    revWasSpotCall = true;
    if (actual == bidCount) {
      revSpotOn = true;
      // everyone else drinks one
      for (final id in List.of(order)) {
        if (id != caller) _drink(id);
      }
      revLoser = null;
      _finishResolve();
    } else {
      revSpotOn = false;
      _applyDrink(caller);
    }
    return true;
  }

  void _applyDrink(String loser) {
    revLoser = loser;
    _drink(loser);
    _finishResolve();
  }

  void _drink(String id) {
    lives[id] = (lives[id] ?? 0) - 1;
    if ((lives[id] ?? 0) <= 0) {
      final idx = order.indexOf(id);
      if (idx >= 0) {
        order.removeAt(idx);
        if (idx < turn) turn--;
      }
    }
  }

  void _finishResolve() {
    phase = 'reveal';
    if (order.length <= 1) {
      over = true;
      winner = order.isNotEmpty ? order.first : revLoser;
    }
  }

  void nextRound(Random rng) {
    if (over) return;
    round++;
    int start = 0;
    final pivot = revLoser ?? lastBidder;
    if (pivot != null && order.contains(pivot)) {
      start = order.indexOf(pivot);
    }
    _roll(rng, startTurn: start);
  }

  void _advance() {
    if (order.isEmpty) return;
    turn = (turn + 1) % order.length;
  }

  Map<String, dynamic> toMap() => {
        'kind': 'dice',
        'order': order,
        'dice': dice,
        'names': names,
        'chars': chars,
        'turn': turn,
        'bidCount': bidCount,
        'bidFace': bidFace,
        'lastBidder': lastBidder,
        'ruleset': ruleset,
        'lives': lives,
        'phase': phase,
        'revCaller': revCaller,
        'revActual': revActual,
        'revLoser': revLoser,
        'revSpotOn': revSpotOn,
        'revWasSpotCall': revWasSpotCall,
        'round': round,
        'winner': winner,
        'over': over,
      };

  factory LiarsDiceState.fromMap(Map m) => LiarsDiceState(
        order: List<String>.from(m['order'] ?? const []),
        dice: ((m['dice'] as Map?) ?? {}).map((k, v) =>
            MapEntry(k as String, List<int>.from((v as List).map((e) => (e as num).toInt())))),
        names: Map<String, String>.from(m['names'] ?? const {}),
        chars: Map<String, String>.from(m['chars'] ?? const {}),
        turn: (m['turn'] as int?) ?? 0,
        bidCount: (m['bidCount'] as int?) ?? 0,
        bidFace: (m['bidFace'] as int?) ?? 1,
        lastBidder: m['lastBidder'] as String?,
        ruleset: (m['ruleset'] as String?) ?? 'basic',
        lives: ((m['lives'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
        phase: (m['phase'] as String?) ?? 'bid',
        revCaller: m['revCaller'] as String?,
        revActual: (m['revActual'] as int?) ?? 0,
        revLoser: m['revLoser'] as String?,
        revSpotOn: m['revSpotOn'] == true,
        revWasSpotCall: m['revWasSpotCall'] == true,
        round: (m['round'] as int?) ?? 1,
        winner: m['winner'] as String?,
        over: m['over'] == true,
      );
}

// ── Bot AI ─────────────────────────────────────────────────────────────────
// FAIR PLAY: a bot only sees its OWN dice plus public info (dice counts, the
// standing bid). It never peeks at opponents' dice — it reasons from the
// binomial expectation. Hard bots additionally read the bid itself as a signal
// (a bidder probably holds some of the face they bid) — legitimate deduction,
// not cheating. Difficulty changes only how sharp the reasoning is.
class LiarsDiceBot {
  static final _rng = Random();

  /// Returns {action:'bid',count,face} | {action:'call'} | {action:'spot'}.
  static Map<String, dynamic> decide(LiarsDiceState s, String botId, int level) {
    final my = s.dice[botId] ?? const [];
    final unknown = s.totalDice - my.length;

    double expected(int face) {
      final wild = s.ruleset == 'traditional' && face != 1;
      final mine = my.where((d) => d == face || (wild && d == 1)).length;
      final p = wild ? 2 / 6 : 1 / 6;
      // hard bots account for the bidder's implied holding of the bid face
      final signal = (level == 2 && face == s.bidFace && s.hasBid) ? 0.6 : 0.0;
      return mine + unknown * p + signal;
    }

    if (!s.hasBid) {
      // opening bid: my most common face, claim what I hold (safe).
      int bestFace = 2, bestN = -1;
      for (int f = 1; f <= 6; f++) {
        final n = my.where((d) => d == f).length;
        if (n > bestN) { bestN = n; bestFace = f; }
      }
      final count = max(1, bestN);
      return {'action': 'bid', 'count': count, 'face': bestFace};
    }

    final exp = expected(s.bidFace);
    // Traditional: if the standing bid looks exactly right, sometimes spot-on.
    if (s.ruleset == 'traditional' && level >= 1 &&
        (s.bidCount - exp).abs() < 0.4 && _rng.nextDouble() < 0.3) {
      return {'action': 'spot'};
    }
    // Call if the standing bid is unlikely to hold.
    final overshoot = s.bidCount - exp; // >0 means bid looks too high
    final callBias = level == 0 ? 1.9 : (level == 1 ? 1.0 : 0.5);
    // easy bots also misjudge at random; hard bots are steady.
    final wobble = level == 0 ? _rng.nextDouble() * 0.8 : 0.0;
    if (overshoot > callBias + wobble || s.bidCount > s.totalDice) {
      return {'action': 'call'};
    }
    // Otherwise raise: prefer raising my own strong face.
    int myBestFace = s.bidFace, myBestN = -1;
    for (int f = 1; f <= 6; f++) {
      final n = my.where((d) => d == f).length;
      if (n > myBestN) { myBestN = n; myBestFace = f; }
    }
    if (myBestFace > s.bidFace) {
      return {'action': 'bid', 'count': s.bidCount, 'face': myBestFace};
    }
    return {'action': 'bid', 'count': s.bidCount + 1, 'face': s.bidFace};
  }
}
