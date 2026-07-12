import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../theme/balatro_theme.dart';
import '../constants/ui_constants.dart';
import '../ai/bot_personality.dart';

class PersonalityIcons {
  static const IconData defaultBot = Icons.smart_toy;
  static const IconData conservative = Icons.shield;
  static const IconData aggressive = Icons.flash_on;
  static const IconData bookBuilder = Icons.auto_stories;
  static const IconData adaptive = Icons.auto_mode;
}

class CompactPlayerScores extends StatelessWidget {
  final GameState gameState;
  final Player? viewingPlayerMelds;
  final Function(Player) onPlayerTap;
  final String? currentUserId;
  final BotPersonalityManager? botPersonalityManager;

  const CompactPlayerScores({
    super.key,
    required this.gameState,
    required this.viewingPlayerMelds,
    required this.onPlayerTap,
    this.currentUserId,
    this.botPersonalityManager,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        children: gameState.players.map((player) {
          final isViewing = viewingPlayerMelds == player;
          final isCurrent = player == gameState.currentPlayer;
          final isCurrentUser = currentUserId != null
              ? player.id == currentUserId
              : player.type == PlayerType.human;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _PlayerChip(
                gameState: gameState,
                player: player,
                isViewing: isViewing,
                isCurrent: isCurrent,
                isCurrentUser: isCurrentUser,
                isMultiplayer: currentUserId != null,
                onTap: () => onPlayerTap(player),
                botPersonalityManager: botPersonalityManager,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final GameState gameState;
  final Player player;
  final bool isViewing;
  final bool isCurrent;
  final bool isCurrentUser;
  final bool isMultiplayer;
  final VoidCallback onTap;
  final BotPersonalityManager? botPersonalityManager;

  const _PlayerChip({
    required this.gameState,
    required this.player,
    required this.isViewing,
    required this.isCurrent,
    required this.isCurrentUser,
    required this.isMultiplayer,
    required this.onTap,
    this.botPersonalityManager,
  });

  @override
  Widget build(BuildContext context) {
    final wentOutIndex = gameState.playerWhoWentOutIndex;
    final playerIndex = gameState.players.indexWhere((p) => p.id == player.id);
    final isWentOut = wentOutIndex != null && playerIndex == wentOutIndex;
    final isAwaitingFinalTurn =
        gameState.finalTurnPhaseActive &&
        gameState.isPlayerAwaitingFinalTurn(player);

    final accent = isViewing
        ? BalatroTheme.neonGreen
        : isAwaitingFinalTurn
        ? BalatroTheme.neonOrange
        : isCurrent
        ? BalatroTheme.neonBlue
        : Colors.white.withValues(alpha: 0.35);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: UIConstants.playerScoresHeight,
          decoration: BoxDecoration(
            color: isViewing
                ? BalatroTheme.neonGreen.withValues(alpha: 0.18)
                : isCurrent
                ? BalatroTheme.neonBlue.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: accent,
              width: isViewing || isCurrent || isAwaitingFinalTurn ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _leadingIcon(),
                    size: UIConstants.playerScoresIconSize,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      player.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: UIConstants.playerScoresNameFontSize,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${player.score}',
                    style: const TextStyle(
                      fontSize: UIConstants.playerScoresScoreFontSize,
                      fontWeight: FontWeight.bold,
                      color: BalatroTheme.neonYellow,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: player.hasPickedUpFoot
                          ? BalatroTheme.neonOrange.withValues(alpha: 0.35)
                          : BalatroTheme.neonBlue.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      player.hasPickedUpFoot ? 'FT' : 'HD',
                      style: const TextStyle(
                        fontSize: UIConstants.playerScoresHandFootFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (player.melds.isNotEmpty) ...[
                    const SizedBox(width: 3),
                    Text(
                      '${player.melds.length}m',
                      style: TextStyle(
                        fontSize: UIConstants.playerScoresMeldFontSize,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  if (isWentOut) ...[
                    const SizedBox(width: 3),
                    _StatusBadge(label: 'OUT', color: BalatroTheme.neonGreen),
                  ] else if (isAwaitingFinalTurn) ...[
                    const SizedBox(width: 3),
                    _StatusBadge(label: 'LAST', color: BalatroTheme.neonOrange),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _leadingIcon() {
    if (isCurrentUser) {
      return Icons.person;
    }
    if (isMultiplayer) {
      return Icons.group;
    }
    return _getBotPersonalityIcon(player);
  }

  IconData _getBotPersonalityIcon(Player player) {
    if (player.type != PlayerType.bot || botPersonalityManager == null) {
      return PersonalityIcons.defaultBot;
    }

    switch (botPersonalityManager!.getPersonality(player.id)) {
      case BotPersonality.conservative:
        return PersonalityIcons.conservative;
      case BotPersonality.aggressive:
        return PersonalityIcons.aggressive;
      case BotPersonality.bookBuilder:
        return PersonalityIcons.bookBuilder;
      case BotPersonality.adaptive:
        return PersonalityIcons.adaptive;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: UIConstants.playerScoresHandFootFontSize,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
