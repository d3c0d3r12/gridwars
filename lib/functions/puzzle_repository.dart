import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/brain_puzzles.dart';
import '../helpers/puzzle_models.dart';

/// Loads Brain Tricks levels from THREE sources, merged by level `id`:
///   1. the built-in pack (`kBrainPuzzles`) — always present, offline-safe seed
///   2. a local cache of the last remote fetch — instant + offline
///   3. the `brainPuzzles` Firebase node — live content (add levels = no app update)
///
/// Remote/cached levels override built-in ones with the same id and new ids are
/// appended. This is how new daily levels appear without republishing the app —
/// as long as they only use art props / emoji / mechanics already in the build.
class PuzzleRepository {
  static const _cacheKey = 'brain_remote_levels_v1';
  static List<PuzzleLevel>? _cached;

  /// Returns the full, merged, id-sorted level list. Result is memoized for the
  /// session. Network failures fall back to cache, then to the built-in pack.
  static Future<List<PuzzleLevel>> getLevels() async {
    if (_cached != null) return _cached!;

    final byId = {for (final l in kBrainPuzzles) l.id: l};

    // 2. local cache (fast, offline)
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_cacheKey);
      if (raw != null && raw.isNotEmpty) {
        _merge(jsonDecode(raw), byId);
      }
    } catch (e) {
      debugPrint('PuzzleRepository cache read failed: $e');
    }

    // 3. remote (live) — short timeout so launch is never blocked for long
    try {
      final snap = await FirebaseDatabase.instance
          .ref()
          .child('brainPuzzles')
          .once()
          .timeout(const Duration(seconds: 5));
      final val = snap.snapshot.value;
      if (val != null) {
        _merge(val, byId);
        try {
          final sp = await SharedPreferences.getInstance();
          await sp.setString(_cacheKey, jsonEncode(val));
        } catch (e) {
          debugPrint('PuzzleRepository cache write failed: $e');
        }
      }
    } catch (e) {
      debugPrint('PuzzleRepository remote fetch skipped: $e');
    }

    final list = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    _cached = list;
    return list;
  }

  /// Forces a re-fetch next time (e.g. after publishing new levels).
  static void invalidate() => _cached = null;

  /// Merges a raw value (Map of {key: levelJson} or a List of levelJson) into
  /// the id-keyed map. Each malformed entry is skipped, never crashing the app.
  static void _merge(dynamic val, Map<int, PuzzleLevel> byId) {
    Iterable entries;
    if (val is Map) {
      entries = val.values;
    } else if (val is List) {
      entries = val.where((e) => e != null);
    } else {
      return;
    }
    for (final e in entries) {
      if (e is Map) {
        try {
          final lvl = PuzzleLevel.fromJson(e);
          byId[lvl.id] = lvl;
        } catch (err) {
          debugPrint('PuzzleRepository skipped bad level: $err');
        }
      }
    }
  }
}
