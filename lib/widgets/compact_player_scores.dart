import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../theme/balatro_theme.dart';
import '../constants/ui_constants.dart';
import '../ai/bot_personality.dart';

class CompactPlayerScores extends StatelessWidget {
  final GameState gameState;
  final Player? viewingPlayerMelds;
  final Function(Player) onPlayerTap;
  final String? currentUserId; // For multiplayer support
  final BotPersonalityManager?
  botPersonalityManager; // For bot personality icons

  const CompactPlayerScores({
    super.key,
    required this.gameState,
    required this.viewingPlayerMelds,
    required this.onPlayerTap,
    this.currentUserId, // Optional - for multiplayer
    this.botPersonalityManager, // Optional - for bot personality icons
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: UIConstants.playerScoresHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: UIConstants.defaultPadding,
      ),
      child: Row(
        children: gameState.players.map((player) {
          final isViewing = viewingPlayerMelds == player;
          final isCurrent = player == gameState.currentPlayer;

          // REUSE SINGLE-PLAYER LOGIC: Adapt human check for multiplayer
          final isCurrentUser = currentUserId != null
              ? player.id == currentUserId
              : player.type == PlayerType.human;

          return Expanded(
            child: GestureDetector(
              onTap: () => onPlayerTap(player),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                padding: const EdgeInsets.all(6),
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
                  borderRadius: BorderRadius.circular(
                    UIConstants.defaultBorderRadius,
                  ),
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
                    // Player name and type
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCurrentUser)
                            const Icon(
                              Icons.person,
                              size: UIConstants.playerScoresIconSize,
                              color: Colors.white,
                            )
                          else if (currentUserId !=
                              null) // Multiplayer - other human player
                            const Icon(
                              Icons.group,
                              size: UIConstants.playerScoresIconSize,
                              color: Colors.white70,
                            )
                          else // Single-player - bot with personality icon
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
                                shadows: [
                                  Shadow(
                                    offset: Offset(1, 1),
                                    blurRadius: 2,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Hand/Foot status
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: player.hasPickedUpFoot
                              ? Colors.orange.withValues(
                                  alpha: UIConstants.mediumTransparent,
                                )
                              : Colors.blue.withValues(
                                  alpha: UIConstants.mediumTransparent,
                                ),
                          borderRadius: BorderRadius.circular(
                            UIConstants.mediumBorderRadius,
                          ),
                        ),
                        child: Text(
                          player.hasPickedUpFoot ? 'FOOT' : 'HAND',
                          style: const TextStyle(
                            fontSize: UIConstants.playerScoresHandFootFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(0.5, 0.5),
                                blurRadius: 1,
                                color: Colors.black87,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Score and melds
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${player.score}',
                            style: const TextStyle(
                              fontSize: UIConstants.playerScoresScoreFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  offset: Offset(1, 1),
                                  blurRadius: 2,
                                  color: Colors.black54,
                                ),
                              ],
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
                                color: Colors.white.withValues(
                                  alpha: UIConstants.semiTransparent,
                                ),
                                borderRadius: BorderRadius.circular(
                                  UIConstants.smallBorderRadius,
                                ),
                              ),
                              child: Text(
                                '${player.melds.length}M',
                                style: const TextStyle(
                                  fontSize:
                                      UIConstants.playerScoresMeldFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0.5, 0.5),
                                      blurRadius: 1,
                                      color: Colors.black87,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Get personality-specific icon for bot players
  IconData _getBotPersonalityIcon(Player player) {
    if (player.type != PlayerType.bot || botPersonalityManager == null) {
      return Icons.smart_toy; // Default bot icon
    }

    final personality = botPersonalityManager!.getPersonality(player.id);

    switch (personality) {
      case BotPersonality.conservative:
        return Icons.shield; // 🛡️ Conservative - defensive strategy
      case BotPersonality.aggressive:
        return Icons.flash_on; // ⚡ Aggressive - speed and intensity
      case BotPersonality.bookBuilder:
        return Icons.menu_book; // 📚 Book Builder - knowledge and accumulation
      case BotPersonality.adaptive:
        return Icons.tune; // 🎯 Adaptive - adjustment and precision
    }
  }
}
