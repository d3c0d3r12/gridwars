import 'package:flutter/material.dart';
import '../widgets/xo_logo.dart';

import '../helpers/color.dart';
import '../helpers/constant.dart';
import 'home_screen.dart';
import 'splash.dart';

class HowToPlay extends StatelessWidget {
  const HowToPlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: lineColor),
            ),
            child: Icon(Icons.arrow_back_rounded, color: inkColor, size: 18),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CoinWidget(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const XOBattleLogo(size: 110),
            const SizedBox(height: 28),
            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: lineColor),
                boxShadow: [shadowSm],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    utils.getTranslated(context, "howToPlayHeading"),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: inkColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    utils.getTranslated(context, "howToPlayContent"),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: ink2Color,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: xColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: xColor.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          utils.getTranslated(context, "ok"),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
