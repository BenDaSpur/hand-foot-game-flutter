import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/card.dart';
import '../models/player.dart';
import '../models/meld.dart';
import '../models/game_state.dart';
import '../game/game_controller.dart';
import '../game/game_controller_factory.dart';
import '../ai/enhanced_bot_ai.dart';
import '../ai/bot_personality.dart';
import '../widgets/playing_card_widget.dart';
import '../widgets/meld_widget.dart';
import '../widgets/mobile_status_bar.dart';
import '../widgets/collapsible_recent_actions.dart';
import '../widgets/compact_player_scores.dart';
import '../theme/balatro_theme.dart';
import '../services/game_analytics_logger.dart';
import 'main_menu_screen.dart';
import '../utils/debug_logger.dart';
import 'managers/bot_turn_manager.dart';
import 'managers/dialog_manager.dart';
import 'managers/game_state_manager.dart';
import 'managers/persistence_manager.dart';

/// Bot configuration for randomized personality assignment
class BotConfig {
  final String name;
  final BotPersonality personality;

  BotConfig(this.name, this.personality);
}

class GameScreen extends StatefulWidget {
  final int? testSeed; // For deterministic testing
  final GameController? gameController; // For continuing saved games

  const GameScreen({super.key, this.testSeed, this.gameController});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController _gameController;
  late EnhancedBotAI _botAI;

  final List<int> _selectedCardIndices =
      []; // Track card indices instead of card objects
  bool _isInitialized = false;
  Player? _viewingPlayerMelds; // null means viewing human player's melds
  bool _statusExpanded = false;
  bool _actionsExpanded = false;
  bool _disposed = false; // Track disposal state
  bool _hasPlayerInteractedSinceDraw = false; // Prevent auto-discard after draw

  // Analytics tracking
  String? _analyticsSessionId;
  final int _totalTurns = 0;
  int _actionSequenceNumber = 0; // Track action sequence within game

  // Manager instances for better code organization
  late BotTurnManager _botTurnManager;
  late DialogManager _dialogManager;
  late GameStateManager _gameStateManager;
  late PersistenceManager _persistenceManager;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Helper method to assign bot personalities consistently
  void _assignBotPersonalities() {
    final botPlayers = _gameController.gameState.players
        .where((p) => p.type == PlayerType.bot)
        .toList();
    _botAI.assignRandomPersonalities(botPlayers);

    // Log personality assignments in debug mode
    if (kDebugMode) {
      for (final bot in botPlayers) {
        final personality = _botAI.personalityManager.getPersonality(bot.id);
        print('Bot ${bot.name} (${bot.id}) assigned personality: $personality');
      }
    }
  }

  /// Initialize all manager instances after game controller setup
  void _initializeManagers() {
    _botTurnManager = BotTurnManager(
      gameController: _gameController,
      botAI: _botAI,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      logHumanAction: (action) =>
          _logHumanAction(action: action, reasoning: 'Bot turn processing'),
      logBotDecision: _logBotDecision,
    );

    _dialogManager = DialogManager(
      context: context,
      gameController: _gameController,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      onNewGame: _startNewGame,
      onReturnToMenu: _returnToMainMenu,
    );

    _gameStateManager = GameStateManager(
      gameController: _gameController,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      onGameEnd: () {
        if (_gameController.gameState.winner != null) {
          _dialogManager.showGameEndDialog(
            _gameController.gameState.winner!,
            _gameController.gameState.players,
          );
        }
      },
      onRoundEnd: () {
        // Clear UI selections and reset for next round
        _selectedCardIndices.clear();
        _viewingPlayerMelds = null;
        processCurrentPlayerTurn();
      },
    );

    _persistenceManager = PersistenceManager(
      gameController: _gameController,
      botAI: _botAI,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      onGameLoaded: (newController, botPersonalities) {
        setState(() {
          _gameController = newController;
          _botAI = EnhancedBotAI();

          // Restore saved bot personalities or assign new ones
          if (botPersonalities.isNotEmpty) {
            _botTurnManager.restoreBotPersonalities(botPersonalities);
          } else {
            _botTurnManager.assignBotPersonalities();
          }

          _selectedCardIndices.clear();
          _viewingPlayerMelds = null;
          _isInitialized = true;

          // Reinitialize managers with new controller
          _initializeManagers();
        });
      },
    );
  }

  Future<void> _initializeGame() async {
    // If a gameController was provided (continuing saved game), use it
    if (widget.gameController != null) {
      _gameController = widget.gameController!;
      _botAI = EnhancedBotAI();
      _initializeManagers();

      setState(() {
        _isInitialized = true;
      });

      // Start bot turns if needed
      processCurrentPlayerTurn();
      return;
    }

    // Check if there's a saved game
    final hasSaved = await GameController.hasSavedGame();

    if (hasSaved) {
      // Show restore dialog directly
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Saved Game Found'),
            content: const Text(
              'Would you like to continue your previous game or start a new one?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startFreshGame();
                },
                child: const Text('New Game'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _restoreSavedGame();
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }
      return;
    }

    _startFreshGame();
  }

  /// Generate random bot configurations with varied personalities and names
  List<BotConfig> _generateRandomBotConfigurations() {
    final Random random = Random();

    // Available bot personalities and their associated names
    final botOptions = [
      BotConfig('Clara', BotPersonality.conservative),
      BotConfig('Carl', BotPersonality.conservative),
      BotConfig('Bob', BotPersonality.aggressive),
      BotConfig('Rita', BotPersonality.aggressive),
      BotConfig('Ben', BotPersonality.bookBuilder),
      BotConfig('Penny', BotPersonality.bookBuilder),
      BotConfig('Alex', BotPersonality.adaptive),
      BotConfig('Sue', BotPersonality.adaptive),
    ];

    // Shuffle and take first two to ensure no duplicates
    botOptions.shuffle(random);
    return botOptions.take(2).toList();
  }

