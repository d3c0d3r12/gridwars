import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../../functions/uno_engine.dart';
import '../../functions/uno_service.dart';
import '../../helpers/color.dart';
import '../../helpers/constant.dart';
import '../../helpers/utils.dart';
import '../../widgets/voice_chat_button.dart';
import 'game_widgets.dart';

// UNO game screen — two modes from one engine:
//  • Local 1v1 vs Computer (online=false): no Firebase, no coins, with a bot.
//  • Online friends (online=true): N players synced via Firebase, winner takes pot.
// Full house rules via the shared engine (stacking, jump-in, 7-0).
class UnoGameScreen extends StatefulWidget {
  final int aiLevel;       // local mode: 0=Easy, 1=Medium, 2=Hard
  final String mode;       // 'classic' | 'allWild' | 'noMercy' (local mode)
  final bool online;
  final String? gameId;    // online mode
  final String? myId;      // online mode (my uid)
  const UnoGameScreen({super.key, this.aiLevel = 1, this.mode = 'classic', this.online = false, this.gameId, this.myId});

  @override
  State<UnoGameScreen> createState() => _UnoGameScreenState();
}

const String _me = 'you';
const String _cpu = 'cpu';

class _UnoGameScreenState extends State<UnoGameScreen> {
  late UnoState _s;
  bool _busy = false;            // bot is acting — block input (local mode)
  bool _disposed = false;
  String _banner = '';
  Timer? _bannerTimer;

  // UNO call: when the human is left with 1 card they must call UNO quickly.
  bool _unoWindow = false;       // human can be caught right now (local mode)
  Timer? _unoCatchTimer;

  // Online mode
  bool get _online => widget.online;
  String get _meId => _online ? widget.myId! : _me;
  StreamSubscription<DatabaseEvent>? _gameSub;
  Timer? _timeoutWatch;
  bool _gotState = false;
  bool _claimed = false;
  bool _resultShown = false;
  List<String> get _opponents => _s.order.where((id) => id != _meId).toList();

  static const _colorVal = {
    'r': Color(0xFFD32F2F), 'y': Color(0xFFF9A825),
    'g': Color(0xFF388E3C), 'b': Color(0xFF1976D2), 'w': Color(0xFF222831),
  };

  @override
  void initState() {
    super.initState();
    if (_online) {
      _initOnline();
    } else {
      _s = UnoState.create(
        playerIds: const [_me, _cpu],
        names: const {_me: 'You', _cpu: 'Computer'},
        bots: const {_me: false, _cpu: true},
        mode: widget.mode,
      );
      if (_s.currentId == _cpu) _runBot();
    }
  }

  void _initOnline() {
    // Placeholder until the first snapshot arrives.
    _s = UnoState(
      order: [_meId], hands: {_meId: []}, names: {_meId: 'You'}, bots: {_meId: false},
      turn: 0, dir: 1, drawPile: [], discard: ['r0'], activeColor: 'r',
    );
    _gameSub = UnoService.gameStream(widget.gameId!).listen((ev) {
      if (_disposed || !mounted || ev.snapshot.value == null) return;
      final map = Map<String, dynamic>.from(ev.snapshot.value as Map);
      setState(() { _s = UnoState.fromMap(map); _gotState = true; });
      if (_s.over) {
        if (_s.winner == _meId && !_claimed) { _claimed = true; UnoService.claimPot(widget.gameId!); }
        _showResult();
      }
    });
    // Watchdog: if the player to move is idle/absent past the timeout, any client
    // nudges the game forward so a disconnect can't freeze the table.
    _timeoutWatch = Timer.periodic(const Duration(seconds: 6), (_) async {
      if (_disposed || !_gotState || _s.over) return;
      final ref = FirebaseDatabase.instance.ref().child('unoGames').child(widget.gameId!).child('lastActionAt');
      final snap = await ref.get();
      final last = (snap.value as int?) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - last > UnoService.turnTimeoutMs) {
        UnoService.timeoutAdvance(widget.gameId!, _s.currentId);
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _bannerTimer?.cancel();
    _unoCatchTimer?.cancel();
    _gameSub?.cancel();
    _timeoutWatch?.cancel();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  bool get _myTurn => _s.currentId == _meId && !_s.over && !_busy;

  String get _modeLabel {
    switch (_s.mode) {
      case 'allWild': return 'ALL WILD';
      case 'noMercy': return 'NO MERCY';
      default: return 'CLASSIC';
    }
  }

  void _flash(String t) {
    if (t.isEmpty) return;
    setState(() => _banner = t);
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _banner = '');
    });
  }

