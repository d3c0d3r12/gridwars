import 'package:firebase_database/firebase_database.dart';

class AdminUser {
  final String uid;
  final String username;
  final String profilePic;
  final int coins;
  final int matchPlayed;
  final int matchWon;
  final int score;
  final bool banned;
  final String banReason;
  final String type;

  const AdminUser({
    required this.uid,
    required this.username,
    required this.profilePic,
    required this.coins,
    required this.matchPlayed,
    required this.matchWon,
    required this.score,
    required this.banned,
    required this.banReason,
    required this.type,
  });

  factory AdminUser.fromMap(String uid, Map data) {
    return AdminUser(
      uid: uid,
      username: data['username']?.toString() ?? 'Unknown',
      profilePic: data['profilePic']?.toString() ?? '',
      coins: (data['coin'] as int?) ?? 0,
      matchPlayed: (data['matchplayed'] as int?) ?? 0,
      matchWon: (data['matchwon'] as int?) ?? 0,
      score: (data['score'] as int?) ?? 0,
      banned: data['banned'] == true,
      banReason: data['banReason']?.toString() ?? '',
      type: data['type']?.toString() ?? 'GUEST',
    );
  }
}

class AdminService {
  static final _db = FirebaseDatabase.instance;

  // ── Admin check ───────────────────────────────────────────────────────────

  static Future<bool> isAdmin(String uid) async {
    try {
      final snap = await _db.ref().child('admins').child(uid).once();
      return snap.snapshot.value == true;
    } catch (_) {
      return false;
    }
  }

  static Stream<bool> isAdminStream(String uid) {
    return _db.ref().child('admins').child(uid).onValue.map(
        (ev) => ev.snapshot.value == true);
  }

  // ── User management ───────────────────────────────────────────────────────

  // Stream: fires immediately when first batch arrives — no blank loading screen.
  static Stream<List<AdminUser>> usersStream({int limit = 100}) {
    return _db.ref().child('users').limitToFirst(limit).onValue.map((ev) {
      if (ev.snapshot.value == null) return <AdminUser>[];
      final map = Map<String, dynamic>.from(ev.snapshot.value as Map);
      final users = map.entries
          .where((e) => e.value is Map)
          .map((e) => AdminUser.fromMap(e.key, e.value as Map))
          .toList();
      users.sort((a, b) => b.coins.compareTo(a.coins));
      return users;
    });
  }

  static Future<List<AdminUser>> getAllUsers({int limit = 100}) async {
    final snap =
        await _db.ref().child('users').limitToFirst(limit).once();
    if (snap.snapshot.value == null) return [];
    final map = Map<String, dynamic>.from(snap.snapshot.value as Map);
    final users = map.entries
        .where((e) => e.value is Map)
        .map((e) => AdminUser.fromMap(e.key, e.value as Map))
        .toList();
    users.sort((a, b) => b.coins.compareTo(a.coins));
    return users;
  }

  // ── Ban / Unban ───────────────────────────────────────────────────────────

  static Future<void> banUser(String uid, String reason) async {
    await _db.ref().child('users').child(uid).update({
      'banned': true,
      'banReason': reason.trim().isEmpty ? 'Violation of terms' : reason.trim(),
      'bannedAt': DateTime.now().toUtc().toString(),
    });
  }

  static Future<void> unbanUser(String uid) async {
    await _db.ref().child('users').child(uid).update({
      'banned': false,
      'banReason': '',
    });
  }

  // ── Coin management ───────────────────────────────────────────────────────

  static Future<void> adjustCoins(String uid, int delta) async {
    await _db
        .ref()
        .child('users')
        .child(uid)
        .child('coin')
        .runTransaction(
            (v) => Transaction.success(((v as int?) ?? 0) + delta));
  }

  static Future<void> setCoins(String uid, int amount) async {
    await _db
        .ref()
        .child('users')
        .child(uid)
        .child('coin')
        .set(amount.clamp(0, 9999999));
  }

  // ── Stat management ───────────────────────────────────────────────────────

  static Future<void> resetStats(String uid) async {
    await _db.ref().child('users').child(uid).update({
      'matchplayed': 0,
      'matchwon': 0,
      'score': 0,
    });
  }

  // ── Ban status stream (for real-time enforcement in home screen) ──────────

  static Stream<bool> bannedStream(String uid) {
    return _db
        .ref()
        .child('users')
        .child(uid)
        .child('banned')
        .onValue
        .map((ev) => ev.snapshot.value == true);
  }

  static Future<Map<String, dynamic>?> getUserData(String uid) async {
    final snap = await _db.ref().child('users').child(uid).once();
    if (snap.snapshot.value == null) return null;
    return Map<String, dynamic>.from(snap.snapshot.value as Map);
  }
}
