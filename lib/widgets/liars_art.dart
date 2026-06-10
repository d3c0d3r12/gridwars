import 'dart:math' as math;
import 'package:flutter/material.dart';

// ════════════════════════════════════════════════════════════════════════════
// Liar's Bar vector art — all hand-drawn in CustomPaint (no image files), to
// recreate the game's look: the 8 named animal characters, the dark seedy bar,
// playing cards, dice and the revolver. Same sketch approach as puzzle_art.dart.
// ════════════════════════════════════════════════════════════════════════════

/// The roster, in display order. id → (display name).
const Map<String, String> kLiarsCharacters = {
  'kudo': 'Kudo',       // red panda
  'foxy': 'Foxy',       // fox
  'scubby': 'Scubby',   // dog
  'toar': 'Toar',       // bull
  'bristle': 'Bristle', // pig
  'gerk': 'Gerk',       // rhino
  'cupcake': 'Cupcake', // rabbit
  'cleo': 'Cleo',       // cat
};

List<String> get kLiarsCharIds => kLiarsCharacters.keys.toList();

const Color _ink = Color(0xFF231A16);

/// A character's head/bust. [dead] greys it out with X eyes.
Widget liarsCharacter(String id, {required double size, bool dead = false}) {
  return SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _CharPainter(id, dead)),
  );
}

/// Full-bleed dark bar backdrop (wood, hanging lamp glow, vignette).
Widget liarsBarBackground() =>
    Positioned.fill(child: CustomPaint(painter: _BarBgPainter()));

/// A playing card. [code] one of A K Q J(joker) D(devil) M(master) C(chaos).
Widget liarsCard(String code, {required double width, bool faceDown = false}) {
  return SizedBox(
    width: width,
    height: width * 1.4,
    child: CustomPaint(painter: _CardPainter(code, faceDown)),
  );
}

Widget liarsDie(int pips, {required double size, bool held = false}) {
  return SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _DiePainter(pips, held)),
  );
}

Widget liarsRevolver({required double size, bool firing = false}) {
  return SizedBox(
    width: size,
    height: size * 0.7,
    child: CustomPaint(painter: _RevolverPainter(firing)),
  );
}

// ── Characters ───────────────────────────────────────────────────────────────
class _CharPainter extends CustomPainter {
  final String id;
  final bool dead;
  _CharPainter(this.id, this.dead);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = (s * 0.04).clamp(1.6, 6.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Paint fill(Color c) => Paint()..color = c..style = PaintingStyle.fill;

    switch (id) {
      case 'kudo': _kudo(canvas, s, stroke, fill); break;
      case 'foxy': _foxy(canvas, s, stroke, fill); break;
      case 'scubby': _scubby(canvas, s, stroke, fill); break;
      case 'toar': _toar(canvas, s, stroke, fill); break;
      case 'bristle': _bristle(canvas, s, stroke, fill); break;
      case 'gerk': _gerk(canvas, s, stroke, fill); break;
      case 'cupcake': _cupcake(canvas, s, stroke, fill); break;
      case 'cleo': _cleo(canvas, s, stroke, fill); break;
      default: _scubby(canvas, s, stroke, fill);
    }

    if (dead) {
      // Grey wash + X eyes over the whole head.
      canvas.drawRect(Offset.zero & Size(s, s), fill(const Color(0x88202020)));
      final xp = Paint()
        ..color = Colors.white
        ..strokeWidth = s * 0.035
        ..strokeCap = StrokeCap.round;
      for (final cx in [s * 0.36, s * 0.64]) {
        final cy = s * 0.46, r = s * 0.05;
        canvas.drawLine(Offset(cx - r, cy - r), Offset(cx + r, cy + r), xp);
        canvas.drawLine(Offset(cx + r, cy - r), Offset(cx - r, cy + r), xp);
      }
    }
  }

