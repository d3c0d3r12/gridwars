import 'package:flutter/material.dart';
import '../../helpers/color.dart';

Widget gameHeader(
    BuildContext ctx,
    String title,
    String sub,
    int myScore,
    int oppScore, {
      VoidCallback? onExit,
    }) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    child: Row(children: [
      GestureDetector(
        onTap: onExit ?? () {
          if (Navigator.canPop(ctx)) Navigator.pop(ctx);
        },
        child: Icon(Icons.close, color: inkColor.withValues(alpha: 0.7)),
      ),
      const Spacer(),
      Column(children: [
        Text(title, style: TextStyle(color: inkColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
        Text(sub, style: TextStyle(color: xColor, fontSize: 11)),
      ]),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: secondaryColor),
        child: Text('$myScore — $oppScore', style: TextStyle(color: inkColor, fontWeight: FontWeight.bold)),
      ),
    ]),
  );
}

Widget gamePill(String text, Color color) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      color: color.withValues(alpha: 0.12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
  );
}

void showGameResult(BuildContext context, bool won, int entryFee) {
  showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
    backgroundColor: surfaceColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: xColor.withValues(alpha: 0.4))),
    title: Text(won ? '🏆 You Win!' : '😔 You Lose', style: TextStyle(color: inkColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
    content: Text(won ? '+${entryFee * 2} coins!' : 'Better luck next time', style: TextStyle(color: xColor, fontSize: 16), textAlign: TextAlign.center),
    actions: [TextButton(onPressed: () {
      if (Navigator.canPop(context)) Navigator.pop(context);
      if (Navigator.canPop(context)) Navigator.pop(context);
    }, child: Text('Back', style: TextStyle(color: xColor)))],
  ));
}

void showOpponentLeftDialog(BuildContext context) {
  showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
    backgroundColor: surfaceColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: xColor.withValues(alpha: 0.4))),
    title: Text('🏆 You Win!', style: TextStyle(color: inkColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
    content: Text('Opponent left the game.', style: TextStyle(color: xColor, fontSize: 15), textAlign: TextAlign.center),
    actions: [TextButton(onPressed: () {
      if (Navigator.canPop(context)) Navigator.pop(context);
      if (Navigator.canPop(context)) Navigator.pop(context);
    }, child: Text('Back', style: TextStyle(color: xColor)))],
  ));
}

void showLeaveConfirmDialog(BuildContext context, VoidCallback onConfirm) {
  showDialog(context: context, barrierDismissible: true, builder: (_) => AlertDialog(
    backgroundColor: surfaceColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: xColor.withValues(alpha: 0.4))),
    title: Text('Leave Game?', style: TextStyle(color: inkColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
    content: Text('Your opponent wins if you leave.', style: TextStyle(color: inkColor.withValues(alpha: 0.7), fontSize: 14), textAlign: TextAlign.center),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text('Stay', style: TextStyle(color: xColor))),
      TextButton(
        onPressed: () {
          Navigator.pop(context);
          onConfirm();
        },
        child: Text('Leave', style: TextStyle(color: red)),
      ),
    ],
  ));
}