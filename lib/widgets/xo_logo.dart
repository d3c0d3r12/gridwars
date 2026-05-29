import 'dart:math';
import 'package:flutter/material.dart';

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
        painter: _XOLogoPainter(),
      ),
    );
  }
}

class _XOLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // ── 1. Background: deep dark circle ───────────────────────────────────────
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0xFF1A0A40), Color(0xFF0D0520), Color(0xFF050110)],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, bgPaint);

    // ── 2. Subtle outer glow ring ──────────────────────────────────────────────
    canvas.drawCircle(c, r - 1,
      Paint()
        ..color = const Color(0xFFFFAA00).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(c, r - 1,
      Paint()
        ..color = const Color(0xFFFFAA00).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // ── 3. Grid lines (tic-tac-toe board) ─────────────────────────────────────
    final gridSize = r * 0.56;
    final gridPaint = Paint()
      ..color = const Color(0xFFFFAA00).withValues(alpha: 0.18)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    // Vertical lines
    canvas.drawLine(Offset(c.dx - gridSize / 3, c.dy - gridSize), Offset(c.dx - gridSize / 3, c.dy + gridSize), gridPaint);
    canvas.drawLine(Offset(c.dx + gridSize / 3, c.dy - gridSize), Offset(c.dx + gridSize / 3, c.dy + gridSize), gridPaint);
    // Horizontal lines
    canvas.drawLine(Offset(c.dx - gridSize, c.dy - gridSize / 3), Offset(c.dx + gridSize, c.dy - gridSize / 3), gridPaint);
    canvas.drawLine(Offset(c.dx - gridSize, c.dy + gridSize / 3), Offset(c.dx + gridSize, c.dy + gridSize / 3), gridPaint);

    // ── 4. O ring — vivid purple with outer glow ──────────────────────────────
    final oRadius = r * 0.44;
    // Glow layer
    canvas.drawCircle(c, oRadius,
      Paint()
        ..color = const Color(0xFF9B4FFF).withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // O ring proper
    canvas.drawCircle(c, oRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.butt
        ..shader = SweepGradient(
          colors: const [
            Color(0xFFCC88FF),
            Color(0xFF7C3AED),
            Color(0xFF5B21B6),
            Color(0xFF7C3AED),
            Color(0xFFCC88FF),
          ],
          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: oRadius)),
    );

    // ── 5. X strokes — bold gold with glow ───────────────────────────────────
    final xExt = r * 0.5;

    // Outer glow (both diagonals)
    final xGlowPaint = Paint()
      ..color = const Color(0xFFFFAA00).withValues(alpha: 0.5)
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    _drawX(canvas, c, xExt, xGlowPaint);

    // Main X stroke — diagonal 1
    canvas.drawLine(
      Offset(c.dx - xExt, c.dy - xExt),
      Offset(c.dx + xExt, c.dy + xExt),
      Paint()
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: const [Color(0xFFFFE566), Color(0xFFFF8C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(c.dx - xExt, c.dy - xExt, xExt * 2, xExt * 2)),
    );
    // Main X stroke — diagonal 2
    canvas.drawLine(
      Offset(c.dx + xExt, c.dy - xExt),
      Offset(c.dx - xExt, c.dy + xExt),
      Paint()
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: const [Color(0xFFFFE566), Color(0xFFFF8C00)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ).createShader(Rect.fromLTWH(c.dx - xExt, c.dy - xExt, xExt * 2, xExt * 2)),
    );

    // ── 6. Center spark ──────────────────────────────────────────────────────
    canvas.drawCircle(c, 12,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(c, 5.5, Paint()..color = Colors.white);
    canvas.drawCircle(c, 2.5, Paint()..color = const Color(0xFFFFCC00));

    // ── 7. Corner dots (compass points) ──────────────────────────────────────
    final dotPaint = Paint()..color = const Color(0xFFFFAA00).withValues(alpha: 0.75);
    for (int i = 0; i < 4; i++) {
      final a = i * pi / 2 + pi / 4;
      canvas.drawCircle(Offset(c.dx + r * 0.76 * cos(a), c.dy + r * 0.76 * sin(a)), 3.5, dotPaint);
    }

    // ── 8. Inner vignette depth ───────────────────────────────────────────────
    canvas.drawCircle(c, r * 0.35,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.05), Colors.transparent],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.35)),
    );
  }

  void _drawX(Canvas canvas, Offset c, double ext, Paint paint) {
    canvas.drawLine(Offset(c.dx - ext, c.dy - ext), Offset(c.dx + ext, c.dy + ext), paint);
    canvas.drawLine(Offset(c.dx + ext, c.dy - ext), Offset(c.dx - ext, c.dy + ext), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
