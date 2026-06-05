import 'package:flutter/material.dart';

// ── Main logo widget ──────────────────────────────────────────────────────────
// Renders the Chill Zone brand logo (controller + lightning) from the asset,
// presented as a rounded dark badge so it sits cleanly on any background.

class XOBattleLogo extends StatelessWidget {
  final double size;
  const XOBattleLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5CFF3B).withValues(alpha: 0.18),
            blurRadius: size * 0.12,
            spreadRadius: size * 0.01,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/chillzone_logo.png',
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

// Keep the old class name as alias so nothing else needs updating
typedef ChillingZoneLogo = XOBattleLogo;

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
