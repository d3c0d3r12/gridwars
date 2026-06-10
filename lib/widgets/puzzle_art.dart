import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Hand-drawn-style vector art for Brain Tricks puzzles. Every object is drawn
/// in code (no image files) in a consistent "notebook sketch" look: dark rounded
/// stroke + flat pastel fills. Call [puzzleArt] with a prop name.
Widget puzzleArt(String name, {required double size, Color? tint}) {
  return SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _PropPainter(name, tint)),
  );
}

/// Full-bleed scene backdrop (wall/floor, sky, paper…).
Widget puzzleBackground(String name) {
  return Positioned.fill(child: CustomPaint(painter: _BgPainter(name)));
}

const Color _ink = Color(0xFF33373D);

class _PropPainter extends CustomPainter {
  final String name;
  final Color? tint;
  _PropPainter(this.name, this.tint);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = (s * 0.045).clamp(2.0, 7.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Paint fill(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.fill;

    switch (name) {
      case 'kettle':
        _kettle(canvas, s, stroke, fill);
        break;
      case 'coffeemaker':
        _coffeemaker(canvas, s, stroke, fill);
        break;
      case 'plug':
        _plug(canvas, s, stroke, fill);
        break;
      case 'socket':
        _socket(canvas, s, stroke, fill);
        break;
      case 'screwdriver':
        _screwdriver(canvas, s, stroke, fill);
        break;
      case 'hammer':
        _hammer(canvas, s, stroke, fill);
        break;
      case 'scissors':
        _scissors(canvas, s, stroke, fill);
        break;
      case 'fireplace':
        _fireplace(canvas, s, stroke, fill);
        break;
      case 'logs':
        _logs(canvas, s, stroke, fill);
        break;
      case 'fire':
      case 'flame':
        _flame(canvas, s, stroke, fill);
        break;
      case 'match':
        _match(canvas, s, stroke, fill);
        break;
      case 'window':
        _window(canvas, s, stroke, fill, broken: false);
        break;
      case 'windowBroken':
        _window(canvas, s, stroke, fill, broken: true);
        break;
      case 'curtain':
        _curtain(canvas, s, stroke, fill);
        break;
      case 'sun':
        _sun(canvas, s, stroke, fill);
        break;
      case 'cloud':
        _cloud(canvas, s, stroke, fill);
        break;
      case 'snow':
      case 'snowflake':
        _snowflake(canvas, s, stroke);
        break;
      case 'icecream':
        _icecream(canvas, s, stroke, fill);
        break;
      case 'person':
      case 'kid':
        _person(canvas, s, stroke, fill, cold: false);
        break;
      case 'personCold':
        _person(canvas, s, stroke, fill, cold: true);
        break;
      case 'baby':
        _baby(canvas, s, stroke, fill);
        break;
      case 'cat':
        _cat(canvas, s, stroke, fill);
        break;
      case 'dog':
        _dog(canvas, s, stroke, fill);
        break;
      case 'fish':
        _fish(canvas, s, stroke, fill);
        break;
      case 'bone':
        _bone(canvas, s, stroke, fill);
        break;
      case 'carrot':
        _carrot(canvas, s, stroke, fill);
        break;
      case 'key':
        _key(canvas, s, stroke, fill);
        break;
      case 'lock':
        _lock(canvas, s, stroke, fill);
        break;
      case 'candle':
        _candle(canvas, s, stroke, fill);
        break;
      case 'glass':
      case 'water':
        _glass(canvas, s, stroke, fill);
        break;
      case 'bucket':
        _bucket(canvas, s, stroke, fill);
        break;
      case 'door':
        _door(canvas, s, stroke, fill);
        break;
      case 'bed':
        _bed(canvas, s, stroke, fill);
        break;
      case 'bulb':
        _bulb(canvas, s, stroke, fill, on: false);
        break;
      case 'bulbOn':
        _bulb(canvas, s, stroke, fill, on: true);
        break;
      case 'star':
        _star(canvas, s, stroke, fill);
        break;
      case 'heart':
        _heart(canvas, s, stroke, fill);
        break;
      case 'ball':
        _ball(canvas, s, stroke, fill);
        break;
      case 'apple':
        _apple(canvas, s, stroke, fill);
        break;
      case 'tree':
        _tree(canvas, s, stroke, fill);
        break;
      case 'car':
        _car(canvas, s, stroke, fill);
        break;
      case 'balloon':
        _balloon(canvas, s, stroke, fill);
        break;
      case 'gift':
        _gift(canvas, s, stroke, fill);
        break;
      case 'box':
        _box(canvas, s, stroke, fill);
        break;
      case 'rug':
        _rug(canvas, s, stroke, fill);
        break;
      case 'button':
        _button(canvas, s, stroke, fill);
        break;
      case 'switchOff':
        _switch(canvas, s, stroke, fill, on: false);
        break;
      case 'switchOn':
        _switch(canvas, s, stroke, fill, on: true);
        break;
      case 'cup':
        _cup(canvas, s, stroke, fill);
        break;
      case 'cheese':
        _cheese(canvas, s, stroke, fill);
        break;
      case 'moon':
        _moon(canvas, s, stroke, fill);
        break;
      case 'cabinet':
        _cabinet(canvas, s, stroke, fill);
        break;
      default:
        _unknown(canvas, s, stroke, fill);
    }
  }

  // ── prop drawings (drawn within an s×s box) ────────────────────────────────

  void _kettle(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .22, s * .3, s * .5, s * .5), Radius.circular(s * .1));
    c.drawRRect(body, f(tint ?? const Color(0xFFB0BEC5)));
    c.drawRRect(body, st);
    // spout
    final spout = Path()
      ..moveTo(s * .72, s * .42)
      ..lineTo(s * .9, s * .34)
      ..lineTo(s * .9, s * .46)
      ..lineTo(s * .72, s * .54)
      ..close();
    c.drawPath(spout, f(tint ?? const Color(0xFFB0BEC5)));
    c.drawPath(spout, st);
    // handle
    c.drawArc(Rect.fromLTWH(s * .3, s * .14, s * .34, s * .3), math.pi, math.pi,
        false, st);
    // lid knob
    c.drawCircle(Offset(s * .47, s * .28), s * .04, f(_ink));
  }

  void _coffeemaker(Canvas c, double s, Paint st, Paint Function(Color) f) {
    // base
    final base = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .2, s * .7, s * .6, s * .16),
        Radius.circular(s * .04));
    c.drawRRect(base, f(const Color(0xFF455A64)));
    c.drawRRect(base, st);
    _kettle(c, s * .82, st, f);
  }

  void _plug(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .3, s * .35, s * .4, s * .4), Radius.circular(s * .08));
    c.drawRRect(body, f(tint ?? const Color(0xFF37474F)));
    c.drawRRect(body, st);
    // prongs
    c.drawLine(Offset(s * .4, s * .35), Offset(s * .4, s * .18), st);
    c.drawLine(Offset(s * .6, s * .35), Offset(s * .6, s * .18), st);
    // cable
    final cable = Path()
      ..moveTo(s * .5, s * .75)
      ..quadraticBezierTo(s * .8, s * .85, s * .7, s * .98);
    c.drawPath(cable, st);
  }

  void _socket(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final plate = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .25, s * .25, s * .5, s * .5), Radius.circular(s * .1));
    c.drawRRect(plate, f(const Color(0xFFECEFF1)));
    c.drawRRect(plate, st);
    c.drawCircle(Offset(s * .42, s * .45), s * .035, f(_ink));
    c.drawCircle(Offset(s * .58, s * .45), s * .035, f(_ink));
    final mouth = Rect.fromCenter(
        center: Offset(s * .5, s * .6), width: s * .22, height: s * .06);
    c.drawArc(mouth, 0, math.pi, false, st);
  }

  void _screwdriver(Canvas c, double s, Paint st, Paint Function(Color) f) {
    // handle
    final h = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .15, s * .55, s * .3, s * .2),
        Radius.circular(s * .08));
    c.drawRRect(h, f(tint ?? const Color(0xFF2E7D32)));
    c.drawRRect(h, st);
    // shaft
    final shaft = Path()
      ..moveTo(s * .45, s * .6)
      ..lineTo(s * .8, s * .35)
      ..lineTo(s * .86, s * .42)
      ..lineTo(s * .5, s * .68)
      ..close();
    c.drawPath(shaft, f(const Color(0xFFB0BEC5)));
    c.drawPath(shaft, st);
  }

  void _hammer(Canvas c, double s, Paint st, Paint Function(Color) f) {
    // handle
    c.save();
    c.translate(s * .5, s * .5);
    c.rotate(-0.5);
    final handle = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, s * .18), width: s * .12, height: s * .5),
        Radius.circular(s * .04));
    c.drawRRect(handle, f(const Color(0xFF8D6E63)));
    c.drawRRect(handle, st);
    final head = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -s * .14), width: s * .5, height: s * .16),
        Radius.circular(s * .03));
    c.drawRRect(head, f(const Color(0xFF607D8B)));
    c.drawRRect(head, st);
    c.restore();
  }

  void _scissors(Canvas c, double s, Paint st, Paint Function(Color) f) {
    c.drawCircle(Offset(s * .3, s * .68), s * .1, f(tint ?? const Color(0xFFEF5350)));
    c.drawCircle(Offset(s * .3, s * .68), s * .1, st);
    c.drawCircle(Offset(s * .3, s * .68), s * .045, f(Colors.white));
    c.drawCircle(Offset(s * .5, s * .68), s * .1, f(tint ?? const Color(0xFFEF5350)));
    c.drawCircle(Offset(s * .5, s * .68), s * .1, st);
    c.drawCircle(Offset(s * .5, s * .68), s * .045, f(Colors.white));
    c.drawLine(Offset(s * .35, s * .6), Offset(s * .85, s * .2), st);
    c.drawLine(Offset(s * .45, s * .6), Offset(s * .85, s * .32), st);
  }

  void _fireplace(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final outer = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .12, s * .15, s * .76, s * .72),
        Radius.circular(s * .04));
    c.drawRRect(outer, f(const Color(0xFFBCAAA4)));
    c.drawRRect(outer, st);
    final mouth = Path()
      ..moveTo(s * .28, s * .85)
      ..lineTo(s * .28, s * .5)
      ..quadraticBezierTo(s * .5, s * .32, s * .72, s * .5)
      ..lineTo(s * .72, s * .85)
      ..close();
    c.drawPath(mouth, f(const Color(0xFF3E2723)));
    c.drawPath(mouth, st);
    // brick lines
    c.drawLine(Offset(s * .12, s * .32), Offset(s * .88, s * .32), st);
  }

  void _logs(Canvas c, double s, Paint st, Paint Function(Color) f) {
    for (int i = 0; i < 2; i++) {
      final y = s * (.45 + i * .22);
      final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(s * .15, y, s * .7, s * .16), Radius.circular(s * .08));
      c.drawRRect(r, f(const Color(0xFF8D6E63)));
      c.drawRRect(r, st);
      c.drawCircle(Offset(s * .2, y + s * .08), s * .05, f(const Color(0xFFD7CCC8)));
      c.drawCircle(Offset(s * .2, y + s * .08), s * .05, st);
    }
  }

  void _flame(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final p = Path()
      ..moveTo(s * .5, s * .15)
      ..quadraticBezierTo(s * .85, s * .5, s * .68, s * .8)
      ..quadraticBezierTo(s * .5, s * .95, s * .32, s * .8)
      ..quadraticBezierTo(s * .15, s * .5, s * .5, s * .15)
      ..close();
    c.drawPath(p, f(const Color(0xFFFF7043)));
    c.drawPath(p, st);
    final inner = Path()
      ..moveTo(s * .5, s * .42)
      ..quadraticBezierTo(s * .66, s * .6, s * .56, s * .78)
      ..quadraticBezierTo(s * .44, s * .82, s * .42, s * .66)
      ..quadraticBezierTo(s * .42, s * .52, s * .5, s * .42)
      ..close();
    c.drawPath(inner, f(const Color(0xFFFFCA28)));
  }

  void _match(Canvas c, double s, Paint st, Paint Function(Color) f) {
    c.drawLine(Offset(s * .25, s * .8), Offset(s * .7, s * .3), st..strokeWidth = s * .07);
    c.drawCircle(Offset(s * .74, s * .26), s * .1, f(const Color(0xFFEF5350)));
    c.drawCircle(Offset(s * .74, s * .26), s * .1, st..strokeWidth = (s * .045).clamp(2.0, 7.0));
  }

  void _window(Canvas c, double s, Paint st, Paint Function(Color) f,
      {required bool broken}) {
    final frame = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .18, s * .15, s * .64, s * .7), Radius.circular(s * .03));
    c.drawRRect(frame, f(broken ? const Color(0xFFCFD8DC) : const Color(0xFFB3E5FC)));
    c.drawRRect(frame, st);
    c.drawLine(Offset(s * .5, s * .15), Offset(s * .5, s * .85), st);
    c.drawLine(Offset(s * .18, s * .5), Offset(s * .82, s * .5), st);
    if (broken) {
      final cr = Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * .02;
      c.drawLine(Offset(s * .3, s * .25), Offset(s * .45, s * .45), cr);
      c.drawLine(Offset(s * .45, s * .45), Offset(s * .32, s * .6), cr);
      c.drawLine(Offset(s * .45, s * .45), Offset(s * .62, s * .58), cr);
      c.drawLine(Offset(s * .45, s * .45), Offset(s * .6, s * .3), cr);
    }
  }

  void _curtain(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final col = tint ?? const Color(0xFFEF9A9A);
    for (int i = 0; i < 4; i++) {
      final x = s * (.2 + i * .16);
      final p = Path()
        ..moveTo(x, s * .12)
        ..quadraticBezierTo(x + s * .1, s * .5, x, s * .88)
        ..lineTo(x + s * .14, s * .88)
        ..quadraticBezierTo(x + s * .04, s * .5, x + s * .14, s * .12)
        ..close();
      c.drawPath(p, f(col));
      c.drawPath(p, st);
    }
    c.drawLine(Offset(s * .12, s * .12), Offset(s * .88, s * .12), st);
  }

  void _sun(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final ray = Paint()
      ..color = const Color(0xFFFFB300)
      ..strokeWidth = s * .045
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      c.drawLine(
        Offset(s * .5 + math.cos(a) * s * .36, s * .5 + math.sin(a) * s * .36),
        Offset(s * .5 + math.cos(a) * s * .48, s * .5 + math.sin(a) * s * .48),
        ray,
      );
    }
    c.drawCircle(Offset(s * .5, s * .5), s * .26, f(const Color(0xFFFFCA28)));
    c.drawCircle(Offset(s * .5, s * .5), s * .26, st);
  }

  void _cloud(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final col = f(tint ?? const Color(0xFFECEFF1));
    c.drawCircle(Offset(s * .38, s * .55), s * .16, col);
    c.drawCircle(Offset(s * .58, s * .5), s * .2, col);
    c.drawCircle(Offset(s * .7, s * .58), s * .14, col);
    final base = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .3, s * .55, s * .45, s * .16), Radius.circular(s * .08));
    c.drawRRect(base, col);
  }

  void _snowflake(Canvas c, double s, Paint st) {
    st.strokeWidth = s * .04;
    for (int i = 0; i < 3; i++) {
      final a = i * math.pi / 3;
      c.drawLine(
        Offset(s * .5 - math.cos(a) * s * .35, s * .5 - math.sin(a) * s * .35),
        Offset(s * .5 + math.cos(a) * s * .35, s * .5 + math.sin(a) * s * .35),
        st..color = const Color(0xFF4FC3F7),
      );
    }
  }

  void _icecream(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final cone = Path()
      ..moveTo(s * .32, s * .5)
      ..lineTo(s * .68, s * .5)
      ..lineTo(s * .5, s * .92)
      ..close();
    c.drawPath(cone, f(const Color(0xFFD7A86E)));
    c.drawPath(cone, st);
    c.drawCircle(Offset(s * .5, s * .42), s * .2, f(tint ?? const Color(0xFFA1887F)));
    c.drawCircle(Offset(s * .5, s * .42), s * .2, st);
    c.drawCircle(Offset(s * .5, s * .26), s * .12, f(tint ?? const Color(0xFFA1887F)));
    c.drawCircle(Offset(s * .5, s * .26), s * .12, st);
  }

  void _person(Canvas c, double s, Paint st, Paint Function(Color) f,
      {required bool cold}) {
    final skin = cold ? const Color(0xFF90CAF9) : const Color(0xFFFFCC80);
    c.drawCircle(Offset(s * .5, s * .3), s * .16, f(skin));
    c.drawCircle(Offset(s * .5, s * .3), s * .16, st);
    final body = Path()
      ..moveTo(s * .3, s * .85)
      ..quadraticBezierTo(s * .5, s * .48, s * .7, s * .85)
      ..close();
    c.drawPath(body, f(tint ?? const Color(0xFF7E57C2)));
    c.drawPath(body, st);
    // eyes
    c.drawCircle(Offset(s * .44, s * .3), s * .02, f(_ink));
    c.drawCircle(Offset(s * .56, s * .3), s * .02, f(_ink));
    if (cold) {
      c.drawLine(Offset(s * .66, s * .2), Offset(s * .78, s * .12), st..strokeWidth = s * .02);
      c.drawLine(Offset(s * .72, s * .2), Offset(s * .78, s * .12), st);
    }
  }

  void _baby(Canvas c, double s, Paint st, Paint Function(Color) f) {
    c.drawCircle(Offset(s * .5, s * .45), s * .28, f(const Color(0xFFFFE0B2)));
    c.drawCircle(Offset(s * .5, s * .45), s * .28, st);
    c.drawCircle(Offset(s * .42, s * .45), s * .025, f(_ink));
    c.drawCircle(Offset(s * .58, s * .45), s * .025, f(_ink));
    c.drawArc(Rect.fromCircle(center: Offset(s * .5, s * .52), radius: s * .08), 0.2,
        math.pi - 0.4, false, st);
    // curl
    c.drawArc(Rect.fromCircle(center: Offset(s * .5, s * .2), radius: s * .05), 0,
        math.pi * 2, false, st);
  }

  void _cat(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final col = tint ?? const Color(0xFF9E9E9E);
    // ears
    final ears = Path()
      ..moveTo(s * .3, s * .4)..lineTo(s * .34, s * .18)..lineTo(s * .46, s * .32)
      ..moveTo(s * .7, s * .4)..lineTo(s * .66, s * .18)..lineTo(s * .54, s * .32);
    c.drawPath(ears, f(col));
    c.drawPath(ears, st);
    c.drawCircle(Offset(s * .5, s * .45), s * .24, f(col));
    c.drawCircle(Offset(s * .5, s * .45), s * .24, st);
    c.drawCircle(Offset(s * .42, s * .42), s * .03, f(_ink));
    c.drawCircle(Offset(s * .58, s * .42), s * .03, f(_ink));
    c.drawLine(Offset(s * .5, s * .5), Offset(s * .5, s * .55), st);
    // whiskers
    c.drawLine(Offset(s * .5, s * .54), Offset(s * .3, s * .5), st);
    c.drawLine(Offset(s * .5, s * .54), Offset(s * .7, s * .5), st);
    // body
    final body = Path()
      ..moveTo(s * .3, s * .85)..quadraticBezierTo(s * .5, s * .6, s * .7, s * .85)..close();
    c.drawPath(body, f(col));
    c.drawPath(body, st);
  }

  void _dog(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final col = tint ?? const Color(0xFFBCAAA4);
    // ears
    c.drawOval(Rect.fromLTWH(s * .22, s * .3, s * .14, s * .3), f(const Color(0xFF8D6E63)));
    c.drawOval(Rect.fromLTWH(s * .64, s * .3, s * .14, s * .3), f(const Color(0xFF8D6E63)));
    c.drawCircle(Offset(s * .5, s * .45), s * .24, f(col));
    c.drawCircle(Offset(s * .5, s * .45), s * .24, st);
    c.drawCircle(Offset(s * .43, s * .42), s * .03, f(_ink));
    c.drawCircle(Offset(s * .57, s * .42), s * .03, f(_ink));
    c.drawCircle(Offset(s * .5, s * .52), s * .04, f(_ink));
    final body = Path()
      ..moveTo(s * .3, s * .85)..quadraticBezierTo(s * .5, s * .6, s * .7, s * .85)..close();
    c.drawPath(body, f(col));
    c.drawPath(body, st);
  }

  void _fish(Canvas c, double s, Paint st, Paint Function(Color) f) {
    c.drawOval(Rect.fromLTWH(s * .18, s * .35, s * .5, s * .3), f(tint ?? const Color(0xFF4FC3F7)));
    c.drawOval(Rect.fromLTWH(s * .18, s * .35, s * .5, s * .3), st);
    final tail = Path()
      ..moveTo(s * .66, s * .5)..lineTo(s * .9, s * .35)..lineTo(s * .9, s * .65)..close();
    c.drawPath(tail, f(tint ?? const Color(0xFF4FC3F7)));
    c.drawPath(tail, st);
    c.drawCircle(Offset(s * .32, s * .47), s * .03, f(_ink));
  }

  void _bone(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final col = f(const Color(0xFFFFF8E1));
    c.drawCircle(Offset(s * .28, s * .35), s * .1, col);
    c.drawCircle(Offset(s * .28, s * .55), s * .1, col);
    c.drawCircle(Offset(s * .72, s * .35), s * .1, col);
    c.drawCircle(Offset(s * .72, s * .55), s * .1, col);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s * .28, s * .38, s * .44, s * .14), Radius.circular(s * .07)),
        col);
  }

  void _carrot(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final body = Path()
      ..moveTo(s * .35, s * .4)..lineTo(s * .65, s * .4)..lineTo(s * .5, s * .9)..close();
    c.drawPath(body, f(const Color(0xFFFF8A65)));
    c.drawPath(body, st);
    final leaf = Paint()..color = const Color(0xFF66BB6A)..strokeWidth = s * .05..strokeCap = StrokeCap.round;
    c.drawLine(Offset(s * .5, s * .4), Offset(s * .4, s * .2), leaf);
    c.drawLine(Offset(s * .5, s * .4), Offset(s * .5, s * .15), leaf);
    c.drawLine(Offset(s * .5, s * .4), Offset(s * .6, s * .2), leaf);
  }

  void _key(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final col = tint ?? const Color(0xFFFFB300);
    c.drawCircle(Offset(s * .32, s * .4), s * .14, f(col));
    c.drawCircle(Offset(s * .32, s * .4), s * .14, st);
    c.drawCircle(Offset(s * .32, s * .4), s * .05, f(Colors.white));
    c.drawLine(Offset(s * .44, s * .5), Offset(s * .78, s * .76), st..strokeWidth = s * .06);
    c.drawLine(Offset(s * .7, s * .68), Offset(s * .78, s * .6), st);
    c.drawLine(Offset(s * .78, s * .76), Offset(s * .86, s * .68), st);
  }

  void _lock(Canvas c, double s, Paint st, Paint Function(Color) f) {
    c.drawArc(Rect.fromLTWH(s * .32, s * .2, s * .36, s * .4), math.pi, math.pi, false,
        st..strokeWidth = s * .06);
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .26, s * .42, s * .48, s * .4), Radius.circular(s * .06));
    c.drawRRect(body, f(tint ?? const Color(0xFFFFB300)));
    c.drawRRect(body, st..strokeWidth = (s * .045).clamp(2.0, 7.0));
    c.drawCircle(Offset(s * .5, s * .6), s * .04, f(_ink));
  }

  void _candle(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .38, s * .35, s * .24, s * .5), Radius.circular(s * .03));
    c.drawRRect(body, f(tint ?? const Color(0xFFFFF59D)));
    c.drawRRect(body, st);
    c.drawLine(Offset(s * .5, s * .35), Offset(s * .5, s * .28), st);
    final fl = Path()
      ..moveTo(s * .5, s * .12)..quadraticBezierTo(s * .6, s * .24, s * .5, s * .3)
      ..quadraticBezierTo(s * .4, s * .24, s * .5, s * .12)..close();
    c.drawPath(fl, f(const Color(0xFFFFA726)));
  }

  void _glass(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final g = Path()
      ..moveTo(s * .32, s * .25)..lineTo(s * .68, s * .25)..lineTo(s * .62, s * .82)
      ..lineTo(s * .38, s * .82)..close();
    c.drawPath(g, f(const Color(0xFFB3E5FC)));
    c.drawPath(g, st);
    final water = Path()
      ..moveTo(s * .36, s * .5)..lineTo(s * .64, s * .5)..lineTo(s * .62, s * .82)
      ..lineTo(s * .38, s * .82)..close();
    c.drawPath(water, f(const Color(0xFF4FC3F7)));
  }

  void _bucket(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final b = Path()
      ..moveTo(s * .26, s * .35)..lineTo(s * .74, s * .35)..lineTo(s * .66, s * .85)
      ..lineTo(s * .34, s * .85)..close();
    c.drawPath(b, f(tint ?? const Color(0xFF90A4AE)));
    c.drawPath(b, st);
    c.drawArc(Rect.fromLTWH(s * .26, s * .15, s * .48, s * .4), math.pi, math.pi, false, st);
  }

  void _door(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final d = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .28, s * .12, s * .44, s * .76), Radius.circular(s * .04));
    c.drawRRect(d, f(tint ?? const Color(0xFF8D6E63)));
    c.drawRRect(d, st);
    c.drawCircle(Offset(s * .64, s * .5), s * .035, f(const Color(0xFFFFD54F)));
  }

  void _bed(Canvas c, double s, Paint st, Paint Function(Color) f) {
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s * .14, s * .45, s * .72, s * .3), Radius.circular(s * .04)),
        f(const Color(0xFFCE93D8)));
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s * .14, s * .45, s * .72, s * .3), Radius.circular(s * .04)),
        st);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s * .2, s * .38, s * .22, s * .14), Radius.circular(s * .04)),
        f(Colors.white));
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s * .2, s * .38, s * .22, s * .14), Radius.circular(s * .04)),
        st);
    c.drawLine(Offset(s * .14, s * .75), Offset(s * .14, s * .88), st);
    c.drawLine(Offset(s * .86, s * .75), Offset(s * .86, s * .88), st);
  }

  void _bulb(Canvas c, double s, Paint st, Paint Function(Color) f, {required bool on}) {
    c.drawCircle(Offset(s * .5, s * .42), s * .26, f(on ? const Color(0xFFFFEE58) : const Color(0xFFE0E0E0)));
    c.drawCircle(Offset(s * .5, s * .42), s * .26, st);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s * .4, s * .64, s * .2, s * .18), Radius.circular(s * .02)),
        f(const Color(0xFFB0BEC5)));
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s * .4, s * .64, s * .2, s * .18), Radius.circular(s * .02)),
        st);
    if (on) {
      final ray = Paint()..color = const Color(0xFFFFB300)..strokeWidth = s * .035..strokeCap = StrokeCap.round;
      for (int i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        c.drawLine(Offset(s * .5 + math.cos(a) * s * .3, s * .42 + math.sin(a) * s * .3),
            Offset(s * .5 + math.cos(a) * s * .4, s * .42 + math.sin(a) * s * .4), ray);
      }
    }
  }

  void _star(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final p = Path();
    for (int i = 0; i < 5; i++) {
      final ao = -math.pi / 2 + i * 2 * math.pi / 5;
      final ai = ao + math.pi / 5;
      final po = Offset(s * .5 + math.cos(ao) * s * .4, s * .5 + math.sin(ao) * s * .4);
      final pi2 = Offset(s * .5 + math.cos(ai) * s * .17, s * .5 + math.sin(ai) * s * .17);
      if (i == 0) p.moveTo(po.dx, po.dy); else p.lineTo(po.dx, po.dy);
      p.lineTo(pi2.dx, pi2.dy);
    }
    p.close();
    c.drawPath(p, f(tint ?? const Color(0xFFFFCA28)));
    c.drawPath(p, st);
  }

  void _heart(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final p = Path()
      ..moveTo(s * .5, s * .8)
      ..cubicTo(s * .05, s * .5, s * .25, s * .15, s * .5, s * .38)
      ..cubicTo(s * .75, s * .15, s * .95, s * .5, s * .5, s * .8)
      ..close();
    c.drawPath(p, f(tint ?? const Color(0xFFEF5350)));
    c.drawPath(p, st);
  }

  void _ball(Canvas c, double s, Paint st, Paint Function(Color) f) {
    c.drawCircle(Offset(s * .5, s * .5), s * .35, f(tint ?? const Color(0xFFFF7043)));
    c.drawCircle(Offset(s * .5, s * .5), s * .35, st);
    c.drawLine(Offset(s * .15, s * .5), Offset(s * .85, s * .5), st);
  }

  void _apple(Canvas c, double s, Paint st, Paint Function(Color) f) {
    c.drawCircle(Offset(s * .38, s * .55), s * .22, f(tint ?? const Color(0xFFEF5350)));
    c.drawCircle(Offset(s * .62, s * .55), s * .22, f(tint ?? const Color(0xFFEF5350)));
    c.drawCircle(Offset(s * .5, s * .55), s * .26, f(tint ?? const Color(0xFFEF5350)));
    c.drawCircle(Offset(s * .5, s * .55), s * .26, st);
    c.drawLine(Offset(s * .5, s * .32), Offset(s * .54, s * .18), st);
  }

  void _tree(Canvas c, double s, Paint st, Paint Function(Color) f) {
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s * .44, s * .55, s * .12, s * .35), Radius.circular(s * .02)),
        f(const Color(0xFF8D6E63)));
    c.drawCircle(Offset(s * .5, s * .4), s * .28, f(const Color(0xFF66BB6A)));
    c.drawCircle(Offset(s * .5, s * .4), s * .28, st);
  }

  void _car(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .12, s * .45, s * .76, s * .25), Radius.circular(s * .06));
    c.drawRRect(body, f(tint ?? const Color(0xFF42A5F5)));
    c.drawRRect(body, st);
    final top = Path()
      ..moveTo(s * .28, s * .45)..lineTo(s * .38, s * .28)..lineTo(s * .64, s * .28)
      ..lineTo(s * .74, s * .45)..close();
    c.drawPath(top, f(tint ?? const Color(0xFF42A5F5)));
    c.drawPath(top, st);
    c.drawCircle(Offset(s * .3, s * .72), s * .1, f(_ink));
    c.drawCircle(Offset(s * .7, s * .72), s * .1, f(_ink));
  }

  void _balloon(Canvas c, double s, Paint st, Paint Function(Color) f) {
    c.drawCircle(Offset(s * .5, s * .4), s * .28, f(tint ?? const Color(0xFFEF5350)));
    c.drawCircle(Offset(s * .5, s * .4), s * .28, st);
    c.drawLine(Offset(s * .5, s * .68), Offset(s * .5, s * .92), st..strokeWidth = s * .02);
  }

  void _gift(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final box = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .22, s * .4, s * .56, s * .45), Radius.circular(s * .03));
    c.drawRRect(box, f(tint ?? const Color(0xFFEF5350)));
    c.drawRRect(box, st);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s * .18, s * .3, s * .64, s * .14), Radius.circular(s * .03)),
        f(const Color(0xFFFFCA28)));
    c.drawLine(Offset(s * .5, s * .3), Offset(s * .5, s * .85), st);
  }

  void _box(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final box = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .2, s * .35, s * .6, s * .5), Radius.circular(s * .03));
    c.drawRRect(box, f(tint ?? const Color(0xFFBCAAA4)));
    c.drawRRect(box, st);
    c.drawLine(Offset(s * .2, s * .5), Offset(s * .8, s * .5), st);
  }

  void _rug(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .12, s * .42, s * .76, s * .3), Radius.circular(s * .04));
    c.drawRRect(r, f(tint ?? const Color(0xFFEF9A9A)));
    c.drawRRect(r, st);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s * .2, s * .48, s * .6, s * .18), Radius.circular(s * .02)),
        st);
  }

  void _button(Canvas c, double s, Paint st, Paint Function(Color) f) {
    c.drawCircle(Offset(s * .5, s * .5), s * .3, f(tint ?? const Color(0xFFEF5350)));
    c.drawCircle(Offset(s * .5, s * .5), s * .3, st);
    c.drawCircle(Offset(s * .5, s * .5), s * .18, f(const Color(0xFFFFCDD2)));
  }

  void _switch(Canvas c, double s, Paint st, Paint Function(Color) f, {required bool on}) {
    final plate = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .32, s * .2, s * .36, s * .6), Radius.circular(s * .06));
    c.drawRRect(plate, f(const Color(0xFFECEFF1)));
    c.drawRRect(plate, st);
    final knob = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .38, on ? s * .26 : s * .5, s * .24, s * .24),
        Radius.circular(s * .04));
    c.drawRRect(knob, f(on ? const Color(0xFF66BB6A) : const Color(0xFFB0BEC5)));
    c.drawRRect(knob, st);
  }

  void _cup(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .28, s * .4, s * .4, s * .42), Radius.circular(s * .05));
    c.drawRRect(body, f(tint ?? const Color(0xFFFFFFFF)));
    c.drawRRect(body, st);
    c.drawArc(Rect.fromLTWH(s * .62, s * .45, s * .22, s * .3), -math.pi / 2, math.pi, false, st);
  }

  void _cheese(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final p = Path()
      ..moveTo(s * .15, s * .7)..lineTo(s * .8, s * .35)..lineTo(s * .85, s * .7)..close();
    c.drawPath(p, f(const Color(0xFFFFD54F)));
    c.drawPath(p, st);
    c.drawCircle(Offset(s * .4, s * .58), s * .04, f(Colors.white));
    c.drawCircle(Offset(s * .6, s * .5), s * .03, f(Colors.white));
  }

  void _moon(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final p = Path()
      ..addArc(Rect.fromCircle(center: Offset(s * .5, s * .5), radius: s * .32), -math.pi / 2, math.pi)
      ..arcToPoint(Offset(s * .5, s * .18), radius: Radius.circular(s * .22), clockwise: false);
    c.drawPath(p, f(const Color(0xFFFFF59D)));
    c.drawPath(p, st);
  }

  void _cabinet(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final d = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .2, s * .15, s * .6, s * .72), Radius.circular(s * .03));
    c.drawRRect(d, f(tint ?? const Color(0xFFA1887F)));
    c.drawRRect(d, st);
    c.drawLine(Offset(s * .5, s * .15), Offset(s * .5, s * .87), st);
    c.drawCircle(Offset(s * .44, s * .5), s * .03, f(_ink));
    c.drawCircle(Offset(s * .56, s * .5), s * .03, f(_ink));
  }

  void _unknown(Canvas c, double s, Paint st, Paint Function(Color) f) {
    final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * .25, s * .25, s * .5, s * .5), Radius.circular(s * .08));
    c.drawRRect(r, f(tint ?? const Color(0xFFB0BEC5)));
    c.drawRRect(r, st);
  }

  @override
  bool shouldRepaint(covariant _PropPainter old) =>
      old.name != name || old.tint != tint;
}

