import 'dart:io';

import 'package:xobattle/helpers/constant.dart';
import 'package:xobattle/helpers/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class Advertisement {
  static loadAd() {
    if (wantGoogleAd) {
      InterstitialAd.load(
          adUnitId: interstitialAdID,
          request: AdRequest(),
          adLoadCallback: InterstitialAdLoadCallback(
              onAdLoaded: (InterstitialAd ad) {
                interstitialAd = ad;
                Advertisement.showAd();
              },
              onAdFailedToLoad: (LoadAdError err) {}));
    } else {
      UnityAds.load(
          placementId: Advertisement().unityInterstitialPlacement(),
          onComplete: (placementId) {
            showAd();
          },
          onFailed: (placementId, error, message) => null);
    }
  }

  static showAd() {
    if (wantGoogleAd) {
      if (interstitialAd != null) {
        interstitialAd!.show().whenComplete(() => music.play(backMusic));
      } else {
        loadAd();
      }
    } else {
      UnityAds.showVideoAd(
          placementId: Advertisement().unityInterstitialPlacement(),
          onComplete: (placementId) {
            music.play(backMusic);
          },
          onFailed: (placementId, error, message) =>
              debugPrint('Video Ad $placementId failed: $error $message'),
          onStart: (placementId) => debugPrint('Video Ad $placementId started'),
          onClick: (placementId) => debugPrint('Video Ad $placementId click'),
          onSkipped: (placementId) {});
    }
  }

  String unityInterstitialPlacement() {
    if (Platform.isAndroid) {
      return "Interstitial_Android";
    }
    if (Platform.isIOS) {
      return "Interstitial_iOS";
    }
    return "";
  }
}
