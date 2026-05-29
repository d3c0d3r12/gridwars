import 'dart:async';

import 'package:xobattle/helpers/demo_localization.dart';
import 'package:xobattle/helpers/string.dart';
import 'package:xobattle/functions/playbgm.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'color.dart';
import 'constant.dart';

Music music = Music();
InterstitialAd? interstitialAd;

class Utils {
  final List<List<int>> winningConditionFour = [
    [0, 1, 2, 3],
    [4, 5, 6, 7],
    [8, 9, 10, 11],
    [12, 13, 14, 15],
    [0, 4, 8, 12],
    [1, 5, 9, 13],
    [2, 6, 10, 14],
    [3, 7, 11, 15],
    [0, 5, 10, 15],
    [3, 6, 9, 12],
  ];

  final List<List<int>> winningCondition = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6]
  ];

  final List<List<int>> winningConditionFive = [
    // Horizontal wins
    [0, 1, 2, 3, 4], // Row 1
    [5, 6, 7, 8, 9], // Row 2
    [10, 11, 12, 13, 14], // Row 3
    [15, 16, 17, 18, 19], // Row 4
    [20, 21, 22, 23, 24], // Row 5

    // Vertical wins
    [0, 5, 10, 15, 20], // Column 1
    [1, 6, 11, 16, 21], // Column 2
    [2, 7, 12, 17, 22], // Column 3
    [3, 8, 13, 18, 23], // Column 4
    [4, 9, 14, 19, 24], // Column 5

    // Diagonal wins
    [0, 6, 12, 18, 24], // Diagonal from top-left to bottom-right
    [4, 8, 12, 16, 20] // Diagonal from top-right to bottom-left
  ];

  // Method to generate the game buttons map based on matrix size
  Map<int, Map<String, String>> generateGameButtons(int size) {
    int totalButtons = size * size;
    return {
      for (var i = 0; i < totalButtons; i++)
        i: {
          "state": "",
          "player": "0",
        }
    };
  }

  // Predefined maps for 3x3, 4x4, and 5x5 matrices
  Map<int, Map<String, String>> get gameButtons => generateGameButtons(3);

  Map<int, Map<String, String>> get gameButtonsFour => generateGameButtons(4);

  Map<int, Map<String, String>> get gameButtonsFive => generateGameButtons(5);

  Locale _locale(String languageCode) {
    switch (languageCode) {
      case "en":
        return Locale("en", 'US');
      case "es":
        return Locale("es", "ES");
      case "hi":
        return Locale("hi", "IN");
      case "ar":
        return Locale("ar", "DZ");
      case "ru":
        return Locale("ru", "RU");
      case "ja":
        return Locale("ja", "JP");
      case "de":
        return Locale("de", "DE");
      default:
        return Locale("en", 'US');
    }
  }

  List<List<T>> generateBoardSublist<T>(List<T> list, int board) {
    ///this will create sublist which is required for AI
    List<List<T>> sublist = [];

    for (var i = 0; i < list.length; i++) {
      if (i % board == 0) {
        List<T> nestedEntry = list.sublist(i, i + board);
        sublist.add(nestedEntry);
      }
    }
    return sublist;
  }

  ///This function removes the extra data and makes it correct list for AI class
  List<String> filterBoard(List currentBoardState) {
    return List.from(currentBoardState.map(
      (e) {
        if (e != 'X' && e != 'O') {
          return '';
        }
        return e;
      },
    ).toList());
  }

  String getTranslated(BuildContext context, String key) {
    return DemoLocalization.of(context)!.translate(key) ?? key;
  }

  Future<Locale> setLocale(String languageCode) async {
    SharedPreferences _prefs = await SharedPreferences.getInstance();
    await _prefs.setString(LAGUAGE_CODE, languageCode);
    return _locale(languageCode);
  }

  Future<Locale> getLocale() async {
    SharedPreferences _prefs = await SharedPreferences.getInstance();
    String languageCode = _prefs.getString(LAGUAGE_CODE) ?? "en";
    return _locale(languageCode);
  }

  Future getSfxValue() async {
    SharedPreferences _sp = await SharedPreferences.getInstance();

    return _sp.getBool(appName + "SFX-ENABLED") ?? false;
  }

  Future setSfxValue() async {
    SharedPreferences _sp = await SharedPreferences.getInstance();

    _sp.setBool(appName + "SFX-ENABLED", byDefaultSoundOn);
  }

  Future setSkinValue(String key, String value) async {
    SharedPreferences _sp = await SharedPreferences.getInstance();

    _sp.setString(key, value);
  }

  Future getSkinValue(String key) async {
    SharedPreferences _sp = await SharedPreferences.getInstance();

    return _sp.getString(key) ?? "";
  }

  Future setUserLoggedIn(String key, bool value) async {
    SharedPreferences _sp = await SharedPreferences.getInstance();

    _sp.setBool(key, value);
  }

  Future getUserLoggedIn(String key) async {
    SharedPreferences _sp = await SharedPreferences.getInstance();

    return _sp.getBool(key) ?? false;
  }

  replaceScreenAfter(BuildContext context, String route) {
    Navigator.of(context).pushReplacementNamed(route);
  }

  Widget showCircularProgress(bool _isProgress, Color color) {
    if (_isProgress) {
      return Center(
          child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ));
    }
    return Container(
      height: 0.0,
      width: 0.0,
    );
  }

  alert(
      {required context,
      required bool isMultipleAction,
      required String defaultActionButtonName,
      required Widget title,
      required Widget content,
      required void Function() onTapActionButton,
      required bool barrierDismissible,
      List? multipleAction}) {
    showDialog(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (context) => PopScope(
              canPop: false,
              child: AlertDialog(
                backgroundColor: surfaceColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(22.0)),
                  side: BorderSide(color: lineColor, width: 1),
                ),
                title: title,
                content: content,
                actions: multipleAction as List<Widget>?,
              ),
            ));
  }

  limitChar(String value, [int? q]) {
    var useQ = q != null ? q : 20;
    var st = value.length > useQ ? "..." : "";

    var r = value.substring(0, value.length > useQ ? useQ : value.length);
    return r + st;
  }

  static final BoxDecoration _cachedGradBack = BoxDecoration(
    color: bgColor,
  );

  BoxDecoration gradBack() => _cachedGradBack;

  String? validatePass(String value, String? msg1, String? msg2) {
    if (value.isEmpty) {
      return msg1;
    } else if (value.length <= 5) {
      return msg2;
    } else {
      return null;
    }
  }

  String? validateEmail(String value, String? msg1, String? msg2) {
    if (value.isEmpty) {
      return msg1;
    } else if (!RegExp(
            r"[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)"
            r"*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+"
            r"[a-z0-9](?:[a-z0-9-]*[a-z0-9])?")
        .hasMatch(value)) {
      return msg2;
    } else {
      return null;
    }
  }

  returnImage(int i, Map buttons, String? imagex, String? imageo) {
    if (buttons[i]["player"] == "1" && buttons[i]["player"] != "0") {
      return imagex;
    } else if (buttons[i]["player"] == "2" && buttons[i]["player"] != "0") {
      return imageo;
    }
  }

  setSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      backgroundColor: inkColor,
      elevation: 4.0,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }
}
