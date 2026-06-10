import 'dart:async';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../functions/parchi_engine.dart';
import '../../functions/parchi_service.dart';
import '../../helpers/color.dart';
import '../../helpers/constant.dart';
import '../../helpers/utils.dart';
import '../../widgets/voice_chat_button.dart';

// ════════════════════════════════════════════════════════════════════════════
// 16 Parchi / Dhapp — table screen for both offline (vs Computer) and online
// (friends over Firebase).
//   Pass a card each round; the moment someone holds 4-of-a-kind, SLAM the pile.
//   Last to slam earns a DHAPP letter. Spell DHAPP and you're out. Last standing
//   wins.
// ════════════════════════════════════════════════════════════════════════════

const _me = 'me';
const _botNames = ['Aman', 'Riya', 'Veer', 'Zoya', 'Kabir'];

class ParchiGameScreen extends StatefulWidget {
  final int aiLevel;     // offline: 0 easy, 1 medium, 2 hard
  final int playerCount; // offline: 2–4 total (incl. you)
  final bool online;
  final String? gameId;
  final String? myId;
  const ParchiGameScreen({
    super.key,
    this.aiLevel = 1,
    this.playerCount = 4,
    this.online = false,
    this.gameId,
    this.myId,
  });

  @override
  State<ParchiGameScreen> createState() => _ParchiGameScreenState();
}

class _ParchiGameScreenState extends State<ParchiGameScreen> {
  late ParchiState _s;
  final _rng = Random();
  final List<Timer> _pending = [];
  bool _disposed = false;
  bool _busy = false;          // resolving a pass — block input
  bool _passingAnim = false;   // brief "cards flying" state
  bool _slammed = false;       // human has slammed this round
  DateTime _slamStart = DateTime.now();
  bool _resultShown = false;
  String? _selected;           // card the human tapped this pass

  // Online
  bool get _online => widget.online;
  String get _meId => _online ? widget.myId! : _me;
  StreamSubscription<DatabaseEvent>? _gameSub;
  Timer? _watch;
  int _lastActionAt = 0;
  bool _gotState = false;
  bool _claimed = false;
  String _slamKey = '';        // '<round>' the slam clock was started for

  static const _accent = Color(0xFF00897B); // teal

  @override
  void initState() {
    super.initState();
    if (_online) {
      _initOnline();
    } else {
      _newLocalGame();
      if (_s.phase == 'slam') {
        WidgetsBinding.instance.addPostFrameCallback((_) => _startSlam());
      }
    }
  }

  void _newLocalGame() {
    final n = widget.playerCount.clamp(2, 4);
    final ids = [_me, for (int i = 0; i < n - 1; i++) 'bot${i + 1}'];
    final names = <String, String>{_me: 'You'};
    final bots = <String, bool>{_me: false};
    final pool = List.of(_botNames)..shuffle(_rng);
    for (int i = 0; i < n - 1; i++) {
      names['bot${i + 1}'] = pool[i];
      bots['bot${i + 1}'] = true;
    }
    _s = ParchiState.create(playerIds: ids, names: names, bots: bots, rng: _rng);
  }

  void _initOnline() {
    _s = ParchiState(
      order: [_meId], hands: {_meId: const []},
      names: {_meId: 'You'}, bots: {_meId: false}, symbols: const [],
    );
    _gameSub = ParchiService.gameStream(widget.gameId!).listen((ev) {
      if (_disposed || !mounted || ev.snapshot.value == null) return;
      final map = Map<String, dynamic>.from(ev.snapshot.value as Map);
      _lastActionAt = (map['lastActionAt'] as int?) ?? 0;
      final ns = ParchiState.fromMap(map);
      _onOnlineState(ns);
    });
    _watch = Timer.periodic(const Duration(seconds: 2), (_) => _tickWatch());
  }

