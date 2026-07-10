import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../theme/balatro_theme.dart';
import '../constants/ui_constants.dart';
import '../ai/bot_personality.dart';

/// Constants for personality icons
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
    return SizedBox(
      height: UIConstants.playerScoresHeight,
      child: Row(
        children: [
          Tooltip(
            message: 'Tap a player to view their melds',
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 4),
              child: Icon(
                Icons.touch_app,
                size: 16,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: gameState.players.map((player) {
                  return SizedBox(
                    width: UIConstants.playerScoresMinWidth,
                    child: _PlayerChip(
                      player: player,
                      gameState: gameState,
                      isViewing: viewingPlayerMelds == player,
                      isCurrent: player == gameState.currentPlayer,
                      isCurrentUser: currentUserId != null
                          ? player.id == currentUserId
                          : player.type == PlayerType.human,
                      isMultiplayer: currentUserId != null,
                      onTap: () => onPlayerTap(player),
                      botPersonalityManager: botPersonalityManager,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final Player player;
  final GameState gameState;
  final bool isViewing;
  final bool isCurrent;
  final bool isCurrentUser;
  final bool isMultiplayer;
  final VoidCallback onTap;
  final BotPersonalityManager? botPersonalityManager;

  const _PlayerChip({
    required this.player,
    required this.gameState,
    required this.isViewing,
    required this.isCurrent,
    required this.isCurrentUser,
    required this.isMultiplayer,
    required this.onTap,
    this.botPersonalityManager,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          gradient: isViewing
              ? const LinearGradient(
                  colors: [BalatroTheme.neonGreen, Colors.green],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : isCurrent
              ? const LinearGradient(
                  colors: [BalatroTheme.neonBlue, Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [Colors.grey[700]!, Colors.grey[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(UIConstants.defaultBorderRadius),
          border: Border.all(
            color: isViewing
                ? BalatroTheme.neonGreen
                : isCurrent
                ? BalatroTheme.neonBlue
                : Colors.grey,
            width: isViewing ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCurrentUser)
                  const Icon(
                    Icons.person,
                    size: UIConstants.playerScoresIconSize,
                    color: Colors.white,
                  )
                else if (isMultiplayer)
                  const Icon(
                    Icons.group,
                    size: UIConstants.playerScoresIconSize,
                    color: Colors.white70,
                  )
                else
                  Icon(
                    _getBotPersonalityIcon(player),
                    size: UIConstants.playerScoresIconSize,
                    color: Colors.white,
                  ),
                const SizedBox(width: 2),
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
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: player.hasPickedUpFoot
                    ? Colors.orange.withValues(alpha: 0.8)
                    : Colors.blue.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                player.hasPickedUpFoot ? 'FOOT' : 'HAND',
                style: const TextStyle(
                  fontSize: UIConstants.playerScoresHandFootFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${player.score}',
                  style: const TextStyle(
                    fontSize: UIConstants.playerScoresScoreFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (player.melds.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '${player.melds.length}M',
                      style: const TextStyle(
                        fontSize: UIConstants.playerScoresMeldFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getBotPersonalityIcon(Player player) {
    if (player.type != PlayerType.bot || botPersonalityManager == null) {
      return PersonalityIcons.defaultBot;
    }

    final personality = botPersonalityManager!.getPersonality(player.id);

    switch (personality) {
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
