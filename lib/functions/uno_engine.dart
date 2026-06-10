import 'dart:math';

// ════════════════════════════════════════════════════════════════════════════
// UNO engine — pure, serializable. Drives local vs-Computer AND Firebase
// multiplayer. House rules: action-card STACKING, JUMP-IN, 7-0.
//
// MODES (the deck is built differently; rules are otherwise shared):
//   'classic'  — standard 108-card deck.
//   'allWild'  — every card is a wild-action card (Wild, Wild+2, Wild+4,
//                Wild Skip, Wild Reverse). Pure chaos, pick a colour every turn.
//   'noMercy'  — classic + Draw 6, Draw 10, Skip-Everyone + extra +4s; any draw
//                stacks on any draw; reach 25 cards and you're KNOCKED OUT.
//
// Card codes:
//   numbers : '<c><0-9>'   skip:'<c>S'  reverse:'<c>R'  draw2:'<c>D'
//   no-mercy: draw6 '<c>#6'   draw10 '<c>#10'   skip-all '<c>#A'
//   wilds   : 'W'  'W4'  'W2'(wild+2)  'WS'(wild skip)  'WR'(wild reverse)
//   (c = r/y/g/b)
// ════════════════════════════════════════════════════════════════════════════

const List<String> kUnoColors = ['r', 'y', 'g', 'b'];
const Map<String, String> kColorName = {'r': 'Red', 'y': 'Yellow', 'g': 'Green', 'b': 'Blue'};

class UnoCard {
  static String colorOf(String code) => code.startsWith('W') ? 'w' : code[0];

  static bool isAnyWild(String code) => code.startsWith('W'); // W, W2, W4, WS, WR
  static bool isNumber(String code) =>
      code.length == 2 && code.codeUnitAt(1) >= 48 && code.codeUnitAt(1) <= 57;
  static int? digit(String code) => isNumber(code) ? code.codeUnitAt(1) - 48 : null;

  static bool isSkip(String code) => code == 'WS' || (code.length == 2 && code[1] == 'S');
  static bool isReverse(String code) => code == 'WR' || (code.length == 2 && code[1] == 'R');
  static bool isSkipAll(String code) => code.endsWith('#A');

  /// How many cards this card forces the next player to draw (0 if none).
  static int drawAmount(String code) {
    if (code == 'W4') return 4;
    if (code == 'W2') return 2;
    if (code.length == 2 && code[1] == 'D') return 2;
    if (code.endsWith('#10')) return 10;
    if (code.endsWith('#6')) return 6;
    return 0;
  }

  static bool isDrawCard(String code) => drawAmount(code) > 0;

  static String label(String code) {
    if (code == 'W') return 'W';
    if (code == 'W4') return '+4';
    if (code == 'W2') return '+2';
    if (code == 'WS') return '⊘';
    if (code == 'WR') return '⇄';
    if (code.endsWith('#6')) return '+6';
    if (code.endsWith('#10')) return '+10';
    if (code.endsWith('#A')) return '∅';
    if (isSkip(code)) return '⊘';
    if (isReverse(code)) return '⇄';
    if (code.length == 2 && code[1] == 'D') return '+2';
    return code[1]; // number
  }

  /// Small tag shown under a wild so players know what it does.
  static String? wildTag(String code) {
    switch (code) {
      case 'W': return 'WILD';
      case 'W4': return 'WILD +4';
      case 'W2': return 'WILD +2';
      case 'WS': return 'WILD SKIP';
      case 'WR': return 'WILD REV';
    }
    return null;
  }
}

List<String> _classicDeck() {
  final d = <String>[];
  for (final c in kUnoColors) {
    d.add('${c}0');
    for (int n = 1; n <= 9; n++) { d.add('$c$n'); d.add('$c$n'); }
    for (final a in ['S', 'R', 'D']) { d.add('$c$a'); d.add('$c$a'); }
  }
  for (int i = 0; i < 4; i++) { d.add('W'); d.add('W4'); }
  return d;
}

/// Build the deck for a given [mode], shuffled.
List<String> buildUnoDeck(String mode, [Random? rng]) {
  final r = rng ?? Random();
  List<String> d;
  if (mode == 'allWild') {
    d = <String>[];
    // ~96 cards, all wild-action.
    for (int i = 0; i < 16; i++) {
      d..add('W')..add('W')..add('W2')..add('W4')..add('WS')..add('WR');
    }
  } else if (mode == 'noMercy') {
    d = _classicDeck();
    for (final c in kUnoColors) {
      d..add('$c#6')..add('$c#6')   // Draw 6 ×2
        ..add('$c#10')              // Draw 10 ×1
        ..add('$c#A')..add('$c#A'); // Skip-Everyone ×2
    }
    for (int i = 0; i < 4; i++) { d.add('W4'); } // extra +4s — no mercy
  } else {
    d = _classicDeck();
  }
  d.shuffle(r);
  return d;
}

