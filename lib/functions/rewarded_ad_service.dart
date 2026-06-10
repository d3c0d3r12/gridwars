import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

import '../helpers/constant.dart';

/// Reusable rewarded-video-ad flow, extracted from the inline logic in
/// shop.dart. Supports Google (AdMob) with a Unity Ads fallback, and enforces
/// the per-day cap stored at `adLimit/{uid}/{ddmmyyyy}`.
///
/// Usage:
///   RewardedAdService.preload();
///   await RewardedAdService.showForReward(onReward: () => grantSomething());
class RewardedAdService {
  static RewardedAd? _ad;
  static bool _loading = false;

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static String _today() {
    final d = DateTime.now();
    return '${d.day}${d.month}${d.year}';
  }

  static String _unityPlacement() {
    if (Platform.isAndroid) return 'Rewarded_Android';
    if (Platform.isIOS) return 'Rewarded_iOS';
    return '';
  }

  /// Preloads a Google rewarded ad (no-op for Unity, which loads on demand).
  static void preload() {
    if (!wantGoogleAd || _ad != null || _loading) return;
    _loading = true;
    MobileAds.instance.updateRequestConfiguration(RequestConfiguration());
    RewardedAd.load(
      adUnitId: rewardedAdID,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (err) {
          _ad = null;
          _loading = false;
          debugPrint('RewardedAdService load failed: $err');
        },
      ),
    );
  }

  /// True if the user is under the daily ad cap. Initializes today's counter to
  /// 0 on first call of the day.
  static Future<bool> _underDailyLimit() async {
    if (_uid.isEmpty) return true; // no account → don't block
    try {
      final ref = FirebaseDatabase.instance
          .ref()
          .child('adLimit')
          .child(_uid)
          .child(_today());
      final snap = await ref.once();
      final val = snap.snapshot.value;
      if (val == null) {
        await ref.set(0);
        return true;
      }
      return (int.tryParse(val.toString()) ?? 0) < adLimit;
    } catch (e) {
      debugPrint('RewardedAdService limit check failed: $e');
      return true;
    }
  }

  static Future<void> _bumpDailyCount() async {
    if (_uid.isEmpty) return;
    try {
      final ref = FirebaseDatabase.instance
          .ref()
          .child('adLimit')
          .child(_uid)
          .child(_today());
      final snap = await ref.once();
      final count = int.tryParse(snap.snapshot.value?.toString() ?? '0') ?? 0;
      await ref.set(count + 1);
    } catch (e) {
      debugPrint('RewardedAdService bump failed: $e');
    }
  }

  /// Shows a rewarded ad and fires [onReward] once if the user earns it.
  ///
  /// Returns:
  ///   - false with reason 'limit' if the daily cap is reached
  ///   - false with reason 'unavailable' if no ad could be shown
  ///   - true if an ad was shown (reward fires via the callback)
  static Future<RewardResult> showForReward(
      {required VoidCallback onReward}) async {
    if (!await _underDailyLimit()) {
      return RewardResult(false, 'limit');
    }

    if (wantGoogleAd) {
      final ad = _ad;
      if (ad == null) {
        preload();
        return RewardResult(false, 'unavailable');
      }
      _ad = null; // consumed
      var rewarded = false;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (a) {
          a.dispose();
          preload();
        },
        onAdFailedToShowFullScreenContent: (a, e) {
          a.dispose();
          preload();
        },
      );
      ad.show(onUserEarnedReward: (a, reward) async {
        if (rewarded) return;
        rewarded = true;
        onReward();
        await _bumpDailyCount();
      });
      return RewardResult(true, 'shown');
    } else {
      // Unity fallback: load-then-show on demand.
      final placement = _unityPlacement();
      var rewarded = false;
      try {
        UnityAds.load(
          placementId: placement,
          onComplete: (_) {
            UnityAds.showVideoAd(
              placementId: placement,
              onComplete: (_) async {
                if (rewarded) return;
                rewarded = true;
                onReward();
                await _bumpDailyCount();
              },
              onFailed: (p, e, m) => debugPrint('Unity rewarded failed: $m'),
              onStart: (_) {},
              onClick: (_) {},
              onSkipped: (_) {},
            );
          },
          onFailed: (p, e, m) => debugPrint('Unity rewarded load failed: $m'),
        );
        return RewardResult(true, 'shown');
      } catch (e) {
        debugPrint('Unity rewarded error: $e');
        return RewardResult(false, 'unavailable');
      }
    }
  }
}

class RewardResult {
  final bool shown;
  final String reason; // 'shown' | 'limit' | 'unavailable'
  RewardResult(this.shown, this.reason);
}
