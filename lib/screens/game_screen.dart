import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../widgets/game_action_buttons.dart';
import '../widgets/game_app_bar.dart';
import '../widgets/game_session_info_menu.dart';
import '../theme/balatro_theme.dart';
import '../services/game_analytics_logger.dart';
import '../services/analytics_batcher.dart';
import '../services/analytics_fields.dart';
import 'main_menu_screen.dart';
import '../utils/debug_logger.dart';
import 'managers/bot_turn_manager.dart';
import 'managers/dialog_manager.dart';
import 'managers/game_state_manager.dart';
import 'managers/persistence_manager.dart';
import 'managers/event_based_game_state_manager.dart';
import '../providers/game_providers.dart';
import '../providers/computed_providers.dart';

/// Bot configuration for randomized personality assignment
class BotConfig {
  final String name;
  final BotPersonality personality;

  const BotConfig(this.name, this.personality);
}

/// Shared bot configurations with predefined personality mappings
const List<BotConfig> kBotConfigurations = [
  BotConfig('Clara', BotPersonality.conservative),
  BotConfig('Carl', BotPersonality.conservative),
  BotConfig('Bob', BotPersonality.aggressive),
  BotConfig('Rita', BotPersonality.aggressive),
  BotConfig('Ben', BotPersonality.bookBuilder),
  BotConfig('Tiana', BotPersonality.bookBuilder),
  BotConfig('Alex', BotPersonality.adaptive),
  BotConfig('Sue', BotPersonality.adaptive),
];

class GameScreen extends ConsumerStatefulWidget {
  final int? testSeed; // For deterministic testing
  final GameController? gameController; // For continuing saved games

  const GameScreen({super.key, this.testSeed, this.gameController});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  // Use providers instead of local state - accessed via ref
  GameController? get _gameController =>
      ref.read(gameControllerProvider)?.controller;
  EnhancedBotAI get _botAI => ref.read(botAIProvider);

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
  int _totalTurns = 0;
  int _actionSequenceNumber = 0; // Track action sequence within game
  Map<String, BotPersonality> _sessionBotPersonalities = {};

  // Manager instances for better code organization
  late BotTurnManager _botTurnManager;
  late DialogManager _dialogManager;
  late GameStateManager _gameStateManager;
  EventBasedGameStateManager? _eventBasedGameStateManager;
  late PersistenceManager _persistenceManager;

  // Prevent multiple game end dialogs
  bool _gameEndDialogShown = false;
  bool _isRoundTransitionInProgress = false;

  // Queue for bot turn processing to ensure one at a time
  bool _isBotTurnInProgress = false;
  final List<Player> _botTurnQueue = [];