class UnoEvent {
  final String text;
  const UnoEvent(this.text);
}

class UnoState {
  List<String> order;
  Map<String, List<String>> hands;
  Map<String, String> names;
  Map<String, bool> bots;

  int turn;
  int dir;
  List<String> drawPile;
  List<String> discard;
  String activeColor;
  int pendingDraw;
  String pendingKind; // '' or 'draw' (any-draw stacking)
  String mode;
  String? winner;
  bool over;
  Set<String> calledUno;
  List<String> eliminated; // No Mercy knockouts

  UnoState({
    required this.order,
    required this.hands,
    required this.names,
    required this.bots,
    required this.turn,
    required this.dir,
    required this.drawPile,
    required this.discard,
    required this.activeColor,
    this.pendingDraw = 0,
    this.pendingKind = '',
    this.mode = 'classic',
    this.winner,
    this.over = false,
    Set<String>? calledUno,
    List<String>? eliminated,
  })  : calledUno = calledUno ?? <String>{},
        eliminated = eliminated ?? <String>[];

  String get topCard => discard.last;
  String get currentId => order[turn];
  bool isBot(String id) => bots[id] ?? false;
  int handCount(String id) => hands[id]?.length ?? 0;
  static const int knockoutAt = 25;

  factory UnoState.create({
    required List<String> playerIds,
    required Map<String, String> names,
    required Map<String, bool> bots,
    String mode = 'classic',
    int handSize = 7,
    Random? rng,
  }) {
    final deck = buildUnoDeck(mode, rng);
    final hands = <String, List<String>>{};
    for (final id in playerIds) {
      hands[id] = [for (int i = 0; i < handSize; i++) deck.removeLast()];
    }
    String first = deck.removeLast();
    if (mode == 'allWild') {
      // Every card is wild — just start one and pick a random colour.
      return UnoState(
        order: List.of(playerIds), hands: hands, names: names, bots: bots,
        turn: 0, dir: 1, drawPile: deck, discard: [first],
        activeColor: kUnoColors[(rng ?? Random()).nextInt(4)], mode: mode,
      );
    }
    // Otherwise flip the first plain card (no wild / no draw starter).
    int guard = 0;
    while ((UnoCard.isAnyWild(first) || UnoCard.isDrawCard(first) || UnoCard.isSkipAll(first)) && guard < 200) {
      deck.insert(0, first);
      first = deck.removeLast();
      guard++;
    }
    return UnoState(
      order: List.of(playerIds), hands: hands, names: names, bots: bots,
      turn: 0, dir: 1, drawPile: deck, discard: [first],
      activeColor: UnoCard.colorOf(first), mode: mode,
    );
  }

  Map<String, dynamic> toMap() => {
        'order': order,
        'hands': hands,
        'names': names,
        'bots': bots,
        'turn': turn,
        'dir': dir,
        'drawPile': drawPile,
        'discard': discard,
        'activeColor': activeColor,
        'pendingDraw': pendingDraw,
        'pendingKind': pendingKind,
        'mode': mode,
        'winner': winner,
        'over': over,
        'calledUno': calledUno.toList(),
        'eliminated': eliminated,
      };

  factory UnoState.fromMap(Map m) => UnoState(
        order: List<String>.from(m['order']),
        hands: (m['hands'] as Map).map((k, v) => MapEntry(k as String, List<String>.from(v))),
        names: Map<String, String>.from(m['names']),
        bots: (m['bots'] as Map).map((k, v) => MapEntry(k as String, v == true)),
        turn: m['turn'] as int,
        dir: m['dir'] as int,
        drawPile: List<String>.from(m['drawPile']),
        discard: List<String>.from(m['discard']),
        activeColor: m['activeColor'] as String,
        pendingDraw: (m['pendingDraw'] as int?) ?? 0,
        pendingKind: (m['pendingKind'] as String?) ?? '',
        mode: (m['mode'] as String?) ?? 'classic',
        winner: m['winner'] as String?,
        over: m['over'] == true,
        calledUno: {...(m['calledUno'] as List? ?? [])}.cast<String>(),
        eliminated: List<String>.from(m['eliminated'] as List? ?? const []),
      );