  // shared eyes (two black dots with white glints)
  void _eyes(Canvas c, double s, Paint Function(Color) fill,
      {double y = 0.46, double dx = 0.14, double r = 0.045}) {
    for (final sx in [-1.0, 1.0]) {
      final cx = s * (0.5 + sx * dx), cy = s * y;
      c.drawCircle(Offset(cx, cy), s * r, fill(_ink));
      c.drawCircle(Offset(cx - s * 0.012, cy - s * 0.012), s * r * 0.35,
          fill(Colors.white));
    }
  }

  void _head(Canvas c, double s, Paint stroke, Paint Function(Color) fill,
      Color face, {double w = 0.62, double h = 0.66}) {
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(s * 0.5, s * 0.52), width: s * w, height: s * h),
      Radius.circular(s * 0.28),
    );
    c.drawRRect(r, fill(face));
    c.drawRRect(r, stroke);
  }

  void _ear(Canvas c, double s, Paint stroke, Paint Function(Color) fill,
      double cx, double cy, double rad, Color col) {
    c.drawCircle(Offset(s * cx, s * cy), s * rad, fill(col));
    c.drawCircle(Offset(s * cx, s * cy), s * rad, stroke);
  }

  void _kudo(Canvas c, double s, Paint st, Paint Function(Color) fill) {
    const face = Color(0xFFC4623A); // rust
    _ear(c, s, st, fill, 0.24, 0.24, 0.13, const Color(0xFF3A2A22));
    _ear(c, s, st, fill, 0.76, 0.24, 0.13, const Color(0xFF3A2A22));
    _ear(c, s, st, fill, 0.24, 0.24, 0.06, const Color(0xFFE9D9C6));
    _ear(c, s, st, fill, 0.76, 0.24, 0.06, const Color(0xFFE9D9C6));
    _head(c, s, st, fill, face);
    // white muzzle + brow patches
    c.drawOval(Rect.fromCenter(center: Offset(s * 0.5, s * 0.62), width: s * 0.4, height: s * 0.34), fill(const Color(0xFFF3E8DC)));
    for (final sx in [-1.0, 1.0]) {
      c.drawOval(Rect.fromCenter(center: Offset(s * (0.5 + sx * 0.14), s * 0.45), width: s * 0.18, height: s * 0.2), fill(const Color(0xFFF3E8DC)));
    }
    _eyes(c, s, fill, y: 0.47, dx: 0.14);
    c.drawCircle(Offset(s * 0.5, s * 0.58), s * 0.035, fill(_ink)); // nose
  }

  void _foxy(Canvas c, double s, Paint st, Paint Function(Color) fill) {
    const face = Color(0xFFBE4F2A);
    // pointy ears (triangles)
    for (final sx in [-1.0, 1.0]) {
      final p = Path()
        ..moveTo(s * (0.5 + sx * 0.18), s * 0.30)
        ..lineTo(s * (0.5 + sx * 0.34), s * 0.04)
        ..lineTo(s * (0.5 + sx * 0.40), s * 0.32)
        ..close();
      c.drawPath(p, fill(const Color(0xFF2A1A14)));
      c.drawPath(p, st);
    }
    _head(c, s, st, fill, face, w: 0.6, h: 0.6);
    // white cheeks + narrow snout
    final snout = Path()
      ..moveTo(s * 0.5, s * 0.5)
      ..lineTo(s * 0.36, s * 0.78)
      ..lineTo(s * 0.64, s * 0.78)
      ..close();
    c.drawPath(snout, fill(const Color(0xFFF1E7DD)));
    _eyes(c, s, fill, y: 0.47, dx: 0.15);
    c.drawCircle(Offset(s * 0.5, s * 0.72), s * 0.035, fill(_ink));
  }

  void _scubby(Canvas c, double s, Paint st, Paint Function(Color) fill) {
    const face = Color(0xFFB7895A);
    // floppy ears
    for (final sx in [-1.0, 1.0]) {
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(s * (0.5 + sx * 0.32), s * 0.5), width: s * 0.18, height: s * 0.46),
        Radius.circular(s * 0.1));
      c.drawRRect(r, fill(const Color(0xFF6E4B2E)));
      c.drawRRect(r, st);
    }
    _head(c, s, st, fill, face);
    c.drawOval(Rect.fromCenter(center: Offset(s * 0.5, s * 0.64), width: s * 0.34, height: s * 0.28), fill(const Color(0xFFE7D2B8)));
    _eyes(c, s, fill, y: 0.46, dx: 0.13);
    c.drawOval(Rect.fromCenter(center: Offset(s * 0.5, s * 0.6), width: s * 0.1, height: s * 0.07), fill(_ink));
  }

  void _toar(Canvas c, double s, Paint st, Paint Function(Color) fill) {
    const face = Color(0xFF6E4A35);
    // horns
    for (final sx in [-1.0, 1.0]) {
      final p = Path()
        ..moveTo(s * (0.5 + sx * 0.22), s * 0.28)
        ..quadraticBezierTo(s * (0.5 + sx * 0.46), s * 0.16, s * (0.5 + sx * 0.40), s * 0.04);
      final hp = Paint()..color = const Color(0xFFEDE6D2)..style = PaintingStyle.stroke..strokeWidth = s * 0.07..strokeCap = StrokeCap.round;
      c.drawPath(p, hp);
    }
    _head(c, s, st, fill, face, w: 0.66, h: 0.62);
    c.drawOval(Rect.fromCenter(center: Offset(s * 0.5, s * 0.66), width: s * 0.42, height: s * 0.3), fill(const Color(0xFF8A6049)));
    _eyes(c, s, fill, y: 0.45, dx: 0.16);
    // nostrils + ring
    for (final sx in [-1.0, 1.0]) {
      c.drawCircle(Offset(s * (0.5 + sx * 0.07), s * 0.66), s * 0.025, fill(_ink));
    }
    final ring = Paint()..color = const Color(0xFFE0B33A)..style = PaintingStyle.stroke..strokeWidth = s * 0.025;
    c.drawCircle(Offset(s * 0.5, s * 0.74), s * 0.05, ring);
  }

  void _bristle(Canvas c, double s, Paint st, Paint Function(Color) fill) {
    const face = Color(0xFFEC9AAE);
    for (final sx in [-1.0, 1.0]) {
      final p = Path()
        ..moveTo(s * (0.5 + sx * 0.2), s * 0.26)
        ..lineTo(s * (0.5 + sx * 0.30), s * 0.12)
        ..lineTo(s * (0.5 + sx * 0.36), s * 0.30)
        ..close();
      c.drawPath(p, fill(const Color(0xFFD97E96)));
      c.drawPath(p, st);
    }
    _head(c, s, st, fill, face);
    _eyes(c, s, fill, y: 0.44, dx: 0.14);
    // snout
    final sn = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(s * 0.5, s * 0.64), width: s * 0.26, height: s * 0.2), Radius.circular(s * 0.08));
    c.drawRRect(sn, fill(const Color(0xFFD97E96)));
    c.drawRRect(sn, st);
    for (final sx in [-1.0, 1.0]) {
      c.drawOval(Rect.fromCenter(center: Offset(s * (0.5 + sx * 0.05), s * 0.64), width: s * 0.04, height: s * 0.07), fill(_ink));
    }
  }

  void _gerk(Canvas c, double s, Paint st, Paint Function(Color) fill) {
    const face = Color(0xFF8B919A);
    _ear(c, s, st, fill, 0.26, 0.26, 0.07, const Color(0xFF6E747C));
    _ear(c, s, st, fill, 0.74, 0.26, 0.07, const Color(0xFF6E747C));
    _head(c, s, st, fill, face, w: 0.64, h: 0.64);
    // horn on nose
    final horn = Path()
      ..moveTo(s * 0.44, s * 0.7)
      ..lineTo(s * 0.5, s * 0.5)
      ..lineTo(s * 0.56, s * 0.7)
      ..close();
    c.drawPath(horn, fill(const Color(0xFFE8E2D0)));
    c.drawPath(horn, st);
    _eyes(c, s, fill, y: 0.44, dx: 0.16);
    c.drawOval(Rect.fromCenter(center: Offset(s * 0.5, s * 0.76), width: s * 0.3, height: s * 0.12), fill(const Color(0xFF6E747C)));
  }

  void _cupcake(Canvas c, double s, Paint st, Paint Function(Color) fill) {
    const face = Color(0xFFF4ECE6);
    for (final sx in [-1.0, 1.0]) {
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(s * (0.5 + sx * 0.16), s * 0.22), width: s * 0.14, height: s * 0.4),
        Radius.circular(s * 0.07));
      c.drawRRect(r, fill(face));
      c.drawRRect(r, st);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(s * (0.5 + sx * 0.16), s * 0.22), width: s * 0.06, height: s * 0.3), Radius.circular(s * 0.04)), fill(const Color(0xFFF4A6C0)));
    }
    _head(c, s, st, fill, face, w: 0.56, h: 0.56);
    _eyes(c, s, fill, y: 0.5, dx: 0.13);
    c.drawCircle(Offset(s * 0.5, s * 0.62), s * 0.03, fill(const Color(0xFFE0708F)));
  }

  void _cleo(Canvas c, double s, Paint st, Paint Function(Color) fill) {
    const face = Color(0xFF5C5563);
    for (final sx in [-1.0, 1.0]) {
      final p = Path()
        ..moveTo(s * (0.5 + sx * 0.16), s * 0.28)
        ..lineTo(s * (0.5 + sx * 0.30), s * 0.06)
        ..lineTo(s * (0.5 + sx * 0.38), s * 0.30)
        ..close();
      c.drawPath(p, fill(face));
      c.drawPath(p, st);
    }
    _head(c, s, st, fill, face, w: 0.58, h: 0.58);
    // green eyes
    for (final sx in [-1.0, 1.0]) {
      c.drawOval(Rect.fromCenter(center: Offset(s * (0.5 + sx * 0.14), s * 0.47), width: s * 0.1, height: s * 0.12), fill(const Color(0xFF8FE36B)));
      c.drawCircle(Offset(s * (0.5 + sx * 0.14), s * 0.47), s * 0.025, fill(_ink));
    }
    c.drawCircle(Offset(s * 0.5, s * 0.6), s * 0.03, fill(const Color(0xFFE0708F)));
    // whiskers
    final wp = Paint()..color = Colors.white70..strokeWidth = s * 0.012;
    for (final sx in [-1.0, 1.0]) {
      c.drawLine(Offset(s * 0.5, s * 0.62), Offset(s * (0.5 + sx * 0.32), s * 0.58), wp);
      c.drawLine(Offset(s * 0.5, s * 0.64), Offset(s * (0.5 + sx * 0.32), s * 0.66), wp);
    }
  }

  @override
  bool shouldRepaint(covariant _CharPainter o) => o.id != id || o.dead != dead;
}

