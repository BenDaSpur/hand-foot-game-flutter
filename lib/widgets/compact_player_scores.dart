import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../theme/balatro_theme.dart';

class CompactPlayerScores extends StatelessWidget {
  final GameState gameState;
  final Player? viewingPlayerMelds;
  final Function(Player) onPlayerTap;

  const CompactPlayerScores({
    super.key,
    required this.gameState,
    required this.viewingPlayerMelds,
    required this.onPlayerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: gameState.players.map((player) {
          final isViewing = viewingPlayerMelds == player;
          final isCurrent = player == gameState.currentPlayer;
          final isHuman = player.type == PlayerType.human;

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
                  borderRadius: BorderRadius.circular(8),
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
                          if (isHuman)
                            const Icon(
                              Icons.person,
                              size: 10,
                              color: Colors.white,
                            )
                          else
                            const Icon(
                              Icons.smart_toy,
                              size: 10,
                              color: Colors.white,
                            ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              player.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
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
                              ? Colors.orange.withValues(alpha: 0.8)
                              : Colors.blue.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          player.hasPickedUpFoot ? 'FOOT' : 'HAND',
                          style: const TextStyle(
                            fontSize: 8,
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
                              fontSize: 11,
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
                                color: Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${player.melds.length}M',
                                style: const TextStyle(
                                  fontSize: 8,
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
}
