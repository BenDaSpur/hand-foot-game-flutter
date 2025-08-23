import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/card.dart';
import '../widgets/playing_card_widget.dart';

class PlayerHandWidget extends StatelessWidget {
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
      height: 120,
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
                      ? (player.currentHand.length - 1) * 50.0 + 70.0
                      : 70.0,
                  child: Stack(
                    children: player.currentHand.asMap().entries.map((entry) {
                      final index = entry.key;
                      final card = entry.value;

                      return Positioned(
                        left: index * 50.0,
                        child: GestureDetector(
                          onTap: () => onCardTap(index),
                          onDoubleTap: () => onCardDoubleTap(index),
                          child: PlayingCardWidget(
                            card: card,
                            width: 70,
                            height: 98,
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
