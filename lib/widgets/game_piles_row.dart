import 'package:flutter/material.dart';
import '../constants/hand_layout_constants.dart';
import '../models/game_state.dart';
import '../theme/balatro_theme.dart';
import 'card_back_widget.dart';
import 'playing_card_widget.dart';

/// Visual deck and discard piles used as animation source anchors.
class GamePilesRow extends StatelessWidget {
  final GameState gameState;
  final GlobalKey deckKey;
  final GlobalKey discardKey;

  const GamePilesRow({
    super.key,
    required this.gameState,
    required this.deckKey,
    required this.discardKey,
  });

  @override
  Widget build(BuildContext context) {
    final topDiscard = gameState.topDiscard;
    final deckLow = gameState.deck.size <= 20;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PileAnchor(
            key: deckKey,
            label: 'Deck',
            count: gameState.deck.size,
            countColor: deckLow ? Colors.red : BalatroTheme.neonYellow,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (gameState.deck.size > 1)
                  const Positioned(
                    left: 4,
                    top: -4,
                    child: CardBackWidget(width: 56, height: 78),
                  ),
                const CardBackWidget(width: 56, height: 78),
              ],
            ),
          ),
          const SizedBox(width: 28),
          _PileAnchor(
            key: discardKey,
            label: 'Discard',
            count: gameState.discardPile.length,
            countColor: BalatroTheme.glowColor,
            child: topDiscard == null
                ? _EmptyDiscardPile(
                    width: HandLayoutConstants.cardWidth * 0.8,
                    height: HandLayoutConstants.cardHeight * 0.8,
                  )
                : PlayingCardWidget(
                    card: topDiscard,
                    width: HandLayoutConstants.cardWidth * 0.8,
                    height: HandLayoutConstants.cardHeight * 0.8,
                  ),
          ),
        ],
      ),
    );
  }
}

class _PileAnchor extends StatelessWidget {
  final String label;
  final int count;
  final Color countColor;
  final Widget child;

  const _PileAnchor({
    super.key,
    required this.label,
    required this.count,
    required this.countColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        child,
        const SizedBox(height: 4),
        Text(
          '$count cards',
          style: TextStyle(
            color: countColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _EmptyDiscardPile extends StatelessWidget {
  final double width;
  final double height;

  const _EmptyDiscardPile({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: BalatroTheme.darkPurple.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(
          PlayingCardWidget.cornerRadiusForWidth(width),
        ),
        border: Border.all(
          color: BalatroTheme.cardBorder.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Icon(
        Icons.layers_clear,
        color: Colors.white24,
        size: width * 0.35,
      ),
    );
  }
}
