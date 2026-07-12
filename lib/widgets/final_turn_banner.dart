import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../theme/balatro_theme.dart';

/// Prominent banner shown while other players take one final turn after a go-out.
class FinalTurnBanner extends StatelessWidget {
  final GameState gameState;

  /// Local human player id (solo) or multiplayer user id. When null, uses
  /// the first [PlayerType.human] in [GameState.players].
  final String? localPlayerId;

  const FinalTurnBanner({
    super.key,
    required this.gameState,
    this.localPlayerId,
  });

  @override
  Widget build(BuildContext context) {
    if (!gameState.finalTurnPhaseActive) {
      return const SizedBox.shrink();
    }

    final wentOut = gameState.playerWhoWentOut;
    final localPlayer = _resolveLocalPlayer();
    final isLocalFinalTurn =
        localPlayer != null && gameState.isPlayerAwaitingFinalTurn(localPlayer);
    final remaining = gameState.playersAwaitingFinalTurn.length;
    final urgencyColor = isLocalFinalTurn
        ? BalatroTheme.neonOrange
        : BalatroTheme.neonYellow;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            urgencyColor.withValues(alpha: 0.28),
            BalatroTheme.neonPink.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: urgencyColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: urgencyColor.withValues(alpha: 0.35),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isLocalFinalTurn ? Icons.timer : Icons.hourglass_bottom,
            color: urgencyColor,
            size: 26,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _headline(isLocalFinalTurn),
                  style: TextStyle(
                    color: urgencyColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _body(wentOut?.name, isLocalFinalTurn, remaining),
                  style: const TextStyle(
                    color: BalatroTheme.primaryText,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                if (isLocalFinalTurn) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Meld every card you can — leftover hand & foot cards '
                    'become penalty points when the round ends.',
                    style: TextStyle(
                      color: urgencyColor.withValues(alpha: 0.95),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Player? _resolveLocalPlayer() {
    if (localPlayerId != null) {
      for (final player in gameState.players) {
        if (player.id == localPlayerId) {
          return player;
        }
      }
      return null;
    }

    for (final player in gameState.players) {
      if (player.type == PlayerType.human) {
        return player;
      }
    }
    return null;
  }

  String _headline(bool isLocalFinalTurn) {
    if (isLocalFinalTurn) {
      return 'YOUR FINAL TURN';
    }
    return 'FINAL TURNS IN PROGRESS';
  }

  String _body(String? wentOutName, bool isLocalFinalTurn, int remaining) {
    final who = wentOutName ?? 'Someone';
    if (isLocalFinalTurn) {
      return '$who went out. This is your last turn before scoring — '
          'play down as much as you can.';
    }

    final turnWord = remaining == 1 ? 'turn' : 'turns';
    return '$who went out. Each other player gets one more $turnWord '
        '($remaining remaining).';
  }
}
