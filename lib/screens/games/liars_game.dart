import 'dart:async';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../functions/liars_deck_engine.dart';
import '../../functions/liars_service.dart';
import '../../helpers/constant.dart';
import '../../helpers/utils.dart';
import '../../widgets/liars_art.dart';
import '../../widgets/voice_chat_button.dart';

// ════════════════════════════════════════════════════════════════════════════
// Liar's Bar — the around-the-table game screen. Liar's Deck (offline vs AI).
// Online + Liar's Dice are added in later steps.
// ════════════════════════════════════════════════════════════════════════════

const _me = 'me';

class LiarsGameScreen extends StatefulWidget {
  final int aiLevel;
  final int playerCount;
  final String ruleset; // basic | devil | chaos
  final bool online;
  final String? gameId;
  final String? myId;
  const LiarsGameScreen({
    super.key,
    this.aiLevel = 1,
    this.playerCount = 4,
    this.ruleset = 'basic',
    this.online = false,
    this.gameId,
    this.myId,
  });

  @override
  State<LiarsGameScreen> createState() => _LiarsGameScreenState();
}

class _LiarsGameScreenState extends State<LiarsGameScreen> {
  late LiarsDeckState _s;
  final _rng = Random();
  final List<Timer> _pending = [];
  bool _disposed = false;
  bool _resultShown = false;
  final Set<int> _selected = {};
  String? _aiming;   // player currently raising the gun
  bool _firing = false;

  // Online
  bool get _online => widget.online;
  String get _meId => _online ? widget.myId! : _me;
  StreamSubscription<DatabaseEvent>? _gameSub;
  Timer? _watch;
  int _lastActionAt = 0;
  bool _gotState = false;
  bool _claimed = false;
  String? _lastShotKey; // de-dupes the online shoot flash

  @override
  void initState() {
    super.initState();
    if (_online) {
      _initOnline();
    } else {
      _newGame();
      WidgetsBinding.instance.addPostFrameCallback((_) => _afterChange());
    }
  }

  void _initOnline() {
    _s = LiarsDeckState(
      order: [_meId], hands: {_meId: const []},
      names: {_meId: 'You'}, chars: {_meId: 'kudo'},
      turn: 0, tableRank: 'K', ruleset: widget.ruleset,
    );
    _gameSub = LiarsService.gameStream(widget.gameId!).listen((ev) {
      if (_disposed || !mounted || ev.snapshot.value == null) return;
      final map = Map<String, dynamic>.from(ev.snapshot.value as Map);
      _lastActionAt = (map['lastActionAt'] as int?) ?? 0;
      final ns = LiarsDeckState.fromMap(map);
      _onOnlineState(ns);
    });
    _watch = Timer.periodic(const Duration(seconds: 1), (_) => _tickWatch());
  }

  void _onOnlineState(LiarsDeckState ns) {
    // drive the shoot flash from incoming shot results
    if (ns.phase == 'shoot' || (ns.phase == 'reveal' && ns.lastShotPlayer != null)) {
      _aiming = ns.lastShotPlayer ?? ns.nextShooter;
      final key = '${ns.round}-${ns.lastShotPlayer}-${ns.gunPos[ns.lastShotPlayer]}';
      if (ns.lastShotPlayer != null && key != _lastShotKey) {
        _lastShotKey = key;
        _firing = true;
        music.play(click);
        _delay(800, () => setState(() => _firing = false));
      }
    } else {
      _aiming = null;
      _firing = false;
    }
    setState(() { _s = ns; _gotState = true; });
    if (ns.over) {
      if (ns.winner == _meId && !_claimed) {
        _claimed = true;
        LiarsService.claimPot(widget.gameId!);
      }
      _showResult();
    }
  }

  void _tickWatch() {
    if (_disposed || !_gotState || _s.over) return;
    final gid = widget.gameId!;
    if (_s.phase == 'shoot') {
      LiarsService.autoResolveShot(gid, _lastActionAt);
    } else if (_s.phase == 'reveal') {
      LiarsService.advanceRound(gid, _lastActionAt);
    } else if (_s.phase == 'play') {
      LiarsService.turnTimeout(gid, _s.currentId, _lastActionAt);
    }
  }

