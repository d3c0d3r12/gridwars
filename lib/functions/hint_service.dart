import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/constant.dart';

/// Manages the "bulbs" hint currency and Brain Tricks level progress.
///
/// Bulbs are **local-first** (SharedPreferences is the source of truth, so it
/// works offline and reads instantly) with a best-effort mirror to
/// `users/{uid}/bulbs` for cross-device continuity. Level progress is purely
/// local — no Firebase rules or sync needed.
class HintService {
  static const _kBulbs = 'brain_bulbs';
  static const _kSeeded = 'brain_seeded';
  static const _kReached = 'brain_level_reached'; // highest unlocked (1-based)
  static const _kCompleted = 'brain_completed'; // CSV of completed level ids

  static SharedPreferences? _sp;
  static int _bulbs = 0;

  static Future<SharedPreferences> get _prefs async =>
      _sp ??= await SharedPreferences.getInstance();

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// The owner/dev account gets unlimited coins + bulbs.
  static bool get isOwner =>
      (FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase() ==
      ownerEmail.toLowerCase();

  /// Tops up the owner account with unlimited coins + bulbs. Safe to call on
  /// every launch (it just re-sets the values). No-op for everyone else.
  static Future<void> ownerTopUp() async {
    if (!isOwner) return;
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseDatabase.instance.ref().child('users').child(uid).update({
        'coin': kOwnerCoins,
        'bulbs': kOwnerCoins,
      });
      _bulbs = kOwnerCoins;
      (await _prefs).setInt(_kBulbs, _bulbs);
    } catch (e) {
      debugPrint('HintService.ownerTopUp failed: $e');
    }
  }

  /// Call once before showing any Brain Tricks UI. Seeds the starting balance
  /// for new players and pulls a higher remote balance if one exists.
  static Future<void> init() async {
    final sp = await _prefs;
    if (sp.getBool(_kSeeded) != true) {
      _bulbs = kStartBulbs;
      await sp.setInt(_kBulbs, _bulbs);
      await sp.setBool(_kSeeded, true);
      _mirrorToFirebase();
    } else {
      _bulbs = sp.getInt(_kBulbs) ?? kStartBulbs;
    }
    // Reconcile with the cloud value (take the max so a fresh install on a
    // logged-in account doesn't lose previously earned bulbs).
    final uid = _uid;
    if (uid != null) {
      try {
        final snap = await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(uid)
            .child('bulbs')
            .once();
        final remote = (snap.snapshot.value as int?);
        if (remote != null && remote > _bulbs) {
          _bulbs = remote;
          await sp.setInt(_kBulbs, _bulbs);
        } else {
          _mirrorToFirebase();
        }
      } catch (e) {
        debugPrint('HintService.init remote read failed: $e');
      }
    }
    // Make sure the leaderboard reflects any progress already made locally.
    syncBrainScore((await completedLevels()).length);
  }

  static int get bulbs => isOwner ? kOwnerCoins : _bulbs;

  static Future<int> getBulbs() async {
    if (isOwner) return kOwnerCoins;
    final sp = await _prefs;
    _bulbs = sp.getInt(_kBulbs) ?? _bulbs;
    return _bulbs;
  }

  /// Spends [n] bulbs. Returns false (and changes nothing) if insufficient.
  static Future<bool> spendBulbs(int n) async {
    if (isOwner) return true; // unlimited for the owner
    if (_bulbs < n) return false;
    _bulbs -= n;
    final sp = await _prefs;
    await sp.setInt(_kBulbs, _bulbs);
    _mirrorToFirebase();
    return true;
  }

  static Future<void> addBulbs(int n) async {
    _bulbs += n;
    final sp = await _prefs;
    await sp.setInt(_kBulbs, _bulbs);
    _mirrorToFirebase();
  }

  static void _mirrorToFirebase() {
    final uid = _uid;
    if (uid == null) return;
    try {
      FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(uid)
          .update({'bulbs': _bulbs});
    } catch (e) {
      debugPrint('HintService bulb mirror failed: $e');
    }
  }

  // ── Progress ───────────────────────────────────────────────────────────────

  /// Highest level number the player has reached (1-based). Level 1 is always
  /// unlocked.
  static int get currentLevel => (_sp?.getInt(_kReached) ?? 1).clamp(1, 1 << 30);

  static Future<int> getCurrentLevel() async {
    final sp = await _prefs;
    return (sp.getInt(_kReached) ?? 1);
  }

  static bool isUnlocked(int levelId) => levelId <= currentLevel;

  static Future<Set<int>> completedLevels() async {
    final sp = await _prefs;
    final raw = sp.getString(_kCompleted) ?? '';
    if (raw.isEmpty) return <int>{};
    return raw
        .split(',')
        .where((e) => e.isNotEmpty)
        .map((e) => int.tryParse(e) ?? 0)
        .where((e) => e > 0)
        .toSet();
  }

  /// Marks a level complete and unlocks the next one.
  static Future<void> markCompleted(int levelId) async {
    final sp = await _prefs;
    final done = await completedLevels()..add(levelId);
    await sp.setString(_kCompleted, done.join(','));
    final reached = sp.getInt(_kReached) ?? 1;
    if (levelId + 1 > reached) {
      await sp.setInt(_kReached, levelId + 1);
    }
    // The leaderboard score is the number of puzzles solved.
    syncBrainScore(done.length);
  }

  /// Mirrors the player's Brain Tricks score (levels solved) to
  /// `users/{uid}/brainScore` so it can power the leaderboard.
  static void syncBrainScore(int score) {
    final uid = _uid;
    if (uid == null) return;
    try {
      FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(uid)
          .update({'brainScore': score});
    } catch (e) {
      debugPrint('HintService brainScore sync failed: $e');
    }
  }
}
