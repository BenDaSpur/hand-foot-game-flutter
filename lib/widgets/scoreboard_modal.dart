import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/card.dart';
import '../config/game_config.dart';
import '../theme/balatro_theme.dart';

class ScoreboardModal extends StatelessWidget {
  final GameState gameState;

  const ScoreboardModal({super.key, required this.gameState});

  Map<String, dynamic> _calculateScoreBreakdown(int playerIndex) {
    int meldPoints = 0;
    int cleanBooks = 0;
    int dirtyBooks = 0;
    int handFootPenalty = 0;
    int redThrees = 0;
    int blackThrees = 0;

    final player = gameState.players[playerIndex];

    // Calculate meld points and books
    for (final meld in player.melds) {
      meldPoints += meld.pointValue;
      if (meld.isBook) {
        if (meld.isClean) {
          cleanBooks++;
        } else {
          dirtyBooks++;
        }
      }
    }

    // Calculate cards left in hand/foot penalty
    final handCards = player.hand;
    final footCards = player.foot;

    for (final card in handCards) {
      handFootPenalty -= card.pointValue.abs().toInt();
      if (card.rank == CardRank.three) {
        if (card.suit == Suit.hearts || card.suit == Suit.diamonds) {
          redThrees++;
        } else {
          blackThrees++;
        }
      }
    }

    for (final card in footCards) {
      handFootPenalty -= card.pointValue.abs().toInt();
      if (card.rank == CardRank.three) {
        if (card.suit == Suit.hearts || card.suit == Suit.diamonds) {
          redThrees++;
        } else {
          blackThrees++;
        }
      }
    }

    // Calculate total
    final total = meldPoints + handFootPenalty;

    return {
      'meldPoints': meldPoints,
      'cleanBooks': cleanBooks,
      'dirtyBooks': dirtyBooks,
      'cleanBookPoints': cleanBooks * GameConfig.cleanBookBonus,
      'dirtyBookPoints': dirtyBooks * GameConfig.dirtyBookBonus,
      'handFootPenalty': handFootPenalty,
      'redThrees': redThrees,
      'blackThrees': blackThrees,
      'redThreePoints': redThrees * GameConfig.redThreeBonus,
      'blackThreePenalty': blackThrees * GameConfig.blackThreePenalty,
      'roundTotal': total,
      'gameTotal': gameState.players[playerIndex].score,
    };
  }

  Color _getScoreColor(int value) {
    if (value > 0) return BalatroTheme.neonGreen;
    if (value < 0) return const Color(0xFFFF4040);
    return Colors.grey;
  }

  Widget _buildPlayerScoreCard(int playerIndex) {
    final breakdown = _calculateScoreBreakdown(playerIndex);
    final isCurrentPlayer = playerIndex == gameState.currentPlayerIndex;
    final player = gameState.players[playerIndex];
    // Only show "CAN GO OUT" if game is still active and player can go out
    final canGoOut = gameState.phase == GamePhase.playing && player.canGoOut;

    // Build accessibility label
    final accessibilityLabel =
        'Player ${playerIndex + 1}, '
        'Total score: ${breakdown['gameTotal']}, '
        'Round ${gameState.round} score: ${breakdown['roundTotal']}, '
        '${canGoOut ? 'Can go out, ' : ''}'
        '${isCurrentPlayer ? 'Current player' : ''}';

    return Semantics(
      label: accessibilityLabel,
      child: Card(
        color: isCurrentPlayer
            ? const Color(0xFF3A3450).withValues(alpha: 0.3)
            : const Color(0xFF1E1B29),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrentPlayer
                  ? BalatroTheme.neonPink
                  : const Color(0xFF3A3450),
              width: isCurrentPlayer ? 2 : 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E1B29),
                const Color(0xFF1E1B29).withValues(alpha: 0.8),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Player header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Player ${playerIndex + 1}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (canGoOut) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: BalatroTheme.neonGreen.withValues(
                                alpha: 0.2,
                              ),
                              border: Border.all(color: BalatroTheme.neonGreen),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'CAN GO OUT',
                              style: TextStyle(
                                fontSize: 10,
                                color: BalatroTheme.neonGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      'Total: ${breakdown['gameTotal']}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(breakdown['gameTotal']),
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),

                // Score breakdown
                _buildScoreRow('Meld Points', breakdown['meldPoints']),

                if (breakdown['cleanBooks'] > 0)
                  _buildScoreRow(
                    'Clean Books (${breakdown['cleanBooks']})',
                    breakdown['cleanBookPoints'],
                  ),

                if (breakdown['dirtyBooks'] > 0)
                  _buildScoreRow(
                    'Dirty Books (${breakdown['dirtyBooks']})',
                    breakdown['dirtyBookPoints'],
                  ),

                if (breakdown['redThrees'] > 0)
                  _buildScoreRow(
                    'Red Threes (${breakdown['redThrees']})',
                    breakdown['redThreePoints'],
                  ),

                if (breakdown['blackThrees'] > 0)
                  _buildScoreRow(
                    'Black Threes (${breakdown['blackThrees']})',
                    breakdown['blackThreePenalty'],
                  ),

                if (breakdown['handFootPenalty'] < 0)
                  _buildScoreRow(
                    'Cards in Hand/Foot',
                    breakdown['handFootPenalty'],
                  ),

                const Divider(color: Colors.white24),

                // Round total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Round ${gameState.round} Score',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${breakdown['roundTotal'] > 0 ? '+' : ''}${breakdown['roundTotal']}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(breakdown['roundTotal']),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.white70)),
          Text(
            value > 0 ? '+$value' : '$value',
            style: TextStyle(
              fontSize: 14,
              color: _getScoreColor(value),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Get players sorted by score (cached for performance)
  List<int> get _sortedPlayerIndices {
    return List.generate(gameState.players.length, (index) => index)..sort(
      (a, b) =>
          gameState.players[b].score.compareTo(gameState.players[a].score),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedPlayers = _sortedPlayerIndices;

    return Semantics(
      label: 'Scoreboard for Round ${gameState.round}',
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B29),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: BalatroTheme.neonPink.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: BalatroTheme.neonPink.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3450).withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '🏆 Scoreboard - Round ${gameState.round}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Semantics(
                      label: 'Close scoreboard',
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),

              // Leaderboard summary
              if (sortedPlayers.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BalatroTheme.neonYellow.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: BalatroTheme.neonYellow.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: BalatroTheme.neonYellow,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Leader: Player ${sortedPlayers[0] + 1} (${gameState.players[sortedPlayers[0]].score} points)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: BalatroTheme.neonYellow,
                        ),
                      ),
                    ],
                  ),
                ),

              // Player score cards
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: gameState.players.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildPlayerScoreCard(sortedPlayers[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
