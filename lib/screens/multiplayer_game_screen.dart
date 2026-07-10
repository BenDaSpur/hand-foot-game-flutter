import 'package:flutter/material.dart';
import '../models/card.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../game/enhanced_multiplayer_controller.dart';
import '../widgets/compact_player_scores.dart';
import '../widgets/game_app_bar.dart';
import '../widgets/game_session_info_menu.dart';
import '../widgets/game_action_buttons.dart';
import '../widgets/melds_section.dart';
import '../widgets/collapsible_recent_actions.dart';
import '../widgets/game_hand_display.dart';
import '../widgets/advanced_meld_selector.dart';
import '../widgets/turn_timer.dart';
import '../services/multiplayer_resume_service.dart';
import '../theme/balatro_theme.dart';
import 'main_menu_screen.dart';

/// Multiplayer game screen that reuses single-player components for consistency
class MultiplayerGameScreen extends StatefulWidget {
  final EnhancedMultiplayerController gameController;

  const MultiplayerGameScreen({super.key, required this.gameController});

  @override
  State<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen> {
  late EnhancedMultiplayerController _gameController;
  final List<int> _selectedCardIndices = [];
  Player? _viewingPlayerMelds;
  bool _actionsExpanded = false;

  // Turn timer settings
  // ignore: prefer_final_fields - may be toggled in future settings
  bool _turnTimerEnabled = true;
  static const int _turnDurationSeconds = 120; // 2 minutes per turn

  @override
  void initState() {
    super.initState();
    _gameController = widget.gameController;
  }

  @override
  void dispose() {
    try {
      _gameController.dispose();
    } catch (e) {
      debugPrint('Warning: Error disposing game controller: $e');
    }
    super.dispose();
  }

  // REUSE: Copy single-player card interaction logic
  void _onCardTap(int cardIndex) {
    if (_gameController.gameState.currentPlayer.id != _gameController.userId) {
      return; // Same pattern as single-player checking PlayerType.human
    }

    final currentUserPlayer = _gameController.getCurrentUserPlayer();
    if (currentUserPlayer == null) return;
    if (cardIndex < 0 || cardIndex >= currentUserPlayer.currentHand.length) {
      return;
    }

    setState(() {
      if (_selectedCardIndices.contains(cardIndex)) {
        _selectedCardIndices.remove(cardIndex);
      } else {
        _selectedCardIndices.add(cardIndex);
      }
    });
  }

  void _onCardDoubleTap(int cardIndex) {
    if (_gameController.gameState.currentPlayer.id != _gameController.userId) {
      return;
    }

    final currentUserPlayer = _gameController.getCurrentUserPlayer();
    if (currentUserPlayer == null) return;
    if (cardIndex < 0 || cardIndex >= currentUserPlayer.currentHand.length) {
      return;
    }

    final selectedCard = currentUserPlayer.currentHand[cardIndex];
    final matchingIndices = <int>[];

    for (int i = 0; i < currentUserPlayer.currentHand.length; i++) {
      final card = currentUserPlayer.currentHand[i];
      if (card.rank == selectedCard.rank && !card.isWild) {
        matchingIndices.add(i);
      }
    }

    setState(() {
      if (matchingIndices.any((i) => _selectedCardIndices.contains(i))) {
        _selectedCardIndices.removeWhere((i) => matchingIndices.contains(i));
      } else {
        for (final i in matchingIndices) {
          if (!_selectedCardIndices.contains(i)) {
            _selectedCardIndices.add(i);
          }
        }
      }
    });
  }

  bool _isCardPlayable(PlayingCard card) {
    if (_gameController.gameState.currentPlayer.id != _gameController.userId) {
      return false;
    }

    if (_gameController.gameState.turnPhase != TurnPhase.meld) {
      return false;
    }

    final currentUserPlayer = _gameController.getCurrentUserPlayer();
    if (currentUserPlayer == null) return false;

    for (int i = 0; i < currentUserPlayer.melds.length; i++) {
      if (currentUserPlayer.melds[i].canAddCard(card)) {
        return true;
      }
    }
    return false;
  }

  List<PlayingCard> get _selectedCards {
    final currentUserPlayer = _gameController.getCurrentUserPlayer();
    if (currentUserPlayer == null) return [];

    return _selectedCardIndices
        .where((index) => index < currentUserPlayer.currentHand.length)
        .map((index) => currentUserPlayer.currentHand[index])
        .toList();
  }

  // REUSE: Copy single-player action methods (simplified)
  void _onDrawFromDeck() {
    _gameController.drawFromDeck();
    setState(() => _selectedCardIndices.clear());
  }

  void _onUnlockDiscard() {
    _gameController.unlockDiscardPile();
    setState(() => _selectedCardIndices.clear());
  }

  void _onDiscard() {
    if (_selectedCards.length == 1) {
      _gameController.discardCard(_selectedCards.first);
      setState(() => _selectedCardIndices.clear());
    }
  }

  void _showAdvancedMeldSelector() {
    final currentUserPlayer = _gameController.getCurrentUserPlayer();
    if (currentUserPlayer == null) return;

    // Safety check: Ensure we're in the correct turn phase and it's user's turn
    if (_gameController.gameState.turnPhase != TurnPhase.meld ||
        _gameController.gameState.currentPlayer.id != _gameController.userId) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdvancedMeldSelector(
        player: currentUserPlayer,
        playDownRequirement: _gameController.gameState.playDownRequirement,
        onCancel: () {
          Navigator.of(context).pop();
        },
        onConfirm: (meldIndices) {
          Navigator.of(context).pop();
          _executeAdvancedMeldCreation(meldIndices);
        },
      ),
    );
  }