  void _newGame() {
    final n = widget.playerCount.clamp(2, 4);
    final ids = [_me, for (int i = 0; i < n - 1; i++) 'bot${i + 1}'];
    final pool = List.of(kLiarsCharIds)..shuffle(_rng);
    final chars = <String, String>{};
    final names = <String, String>{};
    for (int i = 0; i < ids.length; i++) {
      chars[ids[i]] = pool[i];
      names[ids[i]] = ids[i] == _me ? 'You' : kLiarsCharacters[pool[i]]!;
    }
    _s = LiarsDeckState.create(
      playerIds: ids, names: names, chars: chars,
      ruleset: widget.ruleset, rng: _rng,
    );
    _selected.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final t in _pending) {
      t.cancel();
    }
    _pending.clear();
    _gameSub?.cancel();
    _watch?.cancel();
    super.dispose();
  }

  Timer _delay(int ms, void Function() fn) {
    final t = Timer(Duration(milliseconds: ms), () {
      if (!_disposed && mounted) fn();
    });
    _pending.add(t);
    return t;
  }

  // ── Flow ─────────────────────────────────────────────────────────────────────
  void _afterChange() {
    if (_disposed || !mounted) return;
    if (_s.over) {
      _delay(700, _showResult);
      return;
    }
    if (_s.phase == 'shoot') {
      _runShootSequence();
      return;
    }
    if (_s.phase == 'play' && _s.currentId != _me) {
      _delay(850 + _rng.nextInt(500), _botMove);
    }
  }

  void _botMove() {
    if (_s.phase != 'play' || _s.currentId == _me) return;
    final botId = _s.currentId;
    final d = LiarsDeckBot.decide(_s, botId, widget.aiLevel);
    bool ok = false;
    if (d['action'] == 'call') {
      ok = _s.callLiar(botId);
    } else {
      ok = _s.play(botId, List<String>.from(d['cards'] as List));
    }
    if (!ok) {
      // fallback: play the first card
      final h = _s.hands[botId] ?? const [];
      if (h.isNotEmpty) _s.play(botId, [h.first]);
    }
    setState(() {});
    _afterChange();
  }

  Future<void> _runShootSequence() async {
    while (_s.phase == 'shoot' && mounted && !_disposed) {
      final shooter = _s.nextShooter;
      setState(() { _aiming = shooter; _firing = false; });
      await Future.delayed(const Duration(milliseconds: 1100));
      if (!mounted || _disposed) return;
      setState(() => _firing = true);
      _s.resolveNextShot(_rng);
      music.play(click);
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 950));
      if (!mounted || _disposed) return;
      setState(() => _firing = false);
      await Future.delayed(const Duration(milliseconds: 350));
    }
    if (!mounted || _disposed) return;
    setState(() => _aiming = null);
    if (_s.over) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) _showResult();
    } else {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted || _disposed) return;
      setState(() => _s.nextRound(_rng));
      _afterChange();
    }
  }

  // ── Human actions ─────────────────────────────────────────────────────────────
  bool get _myTurn => _s.phase == 'play' && _s.currentId == _meId && !_s.over;

  void _toggleCard(int i) {
    if (!_myTurn) return;
    final hand = _s.hands[_meId] ?? const [];
    if (i >= hand.length) return;
    final card = hand[i];
    setState(() {
      if (_selected.contains(i)) {
        _selected.remove(i);
        return;
      }
      if (kDeckSpecials.contains(card)) {
        _selected..clear()..add(i); // specials go alone
        return;
      }
      // if a special is already selected, clear it first
      _selected.removeWhere((j) => kDeckSpecials.contains(hand[j]));
      if (_selected.length >= _s.playMax) return;
      _selected.add(i);
    });
  }

  void _playSelected() {
    if (!_myTurn || _selected.isEmpty) return;
    final hand = _s.hands[_meId]!;
    final cards = (_selected.toList()..sort()).map((i) => hand[i]).toList();
    music.play(click);
    if (_online) {
      LiarsService.play(widget.gameId!, cards);
      setState(() => _selected.clear());
      return;
    }
    if (_s.play(_me, cards)) {
      setState(() => _selected.clear());
      _afterChange();
    }
  }

  void _callLiar() {
    if (!_myTurn || !_s.hasStandingPlay) return;
    music.play(click);
    if (_online) {
      LiarsService.callLiar(widget.gameId!);
      return;
    }
    if (_s.callLiar(_me)) {
      setState(() {});
      _afterChange();
    }
  }

  // ── Result ─────────────────────────────────────────────────────────────────────
  void _showResult() {
    if (_resultShown || !mounted) return;
    _resultShown = true;
    final won = _s.winner == _meId;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF241612),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(won ? '🏆' : '💀', style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 8),
            Text(won ? 'You Survived!' : 'You\'re Dead',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
            const SizedBox(height: 6),
            Text(
                won
                    ? 'Last liar standing at the bar.'
                    : '${_s.names[_s.winner] ?? 'Someone'} walked out alive.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () { Navigator.pop(context); Navigator.pop(context); },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                  child: const Text('Exit'),
                ),
              ),
              if (!_online) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () { Navigator.pop(context); _restart(); },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8E1D2C),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                    ),
                    child: const Text('Again', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  void _restart() {
    for (final t in _pending) {
      t.cancel();
    }
    _pending.clear();
    _resultShown = false;
    _aiming = null;
    _firing = false;
    setState(_newGame);
    _afterChange();
  }

  // ── UI ───────────────────────────────────────────────────────────────────────
  List<Alignment> _seatAligns(int opp) {
    switch (opp) {
      case 1: return const [Alignment(0, -0.82)];
      case 2: return const [Alignment(-0.72, -0.62), Alignment(0.72, -0.62)];
      default:
        return const [Alignment(-0.78, -0.5), Alignment(0, -0.86), Alignment(0.78, -0.5)];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_online && !_gotState) {
      return const Scaffold(
        backgroundColor: Color(0xFF130D0A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF8E1D2C))),
      );
    }
    // keep eliminated opponents visible as corpses too
    final allOpp = [..._s.names.keys.where((id) => id != _meId)];
    final aligns = _seatAligns(allOpp.length);

    return Scaffold(
      floatingActionButton: (_online && widget.gameId != null && widget.myId != null)
          ? VoiceChatButton(channel: widget.gameId!, myFbUid: widget.myId!)
          : null,
      body: Stack(children: [
        liarsBarBackground(),
        SafeArea(
          child: Column(children: [
            _topBar(),
            Expanded(
              child: Stack(children: [
                _tableFelt(),
                _centerInfo(),
                for (int i = 0; i < allOpp.length; i++)
                  Align(
                    alignment: aligns[i],
                    child: _seat(allOpp[i]),
                  ),
              ]),
            ),
            _myHandArea(),
          ]),
        ),
        if (_aiming != null) _shootOverlay(),
      ]),
    );
  }

  Widget _topBar() {
    final rulesetLabel = {'basic': 'BASIC', 'devil': 'DEVIL', 'chaos': 'CHAOS'}[_s.ruleset] ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 2),
      child: Row(children: [
        IconButton(
          onPressed: () { music.play(click); Navigator.pop(context); },
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Liar's Bar",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5)),
            Text("Liar's Deck · $rulesetLabel · Round ${_s.round}",
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF8E1D2C).withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF8E1D2C)),
          ),
          child: Text(['EASY', 'MEDIUM', 'HARD'][widget.aiLevel.clamp(0, 2)],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
        ),
      ]),
    );
  }

  Widget _tableFelt() {
    return Align(
      alignment: const Alignment(0, 0.35),
      child: FractionallySizedBox(
        widthFactor: 0.92,
        heightFactor: 0.62,
        child: Container(
          decoration: BoxDecoration(
            gradient: const RadialGradient(
              colors: [Color(0xFF1E5E3A), Color(0xFF123E27)],
            ),
            borderRadius: BorderRadius.all(Radius.elliptical(220, 160)),
            border: Border.all(color: const Color(0xFF3A2417), width: 10),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30, spreadRadius: 4)],
          ),
        ),
      ),
    );
  }

  Widget _centerInfo() {
    final rankName = {'A': "ACE'S", 'K': "KING'S", 'Q': "QUEEN'S"}[_s.tableRank] ?? '';
    String standing;
    if (_s.hasStandingPlay) {
      final nm = _s.names[_s.lastPlayer] ?? '';
      standing = '$nm claimed ${_s.lastCount} × ${_s.tableRank}';
    } else {
      standing = 'Open — make a claim';
    }
    return Align(
      alignment: const Alignment(0, 0.18),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        liarsCard(_s.tableRank, width: 56),
        const SizedBox(height: 8),
        Text('$rankName TABLE',
            style: const TextStyle(color: Color(0xFFE8C77A), fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(999)),
          child: Text(standing, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
        if (_s.hasStandingPlay)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (int i = 0; i < _s.lastCount.clamp(0, 3); i++)
                Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: liarsCard('K', width: 26, faceDown: true)),
            ]),
          ),
      ]),
    );
  }

  Widget _seat(String id) {
    final alive = _s.order.contains(id);
    final isCurrent = alive && _s.currentId == id && _s.phase == 'play';
    final justCalled = _s.phase == 'shoot' && _s.revChallenger == id;
    return SizedBox(
      width: 96,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (justCalled)
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFF8E1D2C), borderRadius: BorderRadius.circular(8)),
            child: const Text('LIAR!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
          ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isCurrent ? const Color(0xFFE8C77A) : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: isCurrent
                ? [const BoxShadow(color: Color(0x88E8C77A), blurRadius: 16, spreadRadius: 1)]
                : null,
          ),
          child: liarsCharacter(_s.chars[id] ?? 'scubby', size: 54, dead: !alive),
        ),
        const SizedBox(height: 2),
        Text(_s.names[id] ?? '',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: alive ? Colors.white : Colors.white38, fontWeight: FontWeight.w700, fontSize: 12)),
        if (alive)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            // card count
            ...List.generate(_s.handCount(id).clamp(0, 5),
                (_) => Container(width: 7, height: 10, margin: const EdgeInsets.symmetric(horizontal: 0.5),
                    decoration: BoxDecoration(color: const Color(0xFF8E1D2C), borderRadius: BorderRadius.circular(1.5)))),
          ])
        else
          const Text('OUT', style: TextStyle(color: Color(0xFF8E1D2C), fontWeight: FontWeight.w900, fontSize: 10)),
        if (alive)
          Padding(padding: const EdgeInsets.only(top: 2),
              child: liarsRevolver(size: 30)),
      ]),
    );
  }

  Widget _myHandArea() {
    final hand = List<String>.from(_s.hands[_meId] ?? const []);
    final alive = _s.order.contains(_meId);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1A100C),
        border: Border(top: BorderSide(color: Color(0xFF3A2417), width: 2)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // my identity row
        Row(children: [
          liarsCharacter(_s.chars[_meId] ?? 'kudo', size: 30, dead: !alive),
          const SizedBox(width: 8),
          Text(alive ? 'You' : 'You (dead)',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
          const Spacer(),
          liarsRevolver(size: 34),
        ]),
        const SizedBox(height: 8),
        // hand
        SizedBox(
          height: 92,
          child: hand.isEmpty
              ? const Center(child: Text('No cards — you must call Liar!',
                  style: TextStyle(color: Colors.white54, fontSize: 12)))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < hand.length; i++)
                      GestureDetector(
                        onTap: () => _toggleCard(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          transform: Matrix4.translationValues(0, _selected.contains(i) ? -14 : 0, 0),
                          child: liarsCard(hand[i], width: 52),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _actionBtn(
              'CALL LIAR',
              const Color(0xFF8E1D2C),
              (_myTurn && _s.hasStandingPlay) ? _callLiar : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _actionBtn(
              _selected.isEmpty ? 'PLAY' : 'PLAY ${_selected.length}',
              const Color(0xFF1E7A46),
              (_myTurn && _selected.isNotEmpty) ? _playSelected : null,
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback? onTap) {
    final on = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: on ? color : color.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(14),
          boxShadow: on ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12, offset: const Offset(0, 4))] : null,
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(color: on ? Colors.white : Colors.white38, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
        ),
      ),
    );
  }

  Widget _shootOverlay() {
    final id = _aiming!;
    final fired = _firing && _s.lastShotPlayer == id;
    return _ShootScene(
      charId: _s.chars[id] ?? 'scubby',
      name: id == _meId ? 'You' : (_s.names[id] ?? ''),
      firing: _firing,
      dead: fired && _s.lastShotDead,
      safe: fired && !_s.lastShotDead,
      revealCards: _firing ? const [] : _s.revCards,
      wasLie: _s.revWasLie,
    );
  }
}

