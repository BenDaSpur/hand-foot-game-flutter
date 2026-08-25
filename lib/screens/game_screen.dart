import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/card.dart';
import '../models/player.dart';
import '../models/meld.dart';
import '../models/game_state.dart';
import '../game/game_action_feedback.dart';
import '../game/game_controller.dart';
import '../game/game_controller_factory.dart';
import '../ai/enhanced_bot_ai.dart';
import '../ai/bot_personality.dart';
import '../config/bot_configurations.dart';
import '../config/game_config.dart';
import '../config/solo_game_settings.dart';
import '../services/firebase_service.dart';
import '../widgets/melds_section.dart';
import '../widgets/game_hand_display.dart';
import '../widgets/game_board_layout.dart';
import '../widgets/game_action_buttons.dart';
import '../widgets/game_app_bar.dart';
import '../widgets/game_session_info_menu.dart';
import '../widgets/card_animation_host.dart';
import '../widgets/final_turn_banner.dart';
import '../widgets/last_call_banner.dart';
import '../widgets/stuck_go_out_recovery_banner.dart';
import '../widgets/round_start_mini_game.dart';
import '../game/go_out_guards.dart';
import '../theme/balatro_theme.dart';
import '../services/game_analytics_logger.dart';
import '../services/analytics/bot_decision_analytics_snapshot.dart';
import '../services/analytics/bot_decision_snapshot_mapper.dart';
import '../services/analytics_batcher.dart';
import '../services/analytics_fields.dart';
import 'main_menu_screen.dart';
import 'solo_game_setup_screen.dart';
import '../utils/debug_logger.dart';
import 'managers/bot_turn_manager.dart';
import 'managers/dialog_manager.dart';
import 'managers/game_state_manager.dart';
import 'managers/persistence_manager.dart';
import 'managers/event_based_game_state_manager.dart';
import '../widgets/game_keyboard_shortcuts.dart';
import '../widgets/keyboard_shortcuts_overlay.dart';
import '../utils/game_responsive_layout.dart';
import '../providers/game_providers.dart';
import '../providers/computed_providers.dart';
import '../tutorial/learn_to_play_coordinator.dart';
import '../tutorial/learn_to_play_session.dart';
import '../tutorial/learn_to_play_step.dart';
import '../widgets/learn_to_play_coach_banner.dart';
import '../ads/ads_service.dart';

/// Shared bot configurations live in [kBotConfigurations].

class GameScreen extends ConsumerStatefulWidget {
  final int? testSeed; // For deterministic testing
  final GameController? gameController; // For continuing saved games
  final SoloGameSettings? settings; // For new solo games from setup screen
  final SoloGameLaunchOptions? launchOptions;

  /// When set, runs as Learn to Play on the real game board UI.
  final LearnToPlaySession? learnToPlaySession;

  const GameScreen({
    super.key,
    this.testSeed,
    this.gameController,
    this.settings,
    this.launchOptions,
    this.learnToPlaySession,
  });

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  // Use providers instead of local state - accessed via ref
  GameController? get _gameController =>
      ref.read(gameControllerProvider)?.controller;
  EnhancedBotAI get _botAI => ref.read(botAIProvider);

  /// Turn owner read straight off the controller, which is the same source
  /// [build] uses to decide whether the hand is tappable. Turn-ownership gates
  /// must not disagree with what the player can see on screen.
  Player? get _liveCurrentPlayer => _gameController?.gameState.currentPlayer;

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
  bool _analyticsClosed = false;
  int _lastHeartbeatTurn = 0;

  // Manager instances for better code organization
  late BotTurnManager _botTurnManager;
  late DialogManager _dialogManager;
  late GameStateManager _gameStateManager;
  EventBasedGameStateManager? _eventBasedGameStateManager;
  late PersistenceManager _persistenceManager;

  // Prevent multiple game end dialogs
  bool _gameEndDialogShown = false;
  bool _isRoundTransitionInProgress = false;
  bool _earlyEndAlertInFlight = false;

  // Queue for bot turn processing to ensure one at a time
  bool _isBotTurnInProgress = false;
  final List<Player> _botTurnQueue = [];

  bool _isCardAnimationActive = false;

  // Keyboard shortcuts
  int? _keyboardFocusedCardIndex;
  int? _lastCurrentPlayerIndexForHighlight;
  bool _showKeyboardHelp = false;

  // Card draw animation anchors
  final GlobalKey _deckKey = GlobalKey();
  final GlobalKey _discardKey = GlobalKey();
  final GlobalKey _handStackKey = GlobalKey();
  final GlobalKey _meldAreaKey = GlobalKey();
  final ScrollController _handScrollController = ScrollController();

  LearnToPlayCoordinator? _learnCoordinator;
  bool _learnCompletionShown = false;

