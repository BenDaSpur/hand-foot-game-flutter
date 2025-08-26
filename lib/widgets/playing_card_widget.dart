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

  const PlayingCardWidget({
    super.key,
    required this.card,
    this.isSelected = false,
    this.isPlayable = false,
    this.isNewlyDrawn = false,
    this.onTap,
    this.width = 60,
    this.height = 84,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Transform.translate(
        offset: isSelected ? const Offset(0, -12) : Offset.zero,
        child: Container(
          width: width,
          height: height,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
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
              ] else ...[
                // Enhanced default Balatro styling - ALWAYS visible neon theme
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  offset: const Offset(2, 4),
                  blurRadius: 10,
                ),
                // Strong neon border that's always visible
                BoxShadow(
                  color: BalatroTheme.cardBorder.withValues(alpha: 0.6),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
                // Balatro signature glow
                BoxShadow(
                  color: BalatroTheme.glowColor.withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 3,
                ),
                // Additional neon accent
                BoxShadow(
                  color: BalatroTheme.neonPink.withValues(alpha: 0.1),
                  blurRadius: 12,
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
                  // Center suit symbol
                  Center(
                    child: Text(
                      _getSuitSymbol(),
                      style: TextStyle(
                        fontSize: height > 60 ? 30 : 18,
                        color: _getCardColor(),
                        shadows: [
                          // Dark outline for all cards to improve visibility
                          const Shadow(
                            color: Colors.black,
                            offset: Offset(1.5, 1.5),
                            blurRadius: 3,
                          ),
                          if (isSelected || card.isWild)
                            Shadow(color: _getCardColor(), blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
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

  String _getSuitSymbol() {
    if (card.isJoker) return '🃏';

    switch (card.suit!) {
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
      case Suit.spades:
        return '♠';
    }
  }

  Color _getCardColor() {
    if (card.isJoker) return BalatroTheme.neonPink;
    if (card.isWild) return BalatroTheme.glowColor;

    switch (card.suit) {
      case Suit.hearts:
        return BalatroTheme.heartsColor;
      case Suit.diamonds:
        return BalatroTheme.diamondsColor;
      case Suit.clubs:
        return BalatroTheme.clubsColor;
      case Suit.spades:
        return BalatroTheme.spadesColor;
      case null:
        return BalatroTheme.primaryText;
    }
  }
}
