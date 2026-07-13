import 'package:flutter/material.dart';
import '../models/card.dart';
import '../models/game_state.dart';
import '../theme/balatro_theme.dart';
import '../constants/ui_constants.dart';
import '../utils/game_responsive_layout.dart';
import 'card_back_widget.dart';
import 'playing_card_widget.dart';

/// Compact in-game header: round/phase on row 1, deck/discard on row 2 (phone).
class GameCompactHeader extends StatelessWidget {
  final GameState gameState;
  final GlobalKey deckKey;
  final GlobalKey discardKey;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback? onRecentActionsTap;
  final List<Widget> headerExtras;
  final List<Widget> expandedExtras;

  const GameCompactHeader({
    super.key,
    required this.gameState,
    required this.deckKey,
    required this.discardKey,
    required this.isExpanded,
    required this.onToggleExpand,
    this.onRecentActionsTap,
    this.headerExtras = const [],
    this.expandedExtras = const [],
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
        return 'Draw';
      case TurnPhase.meld:
        return 'Meld';
      case TurnPhase.discard:
        return 'Discard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = GameResponsiveLayout.isPhone(screenWidth);
    final sizes = GameResponsiveLayout.cardSizes(context);
    final deckLow = gameState.deck.size <= 20;
    final deckColor = deckLow ? Colors.red : BalatroTheme.neonYellow;
    final topDiscard = gameState.topDiscard;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BalatroTheme.glowDecoration(
        backgroundColor: BalatroTheme.darkPurple.withValues(alpha: 0.92),
        glowColor: BalatroTheme.glowColor.withValues(alpha: 0.35),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 4),
            child: Row(
              children: [
                _RoundBadge(round: gameState.round),
                const SizedBox(width: 6),
                _PhaseChip(label: _phaseLabel(), color: _phaseColor()),
                if (gameState.finalTurnPhaseActive) ...[
                  const SizedBox(width: 6),
                  _PhaseChip(
                    label: gameState.playersAwaitingFinalTurn.length == 1
                        ? 'Final turn'
                        : 'Final turns',
                    color: BalatroTheme.neonOrange,
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    gameState.currentPlayer.name,
                    style: const TextStyle(
                      color: BalatroTheme.secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isPhone) ...headerExtras,
                if (onRecentActionsTap != null &&
                    gameState.recentActions.isNotEmpty)
                  _RecentActionsChip(
                    count: gameState.recentActions.length,
                    onTap: onRecentActionsTap!,
                  ),
                IconButton(
                  onPressed: onToggleExpand,
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: BalatroTheme.glowColor,
                    size: 22,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  tooltip: isExpanded ? 'Hide details' : 'Show details',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LabeledPile(
                  label: 'Deck',
                  count: gameState.deck.size,
                  countColor: deckColor,
                  child: _DeckPileAnchor(
                    key: deckKey,
                    width: sizes.pileWidth,
                    height: sizes.pileHeight,
                    deckSize: gameState.deck.size,
                  ),
                ),
                SizedBox(width: isPhone ? 32 : 48),
                _LabeledPile(
                  label: 'Discard',
                  count: gameState.discardPile.length,
                  countColor: BalatroTheme.glowColor,
                  child: _DiscardPileAnchor(
                    key: discardKey,
                    width: sizes.pileWidth,
                    height: sizes.pileHeight,
                    topDiscard: topDiscard,
                  ),
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            Divider(
              color: BalatroTheme.glowColor.withValues(alpha: 0.25),
              height: 1,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (isPhone) ...expandedExtras,
                  if (isPhone) ...headerExtras,
                  _InfoChip(
                    label: 'Play down ${gameState.playDownRequirement}',
                    color: BalatroTheme.neonOrange,
                    icon: Icons.casino,
                  ),
                  _InfoChip(
                    label: 'Deck ${gameState.deck.size}${deckLow ? ' ⚠' : ''}',
                    color: deckColor,
                    icon: Icons.style,
                  ),
                  if (topDiscard != null)
                    _InfoChip(
                      label: 'Top ${topDiscard.displayName}',
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

class _LabeledPile extends StatelessWidget {
  final String label;
  final int count;
  final Color countColor;
  final Widget child;

  const _LabeledPile({
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
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        child,
        const SizedBox(height: 3),
        Text(
          '$count',
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

class _RoundBadge extends StatelessWidget {
  final int round;

  const _RoundBadge({required this.round});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: BalatroTheme.neonYellow.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: BalatroTheme.neonYellow.withValues(alpha: 0.7),
        ),
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
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.7)),
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

  const _DeckPileAnchor({
    super.key,
    required this.width,
    required this.height,
    required this.deckSize,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (deckSize > 1)
          Positioned(
            left: 4,
            top: -4,
            child: CardBackWidget(width: width, height: height),
          ),
        CardBackWidget(width: width, height: height),
      ],
    );
  }
}

class _DiscardPileAnchor extends StatelessWidget {
  final double width;
  final double height;
  final PlayingCard? topDiscard;

  const _DiscardPileAnchor({
    super.key,
    required this.width,
    required this.height,
    required this.topDiscard,
  });

  @override
  Widget build(BuildContext context) {
    if (topDiscard == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: BalatroTheme.darkPurple.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: BalatroTheme.cardBorder.withValues(alpha: 0.4),
          ),
        ),
        child: Icon(
          Icons.layers_outlined,
          color: Colors.white.withValues(alpha: 0.2),
          size: width * 0.35,
        ),
      );
    }

    return PlayingCardWidget(card: topDiscard!, width: width, height: height);
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(right: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: BalatroTheme.glowColor.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.history,
                size: 15,
                color: BalatroTheme.glowColor,
              ),
              if (count > 0) ...[
                const SizedBox(width: 3),
                Text(
                  '$count',
                  style: const TextStyle(
                    color: BalatroTheme.glowColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
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
              Divider(
                color: BalatroTheme.glowColor.withValues(alpha: 0.25),
                height: 1,
              ),
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