  // ── Rules ─────────────────────────────────────────────────────────────────
  bool canPlay(String card) {
    // Under a draw stack you may only continue it with ANY draw card.
    if (pendingDraw > 0) return UnoCard.isDrawCard(card);
    if (UnoCard.isAnyWild(card)) return true;
    final top = topCard;
    if (UnoCard.colorOf(card) == activeColor) return true;
    if (UnoCard.isNumber(card) && UnoCard.isNumber(top)) {
      return UnoCard.digit(card) == UnoCard.digit(top);
    }
    if (UnoCard.isSkipAll(card) && UnoCard.isSkipAll(top)) return true;
    if (UnoCard.isSkip(card) && UnoCard.isSkip(top)) return true;
    if (UnoCard.isReverse(card) && UnoCard.isReverse(top)) return true;
    // matching colored draw kinds (e.g. +2 on +2, +6 on +6)
    if (UnoCard.drawAmount(card) > 0 && UnoCard.drawAmount(top) > 0 &&
        !UnoCard.isAnyWild(card) && !UnoCard.isAnyWild(top)) {
      return UnoCard.drawAmount(card) == UnoCard.drawAmount(top);
    }
    return false;
  }

  bool canJumpIn(String playerId, String card) {
    if (over || pendingDraw > 0) return false;
    if (playerId == currentId) return false;
    if (UnoCard.isAnyWild(card)) return false;
    return card == topCard && (hands[playerId]?.contains(card) ?? false);
  }

  List<String> legalMoves(String playerId) {
    if (playerId != currentId) return const [];
    return (hands[playerId] ?? []).where(canPlay).toList();
  }

  int _step(int from, int steps) {
    final n = order.length;
    if (n == 0) return 0;
    return ((from + steps * dir) % n + n) % n;
  }

  List<UnoEvent> play(String card, {String? chosenColor, String? swapTarget}) {
    final events = <UnoEvent>[];
    final me = currentId;
    hands[me]!.remove(card);
    discard.add(card);

    if (hands[me]!.isEmpty) {
      over = true;
      winner = me;
      activeColor = UnoCard.isAnyWild(card) ? (chosenColor ?? activeColor) : UnoCard.colorOf(card);
      events.add(UnoEvent('${names[me]} wins!'));
      return events;
    }

    if (UnoCard.isAnyWild(card)) {
      activeColor = chosenColor ?? kUnoColors[Random().nextInt(4)];
      events.add(UnoEvent('Colour → ${kColorName[activeColor]}'));
    } else {
      activeColor = UnoCard.colorOf(card);
    }

    final two = order.length == 2;
    final amt = UnoCard.drawAmount(card);

    if (amt > 0) {
      pendingDraw += amt;
      pendingKind = 'draw';
      turn = _step(turn, 1);
      events.add(UnoEvent('+$amt! Stack a draw card or draw $pendingDraw'));
    } else if (UnoCard.isSkipAll(card)) {
      // Everyone else is skipped — you play again.
      events.add(const UnoEvent('Skipped everyone!'));
      // turn unchanged
    } else if (UnoCard.isSkip(card)) {
      turn = _step(turn, 2);
      events.add(const UnoEvent('Skipped!'));
    } else if (UnoCard.isReverse(card)) {
      dir = -dir;
      turn = two ? _step(turn, 2) : _step(turn, 1);
      events.add(const UnoEvent('Reversed!'));
    } else if (UnoCard.isNumber(card) && UnoCard.digit(card) == 0) {
      _rotateHands();
      turn = _step(turn, 1);
      events.add(const UnoEvent('0 — hands passed around!'));
    } else if (UnoCard.isNumber(card) && UnoCard.digit(card) == 7) {
      final target = swapTarget ?? order[_step(turn, 1)];
      if (target != me && hands.containsKey(target)) {
        final tmp = hands[me]!; hands[me] = hands[target]!; hands[target] = tmp;
        events.add(UnoEvent('7 — swapped hands with ${names[target]}!'));
      }
      turn = _step(turn, 1);
    } else {
      turn = _step(turn, 1);
    }
    return events;
  }

  void _rotateHands() {
    final n = order.length;
    final newHands = <String, List<String>>{};
    for (int i = 0; i < n; i++) {
      final giver = order[i];
      final receiver = order[((i + dir) % n + n) % n];
      newHands[receiver] = hands[giver]!;
    }
    hands..clear()..addAll(newHands);
  }

  List<String> draw(String playerId, int n) {
    final drawn = <String>[];
    for (int i = 0; i < n; i++) {
      if (drawPile.isEmpty) _reshuffle();
      if (drawPile.isEmpty) break;
      final c = drawPile.removeLast();
      hands[playerId]!.add(c);
      drawn.add(c);
    }
    calledUno.remove(playerId);
    return drawn;
  }

