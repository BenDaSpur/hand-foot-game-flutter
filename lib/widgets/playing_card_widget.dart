import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  /// Get TextStyle for card text
  static TextStyle _getCardTextStyle({
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.bold,
    TextDecoration decoration = TextDecoration.none,
    List<Shadow>? shadows,
  }) {
    // Use system font for test compatibility
    return TextStyle(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      decoration: decoration,
      shadows: shadows,
    );
  }

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
                        style: _getCardTextStyle(
                          fontSize: height > 60 ? 18 : 14,
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
                          style: _getCardTextStyle(
                            fontSize: height > 60 ? 18 : 14,
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

  String _getSuitAssetPath() {
    switch (card.suit) {
      case Suit.hearts:
        return 'assets/images/heart.svg';
      case Suit.diamonds:
        return 'assets/images/diamond.svg';
      case Suit.clubs:
        return 'assets/images/clover.svg';
      case Suit.spades:
        return 'assets/images/spade.svg';
      case null:
        return '';
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
          '🃏', // Jester/playing card emoji
          style: _getCardTextStyle(
            fontSize: size * 0.8, // Slightly larger for emoji
            color: color,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.none,
          ),
        ),
      );
    }

    // Use SVG assets instead of Unicode symbols
    final assetPath = _getSuitAssetPath();
    if (assetPath.isEmpty) {
      // Fallback for null suit
      return SizedBox(width: size + 10, height: size + 10);
    }

    Widget suitWidget = SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );

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