  void _startFreshGame() {
    // Randomize bot personalities and names each game for variety
    final botConfigs = _generateRandomBotConfigurations();

    final players = [
      Player(id: '1', name: 'You', type: PlayerType.human),
      Player(id: '2', name: botConfigs[0].name, type: PlayerType.bot),
      Player(id: '3', name: botConfigs[1].name, type: PlayerType.bot),
    ];

    // Debug logging for player setup
    DebugLogger.debug('Setting up fresh game with players:');
    for (var player in players) {
      DebugLogger.debug(
        '  - ${player.name} (ID: ${player.id}, Type: ${player.type})',
      );
    }

    _gameController = GameControllerFactory.createSingleplayerGame(
      players: players,
      seed: widget.testSeed,
    );

    // Create bot AI and assign the randomized personalities
    _botAI = EnhancedBotAI();
    _botAI.assignPersonality('2', botConfigs[0].personality);
    _botAI.assignPersonality('3', botConfigs[1].personality);

    _gameController.initializeGame();

    // Initialize managers after game setup
    _initializeManagers();

    // Sort the human player's initial hand
    final humanPlayer = players.firstWhere((p) => p.type == PlayerType.human);
    humanPlayer.sortHandByRank();

    // Start analytics session tracking
    _startAnalyticsSession();

    setState(() {
      _isInitialized = true;
    });

    // If the first player is human, save the initial game state
    if (_gameController.gameState.currentPlayer.type == PlayerType.human) {
      _persistenceManager.saveGameState().catchError((error) {
        DebugLogger.error('Error saving initial game state: $error');
      });
    }

    processCurrentPlayerTurn();
  }

  /// SIMPLIFIED: Single entry point for turn processing with error recovery
  void processCurrentPlayerTurn() {
    if (!_isInitialized || _disposed || !mounted) return;

    try {
      // Validate game state before processing
      if (!_gameStateManager.validateGameState()) {
        DebugLogger.error('Game state invalid - attempting recovery');
        _gameStateManager.attemptGameStateRecovery();
        return;
      }

      final currentPlayer = _gameController.gameState.currentPlayer;

      // CRITICAL: Defend against turn corruption from multiplayer sync or other sources
      final humanPlayer = _gameController.gameState.players.firstWhere(
        (p) => p.type == PlayerType.human,
      );
      if (_gameController.gameState.turnPhase == TurnPhase.meld &&
          humanPlayer.currentHand.isNotEmpty &&
          currentPlayer.type != PlayerType.human) {
        DebugLogger.error(
          'TURN CORRUPTION DETECTED: Human should be playing but current player is ${currentPlayer.name}',
        );
        DebugLogger.debug('Correcting current player back to human');
        final humanIndex = _gameController.gameState.players.indexWhere(
          (p) => p.type == PlayerType.human,
        );
        _gameController.gameState.currentPlayerIndex = humanIndex;
        return;
      }

      // Check for round end condition first
      if (_gameController.gameState.phase == GamePhase.roundEnd) {
        DebugLogger.debug(
          'Round has ended - handling transition (Round ${_gameController.gameState.round})',
        );
        _handleRoundTransition().catchError((error) {
          DebugLogger.error('Error handling round transition: $error');
        });
        return;
      }

      // Human turn: Do nothing, wait for UI input
      if (currentPlayer.type == PlayerType.human ||
          currentPlayer.name == 'You') {
        DebugLogger.debug('Human turn - waiting for input');
        _gameStateManager.validateHumanPlayerState();
        // CRITICAL: Ensure we never auto-process human turns
        _botTurnManager
            .resetProcessingState(); // Clear any stuck bot processing flag
        if (mounted) {
          setState(() {}); // Update UI to show it's human turn
          _gameStateManager.checkForRoundTransition();
        }
        return;
      }

      // Bot turn: Process with safety checks and delays
      if (!_botTurnManager.isProcessingBotTurn) {
        // DOUBLE CHECK: Make absolutely sure this is a bot before processing
        if (currentPlayer.type != PlayerType.bot) {
          DebugLogger.error(
            'CRITICAL: Attempted to process non-bot player ${currentPlayer.name} as bot',
          );
          return;
        }
        DebugLogger.debug('Starting bot turn for ${currentPlayer.name}');
        _botTurnManager.processBotTurnWithDelays(currentPlayer);
      } else {
        DebugLogger.warning(
          'Bot processing already in progress - skipping duplicate call',
        );
      }
    } catch (e) {
      DebugLogger.error('Error in processCurrentPlayerTurn: $e');
      _handleCriticalError(e);
    }
  }

  /// Handle complete round transition with proper state management
  Future<void> _handleRoundTransition() async {
    if (_gameController.gameState.phase != GamePhase.roundEnd) return;

    DebugLogger.debug('Handling round transition - calculating scores');

    // Brief pause to show scores
    await Future.delayed(const Duration(seconds: 2));
    if (_disposed || !mounted) return;

    // Check if game should end (phase set to gameEnd by endRound() logic)
    if (_gameController.gameState.phase == GamePhase.gameEnd) {
      final scores = _gameController.gameState.players
          .map((p) => p.score)
          .toList();
      final highestScore = scores.isEmpty
          ? 0
          : scores.reduce((a, b) => a > b ? a : b);

      DebugLogger.debug(
        'Game end condition met - highest score: $highestScore',
      );
      _dialogManager.showGameEndDialog(
        _gameController.gameState.winner!,
        _gameController.gameState.players,
      );
      return;
    }

    // Continue to next round
    try {
      _gameController.nextRound();
      DebugLogger.debug('Advanced to round ${_gameController.gameState.round}');

      if (mounted) {
        setState(() {});

        // Clear any UI selections
        _selectedCardIndices.clear();
        _viewingPlayerMelds = null;

        // Save game state after round transition (fire and forget)
        _persistenceManager.saveGameState().catchError((error) {
          DebugLogger.error(
            'Error saving game state after round transition: $error',
          );
        });

        // Resume game flow
        processCurrentPlayerTurn();
      }
    } catch (e) {
      DebugLogger.error('Error during round transition: $e');
      _dialogManager.showErrorDialog(
        'Error advancing to next round: ${e.toString()}',
      );
    }
  }