  bool get _isLearnToPlay => widget.learnToPlaySession != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize event listeners via Riverpod
    ref.read(gameEventListenerProvider);
    ref.read(soundEventListenerProvider); // Initialize sound effects
    if (_isLearnToPlay) {
      _learnCoordinator = LearnToPlayCoordinator();
    } else {
      AdsService.instance.preloadInterstitial();
    }
    _initializeGame();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_abandonAnalyticsIfNeeded('disposed'));
    _handScrollController.dispose();
    // Dispose event-based manager to clean up subscriptions
    _eventBasedGameStateManager?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        {
          unawaited(_heartbeatAnalytics());
        }
      case AppLifecycleState.hidden:
        {
          if (kIsWeb) {
            unawaited(_abandonAnalyticsIfNeeded('tab_hidden'));
          } else {
            unawaited(_heartbeatAnalytics());
          }
        }
      case AppLifecycleState.detached:
        {
          unawaited(_abandonAnalyticsIfNeeded('tab_hidden'));
        }
      case AppLifecycleState.resumed:
        {
          break;
        }
    }
  }

  /// Helper method to assign bot personalities consistently
  void _assignBotPersonalities() {
    final controller = _gameController;
    if (controller == null) {
      return;
    }

    final resolved = resolveBotPersonalities(
      players: controller.gameState.players,
      settings: controller.gameState.soloSettings,
    );
    for (final entry in resolved.entries) {
      _botAI.assignPersonality(entry.key, entry.value);
    }

    // Log personality assignments in debug mode
    if (kDebugMode) {
      final botPlayers = controller.gameState.players.where(
        (p) => p.type == PlayerType.bot,
      );
      for (final bot in botPlayers) {
        final personality = _botAI.personalityManager.getPersonality(bot.id);
        DebugLogger.debug(
          'Bot ${bot.name} (${bot.id}) assigned personality: $personality',
        );
      }
    }
  }

  /// Restore personalities when opening a continued autosave.
  void _restorePersonalitiesForContinuedGame(GameController controller) {
    final saved = controller.restoredBotPersonalities;
    if (saved.isNotEmpty) {
      _botTurnManager.restoreBotPersonalities(saved);
      return;
    }

    // Legacy saves: derive from solo settings / known bot names
    _assignBotPersonalities();
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
          _scheduleEarlyRoundEndAlerts();
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
      waitForPendingUi: _waitForPendingCardAnimation,
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
        if (_totalTurns - _lastHeartbeatTurn >= 3) {
          unawaited(_heartbeatAnalytics());
        }
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
        _clearHandHighlightState();
        _viewingPlayerMelds = null;
        processCurrentPlayerTurn();
      },
      onRoundEndDetected: () {
        _triggerRoundTransition('event');
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

        _clearHandHighlightState();
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
    // If a gameController was provided (continuing saved game / Learn to Play), use it
    if (widget.gameController != null) {
      // Defer provider mutation out of initState/build (Riverpod requirement).
      await Future<void>.delayed(Duration.zero);
      if (!mounted) {
        return;
      }
      final eventBus = ref.read(gameEventBusProvider);
      ref
          .read(gameControllerProvider.notifier)
          .setController(widget.gameController!, eventBus);
      _initializeManagers();

      // Continue must restore personalities — autosave previously left them
      // unassigned, so icons/AI defaulted to Adaptive (e.g. Clara showed Sue's icon).
      if (!_isLearnToPlay) {
        _restorePersonalitiesForContinuedGame(widget.gameController!);
      } else {
        _assignBotPersonalities();
      }

      _isInitialized = true;
      setState(() {});

      // Start bot turns if needed (skipped in Learn to Play)
      if (!_isLearnToPlay) {
        processCurrentPlayerTurn();
      }
      return;
    }

    // Configured solo start from setup screen takes priority over saved game.
    if (widget.settings != null) {
      await _startFreshGame();
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
                  _navigateToSoloSetup();
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

    await _startFreshGame();
  }

  void _navigateToSoloSetup() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const SoloGameSetupScreen()),
    );
  }

  Future<void> _startFreshGame() async {
    // Defer provider mutations out of initState/build (Riverpod requirement).
    await Future<void>.delayed(Duration.zero);
    if (!mounted || _disposed) {
      return;
    }

    final settings = widget.settings ?? SoloGameSettings.defaults;
    final launch = widget.launchOptions ?? const SoloGameLaunchOptions();

    final List<Player> players;
    final List<BotPersonality> personalities;

    if (launch.useConfiguredBots) {
      final nameSeed =
          widget.testSeed ?? settings.normalizedPersonalities.join().hashCode;
      players = settings.buildPlayers(random: Random(nameSeed));
      personalities = settings.normalizedPersonalities;
    } else {
      final botRandom = widget.testSeed != null
          ? Random(widget.testSeed!)
          : Random();
      final configs = SoloGameSettings.randomBotConfigurations(
        settings.botCount,
        random: botRandom,
      );
      players = SoloGameSettings.buildPlayersFromBotConfigs(configs);
      personalities = configs.map((config) => config.personality).toList();
    }

    final effectiveSettings = launch.useConfiguredBots
        ? settings
        : settings.copyWith(botPersonalities: personalities);

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
      seed: widget.testSeed ?? launch.gameSeed,
      eventBus: eventBus,
      soloSettings: effectiveSettings,
    );

    // Store in Riverpod provider for reactive access
    controllerNotifier.setController(newController, eventBus);

    // Assign bot personalities from setup settings
    final botAI = ref.read(botAIProvider);
    final botPlayers = players.where((p) => p.type == PlayerType.bot).toList();
    for (var i = 0; i < botPlayers.length; i++) {
      botAI.assignPersonality(botPlayers[i].id, personalities[i]);
    }

    _logSoloGameStarted(effectiveSettings);

    newController.initializeGame(dealCards: false);

    // Initialize managers after game setup
    _initializeManagers();

    await _runPerfectGrabAndStartRound(newController, roundNumber: 1);
  }

  Future<void> _runPerfectGrabAndStartRound(
    GameController controller, {
    required int roundNumber,
  }) async {
    if (_disposed || !mounted) {
      return;
    }

    // Deterministic widget/e2e tests pass [testSeed] and skip the timing
    // mini-game so startup is stable under IntegrationTest bindings.
    final bool earnedBonus;
    if (widget.testSeed != null) {
      earnedBonus = false;
    } else {
      earnedBonus = await RoundStartMiniGame.show(
        context,
        roundNumber: roundNumber,
      );
    }
    if (_disposed || !mounted) {
      return;
    }

    controller.completeRoundStart(earnedPerfectGrabBonus: earnedBonus);

    // Sort the human player's initial hand
    final humanPlayer = controller.gameState.players.firstWhere(
      (player) => player.type == PlayerType.human,
    );
    humanPlayer.sortHandByRank();

    if (!_isInitialized) {
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
    } else {
      if (mounted) {
        _clearHandHighlightState();
        _viewingPlayerMelds = null;

        _persistenceManager.saveGameState().catchError((error) {
          DebugLogger.error(
            'Error saving game state after round transition: $error',
          );
        });
      }
    }

    if (mounted) {
      processCurrentPlayerTurn();
    }
  }

  Future<void> _waitForPendingCardAnimation() async {
    // DiscardPileUnlockedEvent is delivered on a microtask.
    await Future<void>.delayed(Duration.zero);
    if (!_isCardAnimationActive || !mounted) {
      return;
    }
    const poll = Duration(milliseconds: 32);
    final deadline = DateTime.now().add(GameConfig.cardAnimationSafetyTimeout);
    while (_isCardAnimationActive &&
        mounted &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(poll);
    }
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
    if (_isLearnToPlay) {
      return;
    }

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
        _triggerRoundTransition('');
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
      if (currentPlayer.type == PlayerType.bot) {
        _lastCurrentPlayerIndexForHighlight = gameState.currentPlayerIndex;

        if (!_isBotTurnInProgress) {
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

        DebugLogger.debug('Queueing bot turn for ${currentPlayer.name}');
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
        final humanIndex = gameState.players.indexWhere(
          (p) => p.type == PlayerType.human,
        );
        if (shouldResetHandHighlightOnTurnChange(
          currentPlayerIndex: gameState.currentPlayerIndex,
          humanPlayerIndex: humanIndex,
          lastCurrentPlayerIndex: _lastCurrentPlayerIndexForHighlight,
        )) {
          _clearHandHighlightState();
          if (mounted) {
            setState(() {});
          }
        }
        _lastCurrentPlayerIndexForHighlight = gameState.currentPlayerIndex;
        _gameStateManager.validateHumanPlayerState();
        // CRITICAL: Ensure we never auto-process human turns
        _botTurnManager
            .resetProcessingState(); // Clear any stuck bot processing flag
        if (mounted) {
          if (controller.gameState.phase == GamePhase.roundEnd) {
            _triggerRoundTransition('human turn');
          } else {
            _scheduleEarlyRoundEndAlerts();
          }
        }
        return;
      }
    } catch (e) {
      DebugLogger.error('Error in processCurrentPlayerTurn: $e');
      _handleCriticalError(e);
    }
  }

  /// Fire-and-forget round transition with source-tagged error logging.
  void _triggerRoundTransition(String source) {
    _handleRoundTransition().catchError((error) {
      final message = source.isEmpty
          ? 'Error handling round transition: $error'
          : 'Error handling round transition from $source: $error';
      DebugLogger.error(message);
    });
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
      final emergencyReason = controller.gameState.emergencyRoundEndReason;
      if (emergencyReason != null) {
        await _dialogManager.showEmergencyRoundEndDialog(
          reason: emergencyReason,
        );
        if (_disposed || !mounted) {
          return;
        }
      }

      await _logRoundEndAnalytics();
      if (_disposed || !mounted) {
        return;
      }

      await _dialogManager.showRoundEndScoreboard();
      if (_disposed || !mounted) {
        return;
      }

      if (!_isLearnToPlay) {
        await AdsService.instance.showInterstitialIfEligible(
          isSolo: true,
          isLearnToPlay: false,
        );
        if (_disposed || !mounted) {
          return;
        }
      }

      controller.recoverGameEndIfNeeded();

      if (controller.gameState.phase == GamePhase.gameEnd) {
        if (!_gameEndDialogShown) {
          final winner =
              controller.gameState.winner ?? ref.read(gameWinnerProvider);
          if (winner != null) {
            _gameEndDialogShown = true;
            final players = List<Player>.from(controller.gameState.players)
              ..sort((a, b) => b.score.compareTo(a.score));
            _dialogManager.showGameEndDialog(winner, players);
          }
        }
        return;
      }

      if (controller.gameState.phase != GamePhase.roundEnd) {
        return;
      }

      final nextRoundNumber = controller.gameState.round;
      controller.prepareNewRoundDeal();
      DebugLogger.debug('Prepared deal for round $nextRoundNumber');

      await _runPerfectGrabAndStartRound(
        controller,
        roundNumber: nextRoundNumber,
      );
      DebugLogger.debug('Advanced to round ${controller.gameState.round}');
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
    // Hand taps are gated by CardAnimationScope in GameHandDisplay. Do not also
    // gate here on [_isCardAnimationActive] — that flag can desync if the host
    // is disposed mid-animation, leaving cards untappable while Play Cards
    // stays enabled.

    if (_liveCurrentPlayer?.type != PlayerType.human) {
      return;
    }

    final humanPlayer = ref.read(humanPlayerProvider);
    if (humanPlayer == null) return;

    // Bounds checking
    if (cardIndex < 0 || cardIndex >= humanPlayer.currentHand.length) return;

    if (_isLearnToPlay) {
      final coordinator = _learnCoordinator;
      final session = widget.learnToPlaySession;
      if (coordinator == null || session == null) {
        return;
      }
      if (coordinator.canPerform(LearnToPlayAction.meld)) {
        if (!session.kingIndicesInHand().contains(cardIndex)) {
          return;
        }
      } else if (coordinator.canPerform(LearnToPlayAction.discard)) {
        if (session.discardTargetIndex() != cardIndex) {
          return;
        }
        setState(() {
          _keyboardFocusedCardIndex = cardIndex;
          _selectedCardIndices
            ..clear()
            ..add(cardIndex);
        });
        _hasPlayerInteractedSinceDraw = true;
        return;
      } else {
        return;
      }
    }

    _hasPlayerInteractedSinceDraw = true; // Mark that player has interacted
    setState(() {
      _keyboardFocusedCardIndex = cardIndex;
      if (_selectedCardIndices.contains(cardIndex)) {
        _selectedCardIndices.remove(cardIndex);
      } else {
        _selectedCardIndices.add(cardIndex);
      }
    });
  }

  void _onCardDoubleTap(int cardIndex) {
    if (_liveCurrentPlayer?.type != PlayerType.human) {
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

  Set<int> _playableCardIndices(Player humanPlayer) {
    if (_liveCurrentPlayer?.type != PlayerType.human) {
      return {};
    }

    if (_isLearnToPlay) {
      final coordinator = _learnCoordinator;
      final session = widget.learnToPlaySession;
      if (coordinator == null || session == null) {
        return {};
      }
      if (coordinator.canPerform(LearnToPlayAction.meld)) {
        return session.kingIndicesInHand().toSet();
      }
      if (coordinator.canPerform(LearnToPlayAction.discard)) {
        final index = session.discardTargetIndex();
        return index == null ? {} : {index};
      }
      return {};
    }

    final gameState = ref.read(currentGameStateProvider);
    if (gameState?.turnPhase != TurnPhase.meld) {
      return {};
    }

    final controller = _gameController;
    if (controller == null) {
      return {};
    }

    return controller.getPlayableCardIndices(humanPlayer);
  }

  bool _isGameStuck() {
    final humanPlayer = ref.read(humanPlayerProvider);
    final currentPlayer = _liveCurrentPlayer;
    final gameState = ref.read(currentGameStateProvider);

    if (humanPlayer == null || currentPlayer == null || gameState == null) {
      return false;
    }

    return GoOutGuards.isHumanStuckWithoutGoOut(
      gameState: gameState,
      humanPlayer: humanPlayer,
      currentPlayer: currentPlayer,
    );
  }

  void _forceNextTurn() {
    final controller = _gameController;
    if (controller != null) {
      final previousPlayer = controller.gameState.currentPlayer;
      controller.advanceTurnAfterAction(previousPlayer);
      // UI will update automatically via provider reactivity
      processCurrentPlayerTurn();
    }
  }

  void _onUndoMeld() {
    final controller = _gameController;
    if (controller == null || !controller.canUndoMeld) {
      return;
    }
    if (controller.undoLastMeld()) {
      setState(() {
        _selectedCardIndices.clear();
      });
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

        _initializeManagers();
        _restorePersonalitiesForContinuedGame(savedController);

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
        unawaited(_startFreshGame());
      }
    } catch (e) {
      _dialogManager.showErrorDialog(
        'Error loading saved game: ${e.toString()}',
      );
      unawaited(_startFreshGame());
    }
  }

  Future<void> _logSoloGameStarted(SoloGameSettings settings) async {
    try {
      await FirebaseService.logGameEvent(
        'solo_game_started',
        parameters: {
          'game_type': 'solo',
          'botCount': settings.botCount,
          'botPersonalities': settings.normalizedPersonalities
              .map((p) => p.name)
              .join(','),
          'goingOutBonus': settings.enableGoingOutBonus,
          'finalTurn': settings.enableFinalTurnAfterGoingOut,
        },
      );
    } catch (_) {
      // Silently ignore Firebase errors in singleplayer mode
    }
  }

  Future<void> _startNewGame() async {
    // Clear any saved game when explicitly starting new
    await GameController.clearSavedGame();

    setState(() {
      _isInitialized = false;
      _clearHandHighlightState();
      _viewingPlayerMelds = null;
    });

    _navigateToSoloSetup();
  }

  void _onDrawFromDeck() {
    final controller = _gameController;
    if (controller == null) return;

    if (_isLearnToPlay) {
      final coordinator = _learnCoordinator;
      final session = widget.learnToPlaySession;
      if (coordinator == null ||
          session == null ||
          !coordinator.canPerform(LearnToPlayAction.draw)) {
        return;
      }
      if (!controller.drawFromDeck()) {
        return;
      }
      session.normalizeHandAfterDraw();
      coordinator.advanceOn(LearnToPlayAction.draw);
      _hasPlayerInteractedSinceDraw = false;
      // Keep the hand unselected so play-down happens in the meld modal.
      _clearHandHighlightState();
      setState(() {});
      return;
    }

    if (controller.drawFromDeck()) {
      // Log human action for analytics
      _logHumanAction(
        action: 'drawFromDeck',
        reasoning: 'Human player drew 2 cards from deck',
      );

      // Cards are now automatically inserted in sorted position
      _hasPlayerInteractedSinceDraw =
          false; // Reset interaction flag after drawing
      _clearHandHighlightState();
      setState(() {});
      _scheduleEarlyRoundEndAlerts();
    } else {
      // Empty-deck emergency end is explained in the round-transition dialog.
      final gameState = controller.gameState;
      if (gameState.phase == GamePhase.roundEnd ||
          gameState.phase == GamePhase.gameEnd) {
        processCurrentPlayerTurn();
      } else {
        _dialogManager.showErrorDialog(
          GameActionFeedback.drawFromDeckFailureMessage(gameState),
        );
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
      _dialogManager.showErrorDialog(
        GameActionFeedback.unlockDiscardBlockerMessage(gameState),
      );
      return;
    }

    final pileSizeBefore = gameState.discardPile.length;
    final unlockTopCard = gameState.topDiscard?.compactName;
    if (controller.unlockDiscardPile()) {
      _hasPlayerInteractedSinceDraw = false;
      _clearHandHighlightState();
      setState(() {});
      // UI will update via Riverpod reactivity when DiscardPileUnlockedEvent fires
      debugPrint('DEBUG: Discard pile unlocked successfully');
      // Top discard is melded; newly drawn cards are discard leftovers plus
      // any draw-pile fill that completed the 5-card unlock pickup.
      final cardsActuallyTaken = pileSizeBefore <= 0
          ? 0
          : 1 + currentPlayer.newlyDrawnCardIndices.length;
      _logHumanAction(
        action: 'unlockDiscardPile',
        reasoning: 'Human unlocked discard pile',
        context: {
          'pileSizeBefore': pileSizeBefore,
          'cardsActuallyTaken': cardsActuallyTaken,
          'unlockTopCard': unlockTopCard,
          // Legacy field — was pile size, not cards received; keep for old queries.
          'cardsTaken': pileSizeBefore,
        },
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
    if (_isLearnToPlay) {
      return false;
    }
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

    final human = controller.gameState.currentPlayer;
    for (final indices in meldIndices) {
      if (indices.any(
        (index) => index < 0 || index >= human.currentHand.length,
      )) {
        _dialogManager.showErrorDialog(
          'Invalid card selection. Please try again.',
        );
        return;
      }
    }

    final allMeldCards = <List<PlayingCard>>[];
    for (final indices in meldIndices) {
      allMeldCards.add(
        indices.map((index) => human.currentHand[index]).toList(),
      );
    }

    if (GoOutGuards.wouldMultiMeldLeaveUnfinishable(human, allMeldCards)) {
      _dialogManager.showErrorDialog(
        GameActionFeedback.unfinishableMeldBlockerMessage(human),
      );
      return;
    }

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
      _advanceLearnAfterSuccessfulMeld();
      setState(() {});

      // Check if creating melds caused the round to end
      await _gameStateManager.checkAndHandleRoundEnd();

      // Meld-phase go-out starts final turns without a discard, so kick the
      // next bot if TurnEndedEvent was missed (session_17871159981788178).
      _resumePlayAfterMeldIfNeeded();

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

  /// After a meld that went out, the next player may already be a bot.
  void _resumePlayAfterMeldIfNeeded() {
    final controller = _gameController;
    if (controller == null || !mounted) {
      return;
    }
    if (controller.gameState.phase != GamePhase.playing) {
      return;
    }
    if (controller.gameState.currentPlayer.type != PlayerType.bot) {
      return;
    }
    processCurrentPlayerTurn();
  }

  Future<void> _onDiscard() async {
    // CRITICAL FIX: Prevent auto-discard after drawing cards
    if (!_hasPlayerInteractedSinceDraw) {
      return;
    }

    if (_isLearnToPlay) {
      final coordinator = _learnCoordinator;
      final session = widget.learnToPlaySession;
      final controller = _gameController;
      if (coordinator == null ||
          session == null ||
          controller == null ||
          !coordinator.canPerform(LearnToPlayAction.discard)) {
        return;
      }
      final target = session.discardTargetIndex();
      if (target == null) {
        return;
      }
      final hand = session.human.currentHand;
      if (target < 0 || target >= hand.length) {
        return;
      }
      if (!controller.discardCard(hand[target])) {
        return;
      }
      coordinator.advanceOn(LearnToPlayAction.discard);
      session.keepHumanInControl();
      _clearHandHighlightState();
      setState(() {});
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
            _clearHandHighlightState();
            await _gameStateManager.checkAndHandleRoundEnd();

            // Schedule bot processing for next frame to avoid immediate execution during human turn
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                final nextPlayer = _liveCurrentPlayer;
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
          _dialogManager.showErrorDialog(
            GameActionFeedback.goOutBlockerMessage(humanPlayer),
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
        _clearHandHighlightState();
        setState(() {});
        await _gameStateManager.checkAndHandleRoundEnd();

        // Schedule bot processing for next frame to avoid immediate execution during human turn
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final nextPlayer = _liveCurrentPlayer;
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

    setState(() {
      _clearHandHighlightState();
    });
  }

  void _clearHandHighlightState() {
    _selectedCardIndices.clear();
    _keyboardFocusedCardIndex = null;
  }

  void _onFocusPreviousCard() {
    final humanPlayer = ref.read(humanPlayerProvider);
    if (humanPlayer == null) {
      return;
    }
    setState(() {
      _keyboardFocusedCardIndex = focusPreviousCardIndex(
        currentIndex: _keyboardFocusedCardIndex,
        handLength: humanPlayer.currentHand.length,
      );
    });
  }

  void _onFocusNextCard() {
    final humanPlayer = ref.read(humanPlayerProvider);
    if (humanPlayer == null) {
      return;
    }
    setState(() {
      _keyboardFocusedCardIndex = focusNextCardIndex(
        currentIndex: _keyboardFocusedCardIndex,
        handLength: humanPlayer.currentHand.length,
      );
    });
  }

  void _onToggleSelectFocusedCard() {
    if (_keyboardFocusedCardIndex != null) {
      _onCardTap(_keyboardFocusedCardIndex!);
    }
  }

  void _toggleKeyboardHelp() {
    setState(() {
      _showKeyboardHelp = !_showKeyboardHelp;
    });
  }

  GameKeyboardContext _buildKeyboardContext(GameState gameState) {
    final controller = _gameController;
    final humanPlayer = ref.read(humanPlayerProvider);
    final handLength = humanPlayer?.currentHand.length ?? 0;
    return GameKeyboardContext(
      turnPhase: gameState.turnPhase,
      canUnlockDiscard: controller?.canUnlockDiscard() ?? false,
      selectedCardCount: _selectedCardIndices.length,
      handLength: handLength,
      focusedCardIndex: clampKeyboardFocus(
        index: _keyboardFocusedCardIndex,
        handLength: handLength,
      ),
      isHumanTurn: gameState.currentPlayer.type == PlayerType.human,
      isAnimating: _isCardAnimationActive,
      hasInteractedSinceDraw: _hasPlayerInteractedSinceDraw,
      isHelpVisible: _showKeyboardHelp,
    );
  }

  GameKeyboardActions _buildKeyboardActions() {
    return GameKeyboardActions(
      onDrawFromDeck: _onDrawFromDeck,
      onUnlockDiscard: _onUnlockDiscard,
      onOpenMeldModal: () => _dialogManager.showAdvancedMeldSelector(
        onMeldsCreated: _executeAdvancedMeldCreation,
      ),
      onDiscard: _onDiscard,
      onClearSelection: () => setState(() => _selectedCardIndices.clear()),
      onSortHand: () => _sortHand('rank'),
      onToggleSelectFocused: _onToggleSelectFocusedCard,
      onFocusPrevious: _onFocusPreviousCard,
      onFocusNext: _onFocusNextCard,
      onShowScoreboard: () => _dialogManager.showScoreboard(),
      onToggleHelp: _toggleKeyboardHelp,
    );
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

    final humanPlayer = controller.gameState.currentPlayer;
    if (GoOutGuards.wouldAddCardsToMeldLeaveUnfinishable(
      humanPlayer,
      meldIndex,
      cardsToAdd,
    )) {
      _dialogManager.showErrorDialog(
        GameActionFeedback.unfinishableMeldBlockerMessage(humanPlayer),
      );
      return;
    }

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
      _resumePlayAfterMeldIfNeeded();

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
    // Use providers for reactive state access
    // Watch the controller state directly to ensure we rebuild when version changes
    final controllerState = ref.watch(gameControllerProvider);
    // Access version to ensure Riverpod tracks this dependency
    final _ = controllerState?.version;
    final gameState = controllerState?.controller.gameState;
    if (!_isInitialized || gameState == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: BalatroTheme.primaryGradient,
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final currentPlayer = gameState.currentPlayer;
    final humanPlayer = gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    // Debug logging for UI rebuilds
    DebugLogger.debug(
      'UI BUILD: Current player=${currentPlayer.name} (${currentPlayer.type}), version=${controllerState?.version}',
    );

    final showDesktopKeyboardHints = !GameResponsiveLayout.isMobile(context);

    return GameKeyboardShortcuts(
      getContext: () => _buildKeyboardContext(gameState),
      actions: _buildKeyboardActions(),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: BalatroTheme.primaryGradient,
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: GameAppBar(
                gameState: gameState,
                isMultiplayer: false,
                sessionInfo: _isLearnToPlay
                    ? null
                    : _soloSessionInfo(gameState),
                additionalActions: [
                  if (_isLearnToPlay)
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Exit lesson',
                      onPressed: _exitLearnToPlay,
                    ),
                  if (!_isLearnToPlay)
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
                onNewGame: _isLearnToPlay
                    ? null
                    : () {
                        _dialogManager.showNewGameConfirmation(_startNewGame);
                      },
                onCopySeed: _isLearnToPlay
                    ? null
                    : () {
                        _persistenceManager.copySeedToClipboard(context);
                      },
                onExportGame: _isLearnToPlay
                    ? null
                    : () {
                        _persistenceManager.copyGameStateToClipboard(context);
                      },
                onLoadGame: _isLearnToPlay
                    ? null
                    : () {
                        _dialogManager.showLoadGameDialog(
                          (inputText) => _persistenceManager.loadGameFromJson(
                            inputText,
                            context,
                          ),
                        );
                      },
                onHowToPlay: () {
                  _dialogManager.showHowToPlayDialog();
                },
              ),
              body: CardAnimationHost(
                eventBus: ref.read(gameEventBusProvider),
                localHumanPlayer: () => ref.read(humanPlayerProvider),
                deckKey: _deckKey,
                discardKey: _discardKey,
                handStackKey: _handStackKey,
                meldAreaKey: _meldAreaKey,
                handScrollController: _handScrollController,
                animationsEnabled: !_isLearnToPlay,
                onAnimationStateChanged: (isAnimating) {
                  if (_isCardAnimationActive != isAnimating) {
                    setState(() {
                      _isCardAnimationActive = isAnimating;
                    });
                  }
                },
                child: Column(
                  children: [
                    if (_isLearnToPlay && _learnCoordinator != null)
                      LearnToPlayCoachBanner(
                        step: _learnCoordinator!.currentStep,
                        progress: _learnCoordinator!.progress,
                        showContinue: _learnCoordinator!.isInfoStep,
                        onContinue: _onLearnContinueInfo,
                      ),
                    Expanded(
                      child: GameBoardLayout(
                        gameState: gameState,
                        viewingPlayerMelds: _viewingPlayerMelds,
                        onPlayerTap: (player) {
                          setState(() {
                            _viewingPlayerMelds = player.id == humanPlayer.id
                                ? null
                                : player;
                          });
                        },
                        deckKey: _deckKey,
                        discardKey: _discardKey,
                        meldAreaKey: _meldAreaKey,
                        headerExpanded: _statusExpanded,
                        onHeaderToggle: () {
                          setState(() {
                            _statusExpanded = !_statusExpanded;
                          });
                        },
                        botPersonalityManager: _botAI.personalityManager,
                        useDesktopRecentActions: true,
                        recentActionsExpanded: _actionsExpanded,
                        onRecentActionsToggle: () {
                          setState(() {
                            _actionsExpanded = !_actionsExpanded;
                          });
                        },
                        headerExtras: showDesktopKeyboardHints
                            ? [
                                KeyboardShortcutsHelpChip(
                                  onTap: _toggleKeyboardHelp,
                                ),
                              ]
                            : const [],
                        aboveMelds: _buildAboveMeldsBanner(
                          context,
                          gameState,
                          currentPlayer,
                        ),
                        meldsSection: MeldsSection(
                          gameState: gameState,
                          humanPlayer: humanPlayer,
                          viewingPlayerMelds: _viewingPlayerMelds,
                          onViewPlayerMelds: (player) {
                            setState(() {
                              _viewingPlayerMelds = player;
                            });
                          },
                          onAddCardToMeld: _onAddCardToMeld,
                          onSelectAllCardsForMeld: _selectAllCardsForMeld,
                          canAddCardToMeld: _canAddCardToMeld,
                          getCompatibleCardsInfo: _getCompatibleCardsInfo,
                        ),
                        actionButtons: GameActionButtons(
                          gameState: gameState,
                          humanPlayer: humanPlayer,
                          selectedCardIndices: _selectedCardIndices,
                          showKeyboardHints:
                              showDesktopKeyboardHints && !_isLearnToPlay,
                          onDrawFromDeck:
                              (!_isLearnToPlay ||
                                  (_learnCoordinator?.canPerform(
                                        LearnToPlayAction.draw,
                                      ) ??
                                      false))
                              ? _onDrawFromDeck
                              : null,
                          onUnlockDiscard: _isLearnToPlay
                              ? null
                              : () {
                                  final controller = _gameController;
                                  return (controller != null &&
                                          controller.canUnlockDiscard())
                                      ? _onUnlockDiscard
                                      : null;
                                }(),
                          onShowAdvancedMeldSelector: _isLearnToPlay
                              ? ((_learnCoordinator?.canPerform(
                                          LearnToPlayAction.meld,
                                        ) ??
                                        false)
                                    ? _openLearnMeldModal
                                    : null)
                              : () => _dialogManager.showAdvancedMeldSelector(
                                  onMeldsCreated: _executeAdvancedMeldCreation,
                                ),
                          onDiscard: () {
                            if (_isLearnToPlay) {
                              if (!(_learnCoordinator?.canPerform(
                                    LearnToPlayAction.discard,
                                  ) ??
                                  false)) {
                                return null;
                              }
                              if (_selectedCards.length != 1) {
                                return null;
                              }
                              return _onDiscard;
                            }
                            return _selectedCards.length == 1
                                ? _onDiscard
                                : null;
                          }(),
                          onUndoMeld: (_gameController?.canUndoMeld ?? false)
                              ? _onUndoMeld
                              : null,
                          canUndoMeld: _gameController?.canUndoMeld ?? false,
                          onClearSelection: () =>
                              setState(() => _selectedCardIndices.clear()),
                        ),
                        handDisplay: GameHandDisplay(
                          player: humanPlayer,
                          selectedCardIndices: _selectedCardIndices,
                          keyboardFocusedCardIndex: clampKeyboardFocus(
                            index: _keyboardFocusedCardIndex,
                            handLength: humanPlayer.currentHand.length,
                          ),
                          onCardTap:
                              _learnHandCardTapEnabled(currentPlayer, gameState)
                              ? _onCardTap
                              : null,
                          onCardDoubleTap:
                              _learnHandCardTapEnabled(currentPlayer, gameState)
                              ? _onCardDoubleTap
                              : null,
                          playableCardIndices: _playableCardIndices(
                            humanPlayer,
                          ),
                          viewingPlayerMelds: _viewingPlayerMelds,
                          onReturnToHand: () {
                            setState(() {
                              _viewingPlayerMelds = null;
                            });
                          },
                          isCurrentPlayerTurn:
                              currentPlayer.type == PlayerType.human &&
                              gameState.phase != GamePhase.gameEnd,
                          handStackKey: _handStackKey,
                          handScrollController: _handScrollController,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_showKeyboardHelp && showDesktopKeyboardHints)
            KeyboardShortcutsOverlay(onDismiss: _toggleKeyboardHelp),
        ],
      ),
    );
  }

  void _onLearnContinueInfo() {
    final coordinator = _learnCoordinator;
    if (coordinator == null ||
        !coordinator.canPerform(LearnToPlayAction.continueInfo)) {
      return;
    }
    coordinator.advanceOn(LearnToPlayAction.continueInfo);
    widget.learnToPlaySession?.keepHumanInControl();
    _selectedCardIndices.clear();
    setState(() {});
    _maybeShowLearnCompletion();
  }

  bool _learnHandCardTapEnabled(Player currentPlayer, GameState gameState) {
    if (currentPlayer.type != PlayerType.human ||
        gameState.phase == GamePhase.gameEnd) {
      return false;
    }
    if (!_isLearnToPlay) {
      return true;
    }
    // During play-down, selection happens inside the meld modal — not on the
    // hand strip — so learners practice the same create-meld flow as solo play.
    if (_learnCoordinator?.canPerform(LearnToPlayAction.meld) ?? false) {
      return false;
    }
    return true;
  }

  void _openLearnMeldModal() {
    final coordinator = _learnCoordinator;
    if (coordinator == null ||
        !coordinator.canPerform(LearnToPlayAction.meld)) {
      return;
    }
    _selectedCardIndices.clear();
    _dialogManager.showAdvancedMeldSelector(
      onMeldsCreated: _executeAdvancedMeldCreation,
    );
  }

  void _advanceLearnAfterSuccessfulMeld() {
    final coordinator = _learnCoordinator;
    final session = widget.learnToPlaySession;
    if (!_isLearnToPlay ||
        coordinator == null ||
        session == null ||
        !coordinator.canPerform(LearnToPlayAction.meld)) {
      return;
    }
    coordinator.advanceOn(LearnToPlayAction.meld);
    _selectedCardIndices.clear();
    final discardIndex = session.discardTargetIndex();
    if (discardIndex != null) {
      _selectedCardIndices.add(discardIndex);
      _hasPlayerInteractedSinceDraw = true;
    }
    setState(() {});
  }

  Future<void> _maybeShowLearnCompletion() async {
    final coordinator = _learnCoordinator;
    if (coordinator == null ||
        !coordinator.isComplete ||
        _learnCompletionShown) {
      return;
    }
    _learnCompletionShown = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: BalatroTheme.darkPurple,
            title: const Text(
              'You learned enough to win!',
              style: TextStyle(color: BalatroTheme.primaryText),
            ),
            content: const Text(
              'You finished the basics and how-to-win tips. '
              'Try a real solo game next — build books, manage your Foot, and race to go out.',
              style: TextStyle(color: BalatroTheme.secondaryText),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainMenuScreen()),
                    (route) => false,
                  );
                },
                child: const Text('Main Menu'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) =>
                          GameScreen(settings: SoloGameSettings.defaults),
                    ),
                    (route) => false,
                  );
                },
                child: const Text('Play Solo'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exitLearnToPlay() async {
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Widget? _buildAboveMeldsBanner(
    BuildContext context,
    GameState gameState,
    Player currentPlayer,
  ) {
    if (_isLearnToPlay) {
      return null;
    }

    if (_isGameStuck() &&
        currentPlayer.type == PlayerType.human &&
        gameState.phase != GamePhase.gameEnd) {
      final humanPlayer = ref.read(humanPlayerProvider) ?? currentPlayer;
      return StuckGoOutRecoveryBanner(
        humanPlayer: humanPlayer,
        onUndo: (_gameController?.canUndoMeld ?? false) ? _onUndoMeld : null,
        onSkipTurn: _forceNextTurn,
      );
    }

    if (gameState.phase == GamePhase.gameEnd && gameState.winner != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              BalatroTheme.neonYellow.withValues(alpha: 0.9),
              BalatroTheme.neonGreen.withValues(alpha: 0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BalatroTheme.glowColor, width: 2),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events, color: Colors.black, size: 24),
                const SizedBox(width: 8),
                Text(
                  'GAME OVER!',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${gameState.winner!.name} wins with ${gameState.winner!.score} pts!',
              style: const TextStyle(color: Colors.black87, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (gameState.lastCallActive && gameState.phase == GamePhase.playing) {
      return LastCallBanner(
        isLocalPlayerTurn: currentPlayer.type == PlayerType.human,
      );
    }

    if (gameState.finalTurnPhaseActive) {
      return FinalTurnBanner(gameState: gameState);
    }

    return null;
  }

  void _scheduleEarlyRoundEndAlerts() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowEarlyRoundEndAlerts();
    });
  }

  Future<void> _maybeShowEarlyRoundEndAlerts() async {
    final controller = _gameController;
    if (controller == null ||
        _earlyEndAlertInFlight ||
        _disposed ||
        !mounted ||
        _isLearnToPlay ||
        _isRoundTransitionInProgress) {
      return;
    }

    final gameState = controller.gameState;
    if (gameState.phase != GamePhase.playing) {
      return;
    }

    if (gameState.lastCallAlertPending) {
      _earlyEndAlertInFlight = true;
      gameState.consumeLastCallAlert();
      final isLocalPlayerTurn =
          gameState.currentPlayer.type == PlayerType.human;
      await _dialogManager.showLastCallAlert(
        isLocalPlayerTurn: isLocalPlayerTurn,
      );
      _earlyEndAlertInFlight = false;
      if (mounted) {
        setState(() {});
      }
      return;
    }

    if (gameState.stalemateAlertPending) {
      _earlyEndAlertInFlight = true;
      gameState.consumeStalemateAlert();
      await _dialogManager.showStalemateWarningAlert();
      _earlyEndAlertInFlight = false;
    }
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
              style: TextStyle(color: BalatroTheme.glowColor),
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
      _lastHeartbeatTurn = 0;
      _analyticsClosed = false;
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
    BotDecisionAnalyticsSnapshot? gameStateSnapshot,
  }) async {
    if (_analyticsSessionId == null) return;

    try {
      final liveGameState = ref.read(currentGameStateProvider);
      if (liveGameState == null && gameStateSnapshot == null) {
        return;
      }

      final analyticsSnapshot =
          gameStateSnapshot ??
          BotDecisionSnapshotMapper.fromGameState(liveGameState!);

      _actionSequenceNumber++; // Increment sequence for this action

      final personality = _botAI.personalityManager.getPersonality(botId);
      await GameAnalyticsLogger.logBotDecision(
        botId: botId,
        decision: decision,
        reasoning: reasoning,
        personality: personality,
        gameState: analyticsSnapshot,
        decisionContext: {
          ...?context,
          // Add sequencing information
          'actionSequence': _actionSequenceNumber,
          'turnNumber': _totalTurns,
          'playerTurnIndex': analyticsSnapshot.currentPlayerIndex,
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
            'bookCount': player.melds
                .where((meld) => meld.cards.length >= 7)
                .length
                .toDouble(),
            'hasPickedUpFoot': player.hasPickedUpFoot ? 1.0 : 0.0,
          },
        );
      }

      await GameAnalyticsLogger.logRoundSummary(
        gameState: gameState,
        botPersonalities: personalities,
      );
      await GameAnalyticsLogger.heartbeatSessionProgress(gameState: gameState);
      await AnalyticsBatcher.flushAllBatches();
    } catch (e) {
      DebugLogger.warning('Failed to log round-end analytics: $e');
    }
  }

  Future<void> _heartbeatAnalytics() async {
    if (_analyticsClosed || _analyticsSessionId == null) {
      return;
    }
    final gameState =
        _gameController?.gameState ?? ref.read(currentGameStateProvider);
    if (gameState == null) {
      return;
    }
    _lastHeartbeatTurn = _totalTurns;
    try {
      await GameAnalyticsLogger.heartbeatSessionProgress(gameState: gameState);
      await AnalyticsBatcher.flushAllBatches();
    } catch (e) {
      DebugLogger.warning('Failed to heartbeat analytics session: $e');
    }
  }

  Future<void> _abandonAnalyticsIfNeeded(String endReason) async {
    if (_analyticsClosed || _analyticsSessionId == null) {
      return;
    }
    final gameState =
        _gameController?.gameState ?? ref.read(currentGameStateProvider);
    if (gameState == null) {
      return;
    }
    _analyticsClosed = true;
    try {
      await GameAnalyticsLogger.abandonGameSession(
        gameState: gameState,
        endReason: endReason,
        totalTurns: _totalTurns,
        botPersonalities: _sessionBotPersonalities,
      );
      _analyticsSessionId = null;
    } catch (e) {
      DebugLogger.warning('Failed to abandon analytics session: $e');
    }
  }

  /// End analytics session when the game completes.
  Future<void> _endAnalyticsSession() async {
    if (_analyticsClosed || _analyticsSessionId == null) {
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

      _analyticsClosed = true;
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