  void _flashEvents(List<UnoEvent> ev) {
    if (ev.isNotEmpty) _flash(ev.map((e) => e.text).join('  •  '));
  }

  // ── Human actions ───────────────────────────────────────────────────────────
  Future<void> _tapCard(String card) async {
    if (_s.over) return;

    // Jump-in: identical card out of turn.
    if (!_myTurn && _s.canJumpIn(_meId, card)) {
      String? color;
      if (UnoCard.isAnyWild(card)) { color = await _pickColor(); if (color == null) return; }
      if (_online) { UnoService.jumpIn(widget.gameId!, card, color: color); return; }
      _bumpUnoWindow();
      _afterHumanPlay(_s.jumpIn(_meId, card, chosenColor: color));
      return;
    }

    if (!_myTurn) return;
    if (!_s.canPlay(card)) { if (_s.pendingDraw == 0) _flash('Can\'t play that'); return; }

    String? color;
    if (UnoCard.isAnyWild(card)) {
      color = await _pickColor();
      if (color == null) return; // cancelled
    }

    if (_online) {
      // 7 swaps with the opponent holding the fewest cards.
      String? swap;
      if (UnoCard.digit(card) == 7) swap = _fewestOpp();
      UnoService.play(widget.gameId!, card, color: color, swapTarget: swap);
      return;
    }

    _bumpUnoWindow();
    final ev = _s.play(card, chosenColor: color); // 7 auto-swaps with the bot in 1v1
    _afterHumanPlay(ev);
  }

  String? _fewestOpp() {
    String? best; int fewest = 1 << 30;
    for (final id in _opponents) {
      if (_s.handCount(id) < fewest) { fewest = _s.handCount(id); best = id; }
    }
    return best;
  }

  // Track whether the human just dropped to exactly 1 card → open catch window.
  void _bumpUnoWindow() {
    _unoCatchWasNeeded = _s.handCount(_meId) == 2; // about to become 1
  }

  bool _unoCatchWasNeeded = false;

  // Local-mode only: after the human plays, refresh, handle UNO catch, run bot.
  void _afterHumanPlay(List<UnoEvent> ev) {
    music.play(dice);
    _flashEvents(ev);
    setState(() {});
    if (_s.over) { _showResult(); return; }

    if (_unoCatchWasNeeded && _s.handCount(_meId) == 1 && !_s.calledUno.contains(_meId)) {
      _openUnoCatch();
    }

    if (_s.currentId == _cpu) _runBot();
  }

  Future<void> _drawOrPenalty() async {
    if (!_myTurn) return;
    if (_online) { UnoService.drawOrPenalty(widget.gameId!); return; }
    if (_s.pendingDraw > 0) {
      final ev = _s.takePenaltyAndPass();
      music.play(dice);
      _flashEvents(ev);
      setState(() {});
      if (_s.currentId == _cpu) _runBot();
      return;
    }
    // Normal draw-one. If playable you MAY play it, else pass.
    final drawn = _s.drawOne();
    music.play(dice);
    setState(() {});
    if (drawn != null && _s.canPlay(drawn)) {
      final play = await _askPlayDrawn(drawn);
      if (!mounted) return;
      if (play) {
        String? color;
        if (UnoCard.isAnyWild(drawn)) color = await _pickColor();
        _bumpUnoWindow();
        final ev = _s.play(drawn, chosenColor: color);
        _afterHumanPlay(ev);
        return;
      }
    }
    _s.passTurn();
    setState(() {});
    if (_s.currentId == _cpu) _runBot();
  }

  void _callUno() {
    if (_s.handCount(_meId) <= 2) {
      if (_online) { UnoService.callUno(widget.gameId!); _flash('UNO!'); return; }
      _s.calledUno.add(_meId);
      _unoCatchTimer?.cancel();
      setState(() => _unoWindow = false);
      _flash('UNO!');
    }
  }

