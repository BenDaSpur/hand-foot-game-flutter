import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/card.dart';
import '../theme/balatro_theme.dart';

class PlayingCardWidget extends StatelessWidget {
  final PlayingCard card;
  final bool isSelected;
  final bool isKeyboardFocused;
  final bool isPlayable;
  final bool isNewlyDrawn;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final bool isInMeld; // Lighter shadows for meld display
  /// When false, skips outer glows/depth shadows (dense grids/modals).
  final bool showShadow;

  static const double cardMargin = 2.0;
  static const double cardCornerRadius = 12.0;

  /// Shared playable-treatment values (subtle green highlight).
  static const double playableBorderWidth = 1.5;
  static const double playableInnerGlowBlur = 6.0;
  static const double playableInnerGlowSpread = 1.0;
  static const double playableInnerGlowAlpha = 0.5;
  static const double playableOuterGlowBlur = 12.0;
  static const double playableOuterGlowSpread = 2.0;
  static const double playableOuterGlowAlpha = 0.2;
  static const double playableUpwardGlowBlur = 8.0;
  static const double playableUpwardGlowSpread = 1.0;
  static const double playableUpwardGlowAlpha = 0.45;
  static const Offset playableUpwardGlowOffset = Offset(0, -3);

  /// Shared depth shadow for playable and default hand cards.
  static const Offset handDepthShadowOffset = Offset(2, 3);
  static const double handDepthShadowBlur = 6.0;
  static const double handDepthShadowSpread = 0.0;
  static const BoxShadow handDepthShadow = BoxShadow(
    color: Colors.black,
    offset: handDepthShadowOffset,
    blurRadius: handDepthShadowBlur,
    spreadRadius: handDepthShadowSpread,
  );

  /// Left-edge in-face cue width. Fan overlap buries side/outer glow on
  /// mid-hand cards; this strip stays visible in the peeking left edge.
  static const double playableFaceStripeWidth = 3.0;
  static const double playableFaceStripeAlpha = 0.85;
  static const Key playableFaceStripeKey = ValueKey('playable-face-stripe');

