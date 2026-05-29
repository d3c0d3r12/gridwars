import 'package:flutter/material.dart';

// ── Background / Canvas ─────────────────────────────────────────────────────
final Color bgColor        = const Color(0xFFF4F5F8); // cool near-white
final Color surfaceColor   = const Color(0xFFFFFFFF); // card surface
final Color surface2Color  = const Color(0xFFF9FAFC); // subtle surface tint

// ── Ink / Text ───────────────────────────────────────────────────────────────
final Color inkColor  = const Color(0xFF181A20); // primary text
final Color ink2Color = const Color(0xFF565A66); // secondary text
final Color ink3Color = const Color(0xFF9A9EAC); // muted text

// ── Borders ──────────────────────────────────────────────────────────────────
final Color lineColor  = const Color(0xFFE7E9EF);
final Color line2Color = const Color(0xFFEFF1F5);

// ── Brand accents ─────────────────────────────────────────────────────────────
final Color xColor     = const Color(0xFF4B4EE6); // indigo — X / primary accent
final Color xSoft      = const Color(0xFF4B4EE6).withValues(alpha: 0.10);
final Color xSoft2     = const Color(0xFF4B4EE6).withValues(alpha: 0.16);
final Color oColor     = const Color(0xFFFB6B5B); // coral — O accent
final Color oSoft      = const Color(0xFFFB6B5B).withValues(alpha: 0.12);
final Color oSoft2     = const Color(0xFFFB6B5B).withValues(alpha: 0.18);
final Color goldColor  = const Color(0xFFECA13A); // gold — coins / ranking
final Color goldSoft   = const Color(0xFFECA13A).withValues(alpha: 0.14);
final Color goodColor  = const Color(0xFF19B36B); // green — wins / positive

// ── Legacy aliases (backward compat — semantic meaning updated) ───────────────
// These keep the same variable name so existing code that uses them still
// compiles; their VALUES have been updated to the new light-theme equivalents.
final Color primaryColor           = bgColor;       // was dark bg → now light bg
final Color secondaryColor         = surfaceColor;  // was dark card → now white card
final Color secondarySelectedColor = xColor;        // was amber → now indigo accent
final Color white                  = const Color(0xFFFFFFFF);
final Color lightWhite             = const Color(0xFFE9E9E9);
final Color back                   = const Color(0xFFF1F1F1);
final Color yellow                 = goldColor;     // was amber gold — keep
final Color red                    = const Color(0xFFFF4757);
final Color grey                   = Colors.grey;

// ── Shadows ───────────────────────────────────────────────────────────────────
const BoxShadow shadowSm = BoxShadow(color: Color(0x0D141623), blurRadius: 2, offset: Offset(0, 1));
const BoxShadow shadow   = BoxShadow(color: Color(0x29161C2D), blurRadius: 18, spreadRadius: -8, offset: Offset(0, 6));
const BoxShadow shadowLg = BoxShadow(color: Color(0x4D1C203C), blurRadius: 48, spreadRadius: -20, offset: Offset(0, 22));

// ── Card decoration shortcut ──────────────────────────────────────────────────
BoxDecoration cardDecoration({double radius = 22, Color? bg}) => BoxDecoration(
  color: bg ?? surfaceColor,
  border: Border.all(color: lineColor, width: 1),
  borderRadius: BorderRadius.circular(radius),
  boxShadow: [shadowSm],
);
