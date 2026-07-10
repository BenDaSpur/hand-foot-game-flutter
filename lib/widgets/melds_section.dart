import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../models/card.dart';
import '../theme/balatro_theme.dart';
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
  final String? currentUserId;

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
    this.currentUserId,
  });

  String _getMeldsHeaderText(Player player) {
    final playerName = player.name;
    if (playerName == 'You') {
      return 'Your Melds';
    } else {
      return '$playerName\'s Melds';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPlayer = gameState.currentPlayer;
    final player = viewingPlayerMelds ?? humanPlayer;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Text(
                  _getMeldsHeaderText(player),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: BalatroTheme.primaryText,
                  ),
                ),
                if (viewingPlayerMelds != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: TextButton(
                      onPressed: () => onViewPlayerMelds(null),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Back to yours',
                        style: TextStyle(
                          color: BalatroTheme.glowColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (player.melds.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No melds yet',
                style: TextStyle(color: BalatroTheme.secondaryText),
              ),
            )
          else
            ...(() {
              final indexedMelds = player.melds.asMap().entries.toList();
              indexedMelds.sort((a, b) {
                final aRank = a.value.rank;
                final bRank = b.value.rank;

                if (aRank == CardRank.ace && bRank != CardRank.ace) {
                  return 1;
                }
                if (bRank == CardRank.ace && aRank != CardRank.ace) {
                  return -1;
                }

                return aRank.index.compareTo(bRank.index);
              });

              return indexedMelds.map((entry) {
                final isCurrentUserTurn = currentUserId != null
                    ? currentPlayer.id == currentUserId
                    : currentPlayer.type == PlayerType.human;

                final canAdd =
                    viewingPlayerMelds == null &&
                    isCurrentUserTurn &&
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
                  canAcceptSelectedCard: canAdd && canAddCardToMeld(entry.key),
                  compatibleCardsInHand: compatibleInfo.count,
                  compatibleCardsAreWilds: compatibleInfo.areWilds,
                );
              });
            })(),
        ],
      ),
    );
  }
}
