import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/round_score_breakdown.dart';
import '../config/game_config.dart';
import '../theme/balatro_theme.dart';

class ScoreboardModal extends StatefulWidget {
  final GameState gameState;
  final int? completedRoundNumber;
  final bool showContinueButton;

  const ScoreboardModal({
    super.key,
    required this.gameState,
    this.completedRoundNumber,
    this.showContinueButton = false,
  });

  @override
  State<ScoreboardModal> createState() => _ScoreboardModalState();
}

class _ScoreboardModalState extends State<ScoreboardModal> {
  int? expandedPlayerIndex;

  Map<String, dynamic> _calculateScoreBreakdown(int playerIndex) {
    int meldPoints = 0;
    int cleanBooks = 0;
    int dirtyBooks = 0;

    final player = widget.gameState.players[playerIndex];

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

    // For current round: only show what's been played (melds)
    // Don't include cards still in hand/foot as penalties
    final currentRoundTotal = meldPoints;

    // Calculate previous rounds score (only if not first round)
    final previousRoundsTotal = widget.gameState.round > 1
        ? player.score - currentRoundTotal
        : 0;

    return {
      'meldPoints': meldPoints,
      'cleanBooks': cleanBooks,
      'dirtyBooks': dirtyBooks,
      'cleanBookPoints': cleanBooks * GameConfig.cleanBookBonus,
      'dirtyBookPoints': dirtyBooks * GameConfig.dirtyBookBonus,
      'currentRoundTotal': currentRoundTotal,
      'previousRoundsTotal': previousRoundsTotal,
      'gameTotal': player.score,
    };
  }

  Color _getScoreColor(int value) {
    if (value > 0) return BalatroTheme.neonGreen;
    if (value < 0) return const Color(0xFFFF4040);
    return Colors.grey;
  }

  Set<String> _duplicatePlayerNames() {
    final nameCounts = <String, int>{};
    for (final player in widget.gameState.players) {
      nameCounts[player.name] = (nameCounts[player.name] ?? 0) + 1;
    }

    return nameCounts.entries
        .where((entry) => entry.value > 1)
        .map((entry) => entry.key)
        .toSet();
  }

  String _displayNameForPlayer(int playerIndex, Set<String> duplicateNames) {
    final player = widget.gameState.players[playerIndex];
    if (duplicateNames.contains(player.name)) {
      return '${player.name} (${playerIndex + 1})';
    }
    return player.name;
  }

