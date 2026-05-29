import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../helpers/color.dart';
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

class _AuthOptionsScreenState extends State<Login>
    with SingleTickerProviderStateMixin {
  Timer? t;
  Utils localValue = Utils();

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    checkUserLoggedIn();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    t?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Subtle radial gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.6, -0.4),
                  radius: 1.0,
                  colors: [
                    xColor.withValues(alpha: 0.07),
                    bgColor,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.7, 0.5),
                  radius: 0.9,
                  colors: [
                    oColor.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: size.height * 0.1),

                      // Brand
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontFamily: 'DISPLATTER',
                            fontSize: 40,
                            letterSpacing: 4,
                          ),
                          children: [
                            TextSpan(
                                text: 'X',
                                style: TextStyle(color: xColor)),
                            TextSpan(
                                text: 'O',
                                style: TextStyle(color: oColor)),
                            TextSpan(
                                text: ' BATTLE',
                                style: TextStyle(color: inkColor)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        utils.getTranslated(
                            context, "CalculateEveryMove"),
                        style: TextStyle(
                          fontSize: 13.5,
                          color: ink2Color,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),

                      SizedBox(height: size.height * 0.08),

                      // Auth buttons
                      if (Platform.isIOS) ...[
                        _AuthBtn(
                          icon: getSvgImage(
                              imageName: 'apple_icon',
                              width: 20,
                              height: 20,
                              imageColor: inkColor),
                          label:
                              utils.getTranslated(context, "signInApple"),
                          onTap: () =>
                              Auth.signin(context, false, "IOS"),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _AuthBtn(
                        icon: getSvgImage(
                            imageName: "google_logo",
                            width: 20,
                            height: 20),
                        label:
                            utils.getTranslated(context, "signInGoogle"),
                        onTap: () => Auth.signin(context, false,
                            "Android",
                            email: "", password: ""),
                      ),
                      const SizedBox(height: 12),
                      _AuthBtn(
                        icon: Icon(Icons.email_outlined,
                            color: Colors.white, size: 20),
                        label:
                            utils.getTranslated(context, "signInEmail"),
                        onTap: () async {
                          await Navigator.of(context).push(
                            CupertinoPageRoute(
                                builder: (_) => LoginWithEmail()),
                          );
                        },
                        isPrimary: true,
                      ),

                      const Spacer(),

                      // Guest
                      Column(
                        children: [
                          Row(children: [
                            Expanded(
                                child: Divider(color: lineColor)),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14),
                              child: Text('or',
                                  style: TextStyle(
                                      color: ink3Color, fontSize: 13)),
                            ),
                            Expanded(
                                child: Divider(color: lineColor)),
                          ]),
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: () => Auth.anonymousSignin(context),
                            child: Text(
                              'Continue as Guest',
                              style: TextStyle(
                                color: ink2Color,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor:
                                    ink3Color,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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

// ── Auth button ────────────────────────────────────────────────────────────────

class _AuthBtn extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _AuthBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isPrimary ? xColor : surfaceColor,
          border: isPrimary ? null : Border.all(color: lineColor),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: xColor.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [shadowSm],
        ),
        child: Row(
          children: [
            const SizedBox(width: 20),
            icon,
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isPrimary ? Colors.white : inkColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }
}