  // Local-mode UNO catch (the bot catches you if you forget to call).
  void _openUnoCatch() {
    setState(() => _unoWindow = true);
    _unoCatchTimer?.cancel();
    _unoCatchTimer = Timer(const Duration(milliseconds: 2200), () {
      if (_disposed || !mounted) return;
      if (!_s.calledUno.contains(_meId) && _s.handCount(_meId) == 1) {
        _s.draw(_meId, 2); // caught — penalty
        _flash('Caught! +2 for not calling UNO');
        setState(() => _unoWindow = false);
      }
    });
  }

  // ── Bot turn loop ────────────────────────────────────────────────────────────
  Future<void> _runBot() async {
    if (_busy) return;
    setState(() => _busy = true);
    while (!_disposed && !_s.over && _s.currentId == _cpu) {
      await Future.delayed(const Duration(milliseconds: 850));
      if (_disposed || !mounted) return;

      if (_s.pendingDraw > 0) {
        final mv = UnoBot.chooseMove(_s, _cpu, widget.aiLevel);
        if (mv != null) {
          final ev = _s.play(mv.card, chosenColor: mv.color);
          music.play(dice); _flashEvents(ev);
        } else {
          _flashEvents(_s.takePenaltyAndPass());
        }
        setState(() {});
        continue;
      }

      final mv = UnoBot.chooseMove(_s, _cpu, widget.aiLevel);
      if (mv == null) {
        final drawn = _s.drawOne();
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 350));
        if (_disposed) return;
        if (drawn != null && _s.canPlay(drawn)) {
          final ev = _s.play(drawn,
              chosenColor: UnoCard.isAnyWild(drawn) ? UnoBot.chooseMove(_s, _cpu, widget.aiLevel)?.color ?? 'r' : null);
          music.play(dice); _flashEvents(ev);
        } else {
          _s.passTurn();
        }
        setState(() {});
        continue;
      }

