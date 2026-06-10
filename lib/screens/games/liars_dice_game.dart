import 'dart:async';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../functions/liars_dice_engine.dart';
import '../../functions/liars_service.dart';
import '../../helpers/constant.dart';
import '../../helpers/utils.dart';
import '../../widgets/liars_art.dart';
import '../../widgets/voice_chat_button.dart';

// ════════════════════════════════════════════════════════════════════════════
// Liar's Bar — Liar's Dice table screen (offline vs AI + online friends).
// ════════════════════════════════════════════════════════════════════════════

const _me = 'me';

class LiarsDiceScreen extends StatefulWidget {
  final int aiLevel;
  final int playerCount;
  final String ruleset; // basic | traditional
  final bool online;
  final String? gameId;
  final String? myId;
  const LiarsDiceScreen({
    super.key,
    this.aiLevel = 1,
    this.playerCount = 4,
    this.ruleset = 'basic',
    this.online = false,
    this.gameId,
    this.myId,
  });

  @override
  State<LiarsDiceScreen> createState() => _LiarsDiceScreenState();
}

class _LiarsDiceScreenState extends State<LiarsDiceScreen> {
  late LiarsDiceState _s;
  final _rng = Random();
  final List<Timer> _pending = [];
  bool _disposed = false;
  bool _resultShown = false;
  int _selCount = 1;
  int _selFace = 2;
  bool _revealing = false;

  bool get _online => widget.online;
  String get _meId => _online ? widget.myId! : _me;
  StreamSubscription<DatabaseEvent>? _gameSub;
  Timer? _watch;
  int _lastActionAt = 0;
  bool _gotState = false;
  bool _claimed = false;
  String _revKey = '';