  // Keyboard shortcuts
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Initialize event listeners via Riverpod
    ref.read(gameEventListenerProvider);
    ref.read(soundEventListenerProvider); // Initialize sound effects
    _initializeGame();
  }

  @override
  void dispose() {
    _disposed = true;
    _focusNode.dispose();
    // Dispose event-based manager to clean up subscriptions
    _eventBasedGameStateManager?.dispose();
    super.dispose();
  }

  /// Helper method to assign bot personalities consistently
  void _assignBotPersonalities() {
    final controller = _gameController;
    if (controller == null) return;

    final botPlayers = controller.gameState.players
        .where((p) => p.type == PlayerType.bot)
        .toList();

    // Create personality mapping from predefined bot configurations
    final personalityMap = <String, BotPersonality>{};
    for (final config in kBotConfigurations) {
      personalityMap[config.name] = config.personality;
    }

    // Assign personalities based on bot names, with fallback to random
    for (final bot in botPlayers) {
      final predefinedPersonality = personalityMap[bot.name];
      if (predefinedPersonality != null) {
        _botAI.assignPersonality(bot.id, predefinedPersonality);
      } else {
        // Fallback to random assignment for unknown bot names
        final personalities = BotPersonality.values;
        final randomPersonality =
            personalities[(bot.id.hashCode % personalities.length)];
        _botAI.assignPersonality(bot.id, randomPersonality);
      }
    }

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
    final controller = _gameController;
    if (controller == null) return;

    final eventBus = ref.read(gameEventBusProvider);

    _botTurnManager = BotTurnManager(
      gameController: controller,
      botAI: _botAI,
      onStateChanged: () {
        // Force UI rebuild to show updated bot turn phase
        if (mounted) {
          setState(() {
            // Empty setState triggers rebuild which reads latest game state
          });
          // Only trigger turn processing if no bot turn is currently in progress
          if (!_isBotTurnInProgress) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isBotTurnInProgress) {
                processCurrentPlayerTurn();
              }
            });
          }
        }
      },
      logHumanAction: (action) =>
          _logHumanAction(action: action, reasoning: 'Bot turn processing'),
      logBotDecision: _logBotDecision,
    );

    _dialogManager = DialogManager(
      context: context,
      gameController: controller,
      onStateChanged: () {
        // State changes handled reactively via providers
      },
      onNewGame: _startNewGame,
      onReturnToMenu: _returnToMainMenu,
    );

    // Use event-based manager for reactive updates
    _eventBasedGameStateManager = EventBasedGameStateManager(
      gameController: controller,
      eventBus: eventBus,
      onStateChanged: () {
        // State changes trigger provider updates automatically
        // Don't call processCurrentPlayerTurn() here - only on turn end
      },
      onTurnEnd: () {
        // Only trigger turn processing when a turn actually ends
        // This prevents infinite loops from state changes during a turn
        _totalTurns++; // Track total turns for analytics
        if (mounted && !_isBotTurnInProgress) {
          processCurrentPlayerTurn();
        }
      },
      onGameEnd: () {
        final winner = ref.read(gameWinnerProvider);
        if (winner != null && !_gameEndDialogShown) {
          _gameEndDialogShown = true;
          final players = ref.read(leaderboardProvider);
          _dialogManager.showGameEndDialog(winner, players);
        }
        _endAnalyticsSession();
      },
      onRoundEnd: () {
        // Clear UI selections and reset for next round
        _selectedCardIndices.clear();
        _viewingPlayerMelds = null;
        processCurrentPlayerTurn();
      },
      onRoundEndDetected: () {
        _handleRoundTransition().catchError((error) {
          DebugLogger.error(
            'Error handling round transition from event: $error',
          );
        });
      },
    );

    // Keep traditional manager for validation methods
    _gameStateManager = GameStateManager(
      gameController: controller,
      onStateChanged: () {},
      onGameEnd: () {},
      onRoundEnd: () {},
    );

    _persistenceManager = PersistenceManager(
      gameController: controller,
      botAI: _botAI,
      onStateChanged: () {
        // State changes handled reactively via providers
      },
      onGameLoaded: (newController, botPersonalities) {
        // Update provider with new controller
        ref
            .read(gameControllerProvider.notifier)
            .setController(newController, eventBus);

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

        // CRITICAL: Resume game flow after import
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            DebugLogger.debug('Resuming game flow after import');
            processCurrentPlayerTurn();
          }
        });
      },
    );
  }

  Future<void> _initializeGame() async {
    // If a gameController was provided (continuing saved game), use it
    if (widget.gameController != null) {
      final eventBus = ref.read(gameEventBusProvider);
      ref
          .read(gameControllerProvider.notifier)
          .setController(widget.gameController!, eventBus);
      _initializeManagers();

      _isInitialized = true;

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

    // Use shared bot configurations
    final botOptions = List<BotConfig>.from(kBotConfigurations);

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

    // Use Riverpod providers for game controller and bot AI
    final controllerNotifier = ref.read(gameControllerProvider.notifier);
    final eventBus = ref.read(gameEventBusProvider);

    final newController = GameControllerFactory.createSingleplayerGame(
      players: players,
      seed: widget.testSeed,
      eventBus: eventBus,
    );

    // Store in Riverpod provider for reactive access
    controllerNotifier.setController(newController, eventBus);

    // Use Riverpod provider for bot AI
    final botAI = ref.read(botAIProvider);
    botAI.assignPersonality('2', botConfigs[0].personality);
    botAI.assignPersonality('3', botConfigs[1].personality);

    newController.initializeGame();

    // Initialize managers after game setup
    _initializeManagers();

    // Sort the human player's initial hand
    final humanPlayer = players.firstWhere((p) => p.type == PlayerType.human);
    humanPlayer.sortHandByRank();

    // Start analytics session tracking
    _startAnalyticsSession();

    _isInitialized = true;

    // If the first player is human, save the initial game state
    final gameState = ref.read(currentGameStateProvider);
    if (gameState?.currentPlayer.type == PlayerType.human) {
      _persistenceManager.saveGameState().catchError((error) {
        DebugLogger.error('Error saving initial game state: $error');
      });
    }

    processCurrentPlayerTurn();
  }

  /// Queue bot turn to process one at a time
  void _queueBotTurn(Player botPlayer) {
    // Add to queue if not already queued
    if (!_botTurnQueue.any((p) => p.id == botPlayer.id)) {
      _botTurnQueue.add(botPlayer);
    }

    // Process queue if nothing is currently processing
    if (!_isBotTurnInProgress) {
      _processNextBotInQueue();
    }
  }

  /// Process the next bot in the queue
  void _processNextBotInQueue() {
    if (_botTurnQueue.isEmpty || _isBotTurnInProgress) return;

    final controller = _gameController;
    if (controller == null) {
      _isBotTurnInProgress = false;
      return;
    }

    _isBotTurnInProgress = true;
    final botPlayer = _botTurnQueue.removeAt(0);

    // Verify this bot is still the current player - read directly from controller
    final gameState = controller.gameState;
    final currentPlayer = gameState.currentPlayer;

    if (currentPlayer.id != botPlayer.id ||
        currentPlayer.type != PlayerType.bot) {
      DebugLogger.debug(
        'Skipping queued bot ${botPlayer.name} - current player is now ${currentPlayer.name}',
      );
      _isBotTurnInProgress = false;
      _processNextBotInQueue(); // Try next in queue
      return;
    }

    DebugLogger.debug('Processing queued bot turn for ${botPlayer.name}');
    _botTurnManager
        .processBotTurnWithDelays(botPlayer)
        .then((_) {
          _isBotTurnInProgress = false;
          DebugLogger.debug('Bot ${botPlayer.name} completed turn');
          if (mounted) {
            processCurrentPlayerTurn();
          }
        })
        .catchError((error) {
          _isBotTurnInProgress = false;
          DebugLogger.error('Bot turn error: $error');
          // Continue processing queue even on error
          if (mounted) {
            processCurrentPlayerTurn();
          }
        });
  }

  /// SIMPLIFIED: Single entry point for turn processing with error recovery
  void processCurrentPlayerTurn() {
    if (!_isInitialized || _disposed || !mounted) return;

    try {
      final controller = _gameController;
      if (controller == null) return;

      // Get game state directly from controller to avoid stale provider data
      final gameState = controller.gameState;

      // CRITICAL: Check if game has ended before processing any turns
      if (gameState.phase == GamePhase.gameEnd) {
        DebugLogger.debug('Game has ended - stopping turn processing');
        final winner = gameState.winner;
        if (winner != null && !_gameEndDialogShown) {
          _gameEndDialogShown = true;
          final players = List<Player>.from(gameState.players);
          players.sort((a, b) => b.score.compareTo(a.score));
          _dialogManager.showGameEndDialog(winner, players);
        }
        return;
      }

      // Handle round end before any turn processing — a bot who went out is
      // still the current player, which otherwise triggers stuck-bot recovery.
      if (gameState.phase == GamePhase.roundEnd) {
        DebugLogger.debug(
          'Round has ended - handling transition (Round ${gameState.round})',
        );
        _handleRoundTransition().catchError((error) {
          DebugLogger.error('Error handling round transition: $error');
        });
        return;
      }

      if (_isRoundTransitionInProgress) {
        return;
      }

      // Validate game state before processing
      if (!_gameStateManager.validateGameState()) {
        DebugLogger.error('Game state invalid - attempting recovery');
        _gameStateManager.attemptGameStateRecovery();
        return;
      }

      // Get current player directly from game state to avoid stale provider data
      final currentPlayer = gameState.currentPlayer;

      DebugLogger.debug(
        'processCurrentPlayerTurn: Current player is ${currentPlayer.name} (${currentPlayer.type})',
      );

      // CRITICAL: Detect and recover from stuck bot turns
      if (currentPlayer.type == PlayerType.bot && !_isBotTurnInProgress) {
        // Bot turn should be processing but isn't - this indicates a stuck state
        DebugLogger.debug(
          'Detected stuck bot turn for ${currentPlayer.name} - initiating recovery',
        );
        _botTurnManager.resetProcessingState();
        // Clear any stale bot queue
        _botTurnQueue.clear();
        // Force bot turn processing to restart
        _queueBotTurn(currentPlayer);
        return;
      }

      // CRITICAL: Defend against turn corruption from multiplayer sync or other sources
      final humanPlayer = gameState.players.firstWhere(
        (p) => p.type == PlayerType.human,
        orElse: () => gameState.players.first,
      );
      if (gameState.turnPhase == TurnPhase.meld &&
          humanPlayer.currentHand.isNotEmpty &&
          currentPlayer.type != PlayerType.human) {
        DebugLogger.error(
          'TURN CORRUPTION DETECTED: Human should be playing but current player is ${currentPlayer.name}',
        );
        DebugLogger.debug('Correcting current player back to human');
        final humanIndex = gameState.players.indexWhere(
          (p) => p.type == PlayerType.human,
        );
        controller.gameState.currentPlayerIndex = humanIndex;
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
          // UI will update automatically via provider reactivity
          _gameStateManager.checkForRoundTransition();
        }
        return;
      }

      // Bot turn: Queue for sequential processing
      if (currentPlayer.type == PlayerType.bot) {
        DebugLogger.debug('Queueing bot turn for ${currentPlayer.name}');
        _queueBotTurn(currentPlayer);
      }
    } catch (e) {
      DebugLogger.error('Error in processCurrentPlayerTurn: $e');
      _handleCriticalError(e);
    }
  }

  /// Handle complete round transition with proper state management
  Future<void> _handleRoundTransition() async {
    if (_isRoundTransitionInProgress) {
      return;
    }

    final controller = _gameController;
    if (controller == null) {
      return;
    }

    if (controller.gameState.phase != GamePhase.roundEnd) {
      return;
    }

    _isRoundTransitionInProgress = true;
    DebugLogger.debug('Handling round transition - calculating scores');

    try {
      await _logRoundEndAnalytics();

      // Brief pause to show scores
      await Future.delayed(const Duration(seconds: 2));
      if (_disposed || !mounted) {
        return;
      }

      if (controller.gameState.phase == GamePhase.gameEnd) {
        if (!_gameEndDialogShown) {
          final winner = ref.read(gameWinnerProvider);
          if (winner != null) {
            _gameEndDialogShown = true;
            final players = ref.read(leaderboardProvider);
            _dialogManager.showGameEndDialog(winner, players);
          }
        }
        return;
      }

      if (controller.gameState.phase != GamePhase.roundEnd) {
        return;
      }

      controller.nextRound();
      DebugLogger.debug('Advanced to round ${controller.gameState.round}');

      if (mounted) {
        _selectedCardIndices.clear();
        _viewingPlayerMelds = null;

        _persistenceManager.saveGameState().catchError((error) {
          DebugLogger.error(
            'Error saving game state after round transition: $error',
          );
        });

        processCurrentPlayerTurn();
      }
    } catch (e) {
      DebugLogger.error('Error during round transition: $e');
      if (mounted) {
        _dialogManager.showErrorDialog(
          'Error advancing to next round: ${e.toString()}',
        );
      }
    } finally {
      _isRoundTransitionInProgress = false;
    }
  }

  void _onCardTap(int cardIndex) {
    final currentPlayer = ref.read(currentPlayerProvider);
    if (currentPlayer?.type != PlayerType.human) {
      return;
    }

    final humanPlayer = ref.read(humanPlayerProvider);
    if (humanPlayer == null) return;

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
    final currentPlayer = ref.read(currentPlayerProvider);
    if (currentPlayer?.type != PlayerType.human) {
      return;
    }

    _hasPlayerInteractedSinceDraw = true; // Mark that player has interacted

    final humanPlayer = ref.read(humanPlayerProvider);
    if (humanPlayer == null) return;

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
    final humanPlayer = ref.read(humanPlayerProvider);
    if (humanPlayer == null) return;

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
    final humanPlayer = ref.read(humanPlayerProvider);
    if (humanPlayer == null) return [];

    return _selectedCardIndices
        .where((index) => index < humanPlayer.currentHand.length)
        .map((index) => humanPlayer.currentHand[index])
        .toList();
  }

  bool _isCardPlayable(PlayingCard card) {
    final currentPlayer = ref.read(currentPlayerProvider);
    if (currentPlayer?.type != PlayerType.human) {
      return false;
    }

    final gameState = ref.read(currentGameStateProvider);
    if (gameState?.turnPhase != TurnPhase.meld) {
      return false;
    }

    final humanPlayer = ref.read(humanPlayerProvider);
    if (humanPlayer == null) return false;

    final controller = _gameController;
    if (controller == null) return false;

    // Check if this card can be added to any existing meld
    for (int i = 0; i < humanPlayer.melds.length; i++) {
      if (humanPlayer.melds[i].canAddCard(card)) {
        return true;
      }
    }

    // Check if this card can form a new meld
    final possibleMelds = controller.findPossibleMelds(humanPlayer);
    for (final meld in possibleMelds) {
      if (meld.contains(card)) {
        return true;
      }
    }

    return false;
  }

  bool _isGameStuck() {
    final humanPlayer = ref.read(humanPlayerProvider);
    final currentPlayer = ref.read(currentPlayerProvider);
    final gameState = ref.read(currentGameStateProvider);

    if (humanPlayer == null || currentPlayer == null || gameState == null) {
      return false;
    }

    // Only consider it stuck if:
    // 1. It's the human player's turn
    // 2. They have an empty foot (not just empty hand - that's normal transition)
    // 3. They've already picked up their foot
    // 4. They don't meet the requirements to go out
    return currentPlayer.type == PlayerType.human &&
        humanPlayer.hasPickedUpFoot &&
        humanPlayer.foot.isEmpty &&
        !humanPlayer.canGoOutWithBooks &&
        gameState.turnPhase == TurnPhase.meld;
  }

  void _forceNextTurn() {
    final controller = _gameController;
    if (controller != null) {
      controller.gameState.nextPlayer();
      // UI will update automatically via provider reactivity
      processCurrentPlayerTurn();
    }
  }

  Future<void> _restoreSavedGame() async {
    try {
      final savedController = await GameController.loadSavedGame();

      if (savedController != null) {
        final eventBus = ref.read(gameEventBusProvider);
        ref
            .read(gameControllerProvider.notifier)
            .setController(savedController, eventBus);

        // Assign consistent bot personalities based on player IDs
        _assignBotPersonalities();

        // Sort the human player's hand
        final humanPlayer = ref.read(humanPlayerProvider);
        if (humanPlayer != null) {
          humanPlayer.sortHandByRank();
        }

        _isInitialized = true;

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
    final controller = _gameController;
    if (controller == null) return;

    if (controller.drawFromDeck()) {
      // Log human action for analytics
      _logHumanAction(
        action: 'drawFromDeck',
        reasoning: 'Human player drew 2 cards from deck',
      );

      // Cards are now automatically inserted in sorted position
      _hasPlayerInteractedSinceDraw =
          false; // Reset interaction flag after drawing
      // UI will update automatically via provider reactivity when event fires
    } else {
      // Check if the round ended automatically due to insufficient cards
      final gameState = ref.read(currentGameStateProvider);
      if (gameState?.phase == GamePhase.roundEnd) {
        _dialogManager.showEmergencyRoundEndDialog();
      } else {
        // Check if deck is empty or insufficient
        if (gameState?.deck.isEmpty ?? false) {
          _dialogManager.showErrorDialog(
            'Cannot draw from deck: The deck is empty!\n\n'
            'The round will continue until a player goes out or all players pass.',
          );
        } else if ((gameState?.deck.size ?? 0) < 2) {
          _dialogManager.showErrorDialog(
            'Cannot draw from deck: Only ${gameState?.deck.size ?? 0} card(s) remaining.\n\n'
            'You must draw exactly 2 cards from the deck. Try drawing from the discard pile instead.',
          );
        }
      }
    }
  }

  void _onUnlockDiscard() {
    final controller = _gameController;
    if (controller == null) {
      debugPrint('DEBUG: _onUnlockDiscard - controller is null!');
      _dialogManager.showErrorDialog('Game not initialized. Please restart.');
      return;
    }

    final gameState = controller.gameState;
    final topCard = gameState.topDiscard;
    final currentPlayer = gameState.currentPlayer;

    // Debug logging to understand why unlock might fail
    debugPrint('DEBUG: _onUnlockDiscard called');
    debugPrint('  - Turn phase: ${gameState.turnPhase}');
    debugPrint('  - Has drawn from deck: ${gameState.hasDrawnFromDeck}');
    debugPrint('  - Top discard: ${topCard?.compactName ?? "none"}');
    debugPrint('  - Player has played down: ${currentPlayer.hasPlayedDown}');
    if (topCard != null) {
      final matchingCards = currentPlayer.currentHand
          .where((card) => card.rank == topCard.rank && !card.isWild)
          .toList();
      debugPrint('  - Matching natural cards in hand: ${matchingCards.length}');
    }

    if (!controller.canUnlockDiscard()) {
      // Provide specific feedback on why unlock is not available
      String reason;
      if (gameState.turnPhase != TurnPhase.draw) {
        reason = 'You can only take the discard pile during the draw phase.';
      } else if (gameState.hasDrawnFromDeck) {
        reason = 'You have already drawn this turn.';
      } else if (gameState.discardPile.isEmpty) {
        reason = 'The discard pile is empty.';
      } else if (topCard?.isWild == true) {
        reason = 'Cannot take discard pile when a wild card is on top.';
      } else if (topCard?.isThree == true) {
        reason = 'Cannot take discard pile when a 3 is on top.';
      } else if (!currentPlayer.hasPlayedDown) {
        reason = 'You must play down first before taking the discard pile.';
      } else {
        final matchingCards = currentPlayer.currentHand
            .where((card) => card.rank == topCard!.rank && !card.isWild)
            .toList();
        if (matchingCards.length < 2) {
          reason =
              'You need at least 2 ${topCard?.rank.name}s in your hand to take the discard.';
        } else {
          reason = 'Cannot take discard pile at this time.';
        }
      }
      _dialogManager.showErrorDialog(reason);
      return;
    }

    final cardsBeforeUnlock = gameState.discardPile.length;
    if (controller.unlockDiscardPile()) {
      // UI will update via Riverpod reactivity when DiscardPileUnlockedEvent fires
      debugPrint('DEBUG: Discard pile unlocked successfully');
      _logHumanAction(
        action: 'unlockDiscardPile',
        reasoning: 'Human unlocked discard pile',
        context: {'cardsTaken': cardsBeforeUnlock},
      );
    } else {
      debugPrint('DEBUG: unlockDiscardPile returned false unexpectedly');
      _dialogManager.showErrorDialog(
        'Failed to take discard pile. Please try again.',
      );
    }
  }

  Future<void> _onAddCardToMeld(int meldIndex) async {
    if (_selectedCards.isEmpty) {
      _dialogManager.showErrorDialog(
        'Select at least one card first before clicking on a meld.',
      );
      return;
    }

    final humanPlayer = ref.read(humanPlayerProvider);
    if (humanPlayer == null) return;

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

    final humanPlayer = ref.read(humanPlayerProvider);
    if (humanPlayer == null) return false;

    if (meldIndex >= humanPlayer.melds.length) return false;

    final meld = humanPlayer.melds[meldIndex];

    // Return true if at least one selected card can be added
    return _selectedCards.any((card) => meld.canAddCard(card));
  }

  ({int count, bool areWilds}) _getCompatibleCardsInfo(int meldIndex) {
    final humanPlayer = ref.read(humanPlayerProvider);
    if (humanPlayer == null) return (count: 0, areWilds: false);

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
    final humanPlayer = ref.read(humanPlayerProvider);
    if (humanPlayer == null) return;

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
    final controller = _gameController;
    if (controller == null) return;

    final success = controller.createMultipleMeldsFromIndices(
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
      final humanPlayer = ref.read(humanPlayerProvider);
      if (humanPlayer == null) return;

      final controller = _gameController;
      if (controller == null) return;

      // Check if discarding this card would empty the hand/foot
      final willBeEmpty = humanPlayer.currentHand.length == 1;

      if (willBeEmpty) {
        // If this would be the last card, validate going out requirements
        if (!humanPlayer.hasPickedUpFoot) {
          // Going from hand to foot is always allowed
          if (controller.discardCard(_selectedCards.first)) {
            // Log human discard action
            _logHumanAction(
              action: 'discardCard',
              reasoning: 'Human discarded ${_selectedCards.first.compactName}',
              context: {
                'card': _selectedCards.first.compactName,
                'cardRank': _selectedCards.first.rank.name,
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
              if (mounted) {
                final nextPlayer = ref.read(currentPlayerProvider);
                if (nextPlayer?.type != PlayerType.human) {
                  processCurrentPlayerTurn();
                }
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

      if (controller.discardCard(_selectedCards.first)) {
        // Log human discard action
        _logHumanAction(
          action: 'discardCard',
          reasoning: 'Human discarded ${_selectedCards.first.compactName}',
          context: {
            'card': _selectedCards.first.compactName,
            'cardRank': _selectedCards.first.rank.name,
            'goingOut': willBeEmpty,
          },
        );

        // Handle post-discard state updates (same as bot players)
        _botTurnManager.handlePostDiscardState(humanPlayer);

        // UI will update automatically via provider reactivity
        _selectedCardIndices.clear();
        await _gameStateManager.checkAndHandleRoundEnd();

        // Schedule bot processing for next frame to avoid immediate execution during human turn
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final nextPlayer = ref.read(currentPlayerProvider);
            if (nextPlayer?.type != PlayerType.human) {
              processCurrentPlayerTurn();
            }
          }
        });
      }
    } else {
      // Handle case where player has no cards to discard
      final humanPlayer = ref.read(humanPlayerProvider);
      if (humanPlayer == null) return;

      final controller = _gameController;
      if (controller == null) return;

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
        controller.gameState.nextPlayer();
        // UI will update automatically via provider reactivity
        processCurrentPlayerTurn();
      }
    }
  }

  void _sortHand(String sortType) {
    final humanPlayer = ref.read(humanPlayerProvider);
    if (humanPlayer == null) return;

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
    final humanPlayer = ref.read(humanPlayerProvider);
    if (humanPlayer == null) return;
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
    final controller = _gameController;
    if (controller == null) return;

    int addedCount = 0;
    for (final card in cardsToAdd) {
      if (controller.addCardToMeld(meldIndex, card)) {
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
      // UI will update automatically via provider reactivity

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

  /// Handle keyboard shortcuts for desktop users
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Only handle key down events
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Only handle shortcuts during human turn
    final currentPlayer = ref.read(currentPlayerProvider);
    if (currentPlayer?.type != PlayerType.human) {
      return KeyEventResult.ignored;
    }

    final gameState = ref.read(currentGameStateProvider);
    if (gameState == null) return KeyEventResult.ignored;

    final humanPlayer = ref.read(humanPlayerProvider);
    if (humanPlayer == null) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // D = Draw from deck
    if (key == LogicalKeyboardKey.keyD) {
      if (gameState.turnPhase == TurnPhase.draw) {
        _onDrawFromDeck();
        return KeyEventResult.handled;
      }
    }

    // T = Take/unlock discard pile
    if (key == LogicalKeyboardKey.keyT) {
      final controller = _gameController;
      if (controller != null &&
          gameState.turnPhase == TurnPhase.draw &&
          controller.canUnlockDiscard()) {
        _onUnlockDiscard();
        return KeyEventResult.handled;
      }
    }

    // M = Open meld selector
    if (key == LogicalKeyboardKey.keyM) {
      if (gameState.turnPhase == TurnPhase.meld && _selectedCards.isNotEmpty) {
        _dialogManager.showAdvancedMeldSelector(
          onMeldsCreated: _executeAdvancedMeldCreation,
        );
        return KeyEventResult.handled;
      }
    }

    // Enter/Space = Discard (if 1 card selected)
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      if (gameState.turnPhase == TurnPhase.meld && _selectedCards.length == 1) {
        _onDiscard();
        return KeyEventResult.handled;
      }
    }

    // Escape = Clear selection
    if (key == LogicalKeyboardKey.escape) {
      if (_selectedCardIndices.isNotEmpty) {
        setState(() => _selectedCardIndices.clear());
        return KeyEventResult.handled;
      }
    }

    // S = Sort hand by rank
    if (key == LogicalKeyboardKey.keyS) {
      _sortHand('rank');
      return KeyEventResult.handled;
    }

    // Number keys 1-9 = Toggle card selection
    final numberKeys = {
      LogicalKeyboardKey.digit1: 0,
      LogicalKeyboardKey.digit2: 1,
      LogicalKeyboardKey.digit3: 2,
      LogicalKeyboardKey.digit4: 3,
      LogicalKeyboardKey.digit5: 4,
      LogicalKeyboardKey.digit6: 5,
      LogicalKeyboardKey.digit7: 6,
      LogicalKeyboardKey.digit8: 7,
      LogicalKeyboardKey.digit9: 8,
      LogicalKeyboardKey.digit0: 9,
    };

    if (numberKeys.containsKey(key)) {
      final index = numberKeys[key]!;
      if (index < humanPlayer.currentHand.length) {
        _onCardTap(index);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // Use providers for reactive state access
    // Watch the controller state directly to ensure we rebuild when version changes
    final controllerState = ref.watch(gameControllerProvider);
    // Access version to ensure Riverpod tracks this dependency
    final _ = controllerState?.version;
    final gameState = controllerState?.controller.gameState;
    if (!_isInitialized || gameState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentPlayer = gameState.currentPlayer;
    final humanPlayer = gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    // Debug logging for UI rebuilds
    DebugLogger.debug(
      'UI BUILD: Current player=${currentPlayer.name} (${currentPlayer.type}), version=${controllerState?.version}',
    );

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        decoration: const BoxDecoration(gradient: BalatroTheme.primaryGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: GameAppBar(
            gameState: gameState,
            isMultiplayer: false,
            sessionInfo: _soloSessionInfo(gameState),
            additionalActions: [
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
            ],
            onNewGame: () {
              _dialogManager.showNewGameConfirmation(_startNewGame);
            },
            onCopySeed: () {
              _persistenceManager.copySeedToClipboard(context);
            },
            onExportGame: () {
              _persistenceManager.copyGameStateToClipboard(context);
            },
            onLoadGame: () {
              _dialogManager.showLoadGameDialog(
                (inputText) =>
                    _persistenceManager.loadGameFromJson(inputText, context),
              );
            },
            onHowToPlay: () {
              _dialogManager.showHowToPlayDialog();
            },
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
                    // If tapping on the human player, set to null (view own melds)
                    // Otherwise, set to the specific player to view their melds
                    final humanPlayer = gameState.players.firstWhere(
                      (p) => p.type == PlayerType.human,
                    );
                    _viewingPlayerMelds = player.id == humanPlayer.id
                        ? null
                        : player;
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
                            Text(() {
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
                            }(), style: Theme.of(context).textTheme.headlineMedium),
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

                            if (aRank == CardRank.ace &&
                                bRank != CardRank.ace) {
                              return 1; // a (ace) comes after b
                            }
                            if (bRank == CardRank.ace &&
                                aRank != CardRank.ace) {
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

              // Emergency recovery for stuck game (only show when necessary)
              if (_isGameStuck() &&
                  currentPlayer.type == PlayerType.human &&
                  gameState.phase != GamePhase.gameEnd)
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

              // Use the shared GameActionButtons widget for consistency
              GameActionButtons(
                gameState: gameState,
                humanPlayer: humanPlayer,
                selectedCardIndices: _selectedCardIndices,
                onDrawFromDeck: _onDrawFromDeck,
                onUnlockDiscard: () {
                  final controller = _gameController;
                  return (controller != null && controller.canUnlockDiscard())
                      ? _onUnlockDiscard
                      : null;
                }(),
                onShowAdvancedMeldSelector: () =>
                    _dialogManager.showAdvancedMeldSelector(
                      onMeldsCreated: _executeAdvancedMeldCreation,
                    ),
                onDiscard: _selectedCards.length == 1 ? _onDiscard : null,
                onClearSelection: () =>
                    setState(() => _selectedCardIndices.clear()),
              ),

              // Hand (always visible, but only interactive during human turn and game not ended)
              Opacity(
                opacity:
                    currentPlayer.type == PlayerType.human &&
                        gameState.phase != GamePhase.gameEnd
                    ? 1.0
                    : 0.7,
                child: Container(
                  height: 135, // Reduced height to minimize bottom space
                  padding: const EdgeInsets.fromLTRB(
                    8,
                    8,
                    8,
                    4,
                  ), // Reduced bottom padding
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
                                  ? (humanPlayer.currentHand.length - 1) *
                                            50.0 +
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
                                                      PlayerType.human &&
                                                  gameState.phase !=
                                                      GamePhase.gameEnd
                                              ? () => _onCardTap(index)
                                              : null,
                                          onDoubleTap:
                                              currentPlayer.type ==
                                                      PlayerType.human &&
                                                  gameState.phase !=
                                                      GamePhase.gameEnd
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

              // Game end overlay when game has finished
              if (gameState.phase == GamePhase.gameEnd &&
                  gameState.winner != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        BalatroTheme.neonYellow.withValues(alpha: 0.9),
                        BalatroTheme.neonGreen.withValues(alpha: 0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BalatroTheme.glowColor, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: BalatroTheme.neonYellow.withValues(alpha: 0.6),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.emoji_events,
                            color: Colors.black,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'GAME OVER!',
                            style: Theme.of(context).textTheme.displayMedium
                                ?.copyWith(color: Colors.black),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${gameState.winner!.name} WINS with ${gameState.winner!.score} points!',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: Colors.black),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Use the menu button to view final scores or start a new game',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
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

  GameSessionInfo _soloSessionInfo(GameState gameState) {
    return GameSessionInfo(
      analyticsSessionId:
          _analyticsSessionId ?? GameAnalyticsLogger.currentSessionId,
      gameSeed: gameState.deck.seed?.toString(),
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
      final gameState = ref.read(currentGameStateProvider);
      if (gameState == null) return;

      // Get bot personalities for tracking
      final botPersonalities = <String, BotPersonality>{};
      for (final player in gameState.players) {
        if (player.type == PlayerType.bot) {
          botPersonalities[player.id] = _botAI.personalityManager
              .getPersonality(player.id);
        }
      }

      _actionSequenceNumber = 0; // Reset sequence counter for new game
      _totalTurns = 0;
      _sessionBotPersonalities = botPersonalities;
      _analyticsSessionId = await GameAnalyticsLogger.startGameSession(
        players: gameState.players,
        gameState: gameState,
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
      final gameState = ref.read(currentGameStateProvider);
      if (gameState == null) return;

      _actionSequenceNumber++; // Increment sequence for this action

      final personality = _botAI.personalityManager.getPersonality(botId);
      await GameAnalyticsLogger.logBotDecision(
        botId: botId,
        decision: decision,
        reasoning: reasoning,
        personality: personality,
        gameState: gameState,
        decisionContext: {
          ...?context,
          // Add sequencing information
          'actionSequence': _actionSequenceNumber,
          'turnNumber': _totalTurns,
          'playerTurnIndex': gameState.currentPlayerIndex,
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
      final gameState = ref.read(currentGameStateProvider);
      final humanPlayer = ref.read(humanPlayerProvider);
      if (gameState == null || humanPlayer == null) return;

      _actionSequenceNumber++; // Increment sequence for this action

      await GameAnalyticsLogger.logGameEvent(
        eventType: action,
        playerId: humanPlayer.id,
        playerType: PlayerType.human,
        eventData: {
          'reasoning': reasoning,
          'context': context,
          'drawSource': drawSourceFromAction(action),

          // Sequencing information
          'actionSequence': _actionSequenceNumber,
          'turnNumber': _totalTurns,
          'playerTurnIndex': gameState.currentPlayerIndex,

          'round': gameState.round,
          'turnPhase': gameState.turnPhase.name,

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
          'deckSize': gameState.deck.size,
          'discardPileSize': gameState.discardPile.length,
          'topDiscardCard': gameState.discardPile.isNotEmpty
              ? gameState.discardPile.last.compactName
              : null,
          'discardPileFrozen': gameState.discardPileFrozen,

          // Opponent context (for strategic decisions)
          'opponents': gameState.players
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

  /// Log per-bot performance metrics at round end.
  Future<void> _logRoundEndAnalytics() async {
    if (_analyticsSessionId == null) {
      return;
    }

    try {
      final controller = _gameController;
      if (controller == null) {
        return;
      }

      final gameState = controller.gameState;
      final personalities = _sessionBotPersonalities.isNotEmpty
          ? _sessionBotPersonalities
          : GameAnalyticsLogger.sessionBotPersonalities;

      for (final player in gameState.players.where(
        (p) => p.type == PlayerType.bot,
      )) {
        final personality = personalities[player.id] ?? BotPersonality.adaptive;
        await GameAnalyticsLogger.logBotPerformanceMetrics(
          botId: player.id,
          personality: personality,
          gameState: gameState,
          performanceMetrics: {
            'roundScore': player.score.toDouble(),
            'handSize': player.currentHand.length.toDouble(),
            'meldCount': player.melds.length.toDouble(),
          },
        );
      }

      await AnalyticsBatcher.flushAllBatches();
    } catch (e) {
      DebugLogger.warning('Failed to log round-end analytics: $e');
    }
  }

  /// End analytics session when the game completes.
  Future<void> _endAnalyticsSession() async {
    if (_analyticsSessionId == null) {
      return;
    }

    try {
      final controller = _gameController;
      final gameState =
          controller?.gameState ?? ref.read(currentGameStateProvider);
      if (gameState == null) {
        return;
      }

      final winner = ref.read(gameWinnerProvider);
      final personalities = _sessionBotPersonalities.isNotEmpty
          ? _sessionBotPersonalities
          : GameAnalyticsLogger.sessionBotPersonalities;

      await GameAnalyticsLogger.endGameSession(
        gameState: gameState,
        winnerId: winner?.id,
        totalTurns: _totalTurns,
        botPersonalities: personalities,
      );
      await AnalyticsBatcher.flushAllBatches();

      _analyticsSessionId = null;
      _sessionBotPersonalities = {};
    } catch (e) {
      DebugLogger.warning('Failed to end analytics session: $e');
    }
  }
}