class _BgPainter extends CustomPainter {
  final String name;
  _BgPainter(this.name);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Paint fill(Color c) => Paint()..color = c;
    switch (name) {
      case 'roomBg':
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h * .68), fill(const Color(0xFFF3E5D8)));
        canvas.drawRect(Rect.fromLTWH(0, h * .68, w, h * .32), fill(const Color(0xFFD7B899)));
        canvas.drawLine(Offset(0, h * .68), Offset(w, h * .68),
            Paint()..color = _ink.withValues(alpha: .25)..strokeWidth = 2);
        break;
      case 'skyBg':
        canvas.drawRect(Offset.zero & size, fill(const Color(0xFFBBDEFB)));
        break;
      case 'tableBg':
        canvas.drawRect(Offset.zero & size, fill(const Color(0xFFFFF8E1)));
        canvas.drawRect(Rect.fromLTWH(0, h * .72, w, h * .28), fill(const Color(0xFFD7CCBE)));
        break;
      case 'snowBg':
        canvas.drawRect(Offset.zero & size, fill(const Color(0xFFE3F2FD)));
        break;
      default:
        canvas.drawRect(Offset.zero & size, fill(const Color(0xFFF9FAFC)));
    }
  }

  @override
  bool shouldRepaint(covariant _BgPainter old) => old.name != name;
}