  @override
  void initState() {
    super.initState();
    if (_online) {
      _initOnline();
    } else {
      _newGame();
      _syncBidControls();
      WidgetsBinding.instance.addPostFrameCallback((_) => _afterChange());
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
    _s = LiarsDiceState.create(
        playerIds: ids, names: names, chars: chars, ruleset: widget.ruleset, rng: _rng);
  }

  void _initOnline() {
    _s = LiarsDiceState(
      order: [_meId], dice: {_meId: const []},
      names: {_meId: 'You'}, chars: {_meId: 'kudo'}, ruleset: widget.ruleset,
    );
    _gameSub = LiarsService.gameStream(widget.gameId!).listen((ev) {
      if (_disposed || !mounted || ev.snapshot.value == null) return;
      final map = Map<String, dynamic>.from(ev.snapshot.value as Map);
      _lastActionAt = (map['lastActionAt'] as int?) ?? 0;
      final ns = LiarsDiceState.fromMap(map);
      _onOnlineState(ns);
    });
    _watch = Timer.periodic(const Duration(seconds: 1), (_) => _tickWatch());
  }

  void _onOnlineState(LiarsDiceState ns) {
    final key = '${ns.round}-${ns.phase}-${ns.revLoser}-${ns.revSpotOn}';
    _revealing = ns.phase == 'reveal';
    if (_revealing && key != _revKey) {
      _revKey = key;
      music.play(click);
    }
    setState(() { _s = ns; _gotState = true; });
    if (ns.phase == 'bid' && ns.currentId == _meId) _syncBidControls();
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
    if (_s.phase == 'reveal') {
      LiarsService.diceAdvanceRound(gid, _lastActionAt);
    } else if (_s.phase == 'bid') {
      LiarsService.diceTurnTimeout(gid, _s.currentId, _lastActionAt);
    }
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

  void _syncBidControls() {
    if (_s.hasBid) {
      if (_s.bidFace < 6) {
        _selCount = _s.bidCount;
        _selFace = _s.bidFace + 1;
      } else {
        _selCount = _s.bidCount + 1;
        _selFace = 1;
      }
    } else {
      _selCount = 1;
      _selFace = 2;
    }
  }

  // ── Offline flow ──────────────────────────────────────────────────────────────
  void _afterChange() {
    if (_disposed || !mounted) return;
    if (_s.over) { _delay(800, _showResult); return; }
    if (_s.phase == 'reveal') {
      setState(() => _revealing = true);
      _delay(2600, () {
        setState(() { _s.nextRound(_rng); _revealing = false; });
        _afterChange();
      });
      return;
    }
    if (_s.phase == 'bid') {
      if (_s.currentId == _me) {
        _syncBidControls();
        setState(() {});
      } else {
        _delay(900 + _rng.nextInt(500), _botMove);
      }
    }
  }

  void _botMove() {
    if (_s.phase != 'bid' || _s.currentId == _me) return;
    final botId = _s.currentId;
    final d = LiarsDiceBot.decide(_s, botId, widget.aiLevel);
    switch (d['action']) {
      case 'call': _s.callLiar(botId); break;
      case 'spot': _s.spotOn(botId); break;
      default: _s.bid(botId, d['count'] as int, d['face'] as int);
    }
    setState(() {});
    _afterChange();
  }

  // ── Human actions ─────────────────────────────────────────────────────────────
  bool get _myTurn => _s.phase == 'bid' && _s.currentId == _meId && !_s.over;

  void _doBid() {
    if (!_myTurn || !_s.isRaise(_selCount, _selFace)) return;
    music.play(click);
    if (_online) {
      LiarsService.diceBid(widget.gameId!, _selCount, _selFace);
      return;
    }
    if (_s.bid(_me, _selCount, _selFace)) { setState(() {}); _afterChange(); }
  }

  void _doCall() {
    if (!_myTurn || !_s.hasBid) return;
    music.play(click);
    if (_online) { LiarsService.diceCall(widget.gameId!); return; }
    if (_s.callLiar(_me)) { setState(() {}); _afterChange(); }
  }

  void _doSpot() {
    if (!_myTurn || !_s.hasBid || _s.ruleset != 'traditional') return;
    music.play(click);
    if (_online) { LiarsService.diceSpot(widget.gameId!); return; }
    if (_s.spotOn(_me)) { setState(() {}); _afterChange(); }
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
            Text(won ? '🏆' : '☠️', style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 8),
            Text(won ? 'You Survived!' : 'Poisoned!',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
            const SizedBox(height: 6),
            Text(
                won ? 'Last one standing at the bar.' : '${_s.names[_s.winner] ?? 'Someone'} drank you under the table.',
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
                      foregroundColor: Colors.white, elevation: 0,
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
    for (final t in _pending) { t.cancel(); }
    _pending.clear();
    _resultShown = false;
    _revealing = false;
    setState(_newGame);
    _syncBidControls();
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
                  Align(alignment: aligns[i], child: _seat(allOpp[i])),
              ]),
            ),
            _myArea(),
          ]),
        ),
        if (_revealing) _revealOverlay(),
      ]),
    );
  }

  Widget _topBar() {
    final rs = widget.ruleset == 'traditional' ? 'TRADITIONAL' : 'BASIC';
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
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            Text("Liar's Dice · $rs · Round ${_s.round}",
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
          child: Text(_online ? 'ONLINE' : ['EASY', 'MEDIUM', 'HARD'][widget.aiLevel.clamp(0, 2)],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
        ),
      ]),
    );
  }

  Widget _tableFelt() {
    return Align(
      alignment: const Alignment(0, 0.35),
      child: FractionallySizedBox(
        widthFactor: 0.92, heightFactor: 0.62,
        child: Container(
          decoration: BoxDecoration(
            gradient: const RadialGradient(colors: [Color(0xFF1E5E3A), Color(0xFF123E27)]),
            borderRadius: const BorderRadius.all(Radius.elliptical(220, 160)),
            border: Border.all(color: const Color(0xFF3A2417), width: 10),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30, spreadRadius: 4)],
          ),
        ),
      ),
    );
  }

  Widget _centerInfo() {
    return Align(
      alignment: const Alignment(0, 0.16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('CURRENT BID', style: TextStyle(color: Color(0xFFE8C77A), fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 8),
        if (_s.hasBid)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${_s.bidCount} ×  ',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26)),
            liarsDie(_s.bidFace, size: 40, held: true),
          ])
        else
          const Text('— open —', style: TextStyle(color: Colors.white60, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(_s.hasBid ? '${_s.names[_s.lastBidder] ?? ''} bid' : 'Make the first bid',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text('${_s.totalDice} dice on the table',
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ]),
    );
  }

  Widget _seat(String id) {
    final alive = _s.order.contains(id);
    final isCurrent = alive && _s.currentId == id && _s.phase == 'bid';
    return SizedBox(
      width: 96,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: isCurrent ? const Color(0xFFE8C77A) : Colors.transparent, width: 2.5),
            boxShadow: isCurrent ? [const BoxShadow(color: Color(0x88E8C77A), blurRadius: 16, spreadRadius: 1)] : null,
          ),
          child: liarsCharacter(_s.chars[id] ?? 'scubby', size: 52, dead: !alive),
        ),
        const SizedBox(height: 2),
        Text(_s.names[id] ?? '',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: alive ? Colors.white : Colors.white38, fontWeight: FontWeight.w700, fontSize: 12)),
        if (alive) ...[
          // dice count
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(
              _s.diceCount(id).clamp(0, 5),
              (_) => Padding(padding: const EdgeInsets.symmetric(horizontal: 0.5), child: liarsDie(1, size: 9)))),
          const SizedBox(height: 2),
          // lives (poison bottles)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(kDiceMaxLives,
              (i) => Icon(Icons.local_drink_rounded,
                  size: 13, color: i < _s.livesOf(id) ? const Color(0xFF7BC47F) : Colors.white24))),
        ] else
          const Text('OUT', style: TextStyle(color: Color(0xFF8E1D2C), fontWeight: FontWeight.w900, fontSize: 10)),
      ]),
    );
  }

  Widget _myArea() {
    final myDice = List<int>.from(_s.dice[_meId] ?? const []);
    final alive = _s.order.contains(_meId);
    final canRaise = _myTurn && _s.isRaise(_selCount, _selFace);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1A100C),
        border: Border(top: BorderSide(color: Color(0xFF3A2417), width: 2)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          liarsCharacter(_s.chars[_meId] ?? 'kudo', size: 28, dead: !alive),
          const SizedBox(width: 8),
          const Text('Your dice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
          const Spacer(),
          Row(children: List.generate(kDiceMaxLives, (i) => Icon(Icons.local_drink_rounded,
              size: 16, color: i < _s.livesOf(_meId) ? const Color(0xFF7BC47F) : Colors.white24))),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final d in myDice)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: liarsDie(d, size: 40, held: true)),
        ]),
        const SizedBox(height: 12),
        // bid builder
        Opacity(
          opacity: _myTurn ? 1 : 0.4,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _stepper('Count', _selCount, () => setState(() { if (_selCount > 1) _selCount--; }),
                () => setState(() { if (_selCount < _s.totalDice) _selCount++; })),
            const SizedBox(width: 14),
            Column(children: [
              const Text('Face', style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 4),
              Row(children: [
                IconButton(visualDensity: VisualDensity.compact,
                    onPressed: _myTurn ? () => setState(() { if (_selFace > 1) _selFace--; }) : null,
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.white70, size: 22)),
                liarsDie(_selFace, size: 34, held: true),
                IconButton(visualDensity: VisualDensity.compact,
                    onPressed: _myTurn ? () => setState(() { if (_selFace < 6) _selFace++; }) : null,
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white70, size: 22)),
              ]),
            ]),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _btn('CALL', const Color(0xFF8E1D2C), (_myTurn && _s.hasBid) ? _doCall : null)),
          if (widget.ruleset == 'traditional') ...[
            const SizedBox(width: 8),
            Expanded(child: _btn('SPOT ON', const Color(0xFF7A4DA8), (_myTurn && _s.hasBid) ? _doSpot : null)),
          ],
          const SizedBox(width: 8),
          Expanded(child: _btn('BID', const Color(0xFF1E7A46), canRaise ? _doBid : null)),
        ]),
      ]),
    );
  }

  Widget _stepper(String label, int value, VoidCallback dec, VoidCallback inc) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      const SizedBox(height: 4),
      Row(children: [
        IconButton(visualDensity: VisualDensity.compact,
            onPressed: _myTurn ? dec : null,
            icon: const Icon(Icons.remove_circle_outline, color: Colors.white70, size: 22)),
        Text('$value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
        IconButton(visualDensity: VisualDensity.compact,
            onPressed: _myTurn ? inc : null,
            icon: const Icon(Icons.add_circle_outline, color: Colors.white70, size: 22)),
      ]),
    ]);
  }

  Widget _btn(String label, Color color, VoidCallback? onTap) {
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
        child: Center(child: Text(label,
            style: TextStyle(color: on ? Colors.white : Colors.white38, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5))),
      ),
    );
  }

  Widget _revealOverlay() {
    final loserName = _s.revLoser == _meId ? 'You' : (_s.names[_s.revLoser] ?? '');
    String title;
    if (_s.revWasSpotCall) {
      title = _s.revSpotOn ? 'SPOT ON! Everyone else drinks' : '${_s.revCaller == _meId ? 'You' : _s.names[_s.revCaller]} missed Spot On';
    } else {
      title = '$loserName drinks the poison 🍷';
    }
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.84),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('There were ${_s.revActual} × ${_s.bidFace}',
              style: const TextStyle(color: Color(0xFFE8C77A), fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 4),
          Text('(bid was ${_s.bidCount})', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 16),
          for (final id in [..._s.names.keys])
            if ((_s.dice[id] ?? const []).isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(width: 70, child: Text(id == _meId ? 'You' : (_s.names[id] ?? ''),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12), textAlign: TextAlign.right)),
                  const SizedBox(width: 8),
                  ...(_s.dice[id] ?? const []).map((d) {
                    final match = d == _s.bidFace || (_s.ruleset == 'traditional' && _s.bidFace != 1 && d == 1);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Opacity(opacity: match ? 1 : 0.35, child: liarsDie(d, size: 26, held: match)),
                    );
                  }),
                ]),
              ),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        ]),
      ),
    );
  }
}