  void _onOnlineState(ParchiState ns) {
    // Reset the slam clock when a fresh slam phase begins.
    if (ns.phase == 'slam' && _slamKey != '${ns.round}') {
      _slamKey = '${ns.round}';
      _slamStart = DateTime.now();
      _slammed = ns.slamTimes.containsKey(_meId);
    }
    setState(() {
      _s = ns;
      _gotState = true;
    });
    if (ns.over) {
      if (ns.winner == _meId && !_claimed) {
        _claimed = true;
        ParchiService.claimPot(widget.gameId!);
      }
      _showResult();
    }
  }

  void _tickWatch() {
    if (_disposed || !_gotState || _s.over) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_s.phase == 'slam' && now - _lastActionAt > ParchiService.slamWindowMs) {
      ParchiService.autoResolveSlam(widget.gameId!);
    } else if (_s.phase == 'reveal' &&
        now - _lastActionAt > ParchiService.revealDwellMs) {
      ParchiService.advanceRound(widget.gameId!);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelPending();
    _gameSub?.cancel();
    _watch?.cancel();
    super.dispose();
  }

  void _cancelPending() {
    for (final t in _pending) {
      t.cancel();
    }
    _pending.clear();
  }

  List<String> get _bots => _s.order.where((id) => id != _meId).toList();

  // ── Passing ────────────────────────────────────────────────────────────────

  Future<void> _commitPass(String symbol) async {
    if (_s.phase != 'passing' || _busy || _s.over) return;
    if (_s.pendingPass.containsKey(_meId)) return; // already passed
    music.play(click);

    if (_online) {
      setState(() {
        _busy = true;
        _selected = symbol;
      });
      await ParchiService.submitPass(widget.gameId!, symbol);
      if (!_disposed && mounted) setState(() => _busy = false);
      return;
    }

    _busy = true;
    _s.submitPass(_me, symbol);
    for (final b in _bots) {
      _s.submitPass(b, ParchiBot.choosePass(_s, b, widget.aiLevel));
    }
    setState(() {
      _selected = symbol;
      _passingAnim = true;
    });
    await Future.delayed(const Duration(milliseconds: 420));
    if (_disposed || !mounted) return;
    _s.resolvePasses();
    setState(() {
      _passingAnim = false;
      _busy = false;
      _selected = null;
    });
    if (_s.phase == 'slam') _startSlam();
  }

  // ── Slam ─────────────────────────────────────────────────────────────────────

  void _startSlam() {
    // Offline only: schedule bot reactions + a human timeout.
    _slamStart = DateTime.now();
    _slammed = false;
    for (final b in _bots) {
      final ms = ParchiBot.reactionMs(_s, b, widget.aiLevel);
      _pending.add(Timer(Duration(milliseconds: ms), () {
        if (_disposed || _s.phase != 'slam') return;
        _s.submitSlam(b, ms);
        _checkSlam();
      }));
    }
    _pending.add(Timer(const Duration(milliseconds: 2600), () {
      if (_disposed || _s.phase != 'slam' || _slammed) return;
      _slammed = true;
      _s.submitSlam(_me, 999999);
      _checkSlam();
    }));
    setState(() {});
  }

  void _humanSlam() {
    if (_s.phase != 'slam' || _slammed) return;
    final ms = DateTime.now().difference(_slamStart).inMilliseconds;
    _slammed = true;
    music.play(click);
    if (_online) {
      setState(() {});
      ParchiService.submitSlam(widget.gameId!, ms);
      return;
    }
    _s.submitSlam(_me, ms);
    setState(() {});
    _checkSlam();
  }

  void _checkSlam() {
    if (!mounted || _disposed) return;
    if (!_s.allSlamsIn) {
      setState(() {});
      return;
    }
    _cancelPending();
    _s.resolveSlam(_rng);
    setState(() {});
    _pending.add(Timer(const Duration(milliseconds: 2000), () {
      if (_disposed || !mounted) return;
      if (_s.over) {
        _showResult();
      } else {
        _s.nextRound(_rng);
        setState(() {});
        if (_s.phase == 'slam') _startSlam();
      }
    }));
  }

  // ── Result ───────────────────────────────────────────────────────────────────

