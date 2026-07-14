import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../constants/ui_constants.dart';
import '../models/player.dart';
import '../models/card.dart';
import '../theme/balatro_theme.dart';
import '../utils/game_responsive_layout.dart';
import 'card_animation_host.dart';
import 'playing_card_widget.dart';

/// Reusable hand display for solo and multiplayer with responsive card sizing.
class GameHandDisplay extends StatelessWidget {
  final Player player;
  final List<int> selectedCardIndices;
  final int? keyboardFocusedCardIndex;
  final Function(int)? onCardTap;
  final Function(int)? onCardDoubleTap;
  final bool Function(PlayingCard)? isCardPlayable;

  /// Preferred playable lookup by hand index (avoids equality edge cases).
  final Set<int>? playableCardIndices;
  final Player? viewingPlayerMelds;
  final VoidCallback? onReturnToHand;
  final bool isCurrentPlayerTurn;
  final bool showHighlights;
  final GlobalKey? handStackKey;
  final ScrollController? handScrollController;

  const GameHandDisplay({
    super.key,
    required this.player,
    required this.selectedCardIndices,
    this.keyboardFocusedCardIndex,
    this.onCardTap,
    this.onCardDoubleTap,
    this.isCardPlayable,
    this.playableCardIndices,
    this.viewingPlayerMelds,
    this.onReturnToHand,
    this.isCurrentPlayerTurn = true,
    this.showHighlights = true,
    this.handStackKey,
    this.handScrollController,
  });

  @override
  Widget build(BuildContext context) {
    final sizes = GameResponsiveLayout.handSizes(context);
    final stackHeight =
        sizes.handHeight + sizes.selectionLift + UIConstants.smallSpacing;

    return Opacity(
      opacity: isCurrentPlayerTurn ? 1.0 : 0.7,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: GestureDetector(
                onTap: onReturnToHand,
                child: Text(
                  () {
                    if (viewingPlayerMelds != null &&
                        viewingPlayerMelds != player) {
                      return 'Viewing ${viewingPlayerMelds!.name} — tap to return';
                    }
                    return 'Your Hand (${player.currentHand.length})';
                  }(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color:
                        viewingPlayerMelds != null &&
                            viewingPlayerMelds != player
                        ? BalatroTheme.neonYellow
                        : Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            SizedBox(
              height: stackHeight,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                  },
                ),
                child: SingleChildScrollView(
                  controller: handScrollController,
                  scrollDirection: Axis.horizontal,
                  // Keep glow shadows visible on edge cards (pairs of 4s/5s etc.)
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(
                    horizontal: UIConstants.handGlowPadding,
                  ),
                  child: SizedBox(
                    width: sizes.handStackWidth(player.currentHand.length),
                    height: stackHeight,
                    child: Stack(
                      key: handStackKey,
                      clipBehavior: Clip.none,
                      children: player.currentHand.asMap().entries.map((entry) {
                        final index = entry.key;
                        final card = entry.value;
                        final hideDuringAnimation =
                            CardAnimationScope.shouldHideHandCard(
                              context,
                              index,
                            );
                        final isPlayable = playableCardIndices != null
                            ? playableCardIndices!.contains(index)
                            : (isCardPlayable?.call(card) ?? false);

                        return Positioned(
                          left: sizes.handCardLeft(index),
                          bottom: 0,
                          child: GestureDetector(
                            onTap: onCardTap != null && !hideDuringAnimation
                                ? () => onCardTap!(index)
                                : null,
                            onDoubleTap:
                                onCardDoubleTap != null && !hideDuringAnimation
                                ? () => onCardDoubleTap!(index)
                                : null,
                            child: Opacity(
                              opacity: hideDuringAnimation ? 0 : 1,
                              child: PlayingCardWidget(
                                key: ValueKey(
                                  'hand-${card.rank}-${card.suit}-$index-${viewingPlayerMelds?.id ?? "you"}',
                                ),
                                card: card,
                                width: sizes.handWidth,
                                height: sizes.handHeight,
                                isSelected: selectedCardIndices.contains(index),
                                isKeyboardFocused:
                                    keyboardFocusedCardIndex == index,
                                isPlayable: isPlayable,
                                isNewlyDrawn:
                                    showHighlights &&
                                    index < player.currentHand.length &&
                                    player.isCardIndexNewlyDrawn(index),
                              ),
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
      ),
    );
  }
}
