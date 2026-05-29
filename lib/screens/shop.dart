import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inapp_purchase/flutter_inapp_purchase.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../helpers/string.dart';
import '../helpers/utils.dart';
import '../functions/advertisement.dart';
import '../functions/gameHistory.dart';
import 'splash.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        music.play(click);
      },
      child: const Scaffold(
        body: ShopActivity(),
      ),
    );
  }
}

class ShopActivity extends StatefulWidget {
  const ShopActivity({super.key});

  @override
  _ShopActivityState createState() => _ShopActivityState();
}

class _ShopActivityState extends State<ShopActivity> {
  StreamSubscription? _purchaseUpdatedSubscription;
  StreamSubscription? _purchaseErrorSubscription;
  StreamSubscription? _conectionSubscription;
  late int curItem;

  final List<String> _productLists = Platform.isAndroid
      ? [
          '100_coins',
          '500_coins',
          '1000_coins',
          '2000_coins',
          '5000_coins',
          '10000_coins',
        ]
      : [
          '100_coins',
          '500_coins',
          '1000_coins',
          '2000_coins',
          '5000_coins',
          '10000_coins',
        ];

  List<Product> _items = [];

  bool isLoaded = false;
  RewardedAd? ins;

  @override
  void initState() {
    super.initState();

    Advertisement.loadAd();
    initPlatformState();

    getADDisplay().then((value) async {
      if (value) {
        createRewardedAd();
      }
    });
    deleteOldAdLimitData();
  }