  Widget _buildPlayerScoreCard(int playerIndex, Set<String> duplicateNames) {
    final breakdown = _calculateScoreBreakdown(playerIndex);
    final isCurrentPlayer = playerIndex == widget.gameState.currentPlayerIndex;
    final player = widget.gameState.players[playerIndex];
    // Only show "CAN GO OUT" if game is still active and player can go out
    final canGoOut =
        widget.gameState.phase == GamePhase.playing && player.canGoOut;
    final isExpanded = expandedPlayerIndex == playerIndex;
    final displayName = _displayNameForPlayer(playerIndex, duplicateNames);

    // Build accessibility label
    final accessibilityLabel =
        '$displayName, '
        'Total score: ${breakdown['gameTotal']}, '
        'Round ${widget.gameState.round} score: ${breakdown['currentRoundTotal']}, '
        '${canGoOut ? 'Can go out, ' : ''}'
        '${isCurrentPlayer ? 'Current player' : ''}';

    return Semantics(
      label: accessibilityLabel,
      child: GestureDetector(
        onTap: () {
          setState(() {
            expandedPlayerIndex = isExpanded ? null : playerIndex;
          });
        },
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
                      Flexible(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(color: Colors.white),
                                overflow: TextOverflow.ellipsis,
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
                                  border: Border.all(
                                    color: BalatroTheme.neonGreen,
                                  ),
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
                      ),
                      Flexible(
                        child: Text(
                          'Total: ${breakdown['gameTotal']}',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                color: _getScoreColor(breakdown['gameTotal']),
                              ),
                          overflow: TextOverflow.ellipsis,
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

                  // Show previous rounds if any (and not first round)
                  if (widget.gameState.round > 1 &&
                      breakdown['previousRoundsTotal'] != 0)
                    _buildScoreRow(
                      'Previous Rounds',
                      breakdown['previousRoundsTotal'],
                    ),

                  const Divider(color: Colors.white24),

                  // Round total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'This Round',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (player.roundScoreHistory.isNotEmpty)
                            Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: Colors.white54,
                              size: 20,
                            ),
                        ],
                      ),
                      Text(
                        '${breakdown['currentRoundTotal'] > 0 ? '+' : ''}${breakdown['currentRoundTotal']}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(breakdown['currentRoundTotal']),
                        ),
                      ),
                    ],
                  ),

                  // Expanded round history
                  if (isExpanded && player.roundScoreHistory.isNotEmpty)
                    _buildRoundHistory(player),
                ],
              ),
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

  Widget _buildRoundHistory(Player player) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2640).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊 Round History',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: BalatroTheme.neonYellow,
            ),
          ),
          const SizedBox(height: 8),
          ...player.roundScoreHistory.map<Widget>(
            (breakdown) => _buildRoundBreakdown(breakdown),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundBreakdown(RoundScoreBreakdown breakdown) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B29).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Round header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Round ${breakdown.round}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '${breakdown.totalRoundScore > 0 ? '+' : ''}${breakdown.totalRoundScore}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _getScoreColor(breakdown.totalRoundScore),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Detailed breakdown
          if (breakdown.cardPoints > 0)
            _buildMiniScoreRow('Card Points', breakdown.cardPoints),
          if (breakdown.cleanBooks > 0)
            _buildMiniScoreRow(
              'Clean Books (${breakdown.cleanBooks})',
              breakdown.cleanBookPoints,
            ),
          if (breakdown.dirtyBooks > 0)
            _buildMiniScoreRow(
              'Dirty Books (${breakdown.dirtyBooks})',
              breakdown.dirtyBookPoints,
            ),
          if (breakdown.goingOutBonus > 0)
            _buildMiniScoreRow('Going Out Bonus', breakdown.goingOutBonus),
          if (breakdown.penaltyPoints > 0)
            _buildMiniScoreRow('Penalty Cards', -breakdown.penaltyPoints),
        ],
      ),
    );
  }

  Widget _buildMiniScoreRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.white60)),
          Text(
            value > 0 ? '+$value' : '$value',
            style: TextStyle(
              fontSize: 11,
              color: _getScoreColor(value),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  int get _displayRoundNumber =>
      widget.completedRoundNumber ?? widget.gameState.round;

  @override
  Widget build(BuildContext context) {
    // Sort players by score once per build
    final sortedPlayers =
        List.generate(widget.gameState.players.length, (index) => index)..sort(
          (a, b) => widget.gameState.players[b].score.compareTo(
            widget.gameState.players[a].score,
          ),
        );
    final duplicateNames = _duplicatePlayerNames();
    final leaderIndex = sortedPlayers[0];
    final leaderName = _displayNameForPlayer(leaderIndex, duplicateNames);

    return Semantics(
      label: 'Scoreboard for Round $_displayRoundNumber',
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
                        widget.showContinueButton
                            ? '🏆 Round $_displayRoundNumber Complete'
                            : '🏆 Scoreboard - Round $_displayRoundNumber',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(color: Colors.white),
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
                        'Leader: $leaderName (${widget.gameState.players[leaderIndex].score} points)',
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
                  itemCount: widget.gameState.players.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildPlayerScoreCard(
                        sortedPlayers[index],
                        duplicateNames,
                      ),
                    );
                  },
                ),
              ),

              if (widget.showContinueButton)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BalatroTheme.neonGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue to Next Round',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