  void _onCardTap(int cardIndex) {
    if (_gameController.gameState.currentPlayer.type != PlayerType.human) {
      return;
    }

    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    // Bounds checking
    if (cardIndex < 0 || cardIndex >= humanPlayer.currentHand.length) return;

    _hasPlayerInteractedSinceDraw = true; // Mark that player has interacted
    setState(() {
      if (_selectedCardIndices.contains(cardIndex)) {
        _selectedCardIndices.remove(cardIndex);
      } else {
        _selectedCardIndices.add(cardIndex);
      }
    });
  }

  void _onCardDoubleTap(int cardIndex) {
    if (_gameController.gameState.currentPlayer.type != PlayerType.human) {
      return;
    }

    _hasPlayerInteractedSinceDraw = true; // Mark that player has interacted

    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    if (cardIndex < 0 || cardIndex >= humanPlayer.currentHand.length) return;

    final selectedCard = humanPlayer.currentHand[cardIndex];
    final matchingIndices = <int>[];

    // Find all cards of the same rank (including the tapped one)
    for (int i = 0; i < humanPlayer.currentHand.length; i++) {
      final card = humanPlayer.currentHand[i];
      if (card.rank == selectedCard.rank && !card.isWild) {
        matchingIndices.add(i);
      }
    }

    setState(() {
      // If any matching cards are already selected, deselect all matching cards
      if (matchingIndices.any((i) => _selectedCardIndices.contains(i))) {
        _selectedCardIndices.removeWhere((i) => matchingIndices.contains(i));
      } else {
        // Otherwise, select all matching cards
        for (final i in matchingIndices) {
          if (!_selectedCardIndices.contains(i)) {
            _selectedCardIndices.add(i);
          }
        }
      }
    });
  }

  void _selectAllCardsForMeld(int meldIndex) {
    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    if (meldIndex >= humanPlayer.melds.length) return;

    final meld = humanPlayer.melds[meldIndex];
    final naturalIndices = <int>[];
    final wildIndices = <int>[];

    // First pass: collect natural cards of the same rank and all wild cards
    for (int i = 0; i < humanPlayer.currentHand.length; i++) {
      final card = humanPlayer.currentHand[i];

      if (card.rank == meld.rank && !card.isWild) {
        // Natural cards of the same rank as the meld
        naturalIndices.add(i);
      } else if (card.isWild) {
        // All wild cards (we'll filter later based on meld type and strategy)
        wildIndices.add(i);
      }
    }

    final selectedIndices = <int>[];

    if (naturalIndices.isNotEmpty) {
      // For existing melds, prefer natural cards of the same rank over wilds
      // This provides cleaner gameplay - add natural cards first, wilds only if needed
      selectedIndices.addAll(naturalIndices);
    } else if (wildIndices.isNotEmpty) {
      // Only select wilds if no natural cards of this rank are available
      final currentWildsInMeld = meld.cards.where((c) => c.isWild).length;
      final currentNaturalsInMeld = meld.cards.where((c) => !c.isWild).length;
      final maxAdditionalWilds = currentNaturalsInMeld - currentWildsInMeld;

      if (maxAdditionalWilds > 0) {
        final wildsToAdd = wildIndices.take(maxAdditionalWilds).toList();
        selectedIndices.addAll(wildsToAdd);
      }
    }

    setState(() {
      // Clear current selection and select the smart selection
      _selectedCardIndices.clear();
      _selectedCardIndices.addAll(selectedIndices);
    });
  }