      final swap = (UnoCard.digit(mv.card) == 7) ? UnoBot.swapTarget(_s, _cpu) : null;
      final ev = _s.play(mv.card, chosenColor: mv.color, swapTarget: swap);
      music.play(dice); _flashEvents(ev);
      setState(() {});
      // Bot auto-calls UNO (no penalty against the bot).
      if (_s.handCount(_cpu) == 1) _s.calledUno.add(_cpu);
    }
    if (!_disposed && mounted) setState(() => _busy = false);
    if (_s.over) _showResult();
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────
  Future<String?> _pickColor() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Choose a colour', style: TextStyle(color: inkColor, fontWeight: FontWeight.bold, fontSize: 17), textAlign: TextAlign.center),
        content: Wrap(
          spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
          children: [for (final c in kUnoColors)
            GestureDetector(
              onTap: () => Navigator.pop(context, c),
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: _colorVal[c], borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: _colorVal[c]!.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Center(child: Text(kColorName[c]![0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _askPlayDrawn(String card) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('You drew', style: TextStyle(color: inkColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        content: SizedBox(height: 96, child: Center(child: _cardWidget(card, width: 64))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Keep', style: TextStyle(color: ink2Color))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Play it', style: TextStyle(color: xColor, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    return res ?? false;
  }

  void _showResult() {
    if (_resultShown || !mounted) return;
    _resultShown = true;
    final won = _s.winner == _meId;
    final winnerName = _s.names[_s.winner] ?? 'Someone';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: xColor.withValues(alpha: 0.4))),
        title: Text(won ? '🏆 You Win!' : '😔 You Lose', style: TextStyle(color: inkColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        content: Text(
          _online
              ? (won ? 'You win the pot! 🎉' : '$winnerName emptied their hand first')
              : (won ? 'You beat the Computer!' : 'The Computer emptied its hand first'),
          style: TextStyle(color: xColor), textAlign: TextAlign.center,
        ),
        actions: [
          if (!_online)
            TextButton(onPressed: () { Navigator.pop(context); _restart(); }, child: Text('Rematch', style: TextStyle(color: xColor, fontWeight: FontWeight.bold))),
          TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: Text('Back', style: TextStyle(color: ink2Color))),
        ],
      ),
    );
  }

  void _restart() {
    _unoCatchTimer?.cancel();
    setState(() {
      _s = UnoState.create(
        playerIds: const [_me, _cpu],
        names: const {_me: 'You', _cpu: 'Computer'},
        bots: const {_me: false, _cpu: true},
        mode: widget.mode,
      );
      _busy = false; _banner = ''; _unoWindow = false;
    });
    if (_s.currentId == _cpu) _runBot();
  }

  void _handleExit() {
    if (!mounted) return;
    if (_s.over) { Navigator.pop(context); return; }
    showLeaveConfirmDialog(context, () { if (mounted) Navigator.pop(context); });
  }

  // ── UI ───────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_online && !_gotState) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: Color(0xFFD32F2F)),
          const SizedBox(height: 16),
          Text('Dealing cards…', style: TextStyle(color: ink2Color, fontWeight: FontWeight.w600)),
        ])),
      );
    }
    final myHand = _s.hands[_meId] ?? [];
    final pending = _s.pendingDraw;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _handleExit(); },
      child: Scaffold(
        backgroundColor: bgColor,
        floatingActionButton: (_online && widget.gameId != null && widget.myId != null)
            ? VoiceChatButton(channel: widget.gameId!, myFbUid: widget.myId!)
            : null,
        body: SafeArea(
          child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: _handleExit,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: lineColor)),
                    child: Icon(Icons.close_rounded, color: ink2Color, size: 18),
                  ),
                ),
                const Spacer(),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('UNO', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: inkColor, letterSpacing: 4)),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFFD32F2F).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                    child: Text(_modeLabel, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFD32F2F), letterSpacing: 1)),
                  ),
                ]),
                const Spacer(),
                _dirChip(),
              ]),
            ),

            // Opponent(s)
            const SizedBox(height: 14),
            _online ? _opponentsOnline() : _opponentArea(),

            const Spacer(),

            // Banner
            SizedBox(
              height: 30,
              child: AnimatedOpacity(
                opacity: _banner.isEmpty ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: _colorVal[_s.activeColor]!.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                  child: Text(_banner, style: TextStyle(color: _colorVal[_s.activeColor], fontWeight: FontWeight.w700, fontSize: 12.5)),
                ),
              ),
            ),

            // Center: draw + discard
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              // Draw pile
              GestureDetector(
                onTap: _myTurn ? _drawOrPenalty : null,
                child: Column(children: [
                  Stack(clipBehavior: Clip.none, children: [
                    _cardBack(width: 70),
                    if (pending > 0)
                      Positioned(
                        right: -6, top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Color(0xFFD32F2F), shape: BoxShape.circle),
                          child: Text('+$pending', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 6),
                  Text(pending > 0 ? 'DRAW $pending' : 'DRAW', style: TextStyle(color: ink3Color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                ]),
              ),
              const SizedBox(width: 28),
              // Discard top
              Column(children: [
                _cardWidget(_s.topCard, width: 80, activeColorForWild: _s.activeColor),
                const SizedBox(height: 6),
                Text(kColorName[_s.activeColor]!.toUpperCase(), style: TextStyle(color: _colorVal[_s.activeColor], fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ]),
            ]),

            const Spacer(),

            // Turn / UNO row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(
                  child: gamePill(
                    _s.over ? 'Game over' : _myTurn ? (pending > 0 ? 'Stack a +$pending or draw' : 'Your turn') : '${_s.names[_s.currentId] ?? 'Opponent'}\'s turn…',
                    _myTurn ? const Color(0xFF388E3C) : ink3Color,
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _callUno,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: _unoWindow ? const Color(0xFFD32F2F) : (_s.handCount(_meId) == 2 ? const Color(0xFFD32F2F).withValues(alpha: 0.85) : surface2Color),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _unoWindow ? [BoxShadow(color: const Color(0xFFD32F2F).withValues(alpha: 0.6), blurRadius: 16, spreadRadius: 1)] : null,
                    ),
                    child: Text('UNO!', style: TextStyle(color: (_unoWindow || _s.handCount(_meId) == 2) ? Colors.white : ink3Color, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
                  ),
                ),
              ]),
            ),

            // My hand
            const SizedBox(height: 10),
            Container(
              height: 132,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: myHand.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final card = myHand[i];
                  final playable = _myTurn ? _s.canPlay(card) : _s.canJumpIn(_meId, card);
                  return GestureDetector(
                    onTap: () => _tapCard(card),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      transform: Matrix4.translationValues(0, playable ? -10 : 0, 0),
                      child: Opacity(
                        opacity: (_myTurn && !playable) ? 0.45 : 1,
                        child: _cardWidget(card, width: 76, highlight: playable),
                      ),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _dirChip() => Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: lineColor)),
        child: Icon(_s.dir == 1 ? Icons.rotate_right_rounded : Icons.rotate_left_rounded, color: ink2Color, size: 20),
      );

  // Online: a row of all other players with their card counts; current turn glows.
  Widget _opponentsOnline() {
    final opps = _opponents;
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: opps.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final id = opps[i];
          final active = _s.currentId == id;
          final n = _s.handCount(id);
          final lowCards = n == 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFD32F2F).withValues(alpha: 0.10) : surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: active ? const Color(0xFFD32F2F).withValues(alpha: 0.5) : lineColor, width: active ? 1.5 : 1),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.person_rounded, size: 15, color: active ? const Color(0xFFD32F2F) : ink2Color),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 80),
                  child: Text(_s.names[id] ?? 'Player',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: inkColor, fontWeight: FontWeight.w700, fontSize: 12.5)),
                ),
              ]),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: lowCards ? const Color(0xFFD32F2F) : surface2Color,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(lowCards ? 'UNO!' : '$n cards',
                    style: TextStyle(color: lowCards ? Colors.white : ink2Color, fontWeight: FontWeight.w800, fontSize: 10.5)),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _opponentArea() {
    final n = _s.handCount(_cpu);
    final showFan = n.clamp(0, 7);
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: _s.currentId == _cpu ? const Color(0xFFD32F2F).withValues(alpha: 0.10) : surfaceColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _s.currentId == _cpu ? const Color(0xFFD32F2F).withValues(alpha: 0.4) : lineColor),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.smart_toy_rounded, size: 16, color: _s.currentId == _cpu ? const Color(0xFFD32F2F) : ink2Color),
          const SizedBox(width: 6),
          Text('Computer', style: TextStyle(color: inkColor, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: surface2Color, borderRadius: BorderRadius.circular(999)),
            child: Text('$n cards', style: TextStyle(color: ink2Color, fontWeight: FontWeight.w700, fontSize: 11)),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 46,
        child: Stack(alignment: Alignment.center, children: [
          for (int i = 0; i < showFan; i++)
            Transform.translate(
              offset: Offset((i - showFan / 2) * 18.0, 0),
              child: _cardBack(width: 32),
            ),
        ]),
      ),
    ]);
  }

  // ── Card visuals ─────────────────────────────────────────────────────────────
  // Glossy gradient shades per colour (light → dark).
  static const _shade = {
    'r': [Color(0xFFFF5A52), Color(0xFFC1271F)],
    'y': [Color(0xFFFFD23F), Color(0xFFE99311)],
    'g': [Color(0xFF5FCB62), Color(0xFF1E7D24)],
    'b': [Color(0xFF4AA8FF), Color(0xFF105FC4)],
    'w': [Color(0xFF3A4150), Color(0xFF11131A)],
  };

  Widget _cardWidget(String code, {required double width, bool highlight = false, String? activeColorForWild}) {
    final h = width * 1.45;
    final col = UnoCard.colorOf(code);
    final isWild = col == 'w';
    final shades = _shade[col]!;
    final dark = shades[1];
    final symColor = isWild ? Colors.white : dark; // symbol sits on the white pill
    final frame = width * 0.055;
    final radius = width * 0.16;

    return Container(
      width: width, height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 7, offset: const Offset(0, 4)),
          if (highlight) BoxShadow(color: shades[0].withValues(alpha: 0.75), blurRadius: 16, spreadRadius: 1.5),
        ],
      ),
      padding: EdgeInsets.all(frame),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - frame),
        child: Stack(children: [
          // Body gradient
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(colors: shades, begin: Alignment.topLeft, end: Alignment.bottomRight),
          ))),
          // Centre pill — white ellipse for colours, 4-colour quadrant for wilds
          Center(child: Transform.rotate(
            angle: -0.42,
            child: SizedBox(
              width: width * 0.78, height: h * 0.66,
              child: isWild ? _wildFace(width) : DecoratedBox(decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.elliptical(width * 0.5, h * 0.4)),
              )),
            ),
          )),
          // Centre symbol
          Center(child: _sym(code, symColor, width * 0.5, shadow: isWild)),
          // Corner indices (top-left + rotated bottom-right)
          Positioned(top: width * 0.04, left: width * 0.07, child: _sym(code, Colors.white, width * 0.24, shadow: true)),
          Positioned(bottom: width * 0.04, right: width * 0.07,
            child: Transform.rotate(angle: 3.14159, child: _sym(code, Colors.white, width * 0.24, shadow: true))),
          // Glossy top sheen
          Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.0)],
              begin: Alignment.topCenter, end: Alignment.center,
            ),
          )))),
          // Wild action tag
          if (isWild && width >= 58 && UnoCard.wildTag(code) != null)
            Positioned(left: 0, right: 0, bottom: width * 0.12, child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: width * 0.08, vertical: width * 0.02),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
                child: Text(UnoCard.wildTag(code)!, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: width * 0.115, letterSpacing: 0.4)),
              ),
            )),
        ]),
      ),
    );
  }

  // The card's symbol: icon for skip/reverse, text otherwise.
  Widget _sym(String code, Color color, double size, {bool shadow = false}) {
    final shadows = shadow ? [Shadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 3, offset: const Offset(0, 1))] : null;
    if (UnoCard.isReverse(code)) {
      return Icon(Icons.swap_vert_rounded, color: color, size: size, shadows: shadows);
    }
    if (UnoCard.isSkip(code)) {
      return Icon(Icons.block_rounded, color: color, size: size * 0.92, shadows: shadows);
    }
    if (UnoCard.isSkipAll(code)) {
      return Icon(Icons.do_not_disturb_on_rounded, color: color, size: size * 0.92, shadows: shadows);
    }
    final label = UnoCard.label(code);
    return Text(label, style: TextStyle(
      color: color, fontWeight: FontWeight.w900, height: 1,
      fontSize: label.length >= 3 ? size * 0.6 : (label.length == 2 ? size * 0.78 : size),
      shadows: shadows,
    ));
  }

  // 4-colour quadrant face for wild cards.
  Widget _wildFace(double width) {
    Widget q(Color c) => Expanded(child: DecoratedBox(decoration: BoxDecoration(color: c)));
    return DecoratedBox(
      decoration: const BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(999))),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        child: Column(children: [
          Expanded(child: Row(children: [q(const Color(0xFFE53935)), q(const Color(0xFFFDD835))])),
          Expanded(child: Row(children: [q(const Color(0xFF43A047)), q(const Color(0xFF1E88E5))])),
        ]),
      ),
    );
  }

  Widget _cardBack({required double width}) {
    final h = width * 1.45;
    final frame = width * 0.055;
    final radius = width * 0.16;
    return Container(
      width: width, height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      padding: EdgeInsets.all(frame),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - frame),
        child: Stack(children: [
          Positioned.fill(child: DecoratedBox(decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF2A2F3C), Color(0xFF0E1016)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ))),
          Center(child: Transform.rotate(
            angle: -0.45,
            child: Container(
              width: width * 0.74, height: h * 0.52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF5A52), Color(0xFFC1271F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.all(Radius.elliptical(width * 0.45, h * 0.32)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: width * 0.03),
              ),
              child: width >= 50
                  ? Center(child: Text('UNO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: width * 0.26, letterSpacing: 1)))
                  : null,
            ),
          )),
          Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0.0)],
              begin: Alignment.topCenter, end: Alignment.center,
            ),
          )))),
        ]),
      ),
    );
  }
}
