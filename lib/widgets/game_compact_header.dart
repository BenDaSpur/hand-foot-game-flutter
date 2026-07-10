import 'package:flutter/material.dart';
import '../models/card.dart';
import '../models/game_state.dart';
import '../theme/balatro_theme.dart';
import '../constants/ui_constants.dart';
import '../utils/game_responsive_layout.dart';
import 'card_back_widget.dart';
import 'playing_card_widget.dart';

/// Compact in-game header merging round/phase info, deck/discard piles, and
/// expandable game stats. Replaces separate MobileStatusBar + GamePilesRow on phone.
/// expandable game stats. Replaces separate MobileStatusBar + GamePilesRow on phone.
class GameCompactHeader extends StatelessWidget {
  final GameState gameState;
  final GlobalKey deckKey;
  final GlobalKey discardKey;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback? onRecentActionsTap;
  final List<Widget> headerExtras;

  const GameCompactHeader({
    super.key,
    required this.gameState,
    required this.deckKey,
    required this.discardKey,
    required this.isExpanded,
    required this.onToggleExpand,
    this.onRecentActionsTap,
    this.headerExtras = const [],
  });

  Color _phaseColor() {
    switch (gameState.turnPhase) {
      case TurnPhase.draw:
        return BalatroTheme.neonBlue;
      case TurnPhase.meld:
        return BalatroTheme.neonGreen;
      case TurnPhase.discard:
        return BalatroTheme.neonOrange;
    }
  }

  String _phaseLabel() {
    switch (gameState.turnPhase) {
      case TurnPhase.draw:
        return 'DRAW';
      case TurnPhase.meld:
        return 'MELD';
      case TurnPhase.discard:
        return 'DISCARD';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizes = GameResponsiveLayout.cardSizes(context);
    final deckLow = gameState.deck.size <= 20;
    final deckColor = deckLow ? Colors.red : BalatroTheme.neonYellow;
    final topDiscard = gameState.topDiscard;
    final pileW = sizes.pileWidth;
    final pileH = sizes.pileHeight;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: UIConstants.defaultMargin,
        vertical: UIConstants.smallSpacing,
      ),
      decoration: BalatroTheme.glowDecoration(
        backgroundColor: BalatroTheme.darkPurple,
        glowColor: BalatroTheme.glowColor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: UIConstants.defaultPadding,
              vertical: UIConstants.smallSpacing,
            ),
            child: Row(
              children: [
                _RoundBadge(round: gameState.round),
                const SizedBox(width: UIConstants.smallSpacing),
                _PhaseChip(label: _phaseLabel(), color: _phaseColor()),
                const SizedBox(width: UIConstants.smallSpacing),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DeckPileAnchor(
                        key: deckKey,
                        width: pileW,
                        height: pileH,
                        deckSize: gameState.deck.size,
                        deckLow: deckLow,
                      ),
                      SizedBox(width: pileW * 0.35),
                      _DiscardPileAnchor(
                        key: discardKey,
                        width: pileW,
                        height: pileH,
                        topDiscard: topDiscard,
                        discardCount: gameState.discardPile.length,
                      ),
                    ],
                  ),
                ),
                if (onRecentActionsTap != null &&
                    gameState.recentActions.isNotEmpty)
                  _RecentActionsChip(
                    count: gameState.recentActions.length,
                    onTap: onRecentActionsTap!,
                  ),
                ...headerExtras,
                IconButton(
                  onPressed: onToggleExpand,
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: BalatroTheme.glowColor,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  tooltip: isExpanded ? 'Hide details' : 'Show details',
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            const Divider(color: BalatroTheme.glowColor, height: 1),
            Padding(
              padding: const EdgeInsets.all(UIConstants.defaultPadding),
              child: Wrap(
                spacing: UIConstants.mediumSpacing,
                runSpacing: UIConstants.smallSpacing,
                children: [
                  _InfoChip(
                    label: gameState.currentPlayer.name,
                    color: BalatroTheme.neonPink,
                    icon: Icons.person,
                  ),
                  _InfoChip(
                    label: 'Play Down: ${gameState.playDownRequirement}',
                    color: BalatroTheme.neonOrange,
                    icon: Icons.casino,
                  ),
                  _InfoChip(
                    label: 'Deck: ${gameState.deck.size}${deckLow ? ' ⚠' : ''}',
                    color: deckColor,
                    icon: Icons.style,
                  ),
                  _InfoChip(
                    label: 'Discard: ${gameState.discardPile.length}',
                    color: BalatroTheme.glowColor,
                    icon: Icons.layers,
                  ),
                  if (topDiscard != null)
                    _InfoChip(
                      label: 'Top: ${topDiscard.displayName}',
                      color: BalatroTheme.neonGreen,
                      icon: Icons.visibility,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoundBadge extends StatelessWidget {
  final int round;

  const _RoundBadge({required this.round});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: BalatroTheme.neonYellow.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: BalatroTheme.neonYellow, width: 1),
      ),
      child: Text(
        'R$round',
        style: const TextStyle(
          color: BalatroTheme.neonYellow,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  final String label;
  final Color color;

  const _PhaseChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _DeckPileAnchor extends StatelessWidget {
  final double width;
  final double height;
  final int deckSize;
  final bool deckLow;

  const _DeckPileAnchor({
    super.key,
    required this.width,
    required this.height,
    required this.deckSize,
    required this.deckLow,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            if (deckSize > 1)
              Positioned(
                left: 3,
                top: -3,
                child: CardBackWidget(width: width, height: height),
              ),
            CardBackWidget(width: width, height: height),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '$deckSize',
          style: TextStyle(
            color: deckLow ? Colors.red : BalatroTheme.neonYellow,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _DiscardPileAnchor extends StatelessWidget {
  final double width;
  final double height;
  final PlayingCard? topDiscard;
  final int discardCount;

  const _DiscardPileAnchor({
    super.key,
    required this.width,
    required this.height,
    required this.topDiscard,
    required this.discardCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        topDiscard == null
            ? Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: BalatroTheme.darkPurple.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: BalatroTheme.cardBorder.withValues(alpha: 0.5),
                  ),
                ),
                child: Icon(
                  Icons.layers_clear,
                  color: Colors.white24,
                  size: width * 0.35,
                ),
              )
            : PlayingCardWidget(
                card: topDiscard!,
                width: width,
                height: height,
              ),
        const SizedBox(height: 2),
        Text(
          '$discardCount',
          style: const TextStyle(
            color: BalatroTheme.glowColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _InfoChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: BalatroTheme.darkPurple.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActionsChip extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _RecentActionsChip({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: BalatroTheme.darkPurple.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: BalatroTheme.glowColor.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 14, color: BalatroTheme.glowColor),
            if (count > 0) ...[
              const SizedBox(width: 2),
              Text(
                '$count',
                style: const TextStyle(
                  color: BalatroTheme.glowColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows recent actions in a bottom sheet (phone-friendly).
void showRecentActionsSheet(BuildContext context, GameState gameState) {
  if (gameState.recentActions.isEmpty) {
    return;
  }

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: BalatroTheme.darkPurple,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.7,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.history, color: BalatroTheme.glowColor),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Actions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: BalatroTheme.glowColor, height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: gameState.recentActions.length,
                  reverse: true,
                  itemBuilder: (context, index) {
                    final action =
                        gameState.recentActions[gameState.recentActions.length -
                            1 -
                            index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        action.toString(),
                        style: const TextStyle(
                          fontSize: UIConstants.recentActionsFontSize,
                          color: BalatroTheme.secondaryText,
                          height: UIConstants.recentActionsLineHeight,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
