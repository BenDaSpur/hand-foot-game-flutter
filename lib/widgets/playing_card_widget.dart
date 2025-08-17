import 'package:flutter/material.dart';
import '../models/card.dart';
import '../theme/balatro_theme.dart';

class PlayingCardWidget extends StatelessWidget {
  final PlayingCard card;
  final bool isSelected;
  final bool isPlayable;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const PlayingCardWidget({
    super.key,
    required this.card,
    this.isSelected = false,
    this.isPlayable = false,
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
                  : isPlayable
                  ? BalatroTheme.neonGreen
                  : BalatroTheme.cardBorder,
              width: isSelected ? 3 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (isSelected) ...[
                BoxShadow(
                  color: BalatroTheme.glowColor.withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: BalatroTheme.glowColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ] else if (isPlayable) ...[
                BoxShadow(
                  color: BalatroTheme.neonGreen.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ] else ...[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  offset: const Offset(2, 4),
                  blurRadius: 6,
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
                        fontSize: height > 60 ? 28 : 16,
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
                        fontSize: height > 60 ? 12 : 9,
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
                          fontSize: height > 60 ? 12 : 9,
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
