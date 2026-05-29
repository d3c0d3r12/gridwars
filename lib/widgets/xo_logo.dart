import 'dart:math';
import 'package:flutter/material.dart';

// ── Main logo widget ──────────────────────────────────────────────────────────
// Renders the "CZ" Chilling Zone monogram: dark bold C + teal lightning-bolt Z,
// with X (indigo) and O (gold ring) accent marks, matching the brand asset.

class XOBattleLogo extends StatelessWidget {
  final double size;
  const XOBattleLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _CZLogoPainter(),
      ),
    );
  }
}

// Keep the old class name as alias so nothing else needs updating
typedef ChillingZoneLogo = XOBattleLogo;

class _CZLogoPainter extends CustomPainter {
  static const _slate  = Color(0xFF1A2B3C);   // C letter — dark slate
  static const _teal   = Color(0xFF00B8D4);   // Z lightning — teal
  static const _tealLt = Color(0xFF4DD0E1);   // Z highlight
  static const _indigo = Color(0xFF4B4EE6);   // X accent
  static const _gold   = Color(0xFFECA13A);   // O accent ring

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // ── 1. Background circle ─────────────────────────────────────────────────
    // Subtle gradient from very light to white, for versatility on any bg
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0xFFF0F4FF), Color(0xFFE8EAF6)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: w / 2));
    canvas.drawCircle(Offset(cx, cy), w / 2, bgPaint);

    // Thin accent ring
    canvas.drawCircle(Offset(cx, cy), w / 2 - 1.5,
      Paint()
        ..color = _teal.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // ── 2. "C" letter (dark slate) ───────────────────────────────────────────
    _drawC(canvas, size);

    // ── 3. "Z" lightning bolt (teal) ─────────────────────────────────────────
    _drawZ(canvas, size);

    // ── 4. X accent (indigo, top-left area) ──────────────────────────────────
    _drawXAccent(canvas, size);

    // ── 5. O accent ring (gold, top-right area) ───────────────────────────────
    _drawOAccent(canvas, size);

    // ── 6. Subtle inner glow ─────────────────────────────────────────────────
    canvas.drawCircle(Offset(cx, cy), w * 0.18,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  void _drawC(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final cx = w * 0.48;
    final cy = h * 0.50;
    final outerR = w * 0.32;
    final innerR = w * 0.20;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: const [Color(0xFF2C3E50), Color(0xFF1A2B3C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(cx - outerR, cy - outerR, outerR * 2, outerR * 2))
      ..style = PaintingStyle.fill;

    // C = thick arc from ~40° to ~320° (leaving gap on right)
    final path = Path();
    const gapAngle = 55.0 * pi / 180.0; // gap on the right side
    final startAngle = gapAngle;
    final sweepAngle = 2 * pi - 2 * gapAngle;

    // Outer arc
    path.addArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: outerR),
      startAngle, sweepAngle,
    );
    // Cut inner circle to make it thick arc
    path.addArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: innerR),
      startAngle + sweepAngle, -sweepAngle,
    );
    path.close();

    // Also add rounded caps (top and bottom of C)
    final capR = (outerR - innerR) / 2;
    final midR  = (outerR + innerR) / 2;
    final topCapCenter = Offset(
      cx + midR * cos(startAngle),
      cy + midR * sin(startAngle),
    );
    final botCapCenter = Offset(
      cx + midR * cos(startAngle + sweepAngle),
      cy + midR * sin(startAngle + sweepAngle),
    );
    path.addOval(Rect.fromCircle(center: topCapCenter, radius: capR));
    path.addOval(Rect.fromCircle(center: botCapCenter, radius: capR));

    canvas.drawPath(path, paint);

    // Shadow on left edge for depth
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: outerR - 1),
      startAngle, sweepAngle * 0.5,
      false,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.10)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawZ(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    // Lightning-bolt Z: three lines forming Z shape
    // Top bar: upper-right area slanting left
    // Diagonal: top-right to bottom-left
    // Bottom bar: lower-left area going right

    final zPath = Path();
    // Top bar of Z
    final t1 = Offset(w * 0.52, h * 0.22);
    final t2 = Offset(w * 0.82, h * 0.22);
    // Diagonal
    final d1 = t2;
    final d2 = Offset(w * 0.42, h * 0.78);
    // Bottom bar of Z
    final b1 = d2;
    final b2 = Offset(w * 0.78, h * 0.78);

    zPath.moveTo(t1.dx, t1.dy);
    zPath.lineTo(t2.dx, t2.dy);
    zPath.lineTo(d2.dx, d2.dy);
    zPath.lineTo(b2.dx, b2.dy);

    // Make it a thick shape by offsetting
    final zPaint = Paint()
      ..shader = LinearGradient(
        colors: const [_tealLt, _teal, Color(0xFF0097A7)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).createShader(Rect.fromLTWH(w * 0.35, h * 0.18, w * 0.5, h * 0.64))
      ..strokeWidth = w * 0.14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(zPath, zPaint);

    // Glow layer
    canvas.drawPath(zPath,
      Paint()
        ..color = _teal.withValues(alpha: 0.35)
        ..strokeWidth = w * 0.22
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Bright highlight on Z
    canvas.drawPath(zPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..strokeWidth = w * 0.04
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawXAccent(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final cx = w * 0.16;
    final cy = h * 0.35;
    final ext = w * 0.075;

    final paint = Paint()
      ..color = _indigo
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(cx - ext, cy - ext), Offset(cx + ext, cy + ext), paint);
    canvas.drawLine(Offset(cx + ext, cy - ext), Offset(cx - ext, cy + ext), paint);
  }

  void _drawOAccent(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final cx = w * 0.86;
    final cy = h * 0.30;
    final r = w * 0.07;

    canvas.drawCircle(Offset(cx, cy), r,
      Paint()
        ..color = _gold
        ..strokeWidth = w * 0.042
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Text wordmark (used alongside the logo) ───────────────────────────────────

class ChillingZoneWordmark extends StatelessWidget {
  final double fontSize;
  final Color? textColor;
  const ChillingZoneWordmark({super.key, this.fontSize = 20, this.textColor});

  @override
  Widget build(BuildContext context) {
    final col = textColor ?? const Color(0xFF1A2B3C);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              letterSpacing: 1.5,
            ),
            children: [
              TextSpan(
                text: 'CHILLING',
                style: TextStyle(color: col),
              ),
            ],
          ),
        ),
        Text(
          'ZONE',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w800,
            fontSize: fontSize * 0.9,
            color: const Color(0xFF00B8D4),
            letterSpacing: 4,
          ),
        ),
        Text(
          'GAME ON.  CHILL ON.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
            fontSize: fontSize * 0.38,
            color: col.withValues(alpha: 0.55),
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