  void _reshuffle() {
    if (discard.length <= 1) return;
    final top = discard.removeLast();
    drawPile = List.of(discard)..shuffle();
    discard..clear()..add(top);
  }

  /// No Mercy: knock out anyone holding [knockoutAt]+ cards. Returns events.
  List<UnoEvent> _applyKnockouts() {
    if (mode != 'noMercy') return const [];
    final events = <UnoEvent>[];
    final dead = order.where((id) => (hands[id]?.length ?? 0) >= knockoutAt).toList();
    for (final id in dead) {
      final idx = order.indexOf(id);
      if (idx < 0) continue;
      order.removeAt(idx);
      hands.remove(id);
      eliminated.add(id);
      events.add(UnoEvent('${names[id]} hit $knockoutAt cards — KNOCKED OUT!'));
      if (idx < turn) turn--;
    }
    if (order.isNotEmpty && turn >= order.length) turn %= order.length;
    if (order.length == 1) { over = true; winner = order.first; }
    return events;
  }

  List<UnoEvent> takePenaltyAndPass() {
    final me = currentId;
    final n = pendingDraw;
    draw(me, n);
    pendingDraw = 0; pendingKind = '';
    final ev = [UnoEvent('${names[me]} drew $n')];
    ev.addAll(_applyKnockouts());
    if (over) return ev;
    if (order.contains(me)) turn = _step(turn, 1); // survived → next player
    // if me was eliminated, removeAt already shifted turn onto the next player
    return ev;
  }

  String? drawOne() {
    final me = currentId;
    final before = hands[me]!.length;
    draw(me, 1);
    if (hands[me]!.length == before) return null;
    return hands[me]!.last;
  }

  void passTurn() => turn = _step(turn, 1);

  List<UnoEvent> jumpIn(String playerId, String card, {String? chosenColor, String? swapTarget}) {
    turn = order.indexOf(playerId);
    final ev = [UnoEvent('${names[playerId]} jumped in!')];
    ev.addAll(play(card, chosenColor: chosenColor, swapTarget: swapTarget));
    return ev;
  }
}

// ── Bot AI ───────────────────────────────────────────────────────────────────
class UnoBot {
  static final _rng = Random();

  static ({String card, String? color})? chooseMove(UnoState s, String botId, int level) {
    final legal = s.legalMoves(botId);
    if (legal.isEmpty) return null;

    if (s.pendingDraw > 0) {
      final card = legal.first;
      return (card: card, color: UnoCard.isAnyWild(card) ? _bestColor(s, botId) : null);
    }
    if (level == 0) {
      final card = legal[_rng.nextInt(legal.length)];
      return (card: card, color: UnoCard.isAnyWild(card) ? _bestColor(s, botId) : null);
    }
    legal.sort((a, b) => _value(s, botId, b, level) - _value(s, botId, a, level));
    final card = legal.first;
    return (card: card, color: UnoCard.isAnyWild(card) ? _bestColor(s, botId) : null);
  }

  static int _value(UnoState s, String botId, String card, int level) {
    int minOpp = 99;
    for (final id in s.order) { if (id != botId) minOpp = min(minOpp, s.handCount(id)); }
    final aggressive = minOpp <= 2;
    final amt = UnoCard.drawAmount(card);
    if (amt >= 6) return 100;                 // dump big draws ASAP
    if (UnoCard.isSkipAll(card)) return aggressive ? 92 : 75;
    if (card == 'W4') return aggressive ? 95 : 25;
    if (amt == 2) return aggressive ? 90 : 70;
    if (UnoCard.isSkip(card) || UnoCard.isReverse(card)) return aggressive ? 80 : 60;
    if (card == 'W') return aggressive ? 50 : 15;
    final d = UnoCard.digit(card);
    if (d == 7 || d == 0) return level == 2 ? 55 : 40;
    return 30;
  }

  static String _bestColor(UnoState s, String botId) {
    final counts = {'r': 0, 'y': 0, 'g': 0, 'b': 0};
    for (final c in s.hands[botId]!) {
      final col = UnoCard.colorOf(c);
      if (counts.containsKey(col)) counts[col] = counts[col]! + 1;
    }
    String best = kUnoColors[_rng.nextInt(4)]; int bestN = -1;
    counts.forEach((k, v) { if (v > bestN) { bestN = v; best = k; } });
    return best;
  }

  static String swapTarget(UnoState s, String botId) {
    String best = botId; int fewest = 99;
    for (final id in s.order) {
      if (id == botId) continue;
      if (s.handCount(id) < fewest) { fewest = s.handCount(id); best = id; }
    }
    return best;
  }
}
