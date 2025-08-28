import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/card.dart';
import '../theme/balatro_theme.dart';
import 'playing_card_widget.dart';

/// Reusable hand display widget that matches single-player styling exactly
/// Used by both single-player and multiplayer screens for consistency
class GameHandDisplay extends StatelessWidget {
  final Player player;
  final List<int> selectedCardIndices;
  final Function(int)? onCardTap;
  final Function(int)? onCardDoubleTap;
  final bool Function(PlayingCard)? isCardPlayable;
  final Player? viewingPlayerMelds;
  final VoidCallback? onReturnToHand;
  final bool isCurrentPlayerTurn; // Control opacity and interactions
  final bool showHighlights; // Control if highlights should be visible

  const GameHandDisplay({
    super.key,
    required this.player,
    required this.selectedCardIndices,
    this.onCardTap,
    this.onCardDoubleTap,
    this.isCardPlayable,
    this.viewingPlayerMelds,
    this.onReturnToHand,
    this.isCurrentPlayerTurn = true,
    this.showHighlights = true,
  });

  @override
  Widget build(BuildContext context) {
    // EXACT SINGLE-PLAYER HAND LAYOUT WITH PROPER OPACITY: Copy the structure exactly
    return Opacity(
      opacity: isCurrentPlayerTurn ? 1.0 : 0.7, // Same as single-player logic
      child: Container(
        height: 165, // Increased from 155 to give more space for selected cards
        padding: const EdgeInsets.fromLTRB(
          8,
          20,
          8,
          10,
        ), // Extra top padding for selection animation
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hand title (same as single-player)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: GestureDetector(
                onTap: onReturnToHand,
                child: Text(
                  () {
                    if (viewingPlayerMelds != null &&
                        viewingPlayerMelds != player) {
                      return 'Viewing ${viewingPlayerMelds!.name}\'s cards - Tap here to return to your hand';
                    }
                    return 'Your Hand (${player.currentHand.length} cards)';
                  }(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color:
                        viewingPlayerMelds != null &&
                            viewingPlayerMelds != player
                        ? BalatroTheme.neonYellow
                        : Colors.white,
                  ),
                ),
              ),
            ),
            // Hand cards (EXACT single-player layout)
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                  },
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  child: SizedBox(
                    width: player.currentHand.isNotEmpty
                        ? (player.currentHand.length - 1) * 50.0 + 70.0
                        : 70.0,
                    height:
                        120, // Increased height to accommodate selection animation
                    child: Stack(
                      clipBehavior: Clip
                          .none, // Allow cards to move outside bounds when selected
                      children: player.currentHand.asMap().entries.map((entry) {
                        final index = entry.key;
                        final card = entry.value;

                        return Positioned(
                          left: index * 50.0,
                          bottom:
                              5, // Position cards from bottom, leaving space at top for selection animation
                          child: GestureDetector(
                            onTap: onCardTap != null
                                ? () => onCardTap!(index)
                                : null,
                            onDoubleTap: onCardDoubleTap != null
                                ? () => onCardDoubleTap!(index)
                                : null,
                            child: PlayingCardWidget(
                              key: ValueKey(
                                'hand-${card.rank}-${card.suit}-$index-${viewingPlayerMelds?.id ?? "you"}',
                              ),
                              card: card,
                              width: 70,
                              height: 98,
                              isSelected: selectedCardIndices.contains(index),
                              isPlayable: isCardPlayable?.call(card) ?? false,
                              isNewlyDrawn:
                                  showHighlights &&
                                  index < player.currentHand.length &&
                                  player.isCardIndexNewlyDrawn(index),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ), // Close Container
    ); // Close Opacity
  }
}
