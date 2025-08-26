import 'package:flutter/material.dart';
import '../models/card.dart';
import '../theme/balatro_theme.dart';

class PlayingCardWidget extends StatelessWidget {
  final PlayingCard card;
  final bool isSelected;
  final bool isPlayable;
  final bool isNewlyDrawn;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final bool isInMeld; // Lighter shadows for meld display

  const PlayingCardWidget({
    super.key,
    required this.card,
    this.isSelected = false,
    this.isPlayable = false,
    this.isNewlyDrawn = false,
    this.onTap,
    this.width = 60,
    this.height = 84,
    this.isInMeld = false,
  });

  @override
  Widget build(BuildContext context) {
    // Force a full repaint to ensure styling is applied
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Transform.translate(
          offset: Offset(0, isSelected ? -12 : 0),
          child: Container(
            width: width,
            height: height,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: BalatroTheme.cardBackground, // Fallback color
              gradient: BalatroTheme.cardGradient,
              border: Border.all(
                color: isSelected
                    ? BalatroTheme.glowColor
                    : isNewlyDrawn
                    ? BalatroTheme.neonYellow
                    : isPlayable
                    ? BalatroTheme.neonGreen
                    : BalatroTheme.cardBorder,
                width: isSelected
                    ? 3
                    : isNewlyDrawn
                    ? 2
                    : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                if (isSelected) ...[
                  // Bright inner glow
                  BoxShadow(
                    color: BalatroTheme.glowColor.withValues(alpha: 0.7),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                  // Outer glow for selection
                  BoxShadow(
                    color: BalatroTheme.glowColor.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 3,
                  ),
                  // Far glow for extra effect
                  BoxShadow(
                    color: BalatroTheme.glowColor.withValues(alpha: 0.2),
                    blurRadius: 24,
                    spreadRadius: 6,
                  ),
                ] else if (isNewlyDrawn) ...[
                  // Newly drawn cards get yellow glow
                  BoxShadow(
                    color: BalatroTheme.neonYellow.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: BalatroTheme.neonYellow.withValues(alpha: 0.3),
                    blurRadius: 14,
                    spreadRadius: 3,
                  ),
                ] else if (isPlayable) ...[
                  // Playable cards get green glow
                  BoxShadow(
                    color: BalatroTheme.neonGreen.withValues(alpha: 0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: BalatroTheme.neonGreen.withValues(alpha: 0.2),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ] else if (card.isWild) ...[
                  // Wild cards always have subtle rainbow glow
                  BoxShadow(
                    color: BalatroTheme.neonPink.withValues(alpha: 0.3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: BalatroTheme.glowColor.withValues(alpha: 0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ] else if (isInMeld) ...[
                  // Subtle shadows for meld display
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: const Offset(1, 2),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: BalatroTheme.cardBorder.withValues(alpha: 0.2),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ] else ...[
                  // Strong Balatro styling for hand cards
                  const BoxShadow(
                    color: Colors.black,
                    offset: Offset(2, 3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: BalatroTheme.cardBorder.withValues(alpha: 0.7),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: BalatroTheme.glowColor.withValues(alpha: 0.3),
                    blurRadius: 14,
                    spreadRadius: 3,
                  ),
                  BoxShadow(
                    color: BalatroTheme.neonPink.withValues(alpha: 0.2),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ],
            ),
            child: Stack(
              children: [
                // Holographic shimmer effect
                if (card.isWild)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          BalatroTheme.neonPink.withValues(alpha: 0.1),
                          BalatroTheme.neonBlue.withValues(alpha: 0.1),
                          BalatroTheme.glowColor.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                  ),
                // Card content with absolute positioning for corners
                Stack(
                  children: [
                    // Center suit symbol - use custom widget to avoid font color issues
                    Center(child: _buildSuitSymbol(height)),
                    // Top-left rank
                    Positioned(
                      top: height > 60 ? 4 : 2,
                      left: height > 60 ? 4 : 2,
                      child: Text(
                        _getCardDisplay(),
                        style: TextStyle(
                          fontSize: height > 60 ? 14 : 11,
                          fontWeight: FontWeight.bold,
                          color: _getCardColor(),
                          shadows: [
                            // Dark outline for visibility on dark background
                            const Shadow(
                              color: Colors.black,
                              offset: Offset(1, 1),
                              blurRadius: 2,
                            ),
                            if (isSelected)
                              Shadow(color: _getCardColor(), blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                    // Bottom-right rank (rotated)
                    Positioned(
                      bottom: height > 60 ? 4 : 2,
                      right: height > 60 ? 4 : 2,
                      child: Transform.rotate(
                        angle: 3.14159,
                        child: Text(
                          _getCardDisplay(),
                          style: TextStyle(
                            fontSize: height > 60 ? 14 : 11,
                            fontWeight: FontWeight.bold,
                            color: _getCardColor(),
                            shadows: [
                              // Dark outline for visibility on dark background
                              const Shadow(
                                color: Colors.black,
                                offset: Offset(1, 1),
                                blurRadius: 2,
                              ),
                              if (isSelected)
                                Shadow(color: _getCardColor(), blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getCardDisplay() {
    if (card.isJoker) return 'JK';

    switch (card.rank) {
      case CardRank.ace:
        return 'A';
      case CardRank.jack:
        return 'J';
      case CardRank.queen:
        return 'Q';
      case CardRank.king:
        return 'K';
      case CardRank.ten:
        return '10';
      default:
        return card.meldValue.toString();
    }
  }

  Color _getCardColor() {
    // Return explicit color values to ensure persistence
    if (card.isJoker) return const Color(0xFFFF1493); // Deep pink for joker
    if (card.isWild) return const Color(0xFF64ffda); // Glow color for wilds

    switch (card.suit) {
      case Suit.hearts:
        return const Color(0xFFe91e63); // Bright pink/red
      case Suit.diamonds:
        return const Color(0xFFff5722); // Bright orange
      case Suit.clubs:
        return const Color(0xFF81c784); // Light green
      case Suit.spades:
        return const Color(0xFF90caf9); // Light blue
      case null:
        return const Color(0xFFe0e0e0); // Light gray for null suit
    }
  }

  Widget _buildSuitSymbol(double height) {
    final color = _getCardColor();
    final size = height > 60 ? 30.0 : 18.0;

    if (card.isJoker) {
      // Use text for joker
      return Container(
        width: size + 10,
        height: size + 10,
        alignment: Alignment.center,
        child: Text(
          'JK',
          style: TextStyle(
            fontSize: size * 0.6,
            color: color,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.none,
          ),
        ),
      );
    }

    // Use custom painted shapes to ensure color persistence
    Widget suitWidget;
    switch (card.suit!) {
      case Suit.hearts:
        suitWidget = CustomPaint(
          size: Size(size, size),
          painter: HeartPainter(color: color),
        );
        break;
      case Suit.diamonds:
        suitWidget = CustomPaint(
          size: Size(size, size),
          painter: DiamondPainter(color: color),
        );
        break;
      case Suit.clubs:
        suitWidget = CustomPaint(
          size: Size(size, size),
          painter: ClubPainter(color: color),
        );
        break;
      case Suit.spades:
        suitWidget = CustomPaint(
          size: Size(size, size),
          painter: SpadePainter(color: color),
        );
        break;
    }

    // Add glow effect for selected or wild cards
    if (isSelected || card.isWild) {
      return Container(
        width: size + 10,
        height: size + 10,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.6),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(child: suitWidget),
      );
    }

    return SizedBox(
      width: size + 10,
      height: size + 10,
      child: Center(child: suitWidget),
    );
  }
}

// Custom painters for suit symbols that respect color
class HeartPainter extends CustomPainter {
  final Color color;
  HeartPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final width = size.width;
    final height = size.height;

    // Draw heart shape
    path.moveTo(width * 0.5, height * 0.25);
    path.cubicTo(
      width * 0.2,
      height * 0.1,
      width * 0.1,
      height * 0.3,
      width * 0.1,
      height * 0.4,
    );
    path.cubicTo(
      width * 0.1,
      height * 0.55,
      width * 0.5,
      height * 0.9,
      width * 0.5,
      height * 0.9,
    );
    path.cubicTo(
      width * 0.5,
      height * 0.9,
      width * 0.9,
      height * 0.55,
      width * 0.9,
      height * 0.4,
    );
    path.cubicTo(
      width * 0.9,
      height * 0.3,
      width * 0.8,
      height * 0.1,
      width * 0.5,
      height * 0.25,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DiamondPainter extends CustomPainter {
  final Color color;
  DiamondPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final width = size.width;
    final height = size.height;

    // Draw diamond shape
    path.moveTo(width * 0.5, height * 0.1);
    path.lineTo(width * 0.9, height * 0.5);
    path.lineTo(width * 0.5, height * 0.9);
    path.lineTo(width * 0.1, height * 0.5);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ClubPainter extends CustomPainter {
  final Color color;
  ClubPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final width = size.width;
    final height = size.height;

    // Draw three circles for club
    canvas.drawCircle(Offset(width * 0.3, height * 0.5), width * 0.2, paint);
    canvas.drawCircle(Offset(width * 0.7, height * 0.5), width * 0.2, paint);
    canvas.drawCircle(Offset(width * 0.5, height * 0.3), width * 0.2, paint);

    // Draw stem
    final stemPath = Path();
    stemPath.moveTo(width * 0.5, height * 0.5);
    stemPath.lineTo(width * 0.45, height * 0.9);
    stemPath.lineTo(width * 0.55, height * 0.9);
    stemPath.close();
    canvas.drawPath(stemPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SpadePainter extends CustomPainter {
  final Color color;
  SpadePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // ----- Spade head: exact vertical flip of your heart -----
    final head = Path()
      // Start at the bottom cusp (mirror of heart’s top seam)
      ..moveTo(w * 0.5, h * 0.75)
      // Left lobe up toward the tip
      ..cubicTo(
        w * 0.2,
        h * 0.90, // was (0.2, 0.10) -> flipped
        w * 0.1,
        h * 0.70, // was (0.1, 0.30)
        w * 0.1,
        h * 0.60, // was (0.1, 0.40)
      )
      // Into the sharp top point
      ..cubicTo(
        w * 0.1,
        h * 0.45, // was (0.1, 0.55)
        w * 0.5,
        h * 0.10, // was (0.5, 0.90)  <-- tip’s handle = tip -> sharp
        w * 0.5,
        h * 0.10, // tip (sharp)
      )
      // Down the right lobe (mirror)
      ..cubicTo(
        w * 0.5,
        h * 0.10, // tip’s handle = tip
        w * 0.9,
        h * 0.45, // was (0.9, 0.55)
        w * 0.9,
        h * 0.60, // was (0.9, 0.40)
      )
      // Back to the bottom cusp
      ..cubicTo(
        w * 0.9,
        h * 0.70, // was (0.9, 0.30)
        w * 0.8,
        h * 0.90, // was (0.8, 0.10)
        w * 0.5,
        h * 0.75, // was (0.5, 0.25)
      )
      ..close();

    canvas.drawPath(head, paint);

    // ----- Stem: small pedestal + tiny foot (card-style) -----
    final cx = w * 0.5;
    final stemTopY = h * 0.75; // attaches at the cusp
    final neckHalf = w * 0.06;
    final baseHalf = w * 0.09;
    final baseY = h * 0.90;
    final footY = h * 0.96;
    final footHalf = w * 0.03;

    final stem = Path()
      ..moveTo(cx - neckHalf, stemTopY)
      ..quadraticBezierTo(cx, stemTopY + h * 0.03, cx + neckHalf, stemTopY)
      ..lineTo(cx + baseHalf, baseY)
      ..lineTo(cx - baseHalf, baseY)
      ..close();

    final foot = Path()
      ..moveTo(cx, baseY)
      ..lineTo(cx - footHalf, footY)
      ..lineTo(cx + footHalf, footY)
      ..close();

    canvas.drawPath(stem, paint);
    canvas.drawPath(foot, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
