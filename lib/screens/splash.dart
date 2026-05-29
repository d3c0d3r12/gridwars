import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../helpers/utils.dart';
import '../widgets/xo_logo.dart';

Utils utils = Utils();

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late AnimationController _textCtrl;
  late AnimationController _pulseCtrl;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _textOpacity;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.4, curve: Curves.easeIn)),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _logoCtrl.forward().then((_) => _textCtrl.forward());
    _navigate();
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _pulseCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: utils.gradBack(),
        child: Stack(
          children: [
            // Decorative background X & O glyphs
            _glyph('X', size.width * 0.06, size.height * 0.08, 72, 0.055),
            _glyph('O', size.width * 0.78, size.height * 0.06, 90, 0.045),
            _glyph('X', size.width * 0.80, size.height * 0.78, 60, 0.055),
            _glyph('O', size.width * 0.06, size.height * 0.76, 78, 0.045),
            _glyph('X', size.width * 0.88, size.height * 0.42, 50, 0.04),
            _glyph('O', size.width * 0.02, size.height * 0.46, 55, 0.04),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo + pulsing glow ring layered in a Stack
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulsing glow ring behind logo
                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, child) => Transform.scale(
                            scale: _pulseScale.value,
                            child: child,
                          ),
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: secondarySelectedColor.withValues(alpha: 0.4),
                                  blurRadius: 60,
                                  spreadRadius: 18,
                                ),
                                BoxShadow(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                                  blurRadius: 80,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Logo centred on glow
                        AnimatedBuilder(
                          animation: _logoCtrl,
                          builder: (_, __) => Opacity(
                            opacity: _logoOpacity.value,
                            child: Transform.scale(
                              scale: _logoScale.value,
                              child: const XOBattleLogo(size: 150),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // App name + tagline
                  AnimatedBuilder(
                    animation: _textCtrl,
                    builder: (_, __) => SlideTransition(
                      position: _textSlide,
                      child: Opacity(
                        opacity: _textOpacity.value,
                        child: Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [white, secondarySelectedColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              child: Text(
                                appName,
                                style: Theme.of(context).textTheme.displaySmall!.copyWith(
                                  fontFamily: 'DISPLATTER',
                                  color: white,
                                  letterSpacing: 5,
                                  shadows: [
                                    Shadow(
                                      color: secondarySelectedColor.withValues(alpha: 0.9),
                                      blurRadius: 24,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: secondarySelectedColor.withValues(alpha: 0.45),
                                  width: 1,
                                ),
                                color: secondarySelectedColor.withValues(alpha: 0.08),
                              ),
                              child: Text(
                                'Calculate Every Move',
                                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                                  color: secondarySelectedColor,
                                  letterSpacing: 1.8,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom loading dots
            Positioned(
              bottom: size.height * 0.08,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _textCtrl,
                builder: (_, __) => Opacity(
                  opacity: _textOpacity.value,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PulseDot(delay: 0),
                      _PulseDot(delay: 200),
                      _PulseDot(delay: 400),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glyph(String text, double x, double y, double size, double opacity) {
    return Positioned(
      left: x,
      top: y,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'DISPLATTER',
          fontSize: size,
          color: white.withValues(alpha: opacity),
        ),
      ),
    );
  }

  void _navigate() async {
    await MobileAds.instance.initialize();
    await UnityAds.init(
      gameId: gameID,
      testMode: true,
      onComplete: () => debugPrint('Unity init complete'),
      onFailed: (e, msg) => debugPrint('Unity init failed: $e $msg'),
    );
    music.play(backMusic);

    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    // Firebase Auth persists the session across app restarts automatically.
    // If currentUser is non-null the session is still valid — go straight home.
    // Fall back to the SP flag for edge cases (e.g. first-run after install).
    final firebaseUser = FirebaseAuth.instance.currentUser;
    bool loggedIn = firebaseUser != null;
    if (!loggedIn) {
      loggedIn = await utils.getUserLoggedIn("isLoggedIn");
    } else {
      // Keep SP in sync so the fallback path is also correct.
      await utils.setUserLoggedIn("isLoggedIn", true);
    }
    if (!mounted) return;
    utils.replaceScreenAfter(context, loggedIn ? "/home" : "/authscreen");
  }
}

class _PulseDot extends StatefulWidget {
  final int delay;
  const _PulseDot({required this.delay});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: secondarySelectedColor.withValues(alpha: _anim.value),
        ),
      ),
    );
  }
}