  void _executeAdvancedMeldCreation(List<List<int>> meldIndices) {
    final currentUserPlayer = _gameController.getCurrentUserPlayer();
    if (currentUserPlayer == null) return;

    // Safety check: Validate all indices are valid
    for (final indices in meldIndices) {
      if (indices.any(
        (index) => index >= currentUserPlayer.currentHand.length,
      )) {
        _showErrorDialog(
          'Advanced Meld Error',
          'Invalid card selection. Please try again.',
        );
        return;
      }
    }

    // Use the multiplayer controller's multi-meld creation
    try {
      final success = _gameController.createMultipleMeldsFromIndices(
        meldIndices,
      );
      if (success) {
        setState(() => _selectedCardIndices.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully created ${meldIndices.length} meld(s)!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showErrorDialog(
          'Meld Creation Failed',
          'Unable to create melds. Please check your selection.',
        );
      }
    } catch (e) {
      _showErrorDialog('Meld Error', e.toString());
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Handle turn timeout - auto-discard a random card
  void _handleTurnTimeout() {
    if (!_gameController.isMyTurn) return;

    final currentUserPlayer = _gameController.getCurrentUserPlayer();
    if (currentUserPlayer == null || currentUserPlayer.currentHand.isEmpty) {
      return;
    }

    // If we haven't drawn yet, draw first
    if (_gameController.gameState.turnPhase == TurnPhase.draw) {
      _gameController.drawFromDeck();
    }

    // Auto-discard the first card in hand
    if (_gameController.gameState.turnPhase == TurnPhase.meld) {
      final cardToDiscard = currentUserPlayer.currentHand.first;
      _gameController.discardCard(cardToDiscard);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⏰ Time up! Auto-discarded ${cardToDiscard.displayName}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    setState(() => _selectedCardIndices.clear());
  }

  // REUSE: Implement meld interaction methods (copied from earlier)
  Future<void> _onAddCardToMeld(int meldIndex) async {
    if (_selectedCards.isEmpty) return;

    final currentUserPlayer = _gameController.getCurrentUserPlayer();
    if (currentUserPlayer == null ||
        meldIndex >= currentUserPlayer.melds.length) {
      return;
    }

    final meld = currentUserPlayer.melds[meldIndex];
    final cardsToAdd = <PlayingCard>[];

    for (final card in _selectedCards) {
      if (meld.canAddCard(card)) {
        cardsToAdd.add(card);
      }
    }

    if (cardsToAdd.isEmpty) return;

    for (final card in cardsToAdd) {
      try {
        _gameController.addCardToMeld(meldIndex, card);
      } catch (e) {
        debugPrint('Failed to add card: $e');
      }
    }

    setState(() => _selectedCardIndices.clear());
  }

  void _selectAllCardsForMeld(int meldIndex) {
    final currentUserPlayer = _gameController.getCurrentUserPlayer();
    if (currentUserPlayer == null ||
        meldIndex >= currentUserPlayer.melds.length) {
      return;
    }

    final meld = currentUserPlayer.melds[meldIndex];
    final naturalIndices = <int>[];
    final wildIndices = <int>[];

    for (int i = 0; i < currentUserPlayer.currentHand.length; i++) {
      final card = currentUserPlayer.currentHand[i];

      if (card.rank == meld.rank && !card.isWild) {
        naturalIndices.add(i);
      } else if (card.isWild) {
        wildIndices.add(i);
      }
    }

    final selectedIndices = <int>[];
    if (naturalIndices.isNotEmpty) {
      selectedIndices.addAll(naturalIndices);
    } else if (wildIndices.isNotEmpty) {
      selectedIndices.addAll(wildIndices.take(2));
    }

    setState(() {
      _selectedCardIndices.clear();
      _selectedCardIndices.addAll(selectedIndices);
    });
  }

  bool _canAddCardToMeld(int meldIndex) {
    if (_selectedCards.isEmpty) return false;

    final currentUserPlayer = _gameController.getCurrentUserPlayer();
    if (currentUserPlayer == null ||
        meldIndex >= currentUserPlayer.melds.length) {
      return false;
    }

    final meld = currentUserPlayer.melds[meldIndex];
    return _selectedCards.any((card) => meld.canAddCard(card));
  }

  ({int count, bool areWilds}) _getCompatibleCardsInfo(int meldIndex) {
    final currentUserPlayer = _gameController.getCurrentUserPlayer();
    if (currentUserPlayer == null ||
        meldIndex >= currentUserPlayer.melds.length) {
      return (count: 0, areWilds: false);
    }

    final meld = currentUserPlayer.melds[meldIndex];
    int naturalCount = 0;
    int wildCount = 0;

    for (final card in currentUserPlayer.currentHand) {
      if (card.rank == meld.rank && !card.isWild) {
        naturalCount++;
      } else if (card.isWild) {
        wildCount++;
      }
    }

    return naturalCount > 0
        ? (count: naturalCount, areWilds: false)
        : (count: wildCount, areWilds: true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GameState>(
      stream: _gameController.gameStateStream,
      initialData: _gameController.gameState,
      builder: (context, snapshot) {
        final gameState = snapshot.data ?? _gameController.gameState;
        final humanPlayer = _gameController.getCurrentUserPlayer();

        if (humanPlayer == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // HANDLE ROUND TRANSITIONS: Show appropriate UI for round end
        if (gameState.phase == GamePhase.roundEnd) {
          return _buildRoundEndScreen(gameState);
        }

        // HANDLE GAME END: Show winner screen
        if (gameState.phase == GamePhase.gameEnd) {
          return _buildGameEndScreen(gameState);
        }

        return Container(
          decoration: const BoxDecoration(
            gradient: BalatroTheme.primaryGradient,
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: GameAppBar(
              gameState: gameState,
              isMultiplayer: true,
              connectionStream: _gameController.connectionStream,
              isOnline: _gameController.isOnline,
              sessionInfo: GameSessionInfo(
                gameId: _gameController.gameId,
                playerId: _gameController.userId,
              ),
              onLeaveGame: () => Navigator.pop(context),
            ),
            body: Column(
              children: [
                // REUSE: Compact status bar
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Icon(
                        _gameController.isOnline ? Icons.wifi : Icons.wifi_off,
                        color: _gameController.isOnline
                            ? Colors.green
                            : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Round ${gameState.round}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(
                          () => _actionsExpanded = !_actionsExpanded,
                        ),
                        child: Text(
                          _actionsExpanded
                              ? 'Hide Actions ▲'
                              : 'Recent Actions ▼',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _gameController.isMyTurn
                              ? Colors.green.withValues(alpha: 0.3)
                              : Colors.orange.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _gameController.isMyTurn
                              ? 'YOUR TURN'
                              : gameState.currentPlayer.name,
                          style: TextStyle(
                            color: _gameController.isMyTurn
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      // Turn timer (only show when timer is enabled)
                      if (_turnTimerEnabled) ...[
                        const SizedBox(width: 8),
                        TurnTimer(
                          key: ValueKey(gameState.currentPlayer.id),
                          turnDurationSeconds: _turnDurationSeconds,
                          isActive: _gameController.isMyTurn,
                          onTimeUp: _handleTurnTimeout,
                          onTick: (remaining) {
                            // Show warning at 30 seconds
                            if (remaining == 30 && _gameController.isMyTurn) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('⏰ 30 seconds remaining!'),
                                  backgroundColor: Colors.orange,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                // REUSE: Recent actions (collapsible)
                if (_actionsExpanded)
                  CollapsibleRecentActions(
                    gameState: gameState,
                    isExpanded: _actionsExpanded,
                    onToggle: () =>
                        setState(() => _actionsExpanded = !_actionsExpanded),
                  ),

                // REUSE: Player scores with multiplayer support
                CompactPlayerScores(
                  gameState: gameState,
                  viewingPlayerMelds: _viewingPlayerMelds,
                  onPlayerTap: (player) {
                    setState(() {
                      // If tapping on the current user's player, set to null (view own melds)
                      // Otherwise, set to the specific player to view their melds
                      _viewingPlayerMelds = player.id == _gameController.userId
                          ? null
                          : player;
                    });
                  },
                  currentUserId:
                      _gameController.userId, // Enable multiplayer mode
                ),

                // REUSE: Melds section with multiplayer support
                if (_viewingPlayerMelds != null)
                  Expanded(
                    flex: 2,
                    child: MeldsSection(
                      gameState: gameState,
                      humanPlayer: humanPlayer,
                      viewingPlayerMelds: _viewingPlayerMelds,
                      onViewPlayerMelds: (player) =>
                          setState(() => _viewingPlayerMelds = player),
                      onAddCardToMeld: _onAddCardToMeld,
                      onSelectAllCardsForMeld: _selectAllCardsForMeld,
                      canAddCardToMeld: _canAddCardToMeld,
                      getCompatibleCardsInfo: _getCompatibleCardsInfo,
                      currentUserId:
                          _gameController.userId, // Enable multiplayer mode
                    ),
                  ),

                // SPACER: Push hand to bottom (like single-player)
                if (_viewingPlayerMelds == null) const Spacer(),

                // REUSE: Action buttons with single-player logic
                GameActionButtons(
                  gameState: gameState,
                  humanPlayer: humanPlayer,
                  selectedCardIndices: _selectedCardIndices,
                  onDrawFromDeck: _onDrawFromDeck,
                  onUnlockDiscard:
                      (gameState.turnPhase == TurnPhase.draw &&
                          _gameController.canUnlockDiscard())
                      ? _onUnlockDiscard
                      : null,
                  onShowAdvancedMeldSelector: _showAdvancedMeldSelector,
                  onDiscard: _selectedCards.length == 1 ? _onDiscard : null,
                  onClearSelection: () =>
                      setState(() => _selectedCardIndices.clear()),
                  currentUserId: _gameController.userId,
                ),

                // REUSE: Perfect hand display from single-player with proper turn state
                GameHandDisplay(
                  player: humanPlayer,
                  selectedCardIndices: _selectedCardIndices,
                  onCardTap: _onCardTap,
                  onCardDoubleTap: _onCardDoubleTap,
                  isCardPlayable: _isCardPlayable,
                  viewingPlayerMelds: _viewingPlayerMelds,
                  onReturnToHand: () =>
                      setState(() => _viewingPlayerMelds = null),
                  isCurrentPlayerTurn:
                      _gameController.gameState.currentPlayer.id ==
                      _gameController.userId,
                  showHighlights:
                      true, // Always show newly drawn highlights in multiplayer
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build round end screen - only host can advance, others wait
  Widget _buildRoundEndScreen(GameState gameState) {
    return Container(
      decoration: const BoxDecoration(gradient: BalatroTheme.primaryGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Round Ended'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events, color: Colors.amber[400], size: 80),
              const SizedBox(height: 16),
              Text(
                'Round ${gameState.round - 1} Complete!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),

              // Show score summary
              ...gameState.players.map(
                (player) => Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${player.name}: ${player.score} points',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Host controls round advancement
              if (_gameController.isHost)
                ElevatedButton(
                  onPressed: () {
                    _gameController.nextRound();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'Start Next Round',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    children: [
                      CircularProgressIndicator(color: Colors.orange),
                      SizedBox(height: 8),
                      Text(
                        'Waiting for host to start next round...',
                        style: TextStyle(color: Colors.orange, fontSize: 14),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build game end screen with winner announcement
  Widget _buildGameEndScreen(GameState gameState) {
    return Container(
      decoration: const BoxDecoration(gradient: BalatroTheme.primaryGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Game Complete'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.celebration, color: Colors.amber[400], size: 100),
              const SizedBox(height: 16),
              Text(
                '🎉 ${gameState.winner?.name ?? "Unknown"} Wins! 🎉',
                style: TextStyle(
                  color: Colors.amber[400],
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Final Score: ${gameState.winner?.score ?? 0} points',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 32),

              // Final leaderboard
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Final Standings:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...gameState.players
                        .map((player) => player)
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) {
                          final position = entry.key + 1;
                          final player = entry.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '$position. ${player.name}: ${player.score} points',
                              style: TextStyle(
                                color: position == 1
                                    ? Colors.amber[400]
                                    : Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: () {
                  // Clean up game and return to main menu
                  _cleanupAndExit();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Return to Main Menu',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Clean up multiplayer game and return to main menu
  void _cleanupAndExit() {
    // Clear active game info (user is intentionally leaving)
    MultiplayerResumeService.clearActiveGame().catchError((e) {
      debugPrint('Warning: Failed to clear active game on exit: $e');
    });

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MainMenuScreen()),
      (route) => false,
    );
  }
}
