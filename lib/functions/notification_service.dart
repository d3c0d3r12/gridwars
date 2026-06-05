import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

// Phase A: in-app / foreground notifications + badge counts (no billing, no FCM).
// A single global instance is started once at home-screen level. It exposes
// ValueNotifiers for badges and fires in-app banners (via an injected callback)
// when a NEW friend request / challenge / message arrives while the app is open.
//
// Phase B (later, when Firebase Blaze is enabled): real background push.
// See FriendService.registerFcmToken() + the documented Cloud Function plan.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _db = FirebaseDatabase.instance;

  // Badge counts — listen anywhere via ValueListenableBuilder.
  final ValueNotifier<int> requestCount = ValueNotifier(0);
  final ValueNotifier<int> challengeCount = ValueNotifier(0);
  final ValueNotifier<int> unreadTotal = ValueNotifier(0);

  // Combined badge for the Profile button (any pending social activity).
  final ValueNotifier<int> totalBadge = ValueNotifier(0);

  StreamSubscription? _reqSub, _chalSub, _friendsSub;
  // Per-friend unread listeners (keyed by friend uid).
  final Map<String, StreamSubscription> _unreadSubs = {};
  final Map<String, int> _unreadByFriend = {};
  bool _started = false;

  // First-load baseline so existing items don't all fire as "new" banners.
  bool _reqPrimed = false, _chalPrimed = false;
  final Set<String> _knownReq = {};
  final Set<String> _knownChal = {};

  // Banner sink — set by the home screen so we can show an in-app message.
  void Function(String message)? onBanner;

  void start() {
    if (_started) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _started = true;

    // ── Friend requests ──
    _reqSub = _db.ref().child('friendRequests').child(uid).onValue.listen((ev) {
      final v = ev.snapshot.value;
      final map = (v is Map) ? v : const {};
      requestCount.value = map.length;
      _recompute();

      if (!_reqPrimed) {
        _reqPrimed = true;
        _knownReq.addAll(map.keys.map((e) => e.toString()));
        return;
      }
      for (final e in map.entries) {
        final id = e.key.toString();
        if (_knownReq.add(id)) {
          final name = (e.value is Map) ? (e.value['fromName']?.toString() ?? 'Someone') : 'Someone';
          onBanner?.call('$name sent you a friend request');
        }
      }
      _knownReq.retainWhere((k) => map.containsKey(k));
    });

    // ── Challenges ──
    _chalSub = _db.ref().child('challenges').child(uid).onValue.listen((ev) {
      final v = ev.snapshot.value;
      final map = (v is Map) ? v : const {};
      challengeCount.value = map.length;
      _recompute();

      if (!_chalPrimed) {
        _chalPrimed = true;
        _knownChal.addAll(map.keys.map((e) => e.toString()));
        return;
      }
      for (final e in map.entries) {
        final id = e.key.toString();
        if (_knownChal.add(id)) {
          final m = (e.value is Map) ? e.value as Map : const {};
          onBanner?.call('${m['fromName'] ?? 'Someone'} challenged you to a game!');
        }
      }
      _knownChal.retainWhere((k) => map.containsKey(k));
    });

    // ── Unread message total ──
    // Reading the whole /chats root is blocked by rules (read is per-chatId),
    // so we fan out per friend: watch each friend's chat node (allowed) and sum.
    _friendsSub = _db.ref().child('friends').child(uid).onValue.listen((ev) {
      final v = ev.snapshot.value;
      final friendUids = (v is Map)
          ? v.keys.map((e) => e.toString()).toSet()
          : <String>{};

      // Remove listeners for friends no longer present.
      for (final old in _unreadSubs.keys.toList()) {
        if (!friendUids.contains(old)) {
          _unreadSubs.remove(old)?.cancel();
          _unreadByFriend.remove(old);
        }
      }
      // Add listeners for new friends.
      for (final fUid in friendUids) {
        if (_unreadSubs.containsKey(fUid)) continue;
        final cid = uid.compareTo(fUid) < 0 ? '${uid}__$fUid' : '${fUid}__$uid';
        _unreadSubs[fUid] = _db.ref().child('chats').child(cid).onValue.listen((cev) {
          final m = cev.snapshot.value;
          int n = 0;
          if (m is Map) {
            m.forEach((_, msg) {
              if (msg is Map && msg['from'] != uid && msg['seen'] != true) n++;
            });
          }
          _unreadByFriend[fUid] = n;
          unreadTotal.value = _unreadByFriend.values.fold(0, (s, x) => s + x);
          _recompute();
        });
      }
    });
  }

  void _recompute() {
    totalBadge.value = requestCount.value + challengeCount.value + unreadTotal.value;
  }

  void stop() {
    _reqSub?.cancel();
    _chalSub?.cancel();
    _friendsSub?.cancel();
    for (final s in _unreadSubs.values) {
      s.cancel();
    }
    _unreadSubs.clear();
    _unreadByFriend.clear();
    _reqSub = _chalSub = _friendsSub = null;
    _started = false;
    _reqPrimed = _chalPrimed = false;
    _knownReq.clear();
    _knownChal.clear();
    requestCount.value = 0;
    challengeCount.value = 0;
    unreadTotal.value = 0;
    totalBadge.value = 0;
  }
}
