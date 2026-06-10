import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

import '../helpers/color.dart';
import '../helpers/constant.dart';
import '../helpers/utils.dart';
import '../widgets/xo_logo.dart';
import 'admin_panel.dart';

Utils utils = Utils();

// Brand accents (same in both themes).
const _cyan = Color(0xFF00C2E0);
const _indigo = Color(0xFF6366F1);
// Dark-mode base tones.
const _deep1 = Color(0xFF0A0B16);
const _deep2 = Color(0xFF15183A);

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late AnimationController _textCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _ringCtrl;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _textOpacity;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 5000))
      ..repeat();

    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _logoCtrl,
          curve: const Interval(0.0, 0.35, curve: Curves.easeIn)),
    );
    _textSlide =
        Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn),
    );
    _pulseScale = Tween<double>(begin: 0.94, end: 1.12).animate(
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
    _ringCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);

    // Follow the system theme: dark splash in dark mode, light otherwise.
    final bool dark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final size = MediaQuery.of(context).size;

    // Theme-resolved tones.
    final List<Color> baseGrad = dark
        ? const [_deep1, _deep2, _deep1]
        : const [Colors.white, Color(0xFFEFF1F8), Colors.white];
    final Color scaffoldBg = dark ? _deep1 : bgColor;
    final Brightness iconBrightness = dark ? Brightness.light : Brightness.dark;
    final List<Color> plateGrad = dark
        ? const [Color(0xFF1E2148), Color(0xFF0E1024)]
        : const [Colors.white, Color(0xFFF1F3FA)];
    final Color plateBorder =
        dark ? Colors.white.withValues(alpha: 0.10) : lineColor;
    final Color plateShadow =
        Colors.black.withValues(alpha: dark ? 0.5 : 0.12);
    final Color wordTop = dark ? Colors.white : inkColor;
    final Color wordBottom = dark ? _cyan : _indigo;
    final double indigoGlow = dark ? 0.40 : 0.18;
    final double cyanGlow = dark ? 0.22 : 0.10;
    final double glyphBoost = dark ? 0.0 : 0.04;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: iconBrightness,
      systemNavigationBarColor: scaffoldBg,
      systemNavigationBarIconBrightness: iconBrightness,
    ));

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          // Rich diagonal gradient base
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: baseGrad,
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // Soft brand glow behind the logo
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.25),
                  radius: 0.95,
                  colors: [
                    _indigo.withValues(alpha: indigoGlow),
                    _cyan.withValues(alpha: cyanGlow),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Decorative background glyphs (faint)
          _glyph('X', size.width * 0.06, size.height * 0.09, 76, _indigo, 0.10 + glyphBoost),
          _glyph('O', size.width * 0.75, size.height * 0.07, 92, _cyan, 0.09 + glyphBoost),
          _glyph('X', size.width * 0.80, size.height * 0.80, 62, _indigo, 0.08 + glyphBoost),
          _glyph('O', size.width * 0.05, size.height * 0.78, 80, _cyan, 0.07 + glyphBoost),
          _glyph('X', size.width * 0.88, size.height * 0.44, 50, _indigo, 0.07 + glyphBoost),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with rotating accent ring + glow
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsing soft glow
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, child) => Transform.scale(
                            scale: _pulseScale.value, child: child),
                        child: Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _indigo.withValues(
                                    alpha: dark ? 0.40 : 0.22),
                                blurRadius: 70,
                                spreadRadius: 10,
                              ),
                              BoxShadow(
                                color: _cyan.withValues(
                                    alpha: dark ? 0.22 : 0.14),
                                blurRadius: 90,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Rotating sweep ring
                      AnimatedBuilder(
                        animation: _ringCtrl,
                        builder: (_, __) => Transform.rotate(
                          angle: _ringCtrl.value * 2 * math.pi,
                          child: CustomPaint(
                            size: const Size(196, 196),
                            painter: _RingPainter(),
                          ),
                        ),
                      ),

                      // Counter-rotating inner ring
                      AnimatedBuilder(
                        animation: _ringCtrl,
                        builder: (_, __) => Transform.rotate(
                          angle: -_ringCtrl.value * 2 * math.pi,
                          child: CustomPaint(
                            size: const Size(150, 150),
                            painter: _RingPainter(thin: true),
                          ),
                        ),
                      ),

                      // Glassy logo plate
                      AnimatedBuilder(
                        animation: _logoCtrl,
                        builder: (_, __) => Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: Container(
                              width: 126,
                              height: 126,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: plateGrad,
                                ),
                                border:
                                    Border.all(color: plateBorder, width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: plateShadow,
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child:
                                  const Center(child: XOBattleLogo(size: 92)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 38),

                // Wordmark + tagline
                AnimatedBuilder(
                  animation: _textCtrl,
                  builder: (_, __) => SlideTransition(
                    position: _textSlide,
                    child: Opacity(
                      opacity: _textOpacity.value,
                      child: Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (rect) => LinearGradient(
                              colors: [wordTop, wordBottom],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ).createShader(rect),
                            child: const Column(
                              children: [
                                Text('CHILL',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w900,
                                      fontSize: 38,
                                      color: Colors.white,
                                      letterSpacing: 6,
                                      height: 1.0,
                                    )),
                                Text('ZONE',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w900,
                                      fontSize: 30,
                                      color: Colors.white,
                                      letterSpacing: 12,
                                      height: 1.1,
                                    )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 7),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: _cyan.withValues(alpha: 0.45),
                                  width: 1),
                              color: _cyan.withValues(
                                  alpha: dark ? 0.08 : 0.10),
                            ),
                            child: Text(
                              'GAME ON.  CHILL ON.',
                              style: TextStyle(
                                color: dark ? _cyan : const Color(0xFF0090A8),
                                letterSpacing: 2.5,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
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

          // Sleek loading bar
          Positioned(
            bottom: size.height * 0.085,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _textCtrl,
              builder: (_, __) => Opacity(
                opacity: _textOpacity.value,
                child: Center(child: _LoadingBar(dark: dark)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glyph(String text, double x, double y, double size, Color col,
      double opacity) {
    return Positioned(
      left: x,
      top: y,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'DISPLATTER',
          fontSize: size,
          color: col.withValues(alpha: opacity),
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

    final firebaseUser = FirebaseAuth.instance.currentUser;
    bool loggedIn = firebaseUser != null;
    if (!loggedIn) {
      loggedIn = await utils.getUserLoggedIn("isLoggedIn");
    } else {
      await utils.setUserLoggedIn("isLoggedIn", true);
    }
    if (!mounted) return;

    // Ban check: if logged in, verify user is not banned before reaching home.
    if (loggedIn && firebaseUser != null) {
      try {
        final snap = await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(firebaseUser.uid)
            .once();
        final data = snap.snapshot.value as Map?;
        if (data != null && data['banned'] == true) {
          final reason = data['banReason']?.toString() ?? '';
          if (mounted) {
            Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => BannedScreen(reason: reason)));
          }
          return;
        }
      } catch (_) {}
    }

    utils.replaceScreenAfter(context, loggedIn ? "/home" : "/authscreen");
  }
}

// Rotating accent ring drawn with a sweep gradient + a leading dot.
class _RingPainter extends CustomPainter {
  final bool thin;
  _RingPainter({this.thin = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - (thin ? 1 : 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thin ? 1.5 : 3
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          (thin ? _indigo : _cyan).withValues(alpha: 0.0),
          (thin ? _indigo : _cyan).withValues(alpha: 0.9),
          (thin ? _cyan : _indigo),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 0.72, 0.9, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);

    if (!thin) {
      final dot = Paint()..color = _cyan;
      canvas.drawCircle(Offset(center.dx + radius, center.dy), 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Indeterminate gradient loading bar.
class _LoadingBar extends StatefulWidget {
  final bool dark;
  const _LoadingBar({required this.dark});

  @override
  State<_LoadingBar> createState() => _LoadingBarState();
}

class _LoadingBarState extends State<_LoadingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300))
    ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const trackW = 170.0;
    const segW = 70.0;
    final trackColor = (widget.dark ? Colors.white : Colors.black)
        .withValues(alpha: widget.dark ? 0.08 : 0.06);
    return SizedBox(
      width: trackW,
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          children: [
            Container(color: trackColor),
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final dx = -segW + (_ctrl.value * (trackW + segW));
                return Positioned(
                  left: dx,
                  top: 0,
                  bottom: 0,
                  width: segW,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        colors: [
                          Colors.transparent,
                          _cyan,
                          _indigo,
                          Colors.transparent
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