  const PlayingCardWidget({
    super.key,
    required this.card,
    this.isSelected = false,
    this.isKeyboardFocused = false,
    this.isPlayable = false,
    this.isNewlyDrawn = false,
    this.onTap,
    this.width = 60,
    this.height = 84,
    this.isInMeld = false,
    this.showShadow = true,
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
          // Shadow layer stays unclipped so selection/playable glows don't
          // composite as a dark smear on the card face (esp. on iOS).
          child: Container(
            width: width,
            height: height,
            margin: const EdgeInsets.all(cardMargin),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cardCornerRadius),
              boxShadow: showShadow ? _cardBoxShadows() : const [],
            ),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: BalatroTheme.cardBackground,
                gradient: BalatroTheme.cardGradient,
                border: Border.all(
                  color: isSelected
                      ? BalatroTheme.glowColor
                      : isKeyboardFocused
                      ? BalatroTheme.neonBlue
                      : isNewlyDrawn
                      ? BalatroTheme.neonYellow
                      : isPlayable
                      ? BalatroTheme.neonGreen
                      : BalatroTheme.cardBorder,
                  width: isSelected
                      ? 3
                      : isKeyboardFocused
                      ? 2
                      : isNewlyDrawn
                      ? 2
                      : isPlayable
                      ? playableBorderWidth
                      : 1,
                ),
                borderRadius: BorderRadius.circular(cardCornerRadius),
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // In-face cue: survives fan overlap burying outer/side glow
                  // (visible on the peeking left strip of mid-hand cards).
                  if (isPlayable && !isSelected && !isNewlyDrawn)
                    Positioned(
                      key: playableFaceStripeKey,
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: playableFaceStripeWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: BalatroTheme.neonGreen.withValues(
                            alpha: playableFaceStripeAlpha,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(cardCornerRadius),
                            bottomLeft: Radius.circular(cardCornerRadius),
                          ),
                        ),
                      ),
                    ),
                  // Holographic shimmer effect
                  if (card.isWild)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(cardCornerRadius),
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
                        top: _cornerInset(height),
                        left: _cornerInset(height),
                        child: Text(
                          _getCardDisplay(),
                          style: _getCardTextStyle(
                            fontSize: _rankFontSize(height),
                            fontWeight: FontWeight.bold,
                            color: _getCardColor(),
                            shadows: const [
                              // Dark outline for visibility on dark background
                              Shadow(
                                color: Colors.black,
                                offset: Offset(1, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Bottom-right rank (rotated). RotatedBox keeps layout bounds
                      // correct so the index stays inside small pile cards.
                      Positioned(
                        bottom: _cornerInset(height),
                        right: _cornerInset(height),
                        child: RotatedBox(
                          quarterTurns: 2,
                          child: Text(
                            _getCardDisplay(),
                            style: _getCardTextStyle(
                              fontSize: _rankFontSize(height),
                              fontWeight: FontWeight.bold,
                              color: _getCardColor(),
                              shadows: const [
                                // Dark outline for visibility on dark background
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(1, 1),
                                  blurRadius: 2,
                                ),
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
      ),
    );
  }

  List<BoxShadow> _cardBoxShadows() {
    if (isSelected) {
      return [
        BoxShadow(
          color: BalatroTheme.glowColor.withValues(alpha: 0.7),
          blurRadius: 8,
          spreadRadius: 1,
        ),
        BoxShadow(
          color: BalatroTheme.glowColor.withValues(alpha: 0.4),
          blurRadius: 16,
          spreadRadius: 3,
        ),
        BoxShadow(
          color: BalatroTheme.glowColor.withValues(alpha: 0.2),
          blurRadius: 24,
          spreadRadius: 6,
        ),
      ];
    }
    if (isNewlyDrawn) {
      return [
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
      ];
    }
    if (isPlayable) {
      return [
        handDepthShadow,
        BoxShadow(
          color: BalatroTheme.neonGreen.withValues(
            alpha: playableUpwardGlowAlpha,
          ),
          blurRadius: playableUpwardGlowBlur,
          spreadRadius: playableUpwardGlowSpread,
          offset: playableUpwardGlowOffset,
        ),
        BoxShadow(
          color: BalatroTheme.neonGreen.withValues(
            alpha: playableInnerGlowAlpha,
          ),
          blurRadius: playableInnerGlowBlur,
          spreadRadius: playableInnerGlowSpread,
        ),
        BoxShadow(
          color: BalatroTheme.neonGreen.withValues(
            alpha: playableOuterGlowAlpha,
          ),
          blurRadius: playableOuterGlowBlur,
          spreadRadius: playableOuterGlowSpread,
        ),
      ];
    }
    if (card.isWild) {
      return [
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
      ];
    }
    if (isInMeld) {
      return [
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
      ];
    }
    return [
      handDepthShadow,
      BoxShadow(
        color: BalatroTheme.cardBorder.withValues(alpha: 0.45),
        blurRadius: 4,
        spreadRadius: 0,
      ),
    ];
  }

  /// Corner rank size scales with card height so pile/meld cards don't collide.
  static double _rankFontSize(double height) {
    if (height >= 90) {
      return 18;
    }
    if (height >= 75) {
      return 14;
    }
    if (height >= 60) {
      return 12;
    }
    return 10;
  }

  static double _cornerInset(double height) {
    if (height >= 75) {
      return 4;
    }
    return 2;
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
    final size = height >= 90
        ? 30.0
        : height >= 75
        ? 22.0
        : height >= 60
        ? 16.0
        : 12.0;

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

    // No BoxShadow on the suit — a transparent container's shadow composites
    // as a dark oval on the card face when selected (especially on iOS).
    return SizedBox(
      width: size + 10,
      height: size + 10,
      child: Center(child: suitWidget),
    );
  }
}
