import 'package:flutter/material.dart';

/// The interaction template a level uses. The puzzle player switches its
/// rendering + answer-checking on this.
enum PuzzleType {
  tapObject, // tap the one correct object/region
  tapMulti, // tap several correct objects (any order)
  choice, // tap one of N labelled cards
  dragTo, // drag an object onto a target (supports multi-pair = combine)
  sequence, // tap nodes in a specific order
  typeAnswer, // (legacy, unused) type a word/number
  count, // (legacy, unused) count things, enter the number
}

/// A positioned element in a puzzle scene. Position is RELATIVE (0..1) so it
/// scales to any screen size. Visual is one of: emoji, Material icon, or an
/// optional asset image. `label` is used by [PuzzleType.choice].
class PuzzleNode {
  final String id;
  final double x; // 0..1 center X
  final double y; // 0..1 center Y
  final double size; // 0..1 relative size (fraction of the smaller scene side)
  final String? emoji;
  final IconData? icon;
  final Color? color;
  final String? art; // name of a vector prop in puzzle_art.dart (preferred)
  final String? asset; // optional 'assets/puzzles/xyz.png'
  final String? label; // for choice cards
  final bool draggable; // for dragTo: this node can be dragged
  final bool isTarget; // for dragTo: this node is a drop target
  final bool hidden; // starts invisible; shown only after a reveal
  final List<String>? reveals; // tapping/dragging this un-hides these node ids
  final bool cover; // a node removed when tapped/dragged (to reveal what's under)
  final double rotate; // radians, purely cosmetic

  const PuzzleNode(
    this.id, {
    this.x = 0.5,
    this.y = 0.5,
    this.size = 0.16,
    this.emoji,
    this.icon,
    this.color,
    this.art,
    this.asset,
    this.label,
    this.draggable = false,
    this.isTarget = false,
    this.hidden = false,
    this.reveals,
    this.cover = false,
    this.rotate = 0,
  });

  /// Builds a node from a JSON map (remote / cached levels).
  factory PuzzleNode.fromJson(Map j) => PuzzleNode(
        j['id'].toString(),
        x: (j['x'] as num?)?.toDouble() ?? 0.5,
        y: (j['y'] as num?)?.toDouble() ?? 0.5,
        size: (j['size'] as num?)?.toDouble() ?? 0.16,
        emoji: j['emoji']?.toString(),
        art: j['art']?.toString(),
        asset: j['asset']?.toString(),
        label: j['label']?.toString(),
        color: j['color'] != null ? Color((j['color'] as num).toInt()) : null,
        draggable: j['draggable'] == true,
        isTarget: j['isTarget'] == true,
        hidden: j['hidden'] == true,
        cover: j['cover'] == true,
        reveals: (j['reveals'] as List?)?.map((e) => e.toString()).toList(),
        rotate: (j['rotate'] as num?)?.toDouble() ?? 0,
      );
}

/// A single puzzle level. Levels are pure data (see lib/data/brain_puzzles.dart)
/// so the pack can grow toward 1000 without new code — and is shaped so the list
/// can later be loaded from remote JSON.
///
/// `answer` meaning by type:
///   tapObject  -> String   (correct node id)
///   tapMulti   -> List<String> (all correct node ids, any order)
///   choice     -> String   (correct node id)
///   dragTo     -> Map<String,String> ({draggableNodeId: targetNodeId})
///   typeAnswer -> String   (or List<String> of accepted answers)
///   count      -> int
class PuzzleLevel {
  final int id; // 1-based level number
  final String question; // the trick prompt shown at top
  final PuzzleType type;
  final List<PuzzleNode> nodes;
  final Object answer;
  final String hint; // revealed for kHintCost bulbs
  final String? highlightId; // node to glow when a hint is bought
  final String solution; // revealed on skip
  final int tier; // 1=easy .. 7=genius — keeps the difficulty curve monotonic
  final String? background; // backdrop art name (e.g. 'roomBg')

  const PuzzleLevel({
    required this.id,
    required this.question,
    required this.type,
    required this.nodes,
    required this.answer,
    required this.hint,
    required this.solution,
    this.highlightId,
    this.tier = 1,
    this.background,
  });

  /// Builds a level from a JSON map (remote / cached levels). `answer` may be a
  /// String (tapObject/choice), a List (tapMulti/sequence), or a Map (dragTo).
  factory PuzzleLevel.fromJson(Map j) {
    final typeStr = j['type'].toString();
    final type = PuzzleType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => PuzzleType.tapObject,
    );
    final a = j['answer'];
    Object ans;
    if (a is Map) {
      ans = a.map((k, v) => MapEntry(k.toString(), v.toString()));
    } else if (a is List) {
      ans = a.map((e) => e.toString()).toList();
    } else {
      ans = a ?? '';
    }
    return PuzzleLevel(
      id: (j['id'] as num).toInt(),
      question: j['question']?.toString() ?? '',
      type: type,
      nodes: ((j['nodes'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => PuzzleNode.fromJson(e))
          .toList(),
      answer: ans,
      hint: j['hint']?.toString() ?? '',
      solution: j['solution']?.toString() ?? '',
      highlightId: j['highlightId']?.toString(),
      tier: (j['tier'] as num?)?.toInt() ?? 1,
      background: j['background']?.toString(),
    );
  }

  PuzzleNode? nodeById(String nid) {
    for (final n in nodes) {
      if (n.id == nid) return n;
    }
    return null;
  }

  /// Normalizes free-text for [PuzzleType.typeAnswer] comparison.
  static String normalize(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Checks a submitted answer against this level's solution.
  bool isCorrect(Object submitted) {
    switch (type) {
      case PuzzleType.tapObject:
      case PuzzleType.choice:
        return submitted.toString() == answer.toString();
      case PuzzleType.tapMulti:
        final want = (answer as List).map((e) => e.toString()).toSet();
        final got = (submitted as Iterable).map((e) => e.toString()).toSet();
        return want.length == got.length && want.containsAll(got);
      case PuzzleType.sequence:
        final want = (answer as List).map((e) => e.toString()).toList();
        final got = (submitted as Iterable).map((e) => e.toString()).toList();
        if (want.length != got.length) return false;
        for (int i = 0; i < want.length; i++) {
          if (want[i] != got[i]) return false;
        }
        return true;
      case PuzzleType.dragTo:
        final want = Map<String, String>.from(answer as Map);
        final got = Map<String, String>.from(submitted as Map);
        if (want.length != got.length) return false;
        for (final e in want.entries) {
          if (got[e.key] != e.value) return false;
        }
        return true;
      case PuzzleType.typeAnswer:
        final n = normalize(submitted.toString());
        if (answer is List) {
          return (answer as List).any((a) => normalize(a.toString()) == n);
        }
        return normalize(answer.toString()) == n;
      case PuzzleType.count:
        return int.tryParse(submitted.toString().trim()) ==
            (answer is int ? answer : int.tryParse(answer.toString()));
    }
  }
}