  List<PlayingCard> get _selectedCards {
    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );
    return _selectedCardIndices
        .where((index) => index < humanPlayer.currentHand.length)
        .map((index) => humanPlayer.currentHand[index])
        .toList();
  }

  bool _isCardPlayable(PlayingCard card) {
    if (_gameController.gameState.currentPlayer.type != PlayerType.human) {
      return false;
    }

    if (_gameController.gameState.turnPhase != TurnPhase.meld) {
      return false;
    }

    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    // Check if this card can be added to any existing meld
    for (int i = 0; i < humanPlayer.melds.length; i++) {
      if (humanPlayer.melds[i].canAddCard(card)) {
        return true;
      }
    }

    // Check if this card can form a new meld
    final possibleMelds = _gameController.findPossibleMelds(humanPlayer);
    for (final meld in possibleMelds) {
      if (meld.contains(card)) {
        return true;
      }
    }

    return false;
  }

  bool _isGameStuck() {
    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );
    final currentPlayer = _gameController.gameState.currentPlayer;

    // Only consider it stuck if:
    // 1. It's the human player's turn
    // 2. They have an empty foot (not just empty hand - that's normal transition)
    // 3. They've already picked up their foot
    // 4. They don't meet the requirements to go out
    return currentPlayer.type == PlayerType.human &&
        humanPlayer.hasPickedUpFoot &&
        humanPlayer.foot.isEmpty &&
        !humanPlayer.canGoOutWithBooks &&
        _gameController.gameState.turnPhase == TurnPhase.meld;
  }

  void _forceNextTurn() {
    _gameController.gameState.nextPlayer();
    setState(() {});
    processCurrentPlayerTurn();
  }

  Future<void> _restoreSavedGame() async {
    try {
      final savedController = await GameController.loadSavedGame();

      if (savedController != null) {
        _gameController = savedController;
        _botAI = EnhancedBotAI();

        // Assign consistent bot personalities based on player IDs
        _assignBotPersonalities();

        // Sort the human player's hand
        final humanPlayer = _gameController.gameState.players.firstWhere(
          (p) => p.type == PlayerType.human,
        );
        humanPlayer.sortHandByRank();

        setState(() {
          _isInitialized = true;
        });

        // Continue game flow
        processCurrentPlayerTurn();
      } else {
        _dialogManager.showErrorDialog(
          'Failed to load saved game. Starting new game.',
        );
        _startFreshGame();
      }
    } catch (e) {
      _dialogManager.showErrorDialog(
        'Error loading saved game: ${e.toString()}',
      );
      _startFreshGame();
    }
  }

  Future<void> _startNewGame() async {
    // Clear any saved game when explicitly starting new
    await GameController.clearSavedGame();

    setState(() {
      _isInitialized = false;
      _selectedCardIndices.clear();
      _viewingPlayerMelds = null;
    });

    // Start a fresh game directly (not checking for saves)
    _startFreshGame();
  }

  void _onDrawFromDeck() {
    if (_gameController.drawFromDeck()) {
      // Log human action for analytics
      _logHumanAction(
        action: 'drawFromDeck',
        reasoning: 'Human player drew 2 cards from deck',
      );

      // Cards are now automatically inserted in sorted position
      _hasPlayerInteractedSinceDraw =
          false; // Reset interaction flag after drawing
      setState(() {}); // Just refresh the UI
    } else {
      // Check if the round ended automatically due to insufficient cards
      if (_gameController.gameState.phase == GamePhase.roundEnd) {
        _dialogManager.showEmergencyRoundEndDialog();
      } else {
        // Check if deck is empty or insufficient
        if (_gameController.gameState.deck.isEmpty) {
          _dialogManager.showErrorDialog(
            'Cannot draw from deck: The deck is empty!\n\n'
            'The round will continue until a player goes out or all players pass.',
          );
        } else if (_gameController.gameState.deck.size < 2) {
          _dialogManager.showErrorDialog(
            'Cannot draw from deck: Only ${_gameController.gameState.deck.size} card(s) remaining.\n\n'
            'You must draw exactly 2 cards from the deck. Try drawing from the discard pile instead.',
          );
        }
      }
    }
  }

  void _onUnlockDiscard() {
    if (_gameController.unlockDiscardPile()) {
      // Cards are now automatically inserted in sorted position
      setState(() {}); // Just refresh the UI
    }
  }

  Future<void> _onAddCardToMeld(int meldIndex) async {
    if (_selectedCards.isEmpty) {
      _dialogManager.showErrorDialog(
        'Select at least one card first before clicking on a meld.',
      );
      return;
    }

    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    if (meldIndex >= humanPlayer.melds.length) {
      _dialogManager.showErrorDialog('Invalid meld selected.');
      return;
    }

    final meld = humanPlayer.melds[meldIndex];
    final cardsToAdd = <PlayingCard>[];
    final invalidCards = <PlayingCard>[];

    // Check which selected cards can be added to this meld
    for (final card in _selectedCards) {
      if (meld.canAddCard(card)) {
        cardsToAdd.add(card);
      } else {
        invalidCards.add(card);
      }
    }

    if (cardsToAdd.isEmpty) {
      final cardNames = _selectedCards.map((c) => c.displayName).join(', ');
      _dialogManager.showErrorDialog(
        'None of the selected cards ($cardNames) can be added to this meld!',
      );
      return;
    }

    // Check if any cards to add are wilds and need confirmation
    final wildsToAdd = cardsToAdd.where((card) => card.isWild).toList();
    if (wildsToAdd.isNotEmpty) {
      _showWildCardConfirmation(meldIndex, cardsToAdd, invalidCards);
      return;
    }

    // Add all valid cards one by one (non-wilds)
    await _addCardsToMeld(meldIndex, cardsToAdd, invalidCards);
  }

  bool _canAddCardToMeld(int meldIndex) {
    if (_selectedCards.isEmpty) return false;

    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    if (meldIndex >= humanPlayer.melds.length) return false;

    final meld = humanPlayer.melds[meldIndex];

    // Return true if at least one selected card can be added
    return _selectedCards.any((card) => meld.canAddCard(card));
  }

  ({int count, bool areWilds}) _getCompatibleCardsInfo(int meldIndex) {
    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    if (meldIndex >= humanPlayer.melds.length) {
      return (count: 0, areWilds: false);
    }

    final meld = humanPlayer.melds[meldIndex];
    int naturalCount = 0;
    int wildAsWildCount = 0;

    for (final card in humanPlayer.currentHand) {
      if (card.rank == meld.rank && !card.isWild) {
        // Natural cards of the same rank
        naturalCount++;
      } else if (card.isWild) {
        // Wild cards that could be used as wilds
        wildAsWildCount++;
      }
    }

    // For existing melds, prioritize natural cards over wilds
    if (naturalCount > 0) {
      // Only count natural cards when they're available for existing melds
      return (count: naturalCount, areWilds: false);
    }

    // If no natural cards available, count wilds that could be added
    if (wildAsWildCount > 0) {
      final currentWildsInMeld = meld.cards.where((c) => c.isWild).length;
      final currentNaturalsInMeld = meld.cards.where((c) => !c.isWild).length;
      final maxAdditionalWilds = currentNaturalsInMeld - currentWildsInMeld;
      final usableWilds = wildAsWildCount > maxAdditionalWilds
          ? maxAdditionalWilds
          : wildAsWildCount;
      return usableWilds > 0
          ? (count: usableWilds, areWilds: true)
          : (count: 0, areWilds: false);
    }

    return (count: 0, areWilds: false);
  }

  void _executeAdvancedMeldCreation(List<List<int>> meldIndices) {
    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    // Safety check: Validate all indices are valid
    for (final indices in meldIndices) {
      if (indices.any((index) => index >= humanPlayer.currentHand.length)) {
        _dialogManager.showErrorDialog(
          'Invalid card selection. Please try again.',
        );
        return;
      }
    }

    // Check for wild cards across all melds and show warning if needed
    final allWildCards = <PlayingCard>[];
    final allMeldCards = <List<PlayingCard>>[];

    for (final indices in meldIndices) {
      final cards = indices.map((i) => humanPlayer.currentHand[i]).toList();
      allMeldCards.add(cards);
      allWildCards.addAll(cards.where((card) => card.isWild));
    }

    if (allWildCards.isNotEmpty) {
      _showWildCardConfirmationForMultiMeld(
        meldIndices,
        allMeldCards,
        allWildCards,
      );
    } else {
      _performMultiMeldCreation(meldIndices);
    }
  }

  void _showWildCardConfirmationForMultiMeld(
    List<List<int>> meldIndices,
    List<List<PlayingCard>> allMeldCards,
    List<PlayingCard> allWildCards,
  ) {
    final wildNames = allWildCards.map((c) => c.displayName).join(', ');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Create Melds with Wilds?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to create ${meldIndices.length} meld(s) with wild cards:',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Text(
                wildNames,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will create "dirty book(s)" from the start. Are you sure?',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performMultiMeldCreation(meldIndices);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create Melds'),
          ),
        ],
      ),
    );
  }

  Future<void> _performMultiMeldCreation(List<List<int>> meldIndices) async {
    // Use the new atomic multi-meld creation method
    final success = _gameController.createMultipleMeldsFromIndices(
      meldIndices,
      skipPlayDownCheck: true,
    );

    if (success) {
      // Log human meld creation
      _logHumanAction(
        action: meldIndices.length == 1 ? 'createMeld' : 'createMultipleMelds',
        reasoning: meldIndices.length == 1
            ? 'Human created new meld'
            : 'Human created ${meldIndices.length} new melds',
        context: {
          'meldCount': meldIndices.length,
          'totalCards': meldIndices.expand((x) => x).length,
        },
      );
      _sortHand('rank');
      setState(() {});

      // Check if creating melds caused the round to end
      await _gameStateManager.checkAndHandleRoundEnd();

      // Show success message
      final message = meldIndices.length == 1
          ? 'Successfully created meld!'
          : 'Successfully created ${meldIndices.length} melds!';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      }
    } else {
      _dialogManager.showErrorDialog(
        'Failed to create melds. Please check your selections and try again.',
      );
    }
  }

  Future<void> _onDiscard() async {
    // CRITICAL FIX: Prevent auto-discard after drawing cards
    if (!_hasPlayerInteractedSinceDraw) {
      return;
    }
    if (_selectedCards.length == 1) {
      final humanPlayer = _gameController.gameState.players.firstWhere(
        (p) => p.type == PlayerType.human,
      );

      // Check if discarding this card would empty the hand/foot
      final willBeEmpty = humanPlayer.currentHand.length == 1;

      if (willBeEmpty) {
        // If this would be the last card, validate going out requirements
        if (!humanPlayer.hasPickedUpFoot) {
          // Going from hand to foot is always allowed
          if (_gameController.discardCard(_selectedCards.first)) {
            // Log human discard action
            _logHumanAction(
              action: 'discardCard',
              reasoning: 'Human discarded ${_selectedCards.first.compactName}',
              context: {
                'card': _selectedCards.first.compactName,
                'transitioningToFoot': !humanPlayer.hasPickedUpFoot,
              },
            );

            // Handle post-discard state updates (same as bot players)
            _botTurnManager.handlePostDiscardState(humanPlayer);

            setState(() {});
            _selectedCardIndices.clear();
            await _gameStateManager.checkAndHandleRoundEnd();

            // Schedule bot processing for next frame to avoid immediate execution during human turn
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted &&
                  _gameController.gameState.currentPlayer.type !=
                      PlayerType.human) {
                processCurrentPlayerTurn();
              }
            });
          }
          return;
        }

        // This would end the game - check requirements
        if (!humanPlayer.canGoOutWithBooks) {
          String missingBooks = '';
          final cleanBooks = humanPlayer.melds.where((m) => m.isClean).length;
          final dirtyBooks = humanPlayer.melds.where((m) => m.isDirty).length;
          final totalBooks = humanPlayer.melds.where((m) => m.isBook).length;

          if (!humanPlayer.hasCleanBook && !humanPlayer.hasDirtyBook) {
            missingBooks =
                'You need both a clean book (no wild cards) and a dirty book (with wild cards) to go out.';
          } else if (!humanPlayer.hasCleanBook) {
            missingBooks = 'You need a clean book (no wild cards) to go out.';
          } else if (!humanPlayer.hasDirtyBook) {
            missingBooks = 'You need a dirty book (with wild cards) to go out.';
          }

          _dialogManager.showErrorDialog(
            'Cannot go out! $missingBooks\n\nYou currently have:\n• $totalBooks book(s) total\n• $cleanBooks clean book(s)\n• $dirtyBooks dirty book(s)',
          );
          return;
        }
      }

      if (_gameController.discardCard(_selectedCards.first)) {
        // Log human discard action
        _logHumanAction(
          action: 'discardCard',
          reasoning: 'Human discarded ${_selectedCards.first.compactName}',
          context: {
            'card': _selectedCards.first.compactName,
            'goingOut': willBeEmpty,
          },
        );

        // Handle post-discard state updates (same as bot players)
        _botTurnManager.handlePostDiscardState(humanPlayer);

        setState(() {});
        _selectedCardIndices.clear();
        await _gameStateManager.checkAndHandleRoundEnd();

        // Schedule bot processing for next frame to avoid immediate execution during human turn
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _gameController.gameState.currentPlayer.type !=
                  PlayerType.human) {
            processCurrentPlayerTurn();
          }
        });
      }
    } else {
      // Handle case where player has no cards to discard
      final humanPlayer = _gameController.gameState.players.firstWhere(
        (p) => p.type == PlayerType.human,
      );

      if (humanPlayer.currentHand.isEmpty) {
        // DO NOT automatically pick up foot - let human player decide
        if (!humanPlayer.hasPickedUpFoot && humanPlayer.hand.isEmpty) {
          DebugLogger.debug('Human player needs to pick up foot manually');
          // Show a message to the user instead of doing it automatically
          _dialogManager.showErrorDialog(
            'Your hand is empty! Please pick up your foot pile to continue.',
          );
          return;
        }

        // If both hand and foot are empty, but requirements aren't met
        if (humanPlayer.hasPickedUpFoot &&
            humanPlayer.foot.isEmpty &&
            !humanPlayer.canGoOutWithBooks) {
          _dialogManager.showErrorDialog(
            'Cannot go out! You need both clean and dirty books to win.',
          );
          return;
        }

        // Force advance turn if we're truly stuck
        _gameController.gameState.nextPlayer();
        setState(() {});
        processCurrentPlayerTurn();
      }
    }
  }

  void _sortHand(String sortType) {
    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    switch (sortType) {
      case 'rank':
        humanPlayer.sortHandByRank();
        break;
      case 'suit':
        humanPlayer.sortHandBySuit();
        break;
      case 'value':
        humanPlayer.sortHandByValue();
        break;
    }

    setState(() {});
    _selectedCardIndices.clear();
  }

  void _showWildCardConfirmation(
    int meldIndex,
    List<PlayingCard> cardsToAdd,
    List<PlayingCard> invalidCards,
  ) {
    final wildsToAdd = cardsToAdd.where((card) => card.isWild).toList();
    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );
    final meld = humanPlayer.melds[meldIndex];

    final wildNames = wildsToAdd.map((c) => c.displayName).join(', ');
    final meldName = '${meld.rank.name.toUpperCase()}s';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              meld.type == MeldType.natural
                  ? 'Make Meld Dirty?'
                  : 'Add Wild Cards?',
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to add wild cards to your $meldName meld:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Text(
                wildNames,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              meld.type == MeldType.natural
                  ? 'This will make your meld a "dirty book" and you will lose the clean book bonus (500 pts). Are you sure?'
                  : 'This will add more wild cards to your existing dirty meld. Are you sure?',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _addCardsToMeld(meldIndex, cardsToAdd, invalidCards);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text(
              meld.type == MeldType.natural ? 'Make Dirty' : 'Add Wilds',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCardsToMeld(
    int meldIndex,
    List<PlayingCard> cardsToAdd,
    List<PlayingCard> invalidCards,
  ) async {
    int addedCount = 0;
    for (final card in cardsToAdd) {
      if (_gameController.addCardToMeld(meldIndex, card)) {
        // Log human meld addition
        _logHumanAction(
          action: 'addToMeld',
          reasoning: 'Human added ${card.compactName} to existing meld',
          context: {'card': card.compactName, 'meldIndex': meldIndex},
        );
        addedCount++;
      }
    }

    if (addedCount > 0) {
      _sortHand('rank');
      _selectedCardIndices.clear();
      setState(() {});

      // Check if adding cards to meld caused the round to end
      await _gameStateManager.checkAndHandleRoundEnd();

      if (invalidCards.isNotEmpty) {
        final invalidNames = invalidCards.map((c) => c.displayName).join(', ');
        _dialogManager.showErrorDialog(
          'Added $addedCount cards to meld. Could not add: $invalidNames',
        );
      }
    } else {
      _dialogManager.showErrorDialog('Failed to add any cards to the meld.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final gameState = _gameController.gameState;
    final currentPlayer = gameState.currentPlayer;
    final humanPlayer = gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    // Debug logging for critical issues only
    if (currentPlayer.type != PlayerType.human &&
        currentPlayer.name != humanPlayer.name) {
      DebugLogger.debug(
        'Current: ${currentPlayer.name}, Human: ${humanPlayer.name}',
      );
    }

    return Container(
      decoration: const BoxDecoration(gradient: BalatroTheme.primaryGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [BalatroTheme.neonPink, BalatroTheme.glowColor],
            ).createShader(bounds),
            child: const Text(
              'HAND & FOOT',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            // Scoreboard button
            IconButton(
              icon: const Icon(
                Icons.leaderboard,
                color: BalatroTheme.neonYellow,
              ),
              tooltip: 'View Scoreboard',
              onPressed: () {
                _dialogManager.showScoreboard();
              },
            ),
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BalatroTheme.glowDecoration(
                glowColor: BalatroTheme.neonGreen,
                backgroundColor: BalatroTheme.darkPurple,
              ),
              child: Text(
                'ROUND ${gameState.round}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: BalatroTheme.neonGreen,
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (String value) {
                switch (value) {
                  case 'new_game':
                    _dialogManager.showNewGameConfirmation(_startNewGame);
                    break;
                  case 'copy_seed':
                    _persistenceManager.copySeedToClipboard(context);
                    break;
                  case 'export_game':
                    _persistenceManager.copyGameStateToClipboard(context);
                    break;
                  case 'load_game':
                    _dialogManager.showLoadGameDialog(
                      (inputText) => _persistenceManager.loadGameFromJson(
                        inputText,
                        context,
                      ),
                    );
                    break;
                  case 'how_to_play':
                    _dialogManager.showHowToPlayDialog();
                    break;
                  case 'main_menu':
                    _returnToMainMenu();
                    break;
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'new_game',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, color: Colors.red),
                      SizedBox(width: 8),
                      Text('New Game'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'copy_seed',
                  child: Row(
                    children: [
                      Icon(Icons.copy, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Copy Seed'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'export_game',
                  child: Row(
                    children: [
                      Icon(Icons.download, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Export Game'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'load_game',
                  child: Row(
                    children: [
                      Icon(Icons.upload, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Load Game'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'how_to_play',
                  child: Row(
                    children: [
                      Icon(Icons.help_outline, color: Colors.purple),
                      SizedBox(width: 8),
                      Text('How to Play'),
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
        body: Column(
          children: [
            // Mobile-optimized status bar
            MobileStatusBar(
              gameState: gameState,
              isExpanded: _statusExpanded,
              onToggle: () {
                setState(() {
                  _statusExpanded = !_statusExpanded;
                });
              },
            ),

            // Collapsible recent actions
            CollapsibleRecentActions(
              gameState: gameState,
              isExpanded: _actionsExpanded,
              onToggle: () {
                setState(() {
                  _actionsExpanded = !_actionsExpanded;
                });
              },
            ),

            const SizedBox(height: 8),

            // Compact player scores
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Tap a player to view their melds:',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
            CompactPlayerScores(
              gameState: gameState,
              viewingPlayerMelds: _viewingPlayerMelds,
              onPlayerTap: (player) {
                setState(() {
                  _viewingPlayerMelds = player;
                });
              },
              botPersonalityManager: _botAI.personalityManager,
            ),

            // Melds section
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            () {
                              final player = _viewingPlayerMelds ?? humanPlayer;
                              final playerName = player.name;
                              // Minimal debug logging - only when there's a mismatch
                              if (_viewingPlayerMelds != null &&
                                  _viewingPlayerMelds != humanPlayer) {
                                DebugLogger.debug(
                                  'Viewing: ${_viewingPlayerMelds!.name}, Expected: ${humanPlayer.name}',
                                );
                              }
                              if (playerName == 'You') {
                                return 'Your Melds:';
                              } else {
                                return '$playerName\'s Melds:';
                              }
                            }(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_viewingPlayerMelds != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _viewingPlayerMelds = null;
                                  });
                                },
                                child: const Text('Back to yours'),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if ((_viewingPlayerMelds ?? humanPlayer).melds.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No melds yet'),
                      )
                    else
                      ...(() {
                        // Sort melds by face value (CardRank)
                        final player = _viewingPlayerMelds ?? humanPlayer;
                        final indexedMelds = player.melds
                            .asMap()
                            .entries
                            .toList();
                        indexedMelds.sort((a, b) {
                          // Special handling for Aces - put them at the end
                          final aRank = a.value.rank;
                          final bRank = b.value.rank;

                          if (aRank == CardRank.ace && bRank != CardRank.ace) {
                            return 1; // a (ace) comes after b
                          }
                          if (bRank == CardRank.ace && aRank != CardRank.ace) {
                            return -1; // b (ace) comes after a
                          }

                          // For non-ace cards or both aces, use normal index comparison
                          return aRank.index.compareTo(bRank.index);
                        });

                        return indexedMelds.map((entry) {
                          final canAdd =
                              _viewingPlayerMelds == null &&
                              currentPlayer.type == PlayerType.human &&
                              gameState.turnPhase == TurnPhase.meld;

                          final compatibleInfo = canAdd
                              ? _getCompatibleCardsInfo(entry.key)
                              : (count: 0, areWilds: false);

                          return MeldWidget(
                            meld: entry.value,
                            meldIndex: entry.key,
                            canAddCards: canAdd,
                            onTap: canAdd ? _onAddCardToMeld : null,
                            onSelectAllCards: canAdd
                                ? _selectAllCardsForMeld
                                : null,
                            canAcceptSelectedCard:
                                canAdd && _canAddCardToMeld(entry.key),
                            compatibleCardsInHand: compatibleInfo.count,
                            compatibleCardsAreWilds: compatibleInfo.areWilds,
                          );
                        });
                      })(),
                  ],
                ),
              ),
            ),

            // Action buttons (only show when it's human's turn)
            if (currentPlayer.type == PlayerType.human) ...[
              // Emergency recovery for stuck game
              if (_isGameStuck())
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.red[100],
                  child: Column(
                    children: [
                      const Text(
                        'Game is stuck! You went out without meeting book requirements.',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _forceNextTurn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Skip Turn (Emergency Recovery)'),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (gameState.turnPhase == TurnPhase.draw) ...[
                      ElevatedButton(
                        onPressed: _onDrawFromDeck,
                        child: const Text('Draw from Deck'),
                      ),
                      if (_gameController.canUnlockDiscard())
                        ElevatedButton(
                          onPressed: _onUnlockDiscard,
                          child: const Text('Take Discard Pile'),
                        ),
                    ],
                    if (gameState.turnPhase == TurnPhase.meld) ...[
                      ElevatedButton(
                        onPressed: () =>
                            _dialogManager.showAdvancedMeldSelector(
                              onMeldsCreated: _executeAdvancedMeldCreation,
                            ),
                        child: const Text('Play Cards'),
                      ),
                      ElevatedButton(
                        onPressed: _selectedCards.length == 1
                            ? _onDiscard
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _selectedCards.length == 1 &&
                                  humanPlayer.currentHand.length == 1
                              ? (humanPlayer.hasPickedUpFoot
                                    ? Colors.orange
                                    : Colors.blue)
                              : null,
                        ),
                        child: Text(
                          _selectedCards.length == 1 &&
                                  humanPlayer.currentHand.length == 1
                              ? (humanPlayer.hasPickedUpFoot
                                    ? 'Go Out'
                                    : 'Go to Foot')
                              : 'Discard',
                        ),
                      ),
                      if (_selectedCardIndices.isNotEmpty)
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedCardIndices.clear();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                          ),
                          child: const Text('Clear Selection'),
                        ),
                    ],
                  ],
                ),
              ),
            ],

            // Hand (always visible, but only interactive during human turn)
            Opacity(
              opacity: currentPlayer.type == PlayerType.human ? 1.0 : 0.7,
              child: Container(
                height:
                    155, // Increased to accommodate selected cards with padding
                padding: const EdgeInsets.fromLTRB(
                  8,
                  10,
                  8,
                  10,
                ), // More generous padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          if (_viewingPlayerMelds != null) {
                            setState(() {
                              _viewingPlayerMelds =
                                  null; // Reset to human player view
                            });
                          }
                        },
                        child: Text(
                          () {
                            if (_viewingPlayerMelds != null &&
                                _viewingPlayerMelds != humanPlayer) {
                              return 'Viewing ${_viewingPlayerMelds!.name}\'s cards - Tap here to return to your hand';
                            }
                            return 'Your Hand (${humanPlayer.currentHand.length} cards)';
                          }(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color:
                                _viewingPlayerMelds != null &&
                                    _viewingPlayerMelds != humanPlayer
                                ? BalatroTheme.neonYellow
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                          },
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          child: SizedBox(
                            width: humanPlayer.currentHand.isNotEmpty
                                ? (humanPlayer.currentHand.length - 1) * 50.0 +
                                      70.0
                                : 70.0,
                            height:
                                110, // Fixed height for the stack (98 + 12 for selection)
                            child: Stack(
                              clipBehavior: Clip
                                  .none, // Allow cards to move outside bounds when selected
                              children: humanPlayer.currentHand
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                    final index = entry.key;
                                    final card = entry.value;

                                    return Positioned(
                                      left: index * 50.0,
                                      child: GestureDetector(
                                        onTap:
                                            currentPlayer.type ==
                                                PlayerType.human
                                            ? () => _onCardTap(index)
                                            : null,
                                        onDoubleTap:
                                            currentPlayer.type ==
                                                PlayerType.human
                                            ? () => _onCardDoubleTap(index)
                                            : null,
                                        child: PlayingCardWidget(
                                          key: ValueKey(
                                            'hand-${card.rank}-${card.suit}-$index-${_viewingPlayerMelds?.id ?? "you"}',
                                          ),
                                          card: card,
                                          width: 70,
                                          height: 98,
                                          isSelected: _selectedCardIndices
                                              .contains(index),
                                          isPlayable: _isCardPlayable(card),
                                          isNewlyDrawn: humanPlayer
                                              .isCardIndexNewlyDrawn(index),
                                        ),
                                      ),
                                    );
                                  })
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
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
          'Are you sure you want to return to the main menu? Your current game progress will be lost.',
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

  /// Handle critical errors that require user intervention
  void _handleCriticalError(dynamic error) {
    DebugLogger.error('Critical error occurred: $error');

    // Stop all processing
    _botTurnManager.resetProcessingState();

    // Show error dialog with recovery options
    _dialogManager.showCriticalErrorDialog(
      'A critical error occurred: ${error.toString()}\n\n'
      'The game may be in an unstable state. What would you like to do?',
      _gameStateManager.attemptGameStateRecovery,
    );
  }

  // ============= ANALYTICS METHODS =============

  /// Start analytics session tracking
  Future<void> _startAnalyticsSession() async {
    try {
      // Get bot personalities for tracking
      final botPersonalities = <String, BotPersonality>{};
      for (final player in _gameController.gameState.players) {
        if (player.type == PlayerType.bot) {
          botPersonalities[player.id] = _botAI.personalityManager
              .getPersonality(player.id);
        }
      }

      _actionSequenceNumber = 0; // Reset sequence counter for new game
      _analyticsSessionId = await GameAnalyticsLogger.startGameSession(
        players: _gameController.gameState.players,
        gameState: _gameController.gameState,
        gameMode: 'singleplayer',
        botPersonalities: botPersonalities,
      );

      if (_analyticsSessionId != null) {
        DebugLogger.debug('Started analytics session: $_analyticsSessionId');
      }
    } catch (e) {
      DebugLogger.warning('Failed to start analytics session: $e');
    }
  }

  /// Log bot decision for analytics
  Future<void> _logBotDecision({
    required String botId,
    required String decision,
    required String reasoning,
    Map<String, dynamic>? context,
  }) async {
    if (_analyticsSessionId == null) return;

    try {
      _actionSequenceNumber++; // Increment sequence for this action

      final personality = _botAI.personalityManager.getPersonality(botId);
      await GameAnalyticsLogger.logBotDecision(
        botId: botId,
        decision: decision,
        reasoning: reasoning,
        personality: personality,
        gameState: _gameController.gameState,
        decisionContext: {
          ...?context,
          // Add sequencing information
          'actionSequence': _actionSequenceNumber,
          'turnNumber': _totalTurns,
          'playerTurnIndex': _gameController.gameState.currentPlayerIndex,
        },
      );
    } catch (e) {
      DebugLogger.warning('Failed to log bot decision: $e');
    }
  }

  /// Log human player actions for analytics comparison
  Future<void> _logHumanAction({
    required String action,
    required String reasoning,
    Map<String, dynamic>? context,
  }) async {
    if (_analyticsSessionId == null) return;

    try {
      _actionSequenceNumber++; // Increment sequence for this action

      final humanPlayer = _gameController.gameState.players.firstWhere(
        (p) => p.type == PlayerType.human,
      );

      await GameAnalyticsLogger.logGameEvent(
        eventType: action,
        playerId: humanPlayer.id,
        playerType: PlayerType.human,
        eventData: {
          'reasoning': reasoning,
          'context': context,

          // Sequencing information
          'actionSequence': _actionSequenceNumber,
          'turnNumber': _totalTurns,
          'playerTurnIndex': _gameController.gameState.currentPlayerIndex,

          'round': _gameController.gameState.round,
          'turnPhase': _gameController.gameState.turnPhase.name,

          // Player state
          'handSize': humanPlayer.currentHand.length,
          'handCards': humanPlayer.currentHand
              .map((c) => c.compactName)
              .toList(),
          'hasPlayedDown': humanPlayer.hasPlayedDown,
          'hasPickedUpFoot': humanPlayer.hasPickedUpFoot,
          'score': humanPlayer.score,

          // Player's melds (what they have on table)
          'meldCount': humanPlayer.melds.length,
          'bookCount': humanPlayer.melds
              .where((m) => m.cards.length >= 7)
              .length,
          'playerMelds': humanPlayer.melds
              .map(
                (meld) => {
                  'cards': meld.cards.map((c) => c.compactName).toList(),
                  'rank': meld.cards.first.rank.name,
                  'isClean': meld.isClean,
                  'isBook': meld.cards.length >= 7,
                  'size': meld.cards.length,
                },
              )
              .toList(),

          // Game state context
          'deckSize': _gameController.gameState.deck.size,
          'discardPileSize': _gameController.gameState.discardPile.length,
          'topDiscardCard': _gameController.gameState.discardPile.isNotEmpty
              ? _gameController.gameState.discardPile.last.compactName
              : null,
          'discardPileFrozen': _gameController.gameState.discardPileFrozen,

          // Opponent context (for strategic decisions)
          'opponents': _gameController.gameState.players
              .where((p) => p.id != humanPlayer.id)
              .map(
                (opponent) => {
                  'id': opponent.id,
                  'type': opponent.type.name,
                  'handSize': opponent.currentHand.length,
                  'hasPlayedDown': opponent.hasPlayedDown,
                  'hasPickedUpFoot': opponent.hasPickedUpFoot,
                  'score': opponent.score,
                  'meldCount': opponent.melds.length,
                  'bookCount': opponent.melds
                      .where((m) => m.cards.length >= 7)
                      .length,
                  'visibleMelds': opponent.melds
                      .map(
                        (meld) => {
                          'rank': meld.cards.first.rank.name,
                          'size': meld.cards.length,
                          'isClean': meld.isClean,
                          'isBook': meld.cards.length >= 7,
                        },
                      )
                      .toList(),
                },
              )
              .toList(),
        },
        success: true,
      );
    } catch (e) {
      DebugLogger.warning('Failed to log human action: $e');
    }
  }
}
