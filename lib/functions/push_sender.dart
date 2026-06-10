import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// ════════════════════════════════════════════════════════════════════════════
// PushSender — fires a WhatsApp-style push by calling our free Cloudflare Worker
// (see /cloudflare/worker.js). No Blaze / Cloud Functions needed.
//
// The app sends only: { toUid, type, body?, data? } plus the caller's Firebase
// ID token (so the Worker can verify the sender and block spam). The Worker
// reads the recipient's FCM token, looks up the sender's name, and delivers the
// push via FCM HTTP v1. Fire-and-forget — never blocks or throws into the UI.
//
// SET THIS after deploying the Worker (Cloudflare gives you the URL):
const String kPushEndpoint = 'https://chillzone-push.lakshaymadaan376.workers.dev';
// ════════════════════════════════════════════════════════════════════════════

class PushSender {
  /// Send a push to [toUid]. [type] is 'friend_request' | 'challenge' | 'chat'.
  /// [body] is optional (the Worker builds a sensible default per type).
  static Future<void> notify({
    required String toUid,
    required String type,
    String? body,
    Map<String, String>? data,
  }) async {
    if (kPushEndpoint.isEmpty) return; // not configured yet → no-op
    if (toUid.isEmpty) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken();
      if (idToken == null) return;

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final req = await client.postUrl(Uri.parse(kPushEndpoint));
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      req.add(utf8.encode(jsonEncode({
        'toUid': toUid,
        'type': type,
        if (body != null) 'body': body,
        if (data != null) 'data': data,
      })));
      final resp = await req.close();
      await resp.drain();
      client.close();
    } catch (e) {
      if (kDebugMode) debugPrint('PushSender.notify error: $e');
    }
  }
}