  void _showResult() {
    if (_resultShown || !mounted) return;
    _resultShown = true;
    final won = _s.winner == _meId;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(won ? '🏆' : '💀', style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 8),
            Text(won ? 'You Win!' : 'You lost the Dhapp!',
                style: TextStyle(
                    color: inkColor, fontWeight: FontWeight.w900, fontSize: 22)),
            const SizedBox(height: 6),
            Text(
                won
                    ? (_online
                        ? 'Last one standing — the pot is yours! 🪙'
                        : 'Last one standing — sharpest hands at the table!')
                    : '${_s.names[_s.winner] ?? 'Someone'} survived to the end.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ink2Color, fontSize: 13)),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ink2Color,
                    side: BorderSide(color: lineColor),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                  ),
                  child: const Text('Exit'),
                ),
              ),
              if (!_online) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _restart();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13)),
                    ),
                    child: const Text('Play Again',
                        style: TextStyle(fontWeight: FontWeight.w800)),
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
    _cancelPending();
    _resultShown = false;
    _slammed = false;
    _busy = false;
    setState(_newLocalGame);
    if (_s.phase == 'slam') _startSlam();
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_online && !_gotState) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: _accent)),
      );
    }
    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: (_online && widget.gameId != null && widget.myId != null)
          ? VoiceChatButton(channel: widget.gameId!, myFbUid: widget.myId!)
          : null,
      body: SafeArea(
        child: Column(children: [
          _topBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: _bots.map(_opponentTile).toList(),
            ),
          ),
          Expanded(child: Center(child: _centerStage())),
          _myArea(),
        ]),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(children: [
        IconButton(
          onPressed: () {
            music.play(click);
            Navigator.of(context).pop();
          },
          icon: Icon(Icons.arrow_back_rounded, color: inkColor),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('16 Parchi · Dhapp',
                style: TextStyle(
                    color: inkColor, fontWeight: FontWeight.w900, fontSize: 18)),
            Text('Round ${_s.round}  •  collect 4 of a kind',
                style: TextStyle(color: ink3Color, fontSize: 11.5)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
              _online
                  ? 'ONLINE'
                  : ['EASY', 'MEDIUM', 'HARD'][widget.aiLevel.clamp(0, 2)],
              style: TextStyle(
                  color: _accent, fontWeight: FontWeight.w800, fontSize: 11)),
        ),
      ]),
    );
  }

  Widget _opponentTile(String id) {
    final out = _s.isOut(id);
    final slammed = _s.slamTimes.containsKey(id);
    final passed = _s.pendingPass.containsKey(id);
    final isLoser = _s.phase == 'reveal' && _s.roundLoser == id;
    final inSlam = _s.phase == 'slam';
    final inPass = _s.phase == 'passing';
    final marked = (inSlam && slammed) || (inPass && passed);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 104,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isLoser ? red.withValues(alpha: 0.12) : surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: marked ? goodColor : (isLoser ? red : lineColor),
          width: marked || isLoser ? 1.6 : 1,
        ),
        boxShadow: [shadowSm],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _accent.withValues(alpha: 0.16),
            child: Text(
              (_s.names[id] ?? '?').characters.first,
              style: TextStyle(
                  color: _accent, fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          if (marked)
            Positioned(
              right: -4, top: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                    color: Color(0xFF19B36B), shape: BoxShape.circle),
                child: Icon(inSlam ? Icons.front_hand_rounded : Icons.check_rounded,
                    color: Colors.white, size: 12),
              ),
            ),
        ]),
        const SizedBox(height: 5),
        Text(_s.names[id] ?? '?',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: inkColor, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 3),
        out
            ? Text('OUT 💀',
                style: TextStyle(
                    color: red, fontWeight: FontWeight.w800, fontSize: 11))
            : _dhappLetters(id, 11),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _s.handCount(id).clamp(0, 4),
            (_) => Container(
              width: 12,
              height: 17,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _dhappLetters(String id, double size) {
    final n = _s.letterCount(id);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(kDhappWord.length, (i) {
        final got = i < n;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.5),
          child: Text(
            kDhappWord[i],
            style: TextStyle(
              color: got ? red : ink3Color.withValues(alpha: 0.4),
              fontWeight: FontWeight.w900,
              fontSize: size,
            ),
          ),
        );
      }),
    );
  }

  Widget _centerStage() {
    if (_s.phase == 'slam') return _slamStage();
    if (_s.phase == 'reveal') return _revealStage();
    return _passStage();
  }

  Widget _passStage() {
    final iPassed = _s.pendingPass.containsKey(_meId);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.sync_alt_rounded,
          color: (_passingAnim || iPassed) ? _accent : ink3Color, size: 46),
      const SizedBox(height: 10),
      Text(
          _passingAnim
              ? 'Passing…'
              : iPassed
                  ? 'Waiting for others…'
                  : 'Pass a card →',
          style: TextStyle(
              color: inkColor, fontWeight: FontWeight.w800, fontSize: 18)),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          'Tap one of your cards to pass it on. Keep the symbol you have most of — first to 4-of-a-kind triggers the Dhapp!',
          textAlign: TextAlign.center,
          style: TextStyle(color: ink3Color, fontSize: 12, height: 1.4),
        ),
      ),
    ]);
  }

  Widget _slamStage() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('SOMEONE HAS A SET!',
          style: TextStyle(
              color: red,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 1)),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: _slammed ? null : _humanSlam,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 170,
          height: 170,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _slammed ? ink3Color.withValues(alpha: 0.25) : red,
            boxShadow: _slammed
                ? null
                : [
                    BoxShadow(
                        color: red.withValues(alpha: 0.5),
                        blurRadius: 28,
                        spreadRadius: 2)
                  ],
          ),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.front_hand_rounded,
                  color: Colors.white, size: _slammed ? 44 : 54),
              const SizedBox(height: 4),
              Text(_slammed ? 'Slapped!' : 'DHAPP!',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: 1)),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(_slammed ? 'Waiting for the slowest hand…' : 'SLAP THE PILE — fast!',
          style: TextStyle(
              color: ink2Color, fontWeight: FontWeight.w700, fontSize: 13)),
    ]);
  }

  Widget _revealStage() {
    final loser = _s.roundLoser;
    final name = loser == _meId ? 'You' : (_s.names[loser] ?? 'Someone');
    final out = _s.roundLoserOut;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(out ? '💀' : '✋', style: const TextStyle(fontSize: 48)),
      const SizedBox(height: 8),
      Text(
        out ? '$name spelled DHAPP — OUT!' : '$name was last to slap!',
        textAlign: TextAlign.center,
        style:
            TextStyle(color: inkColor, fontWeight: FontWeight.w900, fontSize: 18),
      ),
      const SizedBox(height: 8),
      if (loser != null && !out) _dhappLetters(loser, 18),
    ]);
  }

  Widget _myArea() {
    final hand = List<String>.from(_s.hands[_meId] ?? const []);
    final iPassed = _s.pendingPass.containsKey(_meId);
    final myTurn =
        _s.phase == 'passing' && !_busy && !iPassed && !_s.isOut(_meId);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [shadow],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('You',
              style: TextStyle(
                  color: inkColor, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(width: 10),
          _dhappLetters(_meId, 14),
        ]),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: hand
              .asMap()
              .entries
              .map((e) => _myCard(e.value, myTurn, e.key))
              .toList(),
        ),
      ]),
    );
  }

  Widget _myCard(String symbol, bool tappable, int index) {
    final isSel = _selected == symbol && (_passingAnim || _busy);
    return GestureDetector(
      onTap: tappable ? () => _commitPass(symbol) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        transform: Matrix4.translationValues(0, isSel ? -16 : 0, 0),
        width: 62,
        height: 86,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, surface2Color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSel ? _accent : lineColor,
            width: isSel ? 2 : 1.2,
          ),
          boxShadow: [tappable ? shadow : shadowSm],
        ),
        child: Center(child: Text(symbol, style: const TextStyle(fontSize: 38))),
      ),
    );
  }
}