// ── Bar background ───────────────────────────────────────────────────────────
class _BarBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // deep dark gradient
    canvas.drawRect(
      rect,
      Paint()..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF130D0A), Color(0xFF241612), Color(0xFF0C0807)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect),
    );
    // wood plank seams
    final plank = Paint()..color = const Color(0x22000000)..strokeWidth = 2;
    for (double y = size.height * 0.12; y < size.height; y += size.height * 0.14) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), plank);
    }
    // hanging-lamp warm glow, top-center
    final glowC = Offset(size.width * 0.5, size.height * 0.16);
    canvas.drawCircle(
      glowC, size.width * 0.6,
      Paint()..shader = RadialGradient(
        colors: [const Color(0x55E8A23A), const Color(0x00000000)],
      ).createShader(Rect.fromCircle(center: glowC, radius: size.width * 0.6)),
    );
    // lamp + cord
    canvas.drawLine(Offset(size.width * 0.5, 0), Offset(size.width * 0.5, size.height * 0.08),
        Paint()..color = const Color(0xFF000000)..strokeWidth = 2);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.1), size.width * 0.04,
        Paint()..color = const Color(0xFFE8A23A));
    // vignette
    canvas.drawRect(
      rect,
      Paint()..shader = RadialGradient(
        radius: 1.1,
        colors: [const Color(0x00000000), const Color(0xAA000000)],
        stops: const [0.6, 1.0],
      ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Cards ────────────────────────────────────────────────────────────────────
class _CardPainter extends CustomPainter {
  final String code;
  final bool faceDown;
  _CardPainter(this.code, this.faceDown);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(size.width * 0.14));
    final border = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05;

    if (faceDown) {
      canvas.drawRRect(r, Paint()..color = const Color(0xFF6E1721));
      // inset diamond pattern
      final inset = RRect.fromRectAndRadius(
          Offset(size.width * 0.12, size.height * 0.09) &
              Size(size.width * 0.76, size.height * 0.82),
          Radius.circular(size.width * 0.08));
      canvas.drawRRect(inset, Paint()
        ..color = const Color(0xFFB7323F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.03);
      canvas.drawRRect(r, border);
      return;
    }

    canvas.drawRRect(r, Paint()..color = const Color(0xFFF3E9D7)); // aged paper
    canvas.drawRRect(r, border);

    final isRed = code == 'A' || code == 'Q' || code == 'D' || code == 'C';
    final col = isRed ? const Color(0xFFB02A35) : const Color(0xFF222222);
    String glyph;
    switch (code) {
      case 'A': glyph = 'A'; break;
      case 'K': glyph = 'K'; break;
      case 'Q': glyph = 'Q'; break;
      case 'J': glyph = '★'; break; // joker (wild)
      case 'D': glyph = '☠'; break; // devil
      case 'M': glyph = '♛'; break; // master
      case 'C': glyph = '✸'; break; // chaos
      default: glyph = code;
    }
    final tp = TextPainter(
      text: TextSpan(
          text: glyph,
          style: TextStyle(
              color: col,
              fontSize: size.width * 0.62,
              fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
    // corner pips
    final small = TextPainter(
      text: TextSpan(text: glyph, style: TextStyle(color: col, fontSize: size.width * 0.22, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    small.paint(canvas, Offset(size.width * 0.1, size.height * 0.05));
  }

  @override
  bool shouldRepaint(covariant _CardPainter o) => o.code != code || o.faceDown != faceDown;
}

// ── Dice ─────────────────────────────────────────────────────────────────────
class _DiePainter extends CustomPainter {
  final int pips;
  final bool held;
  _DiePainter(this.pips, this.held);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * 0.2));
    canvas.drawRRect(r, Paint()..color = held ? const Color(0xFFF3E9D7) : const Color(0xFFCFC4AE));
    canvas.drawRRect(r, Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = size.width * 0.05);
    final dot = Paint()..color = _ink;
    final u = size.width;
    final pr = u * 0.09;
    final L = u * 0.28, M = u * 0.5, R = u * 0.72;
    void d(double x, double y) => canvas.drawCircle(Offset(x, y), pr, dot);
    switch (pips) {
      case 1: d(M, M); break;
      case 2: d(L, L); d(R, R); break;
      case 3: d(L, L); d(M, M); d(R, R); break;
      case 4: d(L, L); d(R, L); d(L, R); d(R, R); break;
      case 5: d(L, L); d(R, L); d(M, M); d(L, R); d(R, R); break;
      case 6: d(L, L); d(R, L); d(L, M); d(R, M); d(L, R); d(R, R); break;
    }
  }

  @override
  bool shouldRepaint(covariant _DiePainter o) => o.pips != pips || o.held != held;
}

// ── Revolver ─────────────────────────────────────────────────────────────────
class _RevolverPainter extends CustomPainter {
  final bool firing;
  _RevolverPainter(this.firing);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final barrelRect = Rect.fromLTWH(s * 0.08, s * 0.30, s * 0.62, s * 0.13);
    final metalGrad = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF6B7178), Color(0xFF2C3036)],
      ).createShader(barrelRect);
    final dark = Paint()..color = const Color(0xFF1C2024);
    final grip = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF6E4A30), Color(0xFF3F2817)],
      ).createShader(Rect.fromLTWH(s * 0.55, s * 0.46, s * 0.25, s * 0.42));
    final edge = Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = s * 0.018;

    // grip (drawn first, behind)
    final g = Path()
      ..moveTo(s * 0.60, s * 0.48)
      ..lineTo(s * 0.80, s * 0.50)
      ..lineTo(s * 0.72, s * 0.88)
      ..lineTo(s * 0.57, s * 0.86)
      ..close();
    canvas.drawPath(g, grip);
    canvas.drawPath(g, edge);

    // barrel + top sight
    final br = RRect.fromRectAndRadius(barrelRect, Radius.circular(s * 0.03));
    canvas.drawRRect(br, metalGrad);
    canvas.drawRRect(br, edge);
    canvas.drawRect(Rect.fromLTWH(s * 0.10, s * 0.27, s * 0.5, s * 0.025), dark); // top rib
    canvas.drawRect(Rect.fromLTWH(s * 0.11, s * 0.255, s * 0.03, s * 0.03), dark); // front sight
    // muzzle hole
    canvas.drawCircle(Offset(s * 0.085, s * 0.365), s * 0.022, dark);

    // cylinder with chamber holes
    final cc = Offset(s * 0.55, s * 0.44);
    canvas.drawCircle(cc, s * 0.155, metalGrad);
    canvas.drawCircle(cc, s * 0.155, edge);
    canvas.drawCircle(cc, s * 0.05, dark);
    for (int i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      canvas.drawCircle(
          Offset(cc.dx + math.cos(a) * s * 0.1, cc.dy + math.sin(a) * s * 0.1),
          s * 0.022, dark);
    }

    // hammer at the back
    final hammer = Path()
      ..moveTo(s * 0.70, s * 0.33)
      ..lineTo(s * 0.78, s * 0.28)
      ..lineTo(s * 0.79, s * 0.36)
      ..lineTo(s * 0.70, s * 0.40)
      ..close();
    canvas.drawPath(hammer, metalGrad);
    canvas.drawPath(hammer, edge);

    // trigger guard
    canvas.drawArc(Rect.fromCircle(center: Offset(s * 0.52, s * 0.56), radius: s * 0.075), 0, math.pi, false,
        Paint()..color = const Color(0xFF3A3F46)..style = PaintingStyle.stroke..strokeWidth = s * 0.025);

    if (firing) {
      // smoke puff
      final smoke = Paint()..color = const Color(0x66B8B8B8);
      canvas.drawCircle(Offset(s * 0.0, s * 0.34), s * 0.10, smoke);
      canvas.drawCircle(Offset(s * -0.06, s * 0.28), s * 0.07, smoke);
      // layered muzzle flash
      void star(double scale, Color col) {
        final p = Path();
        final cx = s * 0.04, cy = s * 0.365;
        for (int i = 0; i < 10; i++) {
          final a = i * math.pi / 5;
          final rad = (i.isEven ? s * 0.22 : s * 0.09) * scale;
          final pt = Offset(cx - math.cos(a) * rad, cy + math.sin(a) * rad);
          i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
        }
        p.close();
        canvas.drawPath(p, Paint()..color = col);
      }
      star(1.0, const Color(0xFFFF8A1E));
      star(0.62, const Color(0xFFFFD24A));
      star(0.3, Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _RevolverPainter o) => o.firing != firing;
}
