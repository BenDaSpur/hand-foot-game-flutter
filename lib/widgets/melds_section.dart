import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../models/card.dart';
import '../widgets/meld_widget.dart';

class MeldsSection extends StatelessWidget {
  final GameState gameState;
  final Player humanPlayer;
  final Player? viewingPlayerMelds;
  final Function(Player?) onViewPlayerMelds;
  final Function(int) onAddCardToMeld;
  final Function(int) onSelectAllCardsForMeld;
  final bool Function(int) canAddCardToMeld;
  final ({int count, bool areWilds}) Function(int) getCompatibleCardsInfo;

  const MeldsSection({
    super.key,
    required this.gameState,
    required this.humanPlayer,
    required this.viewingPlayerMelds,
    required this.onViewPlayerMelds,
    required this.onAddCardToMeld,
    required this.onSelectAllCardsForMeld,
    required this.canAddCardToMeld,
    required this.getCompatibleCardsInfo,
  });

  @override
  Widget build(BuildContext context) {
    final currentPlayer = gameState.currentPlayer;
    final player = viewingPlayerMelds ?? humanPlayer;

    return Expanded(
      flex: 2,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    () {
                      final playerName = player.name;
                      if (playerName == 'You') {
                        return 'Your Melds:';
                      } else {
                        return '$playerName\'s Melds:';
                      }
                    }(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (viewingPlayerMelds != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: TextButton(
                        onPressed: () => onViewPlayerMelds(null),
                        child: const Text('Back to yours'),
                      ),
                    ),
                ],
              ),
            ),
            if (player.melds.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No melds yet'),
              )
            else
              ...(() {
                // Sort melds by face value (CardRank)
                final indexedMelds = player.melds.asMap().entries.toList();
                indexedMelds.sort((a, b) {
                  // Special handling for Aces - put them at the end
                  final aRank = a.value.rank;
                  final bRank = b.value.rank;

                  if (aRank == CardRank.ace && bRank != CardRank.ace) {
                    return 1; // a (ace) comes after b
                  }
                  if (bRank == CardRank.ace && aRank != CardRank.ace) {
                    return -1; // b (ace) comes after a
                  }

                  // For non-ace cards or both aces, use normal index comparison
                  return aRank.index.compareTo(bRank.index);
                });

                return indexedMelds.map((entry) {
                  final canAdd =
                      viewingPlayerMelds == null &&
                      currentPlayer.type == PlayerType.human &&
                      gameState.turnPhase == TurnPhase.meld;

                  final compatibleInfo = canAdd
                      ? getCompatibleCardsInfo(entry.key)
                      : (count: 0, areWilds: false);

                  return MeldWidget(
                    meld: entry.value,
                    meldIndex: entry.key,
                    canAddCards: canAdd,
                    onTap: canAdd ? onAddCardToMeld : null,
                    onSelectAllCards: canAdd ? onSelectAllCardsForMeld : null,
                    canAcceptSelectedCard:
                        canAdd && canAddCardToMeld(entry.key),
                    compatibleCardsInHand: compatibleInfo.count,
                    compatibleCardsAreWilds: compatibleInfo.areWilds,
                  );
                });
              })(),
          ],
        ),
      ),
    );
  }
}
