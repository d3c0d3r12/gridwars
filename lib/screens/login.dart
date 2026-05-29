import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../helpers/color.dart';
import '../widgets/xo_logo.dart';
import '../helpers/constant.dart';
import '../helpers/utils.dart';
import '../functions/authentication.dart';
import 'login_with_email.dart';
import 'splash.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  _AuthOptionsScreenState createState() => _AuthOptionsScreenState();
}

class _AuthOptionsScreenState extends State<Login> {
  Timer? t;

  Utils localValue = Utils();

  @override
  void initState() {
    super.initState();
    checkUserLoggedIn();
  }

  @override
  void dispose() {
    super.dispose();
    t?.cancel();
  }

  Widget _buildAuthButton({
    required Widget icon,
    required String label,
    required VoidCallback onPressed,
    bool isAccent = false,
  }) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: isAccent
            ? LinearGradient(
                colors: [secondarySelectedColor, Color(0xFFFF8800)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: isAccent ? null : white.withValues(alpha: 0.08),
        border: isAccent
            ? null
            : Border.all(color: white.withValues(alpha: 0.18), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          splashColor: secondarySelectedColor.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                icon,
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isAccent ? primaryColor : white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: utils.gradBack(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              alignment: Alignment.bottomCenter,
              height: size.height * 0.38,
              child: const XOBattleLogo(size: 140),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: size.height * 0.05),
              child: Text(
                utils.getTranslated(context, "CalculateEveryMove"),
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium!
                    .copyWith(fontFamily: 'DISPLATTER', color: white),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        if (Platform.isIOS) ...[
                          _buildAuthButton(
                            icon: getSvgImage(imageName: 'apple_icon', width: 22, height: 22),
                            label: utils.getTranslated(context, "signInApple"),
                            onPressed: () => Auth.signin(context, false, "IOS"),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _buildAuthButton(
                          icon: getSvgImage(imageName: "google_logo", width: 22, height: 22),
                          label: utils.getTranslated(context, "signInGoogle"),
                          onPressed: () => Auth.signin(context, false, "Android", email: "", password: ""),
                        ),
                        const SizedBox(height: 12),
                        _buildAuthButton(
                          icon: Icon(Icons.email_outlined, color: secondarySelectedColor, size: 22),
                          label: utils.getTranslated(context, "signInEmail"),
                          onPressed: () async {
                            await Navigator.of(context).push(
                              CupertinoPageRoute(builder: (_) => LoginWithEmail()),
                            );
                          },
                          isAccent: true,
                        ),
                      ],
                    ),
                    // Guest play — bottom of screen, always visible
                    Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: Column(
                        children: [
                          Row(children: [
                            Expanded(child: Divider(color: white.withValues(alpha: 0.15))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('or', style: TextStyle(color: white.withValues(alpha: 0.4), fontSize: 13)),
                            ),
                            Expanded(child: Divider(color: white.withValues(alpha: 0.15))),
                          ]),
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: () => Auth.anonymousSignin(context),
                            child: Text(
                              'Continue as Guest',
                              style: TextStyle(
                                color: white.withValues(alpha: 0.55),
                                fontSize: 13,
                                decoration: TextDecoration.underline,
                                decorationColor: white.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void checkUserLoggedIn() async {
    bool value = await utils.getUserLoggedIn("isLoggedIn");
    if (value) {
      utils.replaceScreenAfter(context, "/home");
    }
  }
}