// ── Cinematic shoot scene ─────────────────────────────────────────────────────
// The losing character is shown with the revolver to the temple. While aiming
// the gun trembles; on fire a muzzle flash + recoil + (on a live round) a heavy
// screen shake, red flash and the character slumping.
class _ShootScene extends StatefulWidget {
  final String charId, name;
  final bool firing, dead, safe;
  final List<String> revealCards;
  final bool wasLie;
  const _ShootScene({
    required this.charId,
    required this.name,
    required this.firing,
    required this.dead,
    required this.safe,
    required this.revealCards,
    required this.wasLie,
  });

  @override
  State<_ShootScene> createState() => _ShootSceneState();
}

class _ShootSceneState extends State<_ShootScene> with TickerProviderStateMixin {
  late final AnimationController _tremble =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 650));

  @override
  void didUpdateWidget(covariant _ShootScene old) {
    super.didUpdateWidget(old);
    if (!old.firing && widget.firing) {
      _shake.forward(from: 0);
      if (widget.dead) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    }
  }

  @override
  void dispose() {
    _tremble.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiming = !widget.firing;
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: Listenable.merge([_tremble, _shake]),
        builder: (context, _) {
          // shake decays over the controller's run; bigger for a live round
          final t = _shake.value;
          final amp = (widget.dead ? 16.0 : 5.0) * (1 - t);
          final dx = sin(t * pi * 7) * amp;
          final dy = cos(t * pi * 5) * amp * 0.5;
          // subtle aim tremble before firing
          final trem = aiming ? sin(_tremble.value * pi * 2) * 1.6 : 0.0;
          final flashOpacity = (widget.dead && widget.firing) ? (1 - t) * 0.55 : 0.0;

          return Stack(children: [
            Container(color: Colors.black.withValues(alpha: 0.86)),
            // red kill-flash
            Positioned.fill(
              child: IgnorePointer(
                child: Container(color: const Color(0xFFB02020).withValues(alpha: flashOpacity)),
              ),
            ),
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (widget.revealCards.isNotEmpty) ...[
                  Text(widget.wasLie ? 'IT WAS A LIE!' : 'IT WAS TRUE!',
                      style: TextStyle(
                          color: widget.wasLie ? const Color(0xFFE05A4A) : const Color(0xFF5AC77A),
                          fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: widget.revealCards
                          .map((c) => Padding(padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: liarsCard(c, width: 42)))
                          .toList()),
                  const SizedBox(height: 22),
                ],
                // character + gun stage (shaken)
                Transform.translate(
                  offset: Offset(dx + trem, dy),
                  child: SizedBox(
                    width: 280, height: 180,
                    child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                      Align(
                        alignment: const Alignment(-0.15, 0),
                        child: liarsCharacter(widget.charId, size: 150, dead: widget.dead),
                      ),
                      // revolver to the temple (muzzle on its left points into the head)
                      Align(
                        alignment: const Alignment(0.95, -0.28),
                        child: Transform.rotate(
                          angle: -0.18,
                          child: liarsRevolver(size: 120, firing: widget.firing && !widget.safe),
                        ),
                      ),
                      if (widget.dead && widget.firing)
                        const Align(
                          alignment: Alignment(-0.15, -0.25),
                          child: Text('💥', style: TextStyle(fontSize: 64)),
                        ),
                    ]),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.dead
                      ? '${widget.name} — BANG! 💀'
                      : (widget.safe ? '${widget.name} — *click*… alive' : '${widget.name} raises the gun…'),
                  style: TextStyle(
                      color: widget.dead ? const Color(0xFFE05A4A) : Colors.white,
                      fontWeight: FontWeight.w900, fontSize: 20),
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
