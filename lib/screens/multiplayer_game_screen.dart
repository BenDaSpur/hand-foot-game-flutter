import 'package:flutter/material.dart';
import '../game/multiplayer_game_controller.dart';
import '../services/firebase_service.dart';
import '../widgets/playing_card_widget.dart';
import '../widgets/meld_widget.dart';
import '../widgets/mobile_status_bar.dart';
import '../widgets/collapsible_recent_actions.dart';
import '../widgets/compact_player_scores.dart';
import '../widgets/advanced_meld_selector.dart';
import '../theme/balatro_theme.dart';
import '../models/card.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import 'main_menu_screen.dart';

class MultiplayerGameScreen extends StatefulWidget {
  final MultiplayerGameController gameController;

  const MultiplayerGameScreen({super.key, required this.gameController});

  @override
  State<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen> {
  late MultiplayerGameController _gameController;

  final List<int> _selectedCardIndices = [];
  Player? _viewingPlayerMelds;
  bool _statusExpanded = false;
  bool _actionsExpanded = false;

  @override
  void initState() {
    super.initState();
    _gameController = widget.gameController;
  }

  @override
  void dispose() {
    _gameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [BalatroTheme.neonPink, BalatroTheme.glowColor],
          ).createShader(bounds),
          child: const Text(
            'MULTIPLAYER HAND & FOOT',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (String value) {
              switch (value) {
                case 'main_menu':
                  _returnToMainMenu();
                  break;
                case 'leave_game':
                  _leaveGame();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'leave_game',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Leave Game'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'main_menu',
                child: Row(
                  children: [
                    Icon(Icons.home, color: BalatroTheme.neonBlue),
                    SizedBox(width: 8),
                    Text('Main Menu'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a0d2e), Color(0xFF16213e), Color(0xFF0f3460)],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<GameState?>(
            stream: Stream.periodic(
              const Duration(milliseconds: 500),
            ).map((_) => _gameController.gameState),
            builder: (context, snapshot) {
              final gameState = _gameController.gameState;

              return _buildGameContent(gameState);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGameContent(GameState gameState) {
    return Column(
      children: [
        // Mobile Status Bar
        MobileStatusBar(
          gameState: gameState,
          isExpanded: _statusExpanded,
          onToggle: () => setState(() => _statusExpanded = !_statusExpanded),
        ),

        // Main game area
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Compact Player Scores
                CompactPlayerScores(
                  gameState: gameState,
                  viewingPlayerMelds: _viewingPlayerMelds,
                  onPlayerTap: (player) {
                    setState(() {
                      _viewingPlayerMelds = _viewingPlayerMelds == player
                          ? null
                          : player;
                    });
                  },
                ),

                const SizedBox(height: 16),

                // Current Turn Indicator
                _buildTurnIndicator(gameState),

                const SizedBox(height: 16),

                // Game Content
                if (_isCurrentUserTurn(gameState))
                  _buildCurrentUserContent(gameState)
                else
                  _buildWaitingContent(gameState),

                const SizedBox(height: 16),

                // Recent Actions
                CollapsibleRecentActions(
                  gameState: gameState,
                  isExpanded: _actionsExpanded,
                  onToggle: () =>
                      setState(() => _actionsExpanded = !_actionsExpanded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTurnIndicator(GameState gameState) {
    final currentPlayer = gameState.currentPlayer;
    final isCurrentUser = _isCurrentUserTurn(gameState);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? BalatroTheme.neonBlue.withValues(alpha: 0.2)
            : BalatroTheme.cardBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentUser ? BalatroTheme.neonBlue : BalatroTheme.neonPink,
          width: isCurrentUser ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCurrentUser ? Icons.play_arrow : Icons.hourglass_empty,
            color: isCurrentUser
                ? BalatroTheme.neonBlue
                : BalatroTheme.neonPink,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isCurrentUser
                  ? 'It\'s your turn!'
                  : 'Waiting for ${currentPlayer.name}...',
              style: TextStyle(
                color: isCurrentUser ? BalatroTheme.neonBlue : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: 8),
            Text(
              gameState.turnPhase.name.toUpperCase(),
              style: TextStyle(
                color: BalatroTheme.neonBlue.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentUserContent(GameState gameState) {
    final currentUserPlayer = _gameController.getCurrentUserPlayer();
    if (currentUserPlayer == null) {
      return const Text(
        'Error: Current user player not found',
        style: TextStyle(color: Colors.red),
      );
    }

    return Column(
      children: [
        // Player's hand
        _buildPlayerHand(currentUserPlayer),

        const SizedBox(height: 16),

        // Action buttons
        if (gameState.turnPhase == TurnPhase.draw)
          _buildDrawPhaseButtons(gameState)
        else if (gameState.turnPhase == TurnPhase.meld)
          _buildMeldPhaseButtons(gameState, currentUserPlayer)
        else if (gameState.turnPhase == TurnPhase.discard)
          _buildDiscardPhaseButtons(currentUserPlayer),

        const SizedBox(height: 16),

        // Player's melds
        if (currentUserPlayer.melds.isNotEmpty)
          _buildPlayerMelds(currentUserPlayer),
      ],
    );
  }

  Widget _buildWaitingContent(GameState gameState) {
    final viewingPlayer = _viewingPlayerMelds ?? gameState.currentPlayer;

    return Column(
      children: [
        // Current player indicator
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BalatroTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: BalatroTheme.neonPink.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '${gameState.currentPlayer.name} is playing',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Phase: ${gameState.turnPhase.name}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Show selected player's melds
        if (viewingPlayer.melds.isNotEmpty) ...[
          Text(
            "${viewingPlayer.name}'s Melds",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildPlayerMelds(viewingPlayer),
        ] else ...[
          Text(
            '${viewingPlayer.name} has no melds yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlayerHand(Player player) {
    if (player.currentHand.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: const Text(
          'No cards in hand',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Your Hand (${player.currentHand.length} cards)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: player.currentHand.length,
              itemBuilder: (context, index) {
                final card = player.currentHand[index];
                final isSelected = _selectedCardIndices.contains(index);
                final isNewlyDrawn = player.newlyDrawnCardIndices.contains(
                  index,
                );

                return GestureDetector(
                  onTap: () => _toggleCardSelection(index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    child: PlayingCardWidget(
                      card: card,
                      isSelected: isSelected,
                      isNewlyDrawn: isNewlyDrawn,
                      width: 60,
                      height: 84,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawPhaseButtons(GameState gameState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _gameController.drawFromDeck(),
              icon: const Icon(Icons.style),
              label: const Text('Draw from Deck'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BalatroTheme.neonBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          if (gameState.canDrawFromDiscard) ...[
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: gameState.canUnlockDiscard()
                    ? () => _gameController.unlockDiscardPile()
                    : null,
                icon: const Icon(Icons.restore),
                label: const Text('Draw from Discard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BalatroTheme.neonGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMeldPhaseButtons(GameState gameState, Player player) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (_selectedCardIndices.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _createSelectedMeld,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BalatroTheme.neonPink,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      'Create Meld (${_selectedCardIndices.length} cards)',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _clearSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _openAdvancedMeldModal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BalatroTheme.neonOrange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Advanced Meld'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _goToDiscardPhase(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BalatroTheme.mediumPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Skip to Discard'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiscardPhaseButtons(Player player) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (_selectedCardIndices.isNotEmpty)
            ElevatedButton(
              onPressed: _discardSelectedCard,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Discard Selected Card'),
            )
          else
            const Text(
              'Select a card to discard',
              style: TextStyle(color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerMelds(Player player) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${player.name}'s Melds",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...player.melds.asMap().entries.map((entry) {
            final index = entry.key;
            final meld = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: MeldWidget(
                meld: meld,
                meldIndex: index,
                canAddCards:
                    _isCurrentUserTurn(_gameController.gameState) &&
                    player.id == _gameController.userId,
                onCardDrop: (meldIndex) => _addCardToMeld(meldIndex, null),
              ),
            );
          }),
        ],
      ),
    );
  }

  // Helper methods
  bool _isCurrentUserTurn(GameState gameState) {
    return gameState.currentPlayer.id == _gameController.userId;
  }

  void _toggleCardSelection(int index) {
    if (!_isCurrentUserTurn(_gameController.gameState)) return;

    setState(() {
      if (_selectedCardIndices.contains(index)) {
        _selectedCardIndices.remove(index);
      } else {
        // In discard phase, only allow single selection
        if (_gameController.gameState.turnPhase == TurnPhase.discard) {
          _selectedCardIndices.clear();
        }
        _selectedCardIndices.add(index);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedCardIndices.clear());
  }

  void _createSelectedMeld() {
    if (_selectedCardIndices.isEmpty) return;

    final success = _gameController.createMeldByIndices(_selectedCardIndices);
    if (success) {
      setState(() => _selectedCardIndices.clear());
    } else {
      _showErrorDialog('Cannot create meld with selected cards');
    }
  }

  void _discardSelectedCard() {
    if (_selectedCardIndices.length != 1) return;

    final player = _gameController.getCurrentUserPlayer();
    if (player == null) return;

    final card = player.currentHand[_selectedCardIndices.first];
    final success = _gameController.discardCard(card);
    if (success) {
      setState(() => _selectedCardIndices.clear());
    }
  }

  void _addCardToMeld(int meldIndex, PlayingCard? card) {
    // This would be implemented for adding cards to existing melds
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Adding cards to melds not yet implemented'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _openAdvancedMeldModal() {
    final player = _gameController.getCurrentUserPlayer();
    if (player == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AdvancedMeldSelector(
        player: player,
        playDownRequirement: _gameController.gameState.playDownRequirement,
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: (meldIndices) {
          final success = _gameController.createMultipleMeldsFromIndices(
            meldIndices,
          );
          if (success) {
            setState(() => _selectedCardIndices.clear());
          }
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _goToDiscardPhase() {
    // This would advance to discard phase
    // For now, just clear selection
    setState(() => _selectedCardIndices.clear());
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.cardBackground,
        title: const Text('Error', style: TextStyle(color: Colors.red)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: TextStyle(color: BalatroTheme.neonBlue)),
          ),
        ],
      ),
    );
  }

  void _returnToMainMenu() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BalatroTheme.neonPink, width: 1),
        ),
        title: const Text(
          'Return to Main Menu',
          style: TextStyle(
            color: BalatroTheme.neonPink,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to return to the main menu? You will leave this multiplayer game.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const MainMenuScreen()),
                (route) => false,
              );
            },
            child: const Text(
              'Return to Menu',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }

  void _leaveGame() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.red, width: 1),
        ),
        title: const Text(
          'Leave Game',
          style: TextStyle(
            color: Colors.red,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to leave this multiplayer game? Other players will continue playing without you.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop(); // Close dialog

              // Properly leave the game in Firebase
              await FirebaseService.leaveGame(widget.gameController.gameId);

              if (mounted) {
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const MainMenuScreen(),
                  ),
                  (route) => false,
                );
              }
            },
            child: const Text(
              'Leave Game',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
