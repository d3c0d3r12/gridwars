import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

// ── Models ─────────────────────────────────────────────────────────────────

class DiscoveryUser {
  final String uid, username, profilePic;
  final int score;
  final Set<String> tags;
  final int sharedCount;
  const DiscoveryUser(this.uid, this.username, this.profilePic, this.score,
      this.tags, this.sharedCount);
}

class FriendUser {
  final String uid, name, pic;
  const FriendUser(this.uid, this.name, this.pic);
}

class FriendRequest {
  final String fromUid, fromName, fromPic;
  final int time;
  const FriendRequest(this.fromUid, this.fromName, this.fromPic, this.time);
}

class ChatMessage {
  final String id, from, text;
  final int time;
  final bool seen;
  const ChatMessage(this.id, this.from, this.text, this.time, this.seen);
}

class Challenge {
  final String id, fromUid, fromName, gameType, gameKey;
  final int time;
  const Challenge(this.id, this.fromUid, this.fromName, this.gameType,
      this.gameKey, this.time);
}

// ── Service ────────────────────────────────────────────────────────────────

class FriendService {
  static final _db = FirebaseDatabase.instance;
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static String chatId(String a, String b) =>
      a.compareTo(b) < 0 ? '${a}__$b' : '${b}__$a';

  // ── Tags ──────────────────────────────────────────────────────────────────

  static Future<Set<String>> myTags() async {
    final snap = await _db.ref().child('users').child(_uid).child('gameTags').once();
    final v = snap.snapshot.value;
    if (v is Map) return v.keys.map((e) => e.toString()).toSet();
    return {};
  }

  // Saves tags to the private user node AND mirrors public-safe fields into
  // the discovery index so other users can find this person by tag.
  static Future<void> saveTags(Set<String> tags) async {
    final tagMap = {for (final t in tags) t: true};

    // Read public-safe profile fields for the discovery mirror.
    String username = 'Player', pic = '';
    int score = 0;
    try {
      final u = await _db.ref().child('users').child(_uid).once();
      final m = u.snapshot.value as Map? ?? {};
      username = m['username']?.toString() ?? 'Player';
      pic = m['profilePic']?.toString() ?? '';
      score = (m['score'] as int?) ?? 0;
    } catch (_) {}

    await Future.wait([
      _db.ref().child('users').child(_uid).child('gameTags').set(tagMap),
      _db.ref().child('discovery').child(_uid).set({
        'username': username,
        'profilePic': pic,
        'score': score,
        'tags': tagMap,
      }),
    ]);
  }

  // ── Discovery ─────────────────────────────────────────────────────────────

  // Streams users from the public discovery index who share ≥1 tag with me,
  // excluding self, existing friends, and blocked users (both directions),
  // sorted by shared-tag count.
  static Stream<List<DiscoveryUser>> findByTags(Set<String> myTags) async* {
    if (myTags.isEmpty) {
      yield const [];
      return;
    }

    // Snapshot of friends + blocked (both directions) to filter out.
    final friendsSnap = await _db.ref().child('friends').child(_uid).once();
    final blockedSnap = await _db.ref().child('blocked').child(_uid).once();
    final exclude = <String>{_uid};
    if (friendsSnap.snapshot.value is Map) {
      exclude.addAll((friendsSnap.snapshot.value as Map).keys.map((e) => e.toString()));
    }
    if (blockedSnap.snapshot.value is Map) {
      exclude.addAll((blockedSnap.snapshot.value as Map).keys.map((e) => e.toString()));
    }

    yield* _db.ref().child('discovery').onValue.map((ev) {
      final root = ev.snapshot.value;
      if (root is! Map) return <DiscoveryUser>[];
      final out = <DiscoveryUser>[];
      root.forEach((key, val) {
        final uid = key.toString();
        if (exclude.contains(uid) || val is! Map) return;
        final tagsRaw = val['tags'];
        final tags = (tagsRaw is Map)
            ? tagsRaw.keys.map((e) => e.toString()).toSet()
            : <String>{};
        final shared = tags.intersection(myTags).length;
        if (shared == 0) return;
        out.add(DiscoveryUser(
          uid,
          val['username']?.toString() ?? 'Player',
          val['profilePic']?.toString() ?? '',
          (val['score'] as int?) ?? 0,
          tags,
          shared,
        ));
      });
      out.sort((a, b) => b.sharedCount.compareTo(a.sharedCount));
      return out;
    });
  }

  // ── Requests ──────────────────────────────────────────────────────────────