  @override
  void dispose() {
    FlutterInappPurchase.instance.endConnection();

    _conectionSubscription!.cancel();
    _conectionSubscription = null;
    _purchaseUpdatedSubscription!.cancel();
    _purchaseUpdatedSubscription = null;
    _purchaseErrorSubscription!.cancel();
    _purchaseErrorSubscription = null;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: bgColor,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            getSvgImage(imageName: 'shop_icon', imageColor: inkColor),
            const SizedBox(width: 2),
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(utils.getTranslated(context, "shop"),
                  style: TextStyle(color: inkColor, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        iconTheme: IconThemeData(color: inkColor),
      ),
      body: Container(
        color: bgColor,
        height: double.maxFinite,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 40),
          child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 0, mainAxisSpacing: 0),
              // itemCount: coinList.length,
              itemCount: _items.length + 1,
              itemBuilder: (_, i) {
                if (i == _items.length) {
                  return watchAdAndEarn();
                } else {
                  return item(i);
                }
              }),
        ),
      ),
    );
  }

  Widget item(int i) {
    return InkWell(
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              getSvgImage(imageName: coinList[i].icon, height: 60),
              const SizedBox(
                height: 5,
              ),
              Text(
                _items[i]
                    .title
                    .toString()
                    .split('(')
                    .first
                    .trim(), //TO remove package name from product name
                style: TextStyle(color: primaryColor),
                maxLines: 1,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              Text(
                _items[i].displayPrice,
                style:
                    TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                maxLines: 1,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              )
            ],
          ),
        ),
      ),
      onTap: () async {
        curItem = i;
        this._requestPurchase(_items[i]);
      },
    );
  }

  Widget watchAdAndEarn() {
    return InkWell(
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              getSvgImage(
                imageName: 'watchad_icon',
                height: 70,
              ),
              const SizedBox(
                height: 5,
              ),
              Text(
                watchEarn,
                style: TextStyle(color: primaryColor),
                maxLines: 1,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      onTap: () async {
        if (wantGoogleAd) {
          await getADDisplay().then((value) async {
            if (value) {
              if (ins != null) {
                if (wantGoogleAd) {
                  ins!.show(onUserEarnedReward: (ad, reward) async {
                    await updateCoins(adRewardAmount, "Watched ad");

                    FirebaseDatabase db = FirebaseDatabase.instance;
                    var today = time();
                    DatabaseEvent once = await db
                        .ref()
                        .child("adLimit")
                        .child(FirebaseAuth.instance.currentUser!.uid)
                        .child(today)
                        .once();

                    var count = int.parse(once.snapshot.value.toString());

                    await db
                        .ref()
                        .child("adLimit")
                        .child(FirebaseAuth.instance.currentUser!.uid)
                        .update({"$today": count + 1});
                  });
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor: secondarySelectedColor,
                    content: Text(
                      utils.getTranslated(context, "adNotLoaded"),
                      style: TextStyle(
                          color: primaryColor, fontWeight: FontWeight.bold),
                    )));
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: secondarySelectedColor,
                  content: Text(
                    utils.getTranslated(context, "youReachedAtTodaysAdLimit"),
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold),
                  )));
            }
          });
        } else {
          await getADDisplay().then((value) async {
            if (value) {
              try {
                UnityAds.load(
                    placementId: unityRewardAdPlacement(),
                    onComplete: (placementId) {
                      UnityAds.showVideoAd(
                          placementId: unityRewardAdPlacement(),
                          onComplete: (placementId) async {
                            await updateCoins(adRewardAmount, "Watched ad");

                            FirebaseDatabase db = FirebaseDatabase.instance;
                            var today = time();
                            DatabaseEvent once = await db
                                .ref()
                                .child("adLimit")
                                .child(FirebaseAuth.instance.currentUser!.uid)
                                .child(today)
                                .once();

                            var count =
                                int.parse(once.snapshot.value.toString());

                            await db
                                .ref()
                                .child("adLimit")
                                .child(FirebaseAuth.instance.currentUser!.uid)
                                .update({"$today": count + 1});

                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                backgroundColor: secondarySelectedColor,
                                content: Text(
                                  utils.getTranslated(
                                      context, "rewardAmountAddedSuccessfully"),
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold),
                                )));
                          },
                          // loadAd(),
                          onFailed: (placementId, error, message) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                backgroundColor: secondarySelectedColor,
                                content: Text(
                                  "error while loading ad",
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold),
                                )));
                          },
                          onStart: (placementId) =>
                              debugPrint('Video Ad $placementId started'),
                          onClick: (placementId) =>
                              debugPrint('Video Ad $placementId click'),
                          onSkipped: (placementId) {});
                    },
                    onFailed: (placementId, error, message) =>
                        debugPrint('Failed to load Unity ad $message'));
              } catch (e) {}
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: secondarySelectedColor,
                  content: Text(
                    utils.getTranslated(context, "youReachedAtTodaysAdLimit"),
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold),
                  )));
            }
          });
        }
      },
    );
  }

  purchased(coins) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Center(
              child: Text(
                utils.getTranslated(context, "congratulations"),
                style: TextStyle(color: white),
              ),
            ),
            backgroundColor: primaryColor,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(20.0))),
            content: Text("You got $coins",
                textAlign: TextAlign.center, style: TextStyle(color: white)),
          );
        });
  }

  updateCoins(int reward, String status) async {
    FirebaseDatabase fb = FirebaseDatabase.instance;
    DatabaseEvent coin = await fb
        .ref()
        .child("users")
        .child(FirebaseAuth.instance.currentUser!.uid)
        .child("coin")
        .once();
    var newCoin = int.parse(coin.snapshot.value.toString()) + reward;
    fb
        .ref()
        .child("users")
        .child(FirebaseAuth.instance.currentUser!.uid)
        .update({"coin": newCoin});

    History().update(
        date: DateTime.now().toString(),
        gotcoin: reward,
        status: status,
        type: "AD",
        gameid: "notfind",
        oppornentId: "",
        uid: FirebaseAuth.instance.currentUser!.uid);
  }

  createRewardedAd() async {
    if (wantGoogleAd) {
      MobileAds.instance.updateRequestConfiguration(RequestConfiguration());
      RewardedAd.load(
          adUnitId: rewardedAdID,
          request: AdRequest(),
          rewardedAdLoadCallback: RewardedAdLoadCallback(
            onAdLoaded: (RewardedAd ad) {
              setState(() {
                isLoaded = true;
                ins = ad;
              });
            },
            onAdFailedToLoad: (LoadAdError error) {
              debugPrint("failed to load $error");
            },
          ));
    }
  }

  String time() {
    DateTime date = DateTime.now();
    int year = date.year;
    int month = date.month;
    int day = date.day;
    return "$day$month$year";
  }

  //method for daily ad limit
  Future<bool> getADDisplay() async {
    FirebaseDatabase db = FirebaseDatabase.instance;

    var today = time();
    DatabaseEvent once = await db
        .ref()
        .child("adLimit")
        .child(FirebaseAuth.instance.currentUser!.uid)
        .child(today)
        .once();

    var count = once.snapshot.value.toString();

    if (count == "null") {
      await db
          .ref()
          .child("adLimit")
          .child(FirebaseAuth.instance.currentUser!.uid)
          .update({"$today": 0});

      return true;
    } else {
      int count = int.parse(once.snapshot.value.toString());

      if (count < adLimit) {
        return true;
      } else {
        return false;
      }
    }
  }

  String unityRewardAdPlacement() {
    if (Platform.isAndroid) {
      return "Rewarded_Android";
    }
    if (Platform.isIOS) {
      return "Rewarded_iOS";
    }
    return "";
  }

  void _requestPurchase(Product item) {
    FlutterInappPurchase.instance.requestPurchaseWithBuilder(build: (builder) {
      builder.ios.sku = item.id;
      builder.android.skus = [item.id];
      builder.type = ProductQueryType.InApp;
    });
  }

  Future _getProduct() async {
    final List<dynamic> result = await FlutterInappPurchase.instance
        .fetchProducts(skus: _productLists, type: ProductQueryType.InApp);

    List<Product> items = result.cast<Product>().toList();

    try {
      items.sort((a, b) => (a.price ?? 0).compareTo(b.price ?? 0));
    } catch (_) {}

    setState(() {
      this._items = items;
    });
  }

  Future<void> initPlatformState() async {
    // prepare
    await FlutterInappPurchase.instance.initConnection();
    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    _conectionSubscription =
        FlutterInappPurchase.instance.connectionUpdated.listen((connected) {
      debugPrint('connected: $connected');
    });

    _purchaseUpdatedSubscription = FlutterInappPurchase.instance.purchaseUpdated
        .listen((productItem) async {
      debugPrint('purchase-updated: $productItem');

      if (productItem != null) {
        int coin = int.parse(_items[curItem].title.split(" ")[0]);
        await updateCoins(coin, "Coin Purchased");

        if (mounted) {
          purchased(_items[curItem].title);
        }
        await FlutterInappPurchase.instance
            .finishTransaction(purchase: productItem);
      }
    }, onDone: () {
      _purchaseUpdatedSubscription!.cancel();
    });

    _purchaseErrorSubscription =
        FlutterInappPurchase.instance.purchaseError.listen((purchaseError) {
      debugPrint('purchase-error: $purchaseError');
    });

    // Fetch In-App Products
    _getProduct();
  }

  void deleteOldAdLimitData() async {
    Map? adValues = new Map();
    FirebaseDatabase db = FirebaseDatabase.instance;
    var today = time();
    DatabaseEvent once = await db
        .ref()
        .child("adLimit")
        .child(FirebaseAuth.instance.currentUser!.uid)
        .once();

    if (once.snapshot.value != null) {
      adValues = once.snapshot.value as Map;
      adValues.forEach((key, value) {
        if (today != key) {
          FirebaseDatabase.instance
              .ref()
              .child("adLimit")
              .child(FirebaseAuth.instance.currentUser!.uid)
              .child(key)
              .remove();
        }
      });
    }
  }
}
