import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'friend_service.dart';

// ════════════════════════════════════════════════════════════════════════════
// PushService — WhatsApp-style background push (FCM).
//
// Flow: a Cloud Function (see /functions/index.js) fires when a new
// friendRequest / challenge / chat message lands in RTDB, reads the recipient's
// fcmTokens/{uid}, and asks FCM to deliver a notification to that device. FCM
// pushes it to the phone even when the app is closed.
//
// This service handles the CLIENT side:
//   • ask notification permission (iOS + Android 13+),
//   • get the device FCM token and save it to fcmTokens/{uid},
//   • keep it fresh on refresh,
//   • show a heads-up banner when a push arrives while the app is FOREGROUND
//     (the OS shows it automatically when the app is in the background).
//
// Sending FCM costs nothing; only the Cloud Function trigger uses the (free-
// tier) Blaze quota. See registerFcmToken() in FriendService.
// ════════════════════════════════════════════════════════════════════════════

// Must be a top-level function. Runs in a separate isolate when a push arrives
// while the app is terminated/background. The OS draws the notification itself
// from the `notification` payload, so we only need this to exist.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op: the system tray renders the notification from its payload.
}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _fln = FlutterLocalNotificationsPlugin();
  bool _started = false;
  StreamSubscription<String>? _tokenSub;

  static const _channel = AndroidNotificationChannel(
    'chillzone_high',
    'Chill Zone',
    description: 'Friend requests, challenges and messages',
    importance: Importance.high,
  );

  /// Call once after login (uid available). Safe to call again — it no-ops.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      // 1) Permission (Android 13+ shows the system dialog; iOS too).
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // 2) Local-notifications plugin (used to draw FOREGROUND pushes).
      const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initIOS = DarwinInitializationSettings();
      await _fln.initialize(
        const InitializationSettings(android: initAndroid, iOS: initIOS),
      );
      await _fln
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
      // iOS: let foreground pushes show natively too.
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3) Register this device's token, and keep it fresh.
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(token);
      _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);

      // 4) Foreground messages → draw a heads-up banner ourselves.
      FirebaseMessaging.onMessage.listen(_showForeground);
    } catch (e) {
      if (kDebugMode) debugPrint('PushService.start error: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      await FriendService.registerFcmToken(token);
    } catch (_) {}
  }

  void _showForeground(RemoteMessage m) {
    final n = m.notification;
    final title = n?.title ?? m.data['title'] ?? 'Chill Zone';
    final body = n?.body ?? m.data['body'] ?? '';
    if (body.isEmpty && (n == null)) return;
    _fln.show(
      m.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'chillzone_high',
          'Chill Zone',
          channelDescription: 'Friend requests, challenges and messages',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Remove this device's token on logout so it stops receiving pushes.
  Future<void> clearToken() async {
    try {
      _tokenSub?.cancel();
      _tokenSub = null;
      _started = false;
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }
}
