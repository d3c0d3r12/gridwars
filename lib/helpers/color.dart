import 'package:flutter/material.dart';

// ── All color variables are mutable so ThemeManager can hot-swap them ─────────

// Background / Canvas
Color bgColor        = const Color(0xFFF4F5F8);
Color surfaceColor   = const Color(0xFFFFFFFF);
Color surface2Color  = const Color(0xFFF9FAFC);

// Ink / Text
Color inkColor  = const Color(0xFF181A20);
Color ink2Color = const Color(0xFF565A66);
Color ink3Color = const Color(0xFF9A9EAC);

// Borders
Color lineColor  = const Color(0xFFE7E9EF);
Color line2Color = const Color(0xFFEFF1F5);

// Brand accents (same in both themes)
Color xColor    = const Color(0xFF4B4EE6);
Color xSoft     = const Color(0xFF4B4EE6).withValues(alpha: 0.10);
Color xSoft2    = const Color(0xFF4B4EE6).withValues(alpha: 0.16);
Color oColor    = const Color(0xFFFB6B5B);
Color oSoft     = const Color(0xFFFB6B5B).withValues(alpha: 0.12);
Color oSoft2    = const Color(0xFFFB6B5B).withValues(alpha: 0.18);
Color goldColor = const Color(0xFFECA13A);
Color goldSoft  = const Color(0xFFECA13A).withValues(alpha: 0.14);
Color goodColor = const Color(0xFF19B36B);

// Legacy aliases
Color primaryColor           = bgColor;
Color secondaryColor         = surfaceColor;
Color secondarySelectedColor = xColor;
Color white                  = const Color(0xFFFFFFFF);
Color lightWhite             = const Color(0xFFE9E9E9);
Color back                   = const Color(0xFFF1F1F1);
Color yellow                 = goldColor;
Color red                    = const Color(0xFFFF4757);
Color grey                   = Colors.grey;

// Shadows
const BoxShadow shadowSm = BoxShadow(color: Color(0x0D141623), blurRadius: 2, offset: Offset(0, 1));
const BoxShadow shadow   = BoxShadow(color: Color(0x29161C2D), blurRadius: 18, spreadRadius: -8, offset: Offset(0, 6));
const BoxShadow shadowLg = BoxShadow(color: Color(0x4D1C203C), blurRadius: 48, spreadRadius: -20, offset: Offset(0, 22));

BoxDecoration cardDecoration({double radius = 22, Color? bg}) => BoxDecoration(
  color: bg ?? surfaceColor,
  border: Border.all(color: lineColor, width: 1),
  borderRadius: BorderRadius.circular(radius),
  boxShadow: [shadowSm],
);

// ── Light theme values ─────────────────────────────────────────────────────────
void setLightTheme() {
  bgColor        = const Color(0xFFF4F5F8);
  surfaceColor   = const Color(0xFFFFFFFF);
  surface2Color  = const Color(0xFFF9FAFC);
  inkColor       = const Color(0xFF181A20);
  ink2Color      = const Color(0xFF565A66);
  ink3Color      = const Color(0xFF9A9EAC);
  lineColor      = const Color(0xFFE7E9EF);
  line2Color     = const Color(0xFFEFF1F5);
  xSoft          = const Color(0xFF4B4EE6).withValues(alpha: 0.10);
  xSoft2         = const Color(0xFF4B4EE6).withValues(alpha: 0.16);
  oSoft          = const Color(0xFFFB6B5B).withValues(alpha: 0.12);
  oSoft2         = const Color(0xFFFB6B5B).withValues(alpha: 0.18);
  goldSoft       = const Color(0xFFECA13A).withValues(alpha: 0.14);
  // legacy aliases
  primaryColor           = bgColor;
  secondaryColor         = surfaceColor;
  secondarySelectedColor = xColor;
}

// ── Dark theme values ──────────────────────────────────────────────────────────
void setDarkTheme() {
  bgColor        = const Color(0xFF0C0618);  // deep purple-black
  surfaceColor   = const Color(0xFF1E1040);  // rich violet card
  surface2Color  = const Color(0xFF150D35);  // slightly darker card
  inkColor       = const Color(0xFFFFFFFF);  // white text
  ink2Color      = const Color(0xFFFFFFFF).withValues(alpha: 0.65);
  ink3Color      = const Color(0xFFFFFFFF).withValues(alpha: 0.38);
  lineColor      = const Color(0xFFFFFFFF).withValues(alpha: 0.12);
  line2Color     = const Color(0xFFFFFFFF).withValues(alpha: 0.07);
  xSoft          = const Color(0xFF4B4EE6).withValues(alpha: 0.22);
  xSoft2         = const Color(0xFF4B4EE6).withValues(alpha: 0.32);
  oSoft          = const Color(0xFFFB6B5B).withValues(alpha: 0.20);
  oSoft2         = const Color(0xFFFB6B5B).withValues(alpha: 0.28);
  goldSoft       = const Color(0xFFECA13A).withValues(alpha: 0.20);
  // legacy aliases
  primaryColor           = bgColor;
  secondaryColor         = surfaceColor;
  secondarySelectedColor = xColor;
}