  // Returns null on success, or a user-facing error string.
  // IMPORTANT: only reads MY own nodes — reading another user's blocked /
  // friendRequests node is denied by the security rules and would throw.
  static Future<String?> sendRequest(String toUid, String toName) async {
    try {
      if (toUid == _uid) return "That's you!";

      // My-side checks only (allowed to read my own nodes).
      final iBlocked = await _db.ref().child('blocked').child(_uid).child(toUid).once();
      if (iBlocked.snapshot.value == true) return 'You blocked this user. Unblock first.';
      final fr = await _db.ref().child('friends').child(_uid).child(toUid).once();
      if (fr.snapshot.value != null) return 'Already friends.';

      String myName = 'Player', myPic = '';
      try {
        final u = await _db.ref().child('users').child(_uid).once();
        final m = u.snapshot.value as Map? ?? {};
        myName = m['username']?.toString() ?? 'Player';
        myPic = m['profilePic']?.toString() ?? '';
      } catch (_) {}

      // Writing to the recipient's request node is allowed (rule grants write
      // when auth.uid === the fromUid child key). Re-sending is idempotent.
      await _db.ref().child('friendRequests').child(toUid).child(_uid).set({
        'fromName': myName,
        'fromPic': myPic,
        'time': ServerValue.timestamp,
      });
      return null;
    } catch (e) {
      return 'Could not send request. Make sure the Firebase rules are applied.';
    }
  }

  static Stream<List<FriendRequest>> incomingRequests() {
    return _db.ref().child('friendRequests').child(_uid).onValue.map((ev) {
      final v = ev.snapshot.value;
      if (v is! Map) return <FriendRequest>[];
      final out = <FriendRequest>[];
      v.forEach((key, val) {
        if (val is! Map) return;
        out.add(FriendRequest(
          key.toString(),
          val['fromName']?.toString() ?? 'Player',
          val['fromPic']?.toString() ?? '',
          (val['time'] as int?) ?? 0,
        ));
      });
      out.sort((a, b) => b.time.compareTo(a.time));
      return out;
    });
  }

  static Future<void> acceptRequest(String fromUid, String fromName, String fromPic) async {
    String myName = 'Player', myPic = '';
    try {
      final u = await _db.ref().child('users').child(_uid).once();
      final m = u.snapshot.value as Map? ?? {};
      myName = m['username']?.toString() ?? 'Player';
      myPic = m['profilePic']?.toString() ?? '';
    } catch (_) {}

    final now = ServerValue.timestamp;
    await _db.ref().update({
      'friends/$_uid/$fromUid': {'name': fromName, 'pic': fromPic, 'since': now},
      'friends/$fromUid/$_uid': {'name': myName, 'pic': myPic, 'since': now},
      'friendRequests/$_uid/$fromUid': null,
    });
  }

  static Future<void> declineRequest(String fromUid) async {
    await _db.ref().child('friendRequests').child(_uid).child(fromUid).remove();
  }

  // ── Friends ───────────────────────────────────────────────────────────────

  static Stream<List<FriendUser>> friends() {
    return _db.ref().child('friends').child(_uid).onValue.map((ev) {
      final v = ev.snapshot.value;
      if (v is! Map) return <FriendUser>[];
      final out = <FriendUser>[];
      v.forEach((key, val) {
        final m = (val is Map) ? val : const {};
        out.add(FriendUser(
          key.toString(),
          m['name']?.toString() ?? 'Player',
          m['pic']?.toString() ?? '',
        ));
      });
      out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return out;
    });
  }

  static Future<void> removeFriend(String uid) async {
    await _db.ref().update({
      'friends/$_uid/$uid': null,
      'friends/$uid/$_uid': null,
    });
  }

  // ── Block ─────────────────────────────────────────────────────────────────

  static Future<void> blockUser(String uid) async {
    await _db.ref().update({
      'blocked/$_uid/$uid': true,
      'friends/$_uid/$uid': null,
      'friends/$uid/$_uid': null,
      'friendRequests/$_uid/$uid': null,
      'friendRequests/$uid/$_uid': null,
    });
  }

  static Future<void> unblockUser(String uid) async {
    await _db.ref().child('blocked').child(_uid).child(uid).remove();
  }

  static Stream<Set<String>> myBlocked() {
    return _db.ref().child('blocked').child(_uid).onValue.map((ev) {
      final v = ev.snapshot.value;
      if (v is! Map) return <String>{};
      return v.keys.map((e) => e.toString()).toSet();
    });
  }

