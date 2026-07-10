import 'package:flutter/material.dart';
import '../theme/balatro_theme.dart';

/// Face-down playing card used for deck draw animations.
class CardBackWidget extends StatelessWidget {
  final double width;
  final double height;

  const CardBackWidget({super.key, this.width = 70, this.height = 98});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A1F5C), Color(0xFF1A0F2E)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BalatroTheme.glowColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: BalatroTheme.glowColor.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              Icons.style,
              color: BalatroTheme.neonPink.withValues(alpha: 0.8),
              size: width * 0.35,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: BalatroTheme.neonBlue.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
