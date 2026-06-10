import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../helpers/puzzle_models.dart';
import '../helpers/utils.dart';
import '../widgets/puzzle_art.dart';
import '../functions/hint_service.dart';
import '../functions/rewarded_ad_service.dart';

/// The Brain Tricks puzzle player. Renders the right interaction template for
/// each [PuzzleLevel], checks answers, handles hints / skip / watch-ad, and
/// advances level by level.
class BrainPuzzleScreen extends StatefulWidget {
  final List<PuzzleLevel> levels;
  final int startIndex;
  const BrainPuzzleScreen({
    super.key,
    required this.levels,
    required this.startIndex,
  });

  @override
  State<BrainPuzzleScreen> createState() => _BrainPuzzleScreenState();
}

class _BrainPuzzleScreenState extends State<BrainPuzzleScreen>
    with TickerProviderStateMixin {
  late int _index;
  int _bulbs = 0;

  // per-level transient state
  bool _hintShown = false;
  bool _solved = false;
  bool _viaSkip = false;
  String? _wrongNodeId;
  final Set<String> _multiSelected = {};
  final Map<String, String> _drops = {}; // dragId -> targetId
  final List<String> _sequence = []; // tap order for sequence levels
  final Set<String> _revealed = {}; // node ids un-hidden via a cover
  final Set<String> _removedCovers = {}; // cover nodes already used
  final TextEditingController _textCtrl = TextEditingController();

  late final AnimationController _winCtrl;

  PuzzleLevel get _level => widget.levels[_index];
  bool get _hasNext => _index < widget.levels.length - 1;

  @override
  void initState() {
    super.initState();
    _index = widget.levels.isEmpty
        ? 0
        : widget.startIndex.clamp(0, widget.levels.length - 1);
    _winCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _loadBulbs();
  }

  @override
  void dispose() {
    _winCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBulbs() async {
    final b = await HintService.getBulbs();
    if (mounted) setState(() => _bulbs = b);
  }

  void _resetForLevel() {
    _hintShown = false;
    _solved = false;
    _viaSkip = false;
    _wrongNodeId = null;
    _multiSelected.clear();
    _drops.clear();
    _sequence.clear();
    _revealed.clear();
    _removedCovers.clear();
    _textCtrl.clear();
    _winCtrl.reset();
  }

  // ── Outcomes ────────────────────────────────────────────────────────────────

  Future<void> _onSolved({bool viaSkip = false}) async {
    if (_solved) return;
    setState(() {
      _solved = true;
      _viaSkip = viaSkip;
    });
    music.play(viaSkip ? click : wingame);
    await HintService.markCompleted(_level.id);
    if (!viaSkip) {
      await HintService.addBulbs(kSolveBulbReward);
      if (mounted) setState(() => _bulbs = HintService.bulbs);
    }
    _winCtrl.forward(from: 0);
  }

  void _wrong(String? nodeId) {
    HapticFeedback.mediumImpact();
    setState(() => _wrongNodeId = nodeId);
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _wrongNodeId = null);
    });
    _snack('Not quite — think differently 🤔');
  }

  void _next() {
    if (_hasNext) {
      setState(() {
        _index++;
        _resetForLevel();
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  // ── Hint / Skip / Ad ─────────────────────────────────────────────────────────

  Future<void> _buyHint() async {
    if (_hintShown) return;
    if (_bulbs < kHintCost) {
      _offerAd('You need $kHintCost bulbs for a hint.');
      return;
    }
    final ok = await HintService.spendBulbs(kHintCost);
    if (ok) {
      music.play(click);
      setState(() {
        _bulbs = HintService.bulbs;
        _hintShown = true;
      });
    }
  }

  Future<void> _skip() async {
    if (_solved) return;
    if (_bulbs < kSkipCost) {
      _offerAd('You need $kSkipCost bulbs to skip.');
      return;
    }
    final ok = await HintService.spendBulbs(kSkipCost);
    if (ok) {
      setState(() => _bulbs = HintService.bulbs);
      await _onSolved(viaSkip: true);
    }
  }

  Future<void> _watchAd() async {
    final res = await RewardedAdService.showForReward(onReward: () async {
      await HintService.addBulbs(kAdBulbReward);
      if (mounted) {
        setState(() => _bulbs = HintService.bulbs);
        _snack('+$kAdBulbReward bulbs! 💡');
      }
    });
    if (!res.shown) {
      if (res.reason == 'limit') {
        _snack("You've hit today's ad limit. Come back tomorrow!");
      } else {
        _snack('No ad available right now — try again shortly.');
      }
    }
  }

  void _offerAd(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: inkColor,
      behavior: SnackBarBehavior.floating,
      content: Text(msg, style: TextStyle(color: surfaceColor)),
      action: SnackBarAction(
        label: 'WATCH AD',
        textColor: goldColor,
        onPressed: _watchAd,
      ),
    ));
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: inkColor,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1400),
      content: Text(msg, style: TextStyle(color: surfaceColor)),
    ));
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _questionCard(),
            Expanded(child: _sceneArea()),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              music.play(click);
              Navigator.of(context).pop();
            },
            icon: Icon(Icons.arrow_back_rounded, color: inkColor),
          ),
          Expanded(
            child: Text(
              'Level ${_level.id}',
              style: TextStyle(
                color: inkColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _bulbChip(),
        ],
      ),
    );
  }

  Widget _bulbChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: goldSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: goldColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lightbulb_rounded, color: goldColor, size: 18),
          const SizedBox(width: 5),
          Text('$_bulbs',
              style: TextStyle(
                  color: inkColor, fontWeight: FontWeight.w800, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _questionCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(radius: 18),
      child: Column(
        children: [
          Text(
            _level.question,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: inkColor,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          if (_hintShown && !_solved) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: goldSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tips_and_updates_rounded,
                      color: goldColor, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(_level.hint,
                        style: TextStyle(
                            color: inkColor,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sceneArea() {
    if (_solved) return _solvedView();
    switch (_level.type) {
      case PuzzleType.choice:
        return _choiceView();
      case PuzzleType.typeAnswer:
      case PuzzleType.count:
        return _inputView();
      case PuzzleType.tapObject:
      case PuzzleType.tapMulti:
      case PuzzleType.sequence:
        return _tapView();
      case PuzzleType.dragTo:
        return _dragView();
    }
  }

  /// A defined "play canvas" the puzzle objects sit on — gives every level a
  /// scene/stage feel (like the Brain Test notebook) instead of floating items.
  Widget _stage({required Widget child}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [surfaceColor, surface2Color],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: lineColor),
        boxShadow: [shadowSm],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  // ── Node visual ──────────────────────────────────────────────────────────────

  Widget _nodeVisual(PuzzleNode n, double px, {bool selected = false}) {
    final wrong = _wrongNodeId == n.id;
    final glow = _hintShown && _level.highlightId == n.id;
    Widget inner;
    if (n.art != null) {
      inner = puzzleArt(n.art!, size: px, tint: n.color);
    } else if (n.emoji != null) {
      inner = Text(n.emoji!, style: TextStyle(fontSize: px * 0.78));
    } else if (n.asset != null) {
      inner = Image.asset(n.asset!, width: px, height: px, fit: BoxFit.contain);
    } else if (n.icon != null) {
      inner = Icon(n.icon, size: px, color: n.color ?? inkColor);
    } else {
      inner = Container(
        width: px,
        height: px,
        decoration: BoxDecoration(
          color: n.color ?? xColor,
          shape: BoxShape.circle,
        ),
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          if (glow)
            BoxShadow(
                color: goldColor.withValues(alpha: 0.8),
                blurRadius: 22,
                spreadRadius: 3),
          if (selected)
            BoxShadow(
                color: goodColor.withValues(alpha: 0.7),
                blurRadius: 16,
                spreadRadius: 2),
          if (wrong)
            BoxShadow(
                color: red.withValues(alpha: 0.85),
                blurRadius: 18,
                spreadRadius: 2),
        ],
      ),
      child: Transform.rotate(angle: n.rotate, child: inner),
    );
  }

  // ── tapObject / tapMulti ─────────────────────────────────────────────────────

  Widget _tapView() {
    return _stage(
        child: LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth, h = c.maxHeight;
      final minSide = w < h ? w : h;
      return Stack(
        fit: StackFit.expand,
        children: [
          if (_level.background != null) puzzleBackground(_level.background!),
          for (final n in _level.nodes)
            if (_isVisible(n))
              Builder(builder: (_) {
                final px = (n.size * minSide).clamp(28.0, minSide);
                final order = _sequence.indexOf(n.id);
                return Positioned(
                  left: n.x * w - px / 2,
                  top: n.y * h - px / 2,
                  child: GestureDetector(
                    onTap: () => _onTapNode(n),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        _nodeVisual(n, px,
                            selected: _multiSelected.contains(n.id) ||
                                order >= 0),
                        if (order >= 0)
                          Positioned(
                            top: -px * 0.12,
                            right: -px * 0.12,
                            child: _seqBadge(order + 1, px),
                          ),
                      ],
                    ),
                  ),
                );
              }),
        ],
      );
    }));
  }

  /// A node is visible unless it's a removed cover or a still-hidden node.
  bool _isVisible(PuzzleNode n) {
    if (n.cover && _removedCovers.contains(n.id)) return false;
    if (n.hidden && !_revealed.contains(n.id)) return false;
    return true;
  }

  Widget _seqBadge(int n, double px) {
    final d = (px * 0.34).clamp(16.0, 28.0);
    return Container(
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: xColor, shape: BoxShape.circle),
      child: Text('$n',
          style: TextStyle(
              color: Colors.white,
              fontSize: d * 0.55,
              fontWeight: FontWeight.w800)),
    );
  }

  void _onTapNode(PuzzleNode n) {
    if (_solved) return;

    // A cover node reveals what's underneath, then disappears (multi-step).
    if (n.cover || (n.reveals != null && n.reveals!.isNotEmpty)) {
      music.play(click);
      setState(() {
        if (n.cover) _removedCovers.add(n.id);
        _revealed.addAll(n.reveals ?? const []);
      });
      return;
    }

    switch (_level.type) {
      case PuzzleType.tapObject:
        if (_level.isCorrect(n.id)) {
          music.play(click);
          _onSolved();
        } else {
          _wrong(n.id);
        }
        break;
      case PuzzleType.sequence:
        final want = (_level.answer as List).map((e) => e.toString()).toList();
        final next = _sequence.length;
        if (next < want.length && want[next] == n.id) {
          music.play(click);
          setState(() => _sequence.add(n.id));
          if (_level.isCorrect(_sequence)) _onSolved();
        } else {
          setState(() => _sequence.clear()); // wrong order → restart
          _wrong(n.id);
        }
        break;
      default: // tapMulti
        final want = (_level.answer as List).map((e) => e.toString()).toSet();
        if (want.contains(n.id)) {
          music.play(click);
          setState(() => _multiSelected.add(n.id));
          if (_level.isCorrect(_multiSelected)) _onSolved();
        } else {
          _wrong(n.id);
        }
    }
  }

  // ── choice ───────────────────────────────────────────────────────────────────

  Widget _choiceView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 14,
        children: [
          for (final n in _level.nodes) _choiceCard(n),
        ],
      ),
    );
  }

  Widget _choiceCard(PuzzleNode n) {
    final wrong = _wrongNodeId == n.id;
    final glow = _hintShown && _level.highlightId == n.id;
    return GestureDetector(
      onTap: () {
        if (_solved) return;
        if (_level.isCorrect(n.id)) {
          music.play(click);
          _onSolved();
        } else {
          _wrong(n.id);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 150,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 14),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: wrong
                ? red
                : glow
                    ? goldColor
                    : lineColor,
            width: wrong || glow ? 2 : 1,
          ),
          boxShadow: [shadowSm],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (n.emoji != null)
              Text(n.emoji!, style: const TextStyle(fontSize: 44))
            else if (n.icon != null)
              Icon(n.icon, size: 44, color: n.color ?? xColor),
            if ((n.emoji != null || n.icon != null) && n.label != null)
              const SizedBox(height: 10),
            if (n.label != null)
              Text(n.label!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: inkColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // ── typeAnswer / count ───────────────────────────────────────────────────────

  Widget _inputView() {
    final isCount = _level.type == PuzzleType.count;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth, h = c.maxHeight;
      final minSide = w < h ? w : h;
      return Column(
        children: [
          // decorative / countable scene
          Expanded(
            child: _level.nodes.isEmpty
                ? const SizedBox.shrink()
                : _stage(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        for (final n in _level.nodes)
                          Builder(builder: (_) {
                            final px = (n.size * minSide).clamp(24.0, minSide);
                            return Positioned(
                              left: n.x * w - px / 2,
                              top: n.y * (h * 0.7) - px / 2,
                              child: IgnorePointer(child: _nodeVisual(n, px)),
                            );
                          }),
                      ],
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    keyboardType:
                        isCount ? TextInputType.number : TextInputType.text,
                    inputFormatters: isCount
                        ? [FilteringTextInputFormatter.digitsOnly]
                        : null,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submitInput(),
                    style: TextStyle(
                        color: inkColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: isCount ? 'Enter a number' : 'Type your answer',
                      hintStyle: TextStyle(color: ink3Color),
                      filled: true,
                      fillColor: surfaceColor,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: lineColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: xColor, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _submitInput,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: xColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  void _submitInput() {
    if (_solved) return;
    final t = _textCtrl.text.trim();
    if (t.isEmpty) return;
    FocusScope.of(context).unfocus();
    if (_level.isCorrect(t)) {
      music.play(click);
      _onSolved();
    } else {
      _wrong(null);
    }
  }

  // ── dragTo ───────────────────────────────────────────────────────────────────

  Widget _dragView() {
    return _stage(
        child: LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth, h = c.maxHeight;
      final minSide = w < h ? w : h;
      return Stack(
        fit: StackFit.expand,
        children: [
          if (_level.background != null) puzzleBackground(_level.background!),
          // decorative scene objects (not draggable/target/cover) — show them so
          // drag scenes look complete (coffee maker, person, TV, bulb, etc.)
          for (final n in _level.nodes.where((e) =>
              !e.isTarget && !e.draggable && !e.cover && _isVisible(e)))
            Builder(builder: (_) {
              final px = (n.size * minSide).clamp(28.0, minSide);
              return Positioned(
                left: n.x * w - px / 2,
                top: n.y * h - px / 2,
                child: IgnorePointer(child: _nodeVisual(n, px)),
              );
            }),
          // cover nodes — tap to reveal a hidden draggable/object underneath
          for (final n in _level.nodes.where((e) => e.cover && _isVisible(e)))
            Builder(builder: (_) {
              final px = (n.size * minSide).clamp(40.0, minSide);
              return Positioned(
                left: n.x * w - px / 2,
                top: n.y * h - px / 2,
                child: GestureDetector(
                  onTap: () => _onTapNode(n),
                  child: _nodeVisual(n, px),
                ),
              );
            }),
          // targets first (under the draggables)
          for (final n in _level.nodes.where((e) => e.isTarget && _isVisible(e)))
            Builder(builder: (_) {
              final px = (n.size * minSide).clamp(40.0, minSide);
              return Positioned(
                left: n.x * w - px / 2,
                top: n.y * h - px / 2,
                child: DragTarget<String>(
                  onWillAcceptWithDetails: (_) => true,
                  onAcceptWithDetails: (d) => _onDrop(d.data, n.id),
                  builder: (_, cand, __) {
                    return AnimatedScale(
                      scale: cand.isNotEmpty ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 120),
                      child: _nodeVisual(n, px),
                    );
                  },
                ),
              );
            }),
          // draggables (hide once placed)
          for (final n in _level.nodes.where((e) =>
              e.draggable && !_drops.containsKey(e.id) && _isVisible(e)))
            Builder(builder: (_) {
              final px = (n.size * minSide).clamp(40.0, minSide);
              final visual = _nodeVisual(n, px);
              return Positioned(
                left: n.x * w - px / 2,
                top: n.y * h - px / 2,
                child: Draggable<String>(
                  data: n.id,
                  feedback: Material(color: Colors.transparent, child: visual),
                  childWhenDragging: Opacity(opacity: 0.3, child: visual),
                  child: visual,
                ),
              );
            }),
        ],
      );
    }));
  }

  void _onDrop(String dragId, String targetId) {
    if (_solved) return;
    final answer = Map<String, String>.from(_level.answer as Map);
    if (answer[dragId] == targetId) {
      music.play(click);
      final node = _level.nodeById(dragId);
      setState(() {
        _drops[dragId] = targetId;
        // a correct drop can reveal the next step (e.g. logs placed → match appears)
        if (node?.reveals != null) _revealed.addAll(node!.reveals!);
      });
      if (_level.isCorrect(_drops)) _onSolved();
    } else {
      _wrong(dragId);
    }
  }

  // ── Solved view ──────────────────────────────────────────────────────────────

  Widget _solvedView() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: CurvedAnimation(
                    parent: _winCtrl, curve: Curves.elasticOut),
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: _viaSkip ? xSoft : goodColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _viaSkip
                        ? Icons.fast_forward_rounded
                        : Icons.check_rounded,
                    color: _viaSkip ? xColor : goodColor,
                    size: 64,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _viaSkip ? 'Skipped' : 'Solved!',
                style: TextStyle(
                    color: inkColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (!_viaSkip)
                Text('+$kSolveBulbReward 💡',
                    style: TextStyle(
                        color: goldColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              if (_viaSkip) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: lineColor),
                  ),
                  child: Text(
                    'Answer: ${_level.solution}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: ink2Color,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    music.play(click);
                    _next();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: xColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _hasNext ? 'Next Level' : 'Back to Levels',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Footer ───────────────────────────────────────────────────────────────────

  Widget _footer() {
    if (_solved) return const SizedBox.shrink();
    // Hide the action row while the keyboard is open (typeAnswer/count) so the
    // layout never overflows.
    if (MediaQuery.of(context).viewInsets.bottom > 0) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: _footerBtn(
              icon: Icons.search_rounded,
              label: 'Hint',
              cost: kHintCost,
              onTap: _buyHint,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _footerBtn(
              icon: Icons.ondemand_video_rounded,
              label: 'Free bulbs',
              accent: goodColor,
              onTap: _watchAd,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _footerBtn(
              icon: Icons.fast_forward_rounded,
              label: 'Skip',
              cost: kSkipCost,
              accent: oColor,
              onTap: _skip,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerBtn({
    required IconData icon,
    required String label,
    int? cost,
    Color? accent,
    required VoidCallback onTap,
  }) {
    final c = accent ?? xColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: lineColor),
          boxShadow: [shadowSm],
        ),
        child: Column(
          children: [
            Icon(icon, color: c, size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: inkColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
            if (cost != null) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lightbulb_rounded, color: goldColor, size: 12),
                  const SizedBox(width: 2),
                  Text('$cost',
                      style: TextStyle(
                          color: ink2Color,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