  // Only checks MY block list — the rules forbid reading another user's
  // blocked node. If they blocked me, my message still writes (chat rule is
  // auth-open) but their side hides the chat (soft block).
  static Future<bool> iBlocked(String otherUid) async {
    final a = await _db.ref().child('blocked').child(_uid).child(otherUid).once();
    return a.snapshot.value == true;
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  // Fire-and-forget send: no pre-read round trips, so it's instant. RTDB's
  // local latency compensation echoes the new message to the stream immediately.
  // Returns null on success, or an error string.
  static Future<String?> sendMessage(String otherUid, String text) async {
    final t = text.trim();
    if (t.isEmpty) return null;
    try {
      final id = chatId(_uid, otherUid);
      await _db.ref().child('chats').child(id).push().set({
        'from': _uid,
        'text': t,
        'time': ServerValue.timestamp,
        'seen': false,
      });
      return null;
    } catch (e) {
      return 'Could not send. Check Firebase rules / connection.';
    }
  }

  static Stream<List<ChatMessage>> messages(String otherUid) {
    final id = chatId(_uid, otherUid);
    // Plain onValue (no orderByChild → no index requirement); we sort locally.
    return _db.ref().child('chats').child(id).onValue.map((ev) {
      final v = ev.snapshot.value;
      if (v is! Map) return <ChatMessage>[];
      final out = <ChatMessage>[];
      v.forEach((key, val) {
        if (val is! Map) return;
        out.add(ChatMessage(
          key.toString(),
          val['from']?.toString() ?? '',
          val['text']?.toString() ?? '',
          (val['time'] as int?) ?? 0,
          val['seen'] == true,
        ));
      });
      out.sort((a, b) => a.time.compareTo(b.time));
      return out;
    });
  }

  // Lightweight read-receipt: one multi-path write, only the given unseen keys.
  // No .once() read — the caller passes the ids it already has from the stream,
  // so this never causes a re-read storm.
  static Future<void> markRead(String otherUid, {Iterable<String> unseenIds = const []}) async {
    final id = chatId(_uid, otherUid);
    final updates = <String, dynamic>{
      'chatMeta/$id/lastRead/$_uid': ServerValue.timestamp,
    };
    for (final k in unseenIds) {
      updates['chats/$id/$k/seen'] = true;
    }
    try {
      await _db.ref().update(updates);
    } catch (_) {}
  }

  // Count of unread incoming messages in a specific chat.
  static Stream<int> unreadCount(String otherUid) {
    final id = chatId(_uid, otherUid);
    return _db.ref().child('chats').child(id).onValue.map((ev) {
      final v = ev.snapshot.value;
      if (v is! Map) return 0;
      int n = 0;
      v.forEach((_, val) {
        if (val is Map && val['from'] != _uid && val['seen'] != true) n++;
      });
      return n;
    });
  }

  // ── Presence ──────────────────────────────────────────────────────────────

  static Future<void> goOnline() async {
    final ref = _db.ref().child('presence').child(_uid);
    await ref.onDisconnect().set({'online': false, 'lastSeen': ServerValue.timestamp});
    await ref.set({'online': true, 'lastSeen': ServerValue.timestamp});
  }

  static Future<void> goOffline() async {
    await _db.ref().child('presence').child(_uid)
        .set({'online': false, 'lastSeen': ServerValue.timestamp});
  }

  static Stream<Map> presenceOf(String uid) {
    return _db.ref().child('presence').child(uid).onValue.map((ev) {
      final v = ev.snapshot.value;
      return (v is Map) ? v : const {};
    });
  }

  // ── Challenge ─────────────────────────────────────────────────────────────

  // Writes a challenge for `friendUid` pointing at an already-created gameKey.
  // Returns the challenge id (so the sender can cancel it later).
  static Future<String> sendChallenge(
      String friendUid, String gameType, String gameKey) async {
    String myName = 'Player';
    try {
      final u = await _db.ref().child('users').child(_uid).child('username').once();
      myName = u.snapshot.value?.toString() ?? 'Player';
    } catch (_) {}
    final ref = _db.ref().child('challenges').child(friendUid).push();
    await ref.set({
      'fromUid': _uid,
      'fromName': myName,
      'gameType': gameType,
      'gameKey': gameKey,
      'time': ServerValue.timestamp,
    });
    return ref.key!;
  }

  // Sender-side cancel: removes the challenge from the recipient's node.
  static Future<void> cancelSentChallenge(String friendUid, String challengeId) async {
    await _db.ref().child('challenges').child(friendUid).child(challengeId).remove();
  }

  static Stream<List<Challenge>> incomingChallenges() {
    return _db.ref().child('challenges').child(_uid).onValue.map((ev) {
      final v = ev.snapshot.value;
      if (v is! Map) return <Challenge>[];
      final out = <Challenge>[];
      v.forEach((key, val) {
        if (val is! Map) return;
        out.add(Challenge(
          key.toString(),
          val['fromUid']?.toString() ?? '',
          val['fromName']?.toString() ?? 'Player',
          val['gameType']?.toString() ?? 'xo',
          val['gameKey']?.toString() ?? '',
          (val['time'] as int?) ?? 0,
        ));
      });
      out.sort((a, b) => b.time.compareTo(a.time));
      return out;
    });
  }

  static Future<void> removeChallenge(String challengeId) async {
    await _db.ref().child('challenges').child(_uid).child(challengeId).remove();
  }

  // ── Phase B scaffold (real push, NOT active) ───────────────────────────────
  // TODO(Blaze): when Firebase billing is upgraded to Blaze:
  //   1) add `firebase_messaging` to pubspec,
  //   2) call registerFcmToken() after login,
  //   3) `firebase init functions` + deploy an RTDB onCreate trigger on
  //      friendRequests/{toUid}/{fromUid}, chats/{chatId}/{msgId},
  //      challenges/{toUid}/{id} that reads fcmTokens/{toUid} and sends FCM.
  // Until then this is a no-op so the rest of the app stays billing-free.
  static Future<void> registerFcmToken(String token) async {
    if (token.isEmpty) return;
    await _db.ref().child('fcmTokens').child(_uid).set(token);
  }
}
