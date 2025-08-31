import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/card.dart';
import '../models/player.dart';
import '../models/meld.dart';
import '../models/game_state.dart';
import '../game/game_controller.dart';
import '../game/game_controller_factory.dart';
import '../ai/enhanced_bot_ai.dart';
import '../ai/bot_decision.dart';
import '../ai/bot_personality.dart';
import '../widgets/playing_card_widget.dart';
import '../widgets/meld_widget.dart';
import '../widgets/mobile_status_bar.dart';
import '../widgets/collapsible_recent_actions.dart';
import '../widgets/compact_player_scores.dart';
import '../theme/balatro_theme.dart';
import '../services/game_analytics_logger.dart';
import '../widgets/advanced_meld_selector.dart';
import '../widgets/emergency_round_end_dialog.dart';
import '../widgets/scoreboard_modal.dart';
import 'main_menu_screen.dart';
import '../utils/debug_logger.dart';
import '../config/game_config.dart';
import '../services/analytics_batcher.dart';

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
  int _totalTurns = 0;
  int _actionSequenceNumber = 0; // Track action sequence within game

  // SIMPLIFIED: Single flag to prevent overlapping bot processing
  bool _isProcessingBotTurn = false;

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

  Future<void> _initializeGame() async {
    // If a gameController was provided (continuing saved game), use it
    if (widget.gameController != null) {
      _gameController = widget.gameController!;
      _botAI = EnhancedBotAI();

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
      _showRestoreGameDialog();
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
      _saveGameState().catchError((error) {
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
      if (!_validateGameState()) {
        DebugLogger.error('Game state invalid - attempting recovery');
        _attemptGameStateRecovery();
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
        _validateHumanPlayerState();
        // CRITICAL: Ensure we never auto-process human turns
        _isProcessingBotTurn = false; // Clear any stuck bot processing flag
        if (mounted) {
          setState(() {}); // Update UI to show it's human turn
          checkForRoundTransition();
        }
        return;
      }

      // Bot turn: Process with safety checks and delays
      if (!_isProcessingBotTurn) {
        // DOUBLE CHECK: Make absolutely sure this is a bot before processing
        if (currentPlayer.type != PlayerType.bot) {
          DebugLogger.error(
            'CRITICAL: Attempted to process non-bot player ${currentPlayer.name} as bot',
          );
          return;
        }
        DebugLogger.debug('Starting bot turn for ${currentPlayer.name}');
        _processBotTurnWithDelays(currentPlayer);
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

  /// SIMPLIFIED: Process bot turn iteratively to prevent stack overflow
  Future<void> _processBotTurn(Player botPlayer) async {
    if (_isProcessingBotTurn || _disposed || !mounted) return;

    _isProcessingBotTurn = true;

    try {
      // Process bot turn iteratively until turn ends or max iterations reached
      int maxIterations = 10; // Prevent infinite loops
      int iteration = 0;

      while (iteration < maxIterations) {
        iteration++;

        // Verify this is still the current player and it's still a bot
        final currentPlayer = _gameController.gameState.currentPlayer;
        if (currentPlayer.id != botPlayer.id ||
            currentPlayer.type != PlayerType.bot) {
          DebugLogger.debug('Bot processing ended - player changed or not bot');
          break;
        }

        bool actionSucceeded = false;

        // Try bot decision with retry mechanism
        for (int attempt = 0; attempt < 3 && !actionSucceeded; attempt++) {
          try {
            final decision = _botAI.makeDecision(botPlayer, _gameController);
            actionSucceeded = _executeBotDecision(decision, botPlayer);

            if (actionSucceeded) {
              DebugLogger.debug(
                'Bot ${botPlayer.name} executed ${decision.action}',
              );
              // Log the action for better visibility in UI
              _logBotActionForUser(botPlayer, decision);

              // Log bot decision for analytics with actual strategic reasoning
              final strategicReasoning = _generateBotReasoning(
                botPlayer,
                decision,
                _gameController.gameState,
              );
              _logBotDecision(
                botId: botPlayer.id,
                decision: decision.action,
                reasoning: strategicReasoning,
                context: decision.data != null
                    ? {'data': decision.data.toString()}
                    : null,
              );

              // Track turn completion for analytics
              if (decision.action == 'discard' ||
                  decision.action == 'endTurn') {
                _totalTurns++;
              }

              break;
            }
          } catch (e) {
            DebugLogger.warning(
              'Bot decision attempt ${attempt + 1} failed: $e',
            );
          }
        }

        if (!actionSucceeded) {
          // All attempts failed - force completion and exit loop
          DebugLogger.error(
            'Bot ${botPlayer.name} failed all attempts - forcing completion',
          );
          _forceCompleteBotTurn(botPlayer);
          break;
        }

        // Update UI state after successful action
        if (mounted) {
          setState(() {});
          checkForRoundTransition();
        }

        // Add delay after each bot action so users can see what happened
        await Future.delayed(const Duration(milliseconds: 1000));
        if (_disposed || !mounted) break;

        // Check if this bot still has the turn (multi-phase turn)
        final newCurrentPlayer = _gameController.gameState.currentPlayer;
        if (newCurrentPlayer.id != botPlayer.id ||
            newCurrentPlayer.type != PlayerType.bot) {
          // Turn has ended - bot completed their turn
          DebugLogger.debug('Bot ${botPlayer.name} completed turn');
          break;
        }

        // Check for round end
        if (_gameController.gameState.phase == GamePhase.roundEnd) {
          DebugLogger.debug('Round ended during bot turn');
          _handleRoundEnd();
          break;
        }
      }

      if (iteration >= maxIterations) {
        DebugLogger.error(
          'Bot ${botPlayer.name} exceeded max iterations - forcing completion',
        );
        _forceCompleteBotTurn(botPlayer);
      }
    } finally {
      _isProcessingBotTurn = false;
      // Continue processing next player if needed
      if (mounted && !_disposed) {
        // Small delay to ensure UI updates are processed
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_disposed) {
            // Continue processing if it's still a bot turn (same or different bot)
            // Only cancel if turn advanced to human player (prevents interference with manual advancement)
            final currentPlayer = _gameController.gameState.currentPlayer;

            // CRITICAL: Double-check we're not skipping the human player
            if (currentPlayer.type == PlayerType.human) {
              DebugLogger.debug('Human turn - waiting for input');
              // Ensure UI reflects human turn
              if (mounted) setState(() {});
            } else if (currentPlayer.type == PlayerType.bot) {
              // Only process bot turns
              processCurrentPlayerTurn();
            } else {
              DebugLogger.debug(
                'Bot ${botPlayer.name} turn callback cancelled - player changed to ${currentPlayer.name}',
              );
            }
          }
        });
      }
    }
  }

  /// Process bot turn with user-friendly delays between actions
  void _processBotTurnWithDelays(Player botPlayer) {
    // Use Future to handle async processing without blocking main method
    Future(() async {
      await _processBotTurn(botPlayer);
    }).catchError((error) {
      DebugLogger.error('Error in bot turn processing: $error');
      // Reset processing flag on error
      _isProcessingBotTurn = false;
      // Try to continue with next player
      if (mounted && !_disposed) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_disposed) {
            // Continue processing if it's still a bot turn (same or different bot)
            // Only cancel if turn advanced to human player (prevents interference with manual advancement)
            final currentPlayer = _gameController.gameState.currentPlayer;
            if (currentPlayer.type != PlayerType.human) {
              processCurrentPlayerTurn();
            } else {
              DebugLogger.debug(
                'Bot ${botPlayer.name} error callback cancelled - player changed to ${currentPlayer.name}',
              );
            }
          }
        });
      }
    });
  }

  /// Log bot action for better user visibility
  void _logBotActionForUser(Player botPlayer, BotDecision decision) {
    String actionDescription;

    switch (decision.action) {
      case 'drawFromDeck':
        actionDescription = '🎴 drew 2 cards from deck';
        break;
      case 'drawFromDiscard':
        actionDescription = '♻️ took discard pile';
        break;
      case 'createMeld':
        final cards = decision.data as List<PlayingCard>;
        final rank = cards.first.rank.name.toUpperCase();
        actionDescription = '📋 created ${cards.length}-card ${rank}s meld';
        break;
      case 'createMultipleMelds':
        final allMelds = decision.data as List<List<PlayingCard>>;
        actionDescription = '📋 created ${allMelds.length} melds';
        break;
      case 'addToMeld':
        final data = decision.data as Map<String, dynamic>;
        final card = data['card'] as PlayingCard;
        actionDescription = '➕ added ${card.compactName} to meld';
        break;
      case 'discard':
        final card = decision.data as PlayingCard;
        actionDescription = '🗑️ discarded ${card.compactName}';
        break;
      case 'noMeld':
        actionDescription = '⏭️ chose not to meld';
        break;
      case 'goOut':
        actionDescription = '🎉 went out and ended the round!';
        break;
      default:
        actionDescription = decision.action;
        break;
    }

    // Log to game state for UI display with explicit bot player name
    // Note: Can't use the direct logAction because it uses currentPlayer.name
    // and currentPlayer might have changed to the next player by now
    final gameState = _gameController.gameState;
    gameState.recentActions.add(
      GameAction(message: actionDescription, playerName: botPlayer.name),
    );

    // Keep only the last N actions to avoid memory issues
    if (gameState.recentActions.length > GameConfig.maxRecentActions) {
      gameState.recentActions.removeAt(0);
    }
  }

  /// Execute bot decision with comprehensive validation and state management
  bool _executeBotDecision(BotDecision decision, Player botPlayer) {
    try {
      // Validate bot is still current player
      final currentPlayer = _gameController.gameState.currentPlayer;
      if (currentPlayer.id != botPlayer.id ||
          currentPlayer.type != PlayerType.bot) {
        DebugLogger.warning(
          'Bot decision rejected - player changed during processing',
        );
        return false;
      }

      bool success = false;
      final gameState = _gameController.gameState;

      switch (decision.action) {
        case 'drawFromDeck':
          success = _gameController.drawFromDeck();
          if (!success && gameState.deck.isEmpty) {
            // Handle empty deck - end round early
            DebugLogger.debug('Deck empty during bot draw - ending round');
            gameState.endRound();
            return true;
          }
          break;

        case 'drawFromDiscard':
          success = _gameController.drawFromDiscardPile();
          if (!success) {
            // Fallback to deck draw
            DebugLogger.debug(
              'Bot fallback to deck draw after discard pile failure',
            );
            success = _gameController.drawFromDeck();
          }
          break;

        case 'createMeld':
          final cards = decision.data as List<PlayingCard>;
          success = _gameController.createMeld(cards);
          if (success) {
            _validateGameStateAfterMeld(botPlayer);
          }
          break;

        case 'createMultipleMelds':
          final allMelds = decision.data as List<List<PlayingCard>>;
          success = _executeMultipleMeldCreation(allMelds, botPlayer);
          if (success) {
            _validateGameStateAfterMeld(botPlayer);
          }
          break;

        case 'addToMeld':
          final data = decision.data as Map<String, dynamic>;
          final meldIndex = data['meldIndex'] as int;
          final card = data['card'] as PlayingCard;

          // Validate meld index
          if (meldIndex >= 0 && meldIndex < botPlayer.melds.length) {
            success = _gameController.addCardToMeld(meldIndex, card);
            if (success) {
              _validateGameStateAfterMeld(botPlayer);
            }
          }
          break;

        case 'discard':
          final card = decision.data as PlayingCard;
          success = _gameController.discardCard(card);
          if (success) {
            _handlePostDiscardState(botPlayer);
          }
          break;

        case 'noMeld':
          if (gameState.turnPhase == TurnPhase.meld) {
            gameState.turnPhase = TurnPhase.discard;
            success = true;
          }
          break;

        case 'endTurn':
          // Force turn completion if bot requests it
          success = true;
          break;

        case 'goOut':
          if (botPlayer.canGoOut) {
            gameState.endRound();
            success = true;
          } else {
            DebugLogger.warning(
              'Bot tried to go out but cannot - missing book requirements',
            );
            success = false;
          }
          break;

        case 'error':
          DebugLogger.warning('Bot reported error state');
          return false;

        default:
          DebugLogger.error('Unknown bot decision: ${decision.action}');
          return false;
      }

      if (success) {
        // Save game state after successful bot action (fire and forget)
        _saveGameState().catchError((error) {
          DebugLogger.error('Error saving game state: $error');
        });
      }

      return success;
    } catch (e) {
      DebugLogger.error('Error executing bot decision ${decision.action}: $e');
      return false;
    }
  }

  /// Execute multiple meld creation for bots with proper index handling
  bool _executeMultipleMeldCreation(
    List<List<PlayingCard>> allMelds,
    Player botPlayer,
  ) {
    try {
      // Convert cards to indices for the multi-meld system
      final allMeldIndices = <List<int>>[];
      final usedIndices = <int>{}; // Track used indices to handle duplicates

      for (final meld in allMelds) {
        final meldIndices = <int>[];
        for (final card in meld) {
          // Find the card using object identity, not indexOf which fails with duplicates
          int foundIndex = -1;
          for (int i = 0; i < botPlayer.currentHand.length; i++) {
            if (!usedIndices.contains(i) &&
                identical(botPlayer.currentHand[i], card)) {
              foundIndex = i;
              break;
            }
          }

          if (foundIndex >= 0) {
            meldIndices.add(foundIndex);
            usedIndices.add(foundIndex); // Mark this index as used
          }
        }
        if (meldIndices.isNotEmpty) {
          allMeldIndices.add(meldIndices);
        }
      }

      if (allMeldIndices.isNotEmpty) {
        return _gameController.createMultipleMeldsFromIndices(allMeldIndices);
      }

      return false;
    } catch (e) {
      DebugLogger.error('Error in multiple meld creation: $e');
      return false;
    }
  }

  /// Validate game state after meld creation
  void _validateGameStateAfterMeld(Player player) {
    // Check if player went out by melding their last cards
    if (player.currentHand.isEmpty) {
      if (!player.hasPickedUpFoot && player.foot.isNotEmpty) {
        // Transition to foot
        player.pickUpFoot();
        DebugLogger.debug('Bot ${player.name} picked up foot after melding');
      } else if (player.hasPickedUpFoot && player.canGoOut) {
        // Player went out
        _gameController.gameState.endRound();
        DebugLogger.debug('Bot ${player.name} went out by melding');
      }
    }
  }

  /// Handle state after discard action
  void _handlePostDiscardState(Player player) {
    // Check if player needs to pick up foot
    if (player.currentHand.isEmpty &&
        !player.hasPickedUpFoot &&
        player.foot.isNotEmpty) {
      player.pickUpFoot();
      DebugLogger.debug('Bot ${player.name} picked up foot after discard');
    }

    // Check if discard ended the round (player went out)
    if (player.hasPickedUpFoot &&
        player.currentHand.isEmpty &&
        player.canGoOut) {
      _gameController.gameState.endRound();
      DebugLogger.debug('Bot ${player.name} went out by discard');
    }
  }

  Future<void> _checkAndHandleRoundEnd() async {
    if (_gameController.gameState.phase == GamePhase.roundEnd) {
      await _handleRoundTransition();
    }
  }

  /// Check if round transition is needed and trigger it
  void checkForRoundTransition() {
    if (_gameController.gameState.phase == GamePhase.roundEnd && mounted) {
      DebugLogger.debug('Triggering round transition check');
      _handleRoundTransition().catchError((error) {
        DebugLogger.error('Error in round transition check: $error');
      });
    }
  }

  /// Handle complete round transition with proper state management
  Future<void> _handleRoundTransition() async {
    if (_gameController.gameState.phase != GamePhase.roundEnd) return;

    DebugLogger.debug('Handling round transition - calculating scores');

    // Brief pause to show scores
    await Future.delayed(const Duration(seconds: 2));
    if (_disposed || !mounted) return;

    // Check if game should end (someone reached winning score)
    final scores = _gameController.gameState.players
        .map((p) => p.score)
        .toList();
    final highestScore = scores.isEmpty
        ? 0
        : scores.reduce((a, b) => a > b ? a : b);

    if (highestScore >= 8500) {
      DebugLogger.debug(
        'Game end condition met - highest score: $highestScore',
      );
      _handleGameEnd();
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
        _saveGameState().catchError((error) {
          DebugLogger.error(
            'Error saving game state after round transition: $error',
          );
        });

        // Resume game flow
        processCurrentPlayerTurn();
      }
    } catch (e) {
      DebugLogger.error('Error during round transition: $e');
      _showErrorDialog('Error advancing to next round: ${e.toString()}');
    }
  }

  /// Handle immediate round end during bot processing
  void _handleRoundEnd() {
    if (_gameController.gameState.phase == GamePhase.roundEnd) {
      DebugLogger.debug('Immediate round end handling');
      // Don't advance immediately - let the UI show the round end state
      if (mounted) setState(() {});
    }
  }

  /// Handle game end when someone reaches winning score
  void _handleGameEnd() {
    final winner = _gameController.gameState.players.reduce(
      (a, b) => a.score > b.score ? a : b,
    );

    DebugLogger.debug(
      'Game ended - winner: ${winner.name} with ${winner.score} points',
    );

    // End analytics session tracking
    _endAnalyticsSession();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BalatroTheme.glowColor, width: 2),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.emoji_events,
              color: BalatroTheme.neonYellow,
              size: 32,
            ),
            const SizedBox(width: 12),
            Text(
              'GAME WINNER!',
              style: TextStyle(
                color: BalatroTheme.neonYellow,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: BalatroTheme.neonYellow.withValues(alpha: 0.8),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${winner.name} wins with ${winner.score} points!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Final Scores:',
              style: const TextStyle(
                color: BalatroTheme.neonPink,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ..._gameController.gameState.players.map(
              (player) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${player.name}: ${player.score}',
                  style: TextStyle(
                    color: player == winner
                        ? BalatroTheme.neonGreen
                        : Colors.white70,
                    fontWeight: player == winner
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startNewGame();
            },
            child: const Text(
              'New Game',
              style: TextStyle(color: BalatroTheme.neonGreen),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _returnToMainMenu();
            },
            child: const Text(
              'Main Menu',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }

  /// Force bot to complete their turn using fallback actions that follow game rules
  void _forceCompleteBotTurn(Player botPlayer) {
    final gameState = _gameController.gameState;

    DebugLogger.debug(
      'Force completing bot turn for ${botPlayer.name} in phase ${gameState.turnPhase}',
    );

    try {
      // Ensure we're still in a valid state
      if (gameState.phase == GamePhase.roundEnd) {
        DebugLogger.debug('Round already ended during force completion');
        return;
      }

      switch (gameState.turnPhase) {
        case TurnPhase.draw:
          // Bot must draw to continue or move to discard phase
          if (!gameState.hasDrawnFromDeck) {
            final drawn = _gameController.drawFromDeck();
            if (!drawn && gameState.deck.isEmpty) {
              // Deck is empty - end round
              DebugLogger.debug('Ending round due to empty deck');
              gameState.endRound();
              return;
            }
          }
          // Force to discard phase to complete turn
          gameState.turnPhase = TurnPhase.discard;
          _guaranteedTurnCompletion(botPlayer);
          break;

        case TurnPhase.meld:
          // Bot can skip melding - force to discard phase and GUARANTEE completion
          gameState.turnPhase = TurnPhase.discard;
          _absolutelyGuaranteedDiscard(botPlayer);
          break;

        case TurnPhase.discard:
          // ABSOLUTELY GUARANTEED turn completion - no more failures allowed
          _absolutelyGuaranteedDiscard(botPlayer);
          break;
      }
    } catch (e) {
      DebugLogger.error('Error in _forceCompleteBotTurn: $e');
      _absolutelyGuaranteedDiscard(botPlayer);
    }
  }

  /// ABSOLUTELY GUARANTEED bot turn completion - finds lowest point card and discards it
  /// This method CANNOT fail and will always advance the turn
  void _absolutelyGuaranteedDiscard(Player botPlayer) {
    DebugLogger.debug('ABSOLUTELY GUARANTEED DISCARD for ${botPlayer.name}');
    final gameState = _gameController.gameState;

    try {
      // STEP 1: Ensure discard phase
      gameState.turnPhase = TurnPhase.discard;

      // STEP 2: If bot has hand, find the lowest point card to minimize damage
      if (botPlayer.currentHand.isNotEmpty) {
        // Sort cards by point value (ascending) to find least valuable card
        final sortedCards = [...botPlayer.currentHand];
        sortedCards.sort((a, b) => a.pointValue.compareTo(b.pointValue));

        // Prioritize discarding 3s (penalty cards) if available
        final threes = sortedCards
            .where((c) => c.rank == CardRank.three)
            .toList();
        final cardToDiscard = threes.isNotEmpty
            ? threes.first
            : sortedCards.first;

        DebugLogger.debug(
          'Forcing discard of ${cardToDiscard.displayName} (${cardToDiscard.pointValue} pts)',
        );

        // MANUAL DISCARD - bypass all validation to guarantee success
        botPlayer.removeCardFromHand(cardToDiscard);
        gameState.discardPile.add(cardToDiscard);
        gameState.recentActions.add(
          GameAction(
            message: 'forced discard of ${cardToDiscard.displayName}',
            playerName: botPlayer.name,
          ),
        );

        // Check for foot pickup after discard
        if (botPlayer.isHandEmpty && !botPlayer.hasPickedUpFoot) {
          botPlayer.pickUpFoot();
          gameState.recentActions.add(
            GameAction(
              message: 'picked up foot after forced discard',
              playerName: botPlayer.name,
            ),
          );
        }

        // ADVANCE TURN - this is guaranteed to work
        gameState.nextPlayer();
        // Flush analytics on turn completion for better timing
        AnalyticsBatcher.flushOnTurnCompletion();
        setState(() {});
        return;
      }

      // STEP 3: No hand cards - pick up foot if possible
      if (botPlayer.isHandEmpty && !botPlayer.hasPickedUpFoot) {
        botPlayer.pickUpFoot();
        gameState.recentActions.add(
          GameAction(message: 'forced foot pickup', playerName: botPlayer.name),
        );

        // Now discard from foot using same logic
        if (botPlayer.currentHand.isNotEmpty) {
          final sortedCards = [...botPlayer.currentHand];
          sortedCards.sort((a, b) => a.pointValue.compareTo(b.pointValue));
          final cardToDiscard = sortedCards.first;

          botPlayer.removeCardFromHand(cardToDiscard);
          gameState.discardPile.add(cardToDiscard);
          gameState.recentActions.add(
            GameAction(
              message: 'forced discard from foot: ${cardToDiscard.displayName}',
              playerName: botPlayer.name,
            ),
          );
        }

        gameState.nextPlayer();
        setState(() {});
        return;
      }

      // STEP 4: ABSOLUTE LAST RESORT - create an emergency discard card
      DebugLogger.error(
        'CRITICAL: Creating emergency card for ${botPlayer.name}',
      );
      final emergencyCard = PlayingCard(suit: Suit.clubs, rank: CardRank.three);
      botPlayer.addCardsToHand([emergencyCard]);
      botPlayer.removeCardFromHand(emergencyCard);
      gameState.discardPile.add(emergencyCard);
      gameState.recentActions.add(
        GameAction(
          message: 'emergency card discard - turn completed',
          playerName: botPlayer.name,
        ),
      );

      gameState.nextPlayer();
      setState(() {});
    } catch (e) {
      DebugLogger.error('CRITICAL ERROR in _absolutelyGuaranteedDiscard: $e');
      // Even if everything fails, force advance turn to prevent infinite loops
      gameState.nextPlayer();
      setState(() {});
    }
  }

  /// Guaranteed ways to complete a bot turn (discard, foot pickup, or end round)
  void _guaranteedTurnCompletion(Player botPlayer) {
    // Option 1: Try to discard ANY card (break up pairs/trios if needed)
    if (botPlayer.currentHand.isNotEmpty) {
      // Try each card until one works (some might fail due to game state)
      for (final card in [...botPlayer.currentHand]) {
        if (_gameController.discardCard(card)) {
          // Use explicit bot name instead of currentPlayer to avoid race conditions
          _gameController.gameState.recentActions.add(
            GameAction(
              message: 'completed turn with discard',
              playerName: botPlayer.name,
            ),
          );
          return;
        }
      }
      // If controller failed for all cards, log it but continue to emergency
      _gameController.gameState.recentActions.add(
        GameAction(
          message:
              'all discard attempts failed - escalating to emergency completion',
          playerName: botPlayer.name,
        ),
      );
    }

    // Option 2: Pick up foot if hand is empty and foot available
    if (botPlayer.isHandEmpty && !botPlayer.hasPickedUpFoot) {
      botPlayer.pickUpFoot();
      _gameController.gameState.recentActions.add(
        GameAction(message: 'picked up foot pile', playerName: botPlayer.name),
      );
      // Now try to discard from foot - try every card
      if (botPlayer.currentHand.isNotEmpty) {
        for (final card in [...botPlayer.currentHand]) {
          if (_gameController.discardCard(card)) {
            return;
          }
        }
      }
    }

    // Option 3: Check if bot can go out (end round)
    if (botPlayer.canGoOut) {
      _gameController.gameState.recentActions.add(
        GameAction(
          message: 'went out and ended the round!',
          playerName: botPlayer.name,
        ),
      );
      _gameController.gameState.endRound();
      return;
    }

    // If all guaranteed methods failed, use emergency completion
    // This will manually force a discard to complete the turn
    _emergencyCompleteBotTurn(botPlayer);
  }

  /// Emergency bot turn completion when all else fails - NEVER skip turn
  void _emergencyCompleteBotTurn(Player botPlayer) {
    DebugLogger.warning('Emergency bot turn completion for ${botPlayer.name}');

    try {
      final gameState = _gameController.gameState;

      // STEP 1: Force to discard phase
      gameState.turnPhase = TurnPhase.discard;

      // STEP 2: If bot has hand, try every card through controller
      if (botPlayer.currentHand.isNotEmpty) {
        for (final card in [...botPlayer.currentHand]) {
          if (_gameController.discardCard(card)) {
            _gameController.gameState.recentActions.add(
              GameAction(
                message: 'emergency discard completed',
                playerName: botPlayer.name,
              ),
            );
            return;
          }
        }

        // STEP 3: Controller failed - manually discard (bypass validation)
        final cardToDiscard = botPlayer.currentHand.first;
        botPlayer.removeCardFromHand(cardToDiscard);
        gameState.discardPile.add(cardToDiscard);
        gameState.recentActions.add(
          GameAction(
            message: 'forced discard of ${cardToDiscard.displayName}',
            playerName: botPlayer.name,
          ),
        );

        // Check for foot pickup after manual discard
        if (botPlayer.isHandEmpty && !botPlayer.hasPickedUpFoot) {
          botPlayer.pickUpFoot();
          gameState.recentActions.add(
            GameAction(
              message: 'picked up foot after emergency discard',
              playerName: botPlayer.name,
            ),
          );
        }

        // Complete turn legally
        gameState.nextPlayer();
        setState(() {});
        // Don't call processCurrentPlayerTurn() - let delayed callbacks handle turn continuation
        return;
      }

      // STEP 4: No hand cards - try foot pickup
      if (botPlayer.isHandEmpty && !botPlayer.hasPickedUpFoot) {
        botPlayer.pickUpFoot();
        gameState.recentActions.add(
          GameAction(
            message: 'emergency foot pickup',
            playerName: botPlayer.name,
          ),
        );

        // Now discard from foot
        if (botPlayer.currentHand.isNotEmpty) {
          final cardToDiscard = botPlayer.currentHand.first;
          botPlayer.removeCardFromHand(cardToDiscard);
          gameState.discardPile.add(cardToDiscard);
          gameState.recentActions.add(
            GameAction(
              message: 'discarded ${cardToDiscard.displayName} from foot',
              playerName: botPlayer.name,
            ),
          );

          // Complete turn legally
          gameState.nextPlayer();
          setState(() {});
          // Don't call processCurrentPlayerTurn() - let delayed callbacks handle turn continuation
          return;
        }
      }

      // STEP 5: Check if bot can go out (end game)
      if (botPlayer.canGoOut) {
        gameState.recentActions.add(
          GameAction(
            message: 'went out and ended the round!',
            playerName: botPlayer.name,
          ),
        );
        gameState.endRound();
        return;
      }

      // STEP 6: ABSOLUTE LAST RESORT - create emergency card to discard
      // This ensures turn completion even in corrupted game states
      DebugLogger.error(
        'CRITICAL: Creating emergency discard for ${botPlayer.name}',
      );
      final emergencyCard = PlayingCard(suit: Suit.clubs, rank: CardRank.three);
      botPlayer.addCardsToHand([emergencyCard]);
      botPlayer.removeCardFromHand(emergencyCard);
      gameState.discardPile.add(emergencyCard);
      gameState.recentActions.add(
        GameAction(
          message: 'emergency card discard - turn completed',
          playerName: botPlayer.name,
        ),
      );

      // Complete turn legally
      gameState.nextPlayer();

      // Log who's turn it is next for debugging
      final nextPlayer = gameState.currentPlayer;
      DebugLogger.debug(
        'After emergency completion, next player is: ${nextPlayer.name} (${nextPlayer.type})',
      );

      setState(() {});
      // Don't call processCurrentPlayerTurn() - let delayed callbacks handle turn continuation
    } catch (e) {
      DebugLogger.error('Emergency completion failed: $e');
      // Even if everything fails, ensure state is updated
      setState(() {});
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

  Future<void> _saveGameState() async {
    try {
      await _gameController.saveGame();
    } catch (e) {
      print('Failed to save game state: $e');
    }
  }

  void _showRestoreGameDialog() {
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
        _showErrorDialog('Failed to load saved game. Starting new game.');
        _startFreshGame();
      }
    } catch (e) {
      _showErrorDialog('Error loading saved game: ${e.toString()}');
      _startFreshGame();
    }
  }

  void _showNewGameConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Game'),
        content: const Text(
          'Are you sure you want to start a new game? This will reset all progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startNewGame();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('New Game'),
          ),
        ],
      ),
    );
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
        _showEmergencyRoundEndDialog();
      } else {
        // Check if deck is empty or insufficient
        if (_gameController.gameState.deck.isEmpty) {
          _showErrorDialog(
            'Cannot draw from deck: The deck is empty!\n\n'
            'The round will continue until a player goes out or all players pass.',
          );
        } else if (_gameController.gameState.deck.size < 2) {
          _showErrorDialog(
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
      _showErrorDialog(
        'Select at least one card first before clicking on a meld.',
      );
      return;
    }

    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    if (meldIndex >= humanPlayer.melds.length) {
      _showErrorDialog('Invalid meld selected.');
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
      _showErrorDialog(
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

  void _showAdvancedMeldSelector() {
    // Force a UI refresh first to ensure we have the latest game state
    setState(() {});

    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    // Safety check: Ensure we're in the correct turn phase
    if (_gameController.gameState.turnPhase != TurnPhase.meld) {
      _showErrorDialog('You can only create melds during the meld phase.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdvancedMeldSelector(
        player: humanPlayer,
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
    final humanPlayer = _gameController.gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    // Safety check: Validate all indices are valid
    for (final indices in meldIndices) {
      if (indices.any((index) => index >= humanPlayer.currentHand.length)) {
        _showErrorDialog('Invalid card selection. Please try again.');
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
      await _checkAndHandleRoundEnd();

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
      _showErrorDialog(
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

            setState(() {});
            _selectedCardIndices.clear();
            await _checkAndHandleRoundEnd();

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

          _showErrorDialog(
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

        setState(() {});
        _selectedCardIndices.clear();
        await _checkAndHandleRoundEnd();

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
          _showErrorDialog(
            'Your hand is empty! Please pick up your foot pile to continue.',
          );
          return;
        }

        // If both hand and foot are empty, but requirements aren't met
        if (humanPlayer.hasPickedUpFoot &&
            humanPlayer.foot.isEmpty &&
            !humanPlayer.canGoOutWithBooks) {
          _showErrorDialog(
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
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

  void _showEmergencyRoundEndDialog() {
    EmergencyRoundEndDialog.show(
      context,
      onContinue: () {
        _gameController.nextRound();
        setState(() {});
      },
    );
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
      await _checkAndHandleRoundEnd();

      if (invalidCards.isNotEmpty) {
        final invalidNames = invalidCards.map((c) => c.displayName).join(', ');
        _showErrorDialog(
          'Added $addedCount cards to meld. Could not add: $invalidNames',
        );
      }
    } else {
      _showErrorDialog('Failed to add any cards to the meld.');
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
                showDialog(
                  context: context,
                  builder: (context) => ScoreboardModal(gameState: gameState),
                );
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
                    _showNewGameConfirmation();
                    break;
                  case 'copy_seed':
                    _copySeedToClipboard();
                    break;
                  case 'export_game':
                    _exportGameState();
                    break;
                  case 'load_game':
                    _showLoadGameDialog();
                    break;
                  case 'how_to_play':
                    _showHowToPlayDialog();
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
                        onPressed: () => _showAdvancedMeldSelector(),
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

  void _copySeedToClipboard() {
    final seed =
        _gameController.gameSeed?.toString() ?? 'No seed (legacy game)';
    Clipboard.setData(ClipboardData(text: seed));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Game seed copied to clipboard: $seed'),
        backgroundColor: BalatroTheme.neonGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _exportGameState() {
    final gameStateBase64 = _gameController.exportGameState();
    Clipboard.setData(ClipboardData(text: gameStateBase64));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Compact game save copied to clipboard'),
        backgroundColor: BalatroTheme.neonBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () {
            _showExportedGameDialog(gameStateBase64);
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showExportedGameDialog(String gameStateBase64) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        title: const Text(
          'Compact Game Save',
          style: TextStyle(color: BalatroTheme.neonPink),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This compact save uses an optimized format for easy sharing. Mobile/desktop versions use gzip compression for maximum size reduction.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.maxFinite,
              height: 300,
              child: SingleChildScrollView(
                child: SelectableText(
                  gameStateBase64,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: BalatroTheme.neonGreen),
            ),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: gameStateBase64));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Game state copied to clipboard'),
                  backgroundColor: BalatroTheme.neonGreen,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text(
              'Copy',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }

  void _showLoadGameDialog() {
    final TextEditingController textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        title: const Text(
          'Load Game Save',
          style: TextStyle(color: BalatroTheme.neonPink),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste your game save (supports all formats: ultra-compact, base64, or JSON):',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: textController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: BalatroTheme.neonBlue,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: BalatroTheme.neonBlue,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: BalatroTheme.glowColor,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: 'Paste game state JSON here...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: BalatroTheme.deepPurple,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      final clipboardData = await Clipboard.getData(
                        'text/plain',
                      );
                      if (clipboardData?.text != null) {
                        textController.text = clipboardData!.text!;
                      }
                    },
                    child: const Text(
                      'Paste from Clipboard',
                      style: TextStyle(color: BalatroTheme.neonYellow),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      textController.clear();
                    },
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: BalatroTheme.neonOrange),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: BalatroTheme.neonGreen),
            ),
          ),
          TextButton(
            onPressed: () {
              _loadGameFromJson(textController.text);
              Navigator.of(context).pop();
            },
            child: const Text(
              'Load Game',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }

  void _showHowToPlayDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        title: const Text(
          'How to Play Hand & Foot',
          style: TextStyle(color: BalatroTheme.neonPink),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '🎯 OBJECTIVE',
                  style: TextStyle(
                    color: BalatroTheme.neonGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Be the first player to "go out" by melding all cards in your hand and foot.',
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 16),

                Text(
                  '🃏 SETUP',
                  style: TextStyle(
                    color: BalatroTheme.neonGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '• Each player gets 11 cards for their "hand" and 11 for their "foot"\n'
                  '• You play your hand first, then pick up your foot when hand is empty\n'
                  '• Play-down requirements increase each round (60, 90, 120+ points)',
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 16),

                Text(
                  '📝 MELDS',
                  style: TextStyle(
                    color: BalatroTheme.neonGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '• Melds are sets of 3+ cards of the same rank\n'
                  '• 2s and Jokers are wild cards\n'
                  '• 3s cannot be melded and block the discard pile\n'
                  '• Only one meld per rank allowed\n'
                  '• Books (7+ cards) give bonus points:\n'
                  '  - Clean Book (no wilds): +500 points\n'
                  '  - Dirty Book (with wilds): +300 points\n'
                  '  - Wild Book (all wilds): +1000 points',
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 16),

                Text(
                  '🎮 GAMEPLAY',
                  style: TextStyle(
                    color: BalatroTheme.neonGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '1. DRAW: Take 2 cards from deck OR unlock discard pile\n'
                  '2. MELD: Play cards (first meld must meet point requirement)\n'
                  '3. DISCARD: End your turn by discarding one card\n\n'
                  '• To unlock discard pile: Need 2+ natural cards matching top card\n'
                  '• Must have already played down to unlock discard pile\n'
                  '• Going out requires one clean book AND one dirty book',
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 16),

                Text(
                  '🏆 WINNING',
                  style: TextStyle(
                    color: BalatroTheme.neonGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'First player to reach 8,500 points wins!\n'
                  'Going out gives +100 bonus points.',
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 16),

                Text(
                  '🤖 BOT PERSONALITIES',
                  style: TextStyle(
                    color: BalatroTheme.neonGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '🛡️ Conservative Bot:\n'
                  'The cautious strategist who holds up to 18 cards, rarely takes risks with the discard pile, and prefers to accumulate before making moves. Patient and methodical, this bot worries less about time pressure and focuses on safe, calculated plays.\n\n'
                  '⚡ Aggressive Bot:\n'
                  'The bold risk-taker who transitions to foot quickly (14 card limit), frequently unlocks discard piles, and makes rapid decisions. This bot feels time pressure more acutely and prefers immediate action over long-term planning.\n\n'
                  '📚 Book Builder Bot:\n'
                  'The point maximizer who specializes in completing 7+ card books for massive bonuses (500 clean, 300 dirty). Holds cards strategically in later rounds to complete books defensively when opponents might go out.\n\n'
                  '🎯 Adaptive Bot:\n'
                  'The balanced strategist who changes tactics based on game state and opponent behavior. Uses standard holding limits (16 cards) and adjusts aggression based on what others are doing.\n\n'
                  'Each bot has distinct decision-making patterns that create unique gameplay experiences!',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Got it!',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }

  void _loadGameFromJson(String inputText) {
    if (inputText.trim().isEmpty) {
      _showErrorDialog('Please paste a valid game save (Base64 or JSON).');
      return;
    }

    try {
      final newController = GameController.fromExportJson(inputText);
      if (newController == null) {
        _showErrorDialog(
          'Failed to load game save. The format may be invalid or corrupted.',
        );
        return;
      }

      setState(() {
        _gameController = newController;
        _botAI = EnhancedBotAI();

        // Assign consistent bot personalities based on player IDs
        _assignBotPersonalities();

        _selectedCardIndices.clear();
        _viewingPlayerMelds = null;
        _isInitialized = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Game loaded successfully! Seed: ${newController.gameSeed ?? "No seed"}',
          ),
          backgroundColor: BalatroTheme.neonGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 3),
        ),
      );

      // Process bot turns if needed
      processCurrentPlayerTurn();
    } catch (e) {
      _showErrorDialog('Error loading game: ${e.toString()}');
    }
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

  /// Validate game state integrity
  bool _validateGameState() {
    try {
      final gameState = _gameController.gameState;

      // Check basic game state validity
      if (gameState.players.isEmpty) {
        DebugLogger.error('No players in game state');
        return false;
      }

      if (gameState.currentPlayerIndex < 0 ||
          gameState.currentPlayerIndex >= gameState.players.length) {
        DebugLogger.error(
          'Invalid current player index: ${gameState.currentPlayerIndex}',
        );
        return false;
      }

      // Check deck state
      if (gameState.deck.isEmpty && gameState.phase != GamePhase.roundEnd) {
        DebugLogger.warning('Deck is empty but round not ended');
        // This is recoverable - end the round
        gameState.endRound();
      }

      // Check for impossible player states
      for (final player in gameState.players) {
        // Check if player might be trying to go out
        final hasCleanBook = player.melds.any(
          (meld) => meld.isClean && meld.isBook,
        );
        final hasDirtyBook = player.melds.any(
          (meld) => !meld.isClean && meld.isBook,
        );
        final canGoOut = hasCleanBook && hasDirtyBook;

        // When hasPickedUpFoot is true and both hand and foot are empty,
        // it could mean the player went out (valid) or there's an error
        if (player.hasPickedUpFoot &&
            player.foot.isEmpty &&
            player.hand.isEmpty) {
          // This is OK if:
          // 1. The round has ended (someone went out)
          // 2. This player can go out (has required books)
          if (gameState.phase != GamePhase.roundEnd && !canGoOut) {
            DebugLogger.error(
              'Player ${player.name} has no cards but cannot go out (needs clean AND dirty book)',
            );
            // Don't return false - let the game continue, they might need emergency discard
          }
        }

        // If not using foot yet, hand shouldn't be empty unless picking up foot
        if (!player.hasPickedUpFoot &&
            player.hand.isEmpty &&
            player.foot.isNotEmpty) {
          // This is actually fine - player is about to pick up foot
          // The pickUpFoot() method will be called when they play/discard next
        } else if (!player.hasPickedUpFoot &&
            player.hand.isEmpty &&
            player.foot.isEmpty &&
            gameState.phase != GamePhase.roundEnd) {
          DebugLogger.error(
            'Player ${player.name} has no cards in hand or foot and round hasn\'t ended',
          );
          return false;
        }
      }

      return true;
    } catch (e) {
      DebugLogger.error('Error validating game state: $e');
      return false;
    }
  }

  /// Attempt to recover from invalid game state
  void _attemptGameStateRecovery() {
    try {
      DebugLogger.debug('Attempting game state recovery');

      // Reset processing flags
      _isProcessingBotTurn = false;

      // Clear UI selections
      _selectedCardIndices.clear();

      // Try to restore from last saved state
      _restoreFromSavedState().catchError((error) {
        DebugLogger.error('Error restoring from saved state: $error');
      });
    } catch (e) {
      DebugLogger.error('Game state recovery failed: $e');
      _showCriticalErrorDialog(
        'Game state corrupted. Please restart the game.',
      );
    }
  }

  /// Validate human player state WITHOUT making automatic moves
  void _validateHumanPlayerState() {
    try {
      final humanPlayer = _gameController.gameState.players.firstWhere(
        (p) => p.type == PlayerType.human,
        orElse: () => throw StateError('No human player found'),
      );

      // ONLY VALIDATE - DO NOT MAKE AUTOMATIC MOVES FOR HUMANS
      // Just log potential issues for debugging
      if (humanPlayer.currentHand.isEmpty &&
          !humanPlayer.hasPickedUpFoot &&
          humanPlayer.foot.isNotEmpty) {
        DebugLogger.debug('Human player can pick up foot when ready');
      }

      if (humanPlayer.hasPickedUpFoot &&
          humanPlayer.currentHand.isEmpty &&
          humanPlayer.canGoOut) {
        DebugLogger.debug('Human player can go out when ready');
      }
    } catch (e) {
      DebugLogger.error('Error validating human player state: $e');
    }
  }

  /// Handle critical errors that require user intervention
  void _handleCriticalError(dynamic error) {
    DebugLogger.error('Critical error occurred: $error');

    // Stop all processing
    _isProcessingBotTurn = false;

    // Show error dialog with recovery options
    _showCriticalErrorDialog(
      'A critical error occurred: ${error.toString()}\n\n'
      'The game may be in an unstable state. What would you like to do?',
    );
  }

  /// Show critical error dialog with recovery options
  void _showCriticalErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.red, width: 2),
        ),
        title: Row(
          children: const [
            Icon(Icons.error, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text(
              'Critical Error',
              style: TextStyle(
                color: Colors.red,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _attemptGameRecovery();
            },
            child: const Text(
              'Try Recovery',
              style: TextStyle(color: BalatroTheme.neonYellow),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startNewGame();
            },
            child: const Text(
              'New Game',
              style: TextStyle(color: BalatroTheme.neonGreen),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _returnToMainMenu();
            },
            child: const Text(
              'Main Menu',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }

  /// Attempt to recover the game from a critical error
  void _attemptGameRecovery() {
    try {
      DebugLogger.debug('Attempting critical game recovery');

      // Reset all processing flags
      _isProcessingBotTurn = false;

      // Clear UI state
      _selectedCardIndices.clear();
      _viewingPlayerMelds = null;

      // Try to restore a valid game state
      _restoreFromSavedState().catchError((error) {
        DebugLogger.error('Error in critical recovery: $error');
      });

      // Force UI refresh
      if (mounted) {
        setState(() {});

        // Resume game processing
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) processCurrentPlayerTurn();
        });
      }
    } catch (e) {
      DebugLogger.error('Critical recovery failed: $e');
      _showErrorDialog(
        'Recovery failed. Please start a new game or return to main menu.',
      );
    }
  }

  /// Restore game from saved state as fallback
  Future<void> _restoreFromSavedState() async {
    try {
      final hasSaved = await GameController.hasSavedGame();
      if (hasSaved) {
        final savedController = await GameController.loadSavedGame();
        if (savedController != null) {
          DebugLogger.debug('Restored game from saved state');
          _gameController = savedController;
          _botAI = EnhancedBotAI();
          _assignBotPersonalities();

          if (mounted) setState(() {});
          return;
        }
      }

      DebugLogger.warning('No saved state available for recovery');
    } catch (e) {
      DebugLogger.error('Error restoring from saved state: $e');
    }
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

  /// End analytics session tracking
  Future<void> _endAnalyticsSession() async {
    if (_analyticsSessionId == null) return;

    try {
      final winner = _gameController.gameState.winner;
      final botPersonalities = <String, BotPersonality>{};
      for (final player in _gameController.gameState.players) {
        if (player.type == PlayerType.bot) {
          botPersonalities[player.id] = _botAI.personalityManager
              .getPersonality(player.id);
        }
      }

      await GameAnalyticsLogger.endGameSession(
        gameState: _gameController.gameState,
        winnerId: winner?.id,
        totalTurns: _totalTurns,
        botPersonalities: botPersonalities,
      );

      DebugLogger.debug('Ended analytics session: $_analyticsSessionId');
      _analyticsSessionId = null;
    } catch (e) {
      DebugLogger.warning('Failed to end analytics session: $e');
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

  /// Generate strategic reasoning for bot decisions (for analytics)
  String _generateBotReasoning(
    Player bot,
    BotDecision decision,
    GameState gameState,
  ) {
    final personality = _botAI.personalityManager.getPersonality(bot.id);
    final handSize = bot.currentHand.length;
    final hasBooks = bot.melds.where((m) => m.cards.length >= 7).length;

    switch (decision.action) {
      case 'drawFromDeck':
        if (!bot.hasPlayedDown) {
          return '$personality bot drawing from deck to build hand for play-down ($handSize cards)';
        } else if (!bot.hasPickedUpFoot) {
          return '$personality bot drawing from deck while building toward foot transition';
        } else {
          return '$personality bot drawing from deck in foot phase ($handSize cards, $hasBooks books)';
        }

      case 'drawFromDiscard':
        return '$personality bot taking discard pile (${gameState.discardPile.length} cards) for strategic advantage';

      case 'createMeld':
        if (!bot.hasPlayedDown) {
          return '$personality bot creating initial meld to play down (Round ${gameState.round})';
        } else {
          return '$personality bot creating new meld to build toward books (${bot.melds.length + 1} total melds)';
        }

      case 'createMultipleMelds':
        return '$personality bot creating multiple melds for explosive play-down (Round ${gameState.round})';

      case 'addToMeld':
        final data = decision.data as Map<String, dynamic>?;
        final card = data?['card'];
        return '$personality bot adding ${card?.toString() ?? 'card'} to existing meld (building toward book)';

      case 'discard':
        final card = decision.data;
        if (handSize <= 3) {
          return '$personality bot discarding ${card?.toString() ?? 'card'} while positioning for end-game';
        } else {
          return '$personality bot discarding ${card?.toString() ?? 'card'} (${handSize - 1} cards remaining)';
        }

      case 'goOut':
        return '$personality bot going out with $hasBooks books to win the round!';

      case 'noMeld':
        if (!bot.hasPlayedDown) {
          return '$personality bot waiting for better play-down opportunity ($handSize cards)';
        } else {
          return '$personality bot holding cards strategically ($handSize cards, $hasBooks books)';
        }

      default:
        return '$personality bot executing ${decision.action} strategy';
    }
  }
}
