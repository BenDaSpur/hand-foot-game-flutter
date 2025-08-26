import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/card.dart';
import '../widgets/playing_card_widget.dart';

class PlayerHandWidget extends StatelessWidget {
  // Layout constants
  static const double _handContainerHeight = 120.0;
  static const double _cardWidth = 70.0;
  static const double _cardHeight = 98.0;
  static const double _cardOffset = 50.0;
  final Player player;
  final List<int> selectedCardIndices;
  final Function(int) onCardTap;
  final Function(int) onCardDoubleTap;
  final bool Function(PlayingCard) isCardPlayable;

  const PlayerHandWidget({
    super.key,
    required this.player,
    required this.selectedCardIndices,
    required this.onCardTap,
    required this.onCardDoubleTap,
    required this.isCardPlayable,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _handContainerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'Your Hand (${player.currentHand.length} cards)',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: player.currentHand.isNotEmpty
                      ? (player.currentHand.length - 1) * _cardOffset +
                            _cardWidth
                      : _cardWidth,
                  child: Stack(
                    children: player.currentHand.asMap().entries.map((entry) {
                      final index = entry.key;
                      final card = entry.value;

                      return Positioned(
                        left: index * _cardOffset,
                        child: GestureDetector(
                          onTap: () => onCardTap(index),
                          onDoubleTap: () => onCardDoubleTap(index),
                          child: PlayingCardWidget(
                            key: ValueKey(
                              'hand-${card.rank}-${card.suit}-$index',
                            ),
                            card: card,
                            width: _cardWidth,
                            height: _cardHeight,
                            isSelected: selectedCardIndices.contains(index),
                            isPlayable: isCardPlayable(card),
                            isNewlyDrawn: player.isCardIndexNewlyDrawn(index),
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
    );
  }
}
