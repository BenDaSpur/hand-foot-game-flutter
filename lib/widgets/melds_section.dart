import 'package:material_ui/material_ui.dart';

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
    if (player.id == humanPlayer.id) {
      return 'Your Melds';
    }
    return '${player.name}\'s Melds';
  }

  List<Widget> _buildMeldWidgets(Player player) {
    final currentPlayer = gameState.currentPlayer;
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
    }).toList();
  }

  /// Empty-state copy for the table melds area (not "sets in hand").
  static String emptyStateSubtitle({
    required TurnPhase turnPhase,
    required bool hasPlayedDown,
    required int playDownRequirement,
  }) {
    if (turnPhase == TurnPhase.draw) {
      return 'Draw first, then use Play Cards to lay sets from your hand.';
    }
    if (!hasPlayedDown) {
      return 'Tap Play Cards — first play-down needs $playDownRequirement '
          'points (sets in your hand don’t count until laid).';
    }
    return 'Tap Play Cards to lay more melds.';
  }

  Widget _buildEmptyState() {
    final subtitle = emptyStateSubtitle(
      turnPhase: gameState.turnPhase,
      hasPlayedDown: humanPlayer.hasPlayedDown,
      playDownRequirement: gameState.playDownRequirement,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: BalatroTheme.glowColor.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.view_module_outlined,
              size: 28,
              color: BalatroTheme.glowColor.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 8),
            const Text(
              'No melds on the table yet',
              style: TextStyle(
                color: BalatroTheme.primaryText,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: BalatroTheme.secondaryText.withValues(alpha: 0.85),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = viewingPlayerMelds ?? humanPlayer;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
            child: Row(
              children: [
                Text(
                  _getMeldsHeaderText(player),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: BalatroTheme.primaryText,
                  ),
                ),
                if (viewingPlayerMelds != null)
                  TextButton(
                    onPressed: () => onViewPlayerMelds(null),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '← Yours',
                      style: TextStyle(
                        color: BalatroTheme.glowColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (player.melds.isEmpty)
          SliverToBoxAdapter(child: _buildEmptyState())
        else
          SliverList(
            delegate: SliverChildListDelegate(_buildMeldWidgets(player)),
          ),
      ],
    );
  }
}
