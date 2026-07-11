import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../models/player.dart';
import '../../models/card.dart';
import '../../models/game_state.dart';
import '../../game/game_controller.dart';
import '../../ai/enhanced_bot_ai.dart';
import '../../ai/bot_decision.dart';
import '../../ai/bot_personality.dart';
import '../../config/bot_configurations.dart';
import '../../utils/debug_logger.dart';
import '../../config/game_config.dart';
import '../../services/analytics_batcher.dart';

/// Manages all bot-related functionality for the game screen.
///
/// This class handles bot turn processing, personality management,
/// decision execution, and emergency completion scenarios.
/// Extracted from GameScreen to improve code organization and testability.
class BotTurnManager {
  final GameController gameController;
  final EnhancedBotAI botAI;
  final Function() onStateChanged;
  final Function(String) logHumanAction;
  final Function({
    required String botId,
    required String decision,
    required String reasoning,
    Map<String, dynamic>? context,
  })
  logBotDecision;

  bool _isProcessingBotTurn = false;

  BotTurnManager({
    required this.gameController,
    required this.botAI,
    required this.onStateChanged,
    required this.logHumanAction,
    required this.logBotDecision,
  });

  /// End the round when a bot goes out, publishing events for UI transition.
  void endRoundForBot(Player botPlayer, {String? actionMessage}) {
    final gameState = gameController.gameState;
    if (gameState.phase == GamePhase.roundEnd ||
        gameState.phase == GamePhase.gameEnd) {
      return;
    }

    if (actionMessage != null) {
      gameState.recentActions.add(
        GameAction(message: actionMessage, playerName: botPlayer.name),
      );
    }

    gameController.endRoundForPlayer(botPlayer);
    onStateChanged();
  }

  /// Helper method to assign bot personalities consistently
  void assignBotPersonalities() {
    final botPlayers = gameController.gameState.players
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
        botAI.assignPersonality(bot.id, predefinedPersonality);
      } else {
        // Fallback to random assignment for unknown bot names
        final personalities = BotPersonality.values;
        final randomPersonality =
            personalities[(bot.id.hashCode % personalities.length)];
        botAI.assignPersonality(bot.id, randomPersonality);
      }
    }

    // Log personality assignments in debug mode
    if (kDebugMode) {
      for (final bot in botPlayers) {
        final personality = botAI.personalityManager.getPersonality(bot.id);
        print('Bot ${bot.name} (${bot.id}) assigned personality: $personality');
      }
    }
  }

  /// Restore bot personalities from imported save data
  void restoreBotPersonalities(Map<String, String> savedPersonalities) {
    // Clear any existing assignments
    botAI.personalityManager.clearPersonalityData();

    final botPlayers = gameController.gameState.players
        .where((p) => p.type == PlayerType.bot)
        .toList();

    for (final bot in botPlayers) {
      final savedPersonalityName = savedPersonalities[bot.id];
      if (savedPersonalityName != null) {
        // Parse saved personality name back to enum
        final personality = BotPersonality.values.firstWhere(
          (p) => p.toString() == savedPersonalityName,
          orElse: () => BotPersonality.adaptive, // Fallback to adaptive
        );
        botAI.assignPersonality(bot.id, personality);

        if (kDebugMode) {
          print(
            'Bot ${bot.name} (${bot.id}) restored personality: $personality',
          );
        }
      } else {
        // If no saved personality for this bot, assign a random one
        final randomPersonality = BotPersonality
            .values[Random().nextInt(BotPersonality.values.length)];
        botAI.assignPersonality(bot.id, randomPersonality);

        if (kDebugMode) {
          print(
            'Bot ${bot.name} (${bot.id}) assigned new personality: $randomPersonality (no saved data)',
          );
        }
      }
    }
  }

  /// Process bot turn with user-friendly delays between actions
  Future<void> processBotTurnWithDelays(Player botPlayer) async {
    try {
      await processBotTurn(botPlayer);
    } catch (error) {
      DebugLogger.error('Error in bot turn processing: $error');
      // Reset processing flag on error
      _isProcessingBotTurn = false;
      rethrow;
    }
  }

  // Configurable delays for bot turn phases (in milliseconds)
  static const int _phaseDelayMs =
      1500; // Delay after each phase (draw, meld, discard)
  static const int _actionDelayMs = 800; // Delay between actions within a phase
  static const int _turnStartDelayMs = 500; // Brief delay when bot turn starts

  /// SIMPLIFIED: Process bot turn iteratively to prevent stack overflow
  Future<void> processBotTurn(Player botPlayer) async {
    if (_isProcessingBotTurn) {
      return;
    }

    final initialPhase = gameController.gameState.phase;
    if (initialPhase == GamePhase.roundEnd ||
        initialPhase == GamePhase.gameEnd) {
      DebugLogger.debug(
        'Skipping bot turn for ${botPlayer.name} - round/game already ended',
      );
      return;
    }

    _isProcessingBotTurn = true;

    try {
      // Brief delay at start of bot turn so user sees the transition
      await Future.delayed(const Duration(milliseconds: _turnStartDelayMs));
      onStateChanged(); // Show "Waiting for X to draw..."

      // Process bot turn iteratively until turn ends or max iterations reached
      int maxIterations = 15; // Increased to allow for longer meld phases
      int iteration = 0;
      TurnPhase? lastPhase;

      while (iteration < maxIterations) {
        iteration++;

        // Verify this is still the current player and it's still a bot
        final currentPlayer = gameController.gameState.currentPlayer;
        if (currentPlayer.id != botPlayer.id ||
            currentPlayer.type != PlayerType.bot) {
          DebugLogger.debug('Bot processing ended - player changed or not bot');
          break;
        }

        // Track phase changes to add appropriate delays
        final currentPhase = gameController.gameState.turnPhase;
        final phaseChanged = lastPhase != null && lastPhase != currentPhase;
        lastPhase = currentPhase;

        // Add longer delay when transitioning between phases
        if (phaseChanged) {
          onStateChanged(); // Update UI to show new phase
          await Future.delayed(const Duration(milliseconds: _phaseDelayMs));
        }

        bool actionSucceeded = false;

        // Try bot decision with retry mechanism
        for (int attempt = 0; attempt < 3 && !actionSucceeded; attempt++) {
          try {
            final decision = botAI.makeDecision(botPlayer, gameController);
            actionSucceeded = executeBotDecision(decision, botPlayer);

            if (actionSucceeded) {
              DebugLogger.debug(
                'Bot ${botPlayer.name} executed ${decision.action}',
              );

              // Log the action for better visibility in UI
              logBotActionForUser(botPlayer, decision);

              // Log bot decision for analytics with actual strategic reasoning
              final strategicReasoning = generateBotReasoning(
                botPlayer,
                decision,
                gameController.gameState,
              );

              logBotDecision(
                botId: botPlayer.id,
                decision: decision.action,
                reasoning: strategicReasoning,
                context: decision.data != null
                    ? {'data': decision.data.toString()}
                    : null,
              );
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
          forceCompleteBotTurn(botPlayer);
          break;
        }

        // Update UI state after successful action
        onStateChanged();

        // Add delay after each bot action so users can see what happened
        // Use shorter delay for actions within meld phase, longer for phase transitions
        final delayMs = gameController.gameState.turnPhase == TurnPhase.meld
            ? _actionDelayMs
            : _phaseDelayMs;
        await Future.delayed(Duration(milliseconds: delayMs));

        // Check if this bot still has the turn (multi-phase turn)
        final newCurrentPlayer = gameController.gameState.currentPlayer;
        if (newCurrentPlayer.id != botPlayer.id ||
            newCurrentPlayer.type != PlayerType.bot) {
          // Turn has ended - bot completed their turn
          DebugLogger.debug('Bot ${botPlayer.name} completed turn');
          // Final update and pause so user sees the completed turn
          onStateChanged();
          await Future.delayed(const Duration(milliseconds: _phaseDelayMs));
          break;
        }

        // Check for round end
        if (gameController.gameState.phase == GamePhase.roundEnd) {
          DebugLogger.debug('Round ended during bot turn');
          onStateChanged();
          await Future.delayed(const Duration(milliseconds: _phaseDelayMs));
          break;
        }
      }

      if (iteration >= maxIterations) {
        DebugLogger.error(
          'Bot ${botPlayer.name} exceeded max iterations - forcing completion',
        );
        forceCompleteBotTurn(botPlayer);
      }
    } finally {
      _isProcessingBotTurn = false;
    }
  }

  /// Execute bot decision with comprehensive validation and state management
  bool executeBotDecision(BotDecision decision, Player botPlayer) {
    try {
      // Validate bot is still current player
      final currentPlayer = gameController.gameState.currentPlayer;
      if (currentPlayer.id != botPlayer.id ||
          currentPlayer.type != PlayerType.bot) {
        DebugLogger.warning(
          'Bot decision rejected - player changed during processing',
        );
        return false;
      }

      bool success = false;
      final gameState = gameController.gameState;

      switch (decision.action) {
        case 'drawFromDeck':
          success = gameController.drawFromDeck();
          if (!success && gameState.deck.isEmpty) {
            // Handle empty deck - end round early
            DebugLogger.debug('Deck empty during bot draw - ending round');
            endRoundForBot(botPlayer);
            return true;
          }
          break;

        case 'drawFromDiscard':
          success = gameController.drawFromDiscardPile();
          if (!success) {
            // Fallback to deck draw
            DebugLogger.debug(
              'Bot fallback to deck draw after discard pile failure',
            );
            success = gameController.drawFromDeck();
          }
          break;

        case 'unlockDiscardPile':
          success = gameController.unlockDiscardPile();
          if (!success && gameState.canUnlockDiscard()) {
            success = gameController.drawFromDiscardPile();
          }
          if (!success) {
            DebugLogger.debug(
              'Bot unlockDiscardPile failed - falling back to deck draw',
            );
            success = gameController.drawFromDeck();
          }
          break;

        case 'createMeld':
          final cards = decision.data as List<PlayingCard>;
          success = gameController.createMeld(cards);
          if (success) {
            validateGameStateAfterMeld(botPlayer);
          }
          break;

        case 'createMultipleMelds':
          final allMelds = decision.data as List<List<PlayingCard>>;
          success = executeMultipleMeldCreation(allMelds, botPlayer);
          if (success) {
            validateGameStateAfterMeld(botPlayer);
          }
          break;

        case 'addToMeld':
          final data = decision.data as Map<String, dynamic>;
          final meldIndex = data['meldIndex'] as int;
          final card = data['card'] as PlayingCard;
          final handCard = botPlayer.findHandCardInstance(card);
          // Validate meld index
          if (meldIndex >= 0 &&
              meldIndex < botPlayer.melds.length &&
              handCard != null) {
            success = gameController.addCardToMeld(meldIndex, handCard);
            if (success) {
              validateGameStateAfterMeld(botPlayer);
            }
          }
          break;

        case 'discard':
          final card = decision.data as PlayingCard;
          final handCard = botPlayer.findHandCardInstance(card);
          if (handCard != null) {
            success = gameController.discardCard(handCard);
            if (success) {
              handlePostDiscardState(botPlayer);
            }
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
          DebugLogger.debug(
            'Bot ${botPlayer.name} requesting emergency turn end',
          );
          _completeTurnAndNotify(botPlayer);
          success = true;
          break;

        case 'goOut':
          if (botPlayer.canGoOut) {
            endRoundForBot(
              botPlayer,
              actionMessage: '🎉 went out and ended the round!',
            );
            success = true;
          } else if (botPlayer.canGoOutWithBooks &&
              botPlayer.currentHand.length == 1) {
            final lastCard = botPlayer.currentHand.first;
            success = gameController.discardCard(lastCard);
            if (success) {
              handlePostDiscardState(botPlayer);
            }
          } else {
            DebugLogger.warning(
              'Bot tried to go out but cannot - missing book requirements',
            );
            success = false;
          }
          break;

        case 'error':
          DebugLogger.warning(
            'Bot reported error state - attempting turn recovery',
          );
          _recoverFromBotError(botPlayer);
          return true;

        default:
          DebugLogger.error('Unknown bot decision: ${decision.action}');
          return false;
      }

      return success;
    } catch (e) {
      DebugLogger.error('Error executing bot decision ${decision.action}: $e');
      return false;
    }
  }

  /// Execute multiple meld creation for bots with proper index handling
  bool executeMultipleMeldCreation(
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
        return gameController.createMultipleMeldsFromIndices(allMeldIndices);
      }

      return false;
    } catch (e) {
      DebugLogger.error('Error in multiple meld creation: $e');
      return false;
    }
  }

  /// Validate game state after meld creation
  void validateGameStateAfterMeld(Player player) {
    // Check if player went out by melding their last cards
    if (player.currentHand.isEmpty) {
      if (!player.hasPickedUpFoot && player.foot.isNotEmpty) {
        // Transition to foot
        player.pickUpFoot();
        DebugLogger.debug('Bot ${player.name} picked up foot after melding');
      } else if (player.hasPickedUpFoot && player.canGoOut) {
        // Player went out
        endRoundForBot(player);
        DebugLogger.debug('Bot ${player.name} went out by melding');
      }
    }
  }

  void _completeTurnAndNotify(Player previousPlayer) {
    gameController.advanceTurnAfterAction(previousPlayer);
    AnalyticsBatcher.flushOnTurnCompletion();
    onStateChanged();
  }

  void _finishForcedDiscard(Player botPlayer) {
    final turnAdvanced = handlePostDiscardState(botPlayer);
    if (!turnAdvanced) {
      _completeTurnAndNotify(botPlayer);
    } else {
      onStateChanged();
    }
  }

  /// Handle state after discard action.
  ///
  /// Returns true when play was already advanced (go-out handled or turn changed).
  bool handlePostDiscardState(Player player) {
    final gameState = gameController.gameState;

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
      if (gameState.phase == GamePhase.roundEnd ||
          gameState.phase == GamePhase.gameEnd ||
          gameState.currentPlayer.id != player.id) {
        return true;
      }

      endRoundForBot(player);
      DebugLogger.debug('Bot ${player.name} went out by discard');
      return true;
    }

    return false;
  }

  /// Attempt a meld during forced turn completion to shrink hand toward foot.
  bool tryForceMeld(Player botPlayer) {
    if (!botPlayer.hasPlayedDown) {
      return false;
    }

    for (int i = 0; i < botPlayer.melds.length; i++) {
      for (final card in [...botPlayer.currentHand]) {
        if (botPlayer.melds[i].canAddCard(card)) {
          if (gameController.addCardToMeld(i, card)) {
            validateGameStateAfterMeld(botPlayer);
            return true;
          }
        }
      }
    }

    final possibleMelds = gameController.findPossibleMelds(botPlayer)
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final meld in possibleMelds) {
      if (gameController.createMeld(meld)) {
        validateGameStateAfterMeld(botPlayer);
        return true;
      }
    }

    return false;
  }

  /// Recover from bot error decisions without counting as failed attempts.
  void _recoverFromBotError(Player botPlayer) {
    final gameState = gameController.gameState;

    if (gameState.phase == GamePhase.roundEnd) {
      return;
    }

    if (botPlayer.currentHand.isEmpty) {
      if (!botPlayer.hasPickedUpFoot && botPlayer.foot.isNotEmpty) {
        botPlayer.pickUpFoot();
        gameState.recentActions.add(
          GameAction(
            message: 'picked up foot after error recovery',
            playerName: botPlayer.name,
          ),
        );
      }
      if (botPlayer.canGoOut) {
        endRoundForBot(botPlayer);
        onStateChanged();
        return;
      }
    }

    switch (gameState.turnPhase) {
      case TurnPhase.draw:
        if (!gameState.hasDrawnFromDeck) {
          gameController.drawFromDeck();
        }
        if (gameState.turnPhase == TurnPhase.meld) {
          tryForceMeld(botPlayer);
        }
        gameState.turnPhase = TurnPhase.discard;
        absolutelyGuaranteedDiscard(botPlayer);
        break;
      case TurnPhase.meld:
        tryForceMeld(botPlayer);
        gameState.turnPhase = TurnPhase.discard;
        absolutelyGuaranteedDiscard(botPlayer);
        break;
      case TurnPhase.discard:
        absolutelyGuaranteedDiscard(botPlayer);
        break;
    }
  }

  /// Force bot to complete their turn using fallback actions that follow game rules
  void forceCompleteBotTurn(Player botPlayer) {
    final gameState = gameController.gameState;

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
            final drawn = gameController.drawFromDeck();
            if (!drawn && gameState.deck.isEmpty) {
              // Deck is empty - end round
              DebugLogger.debug('Ending round due to empty deck');
              endRoundForBot(botPlayer);
              return;
            }
          }
          if (gameState.turnPhase == TurnPhase.meld) {
            tryForceMeld(botPlayer);
          }
          // Force to discard phase to complete turn
          gameState.turnPhase = TurnPhase.discard;
          guaranteedTurnCompletion(botPlayer);
          break;

        case TurnPhase.meld:
          // Try melding before force-discarding to shrink hand toward foot
          tryForceMeld(botPlayer);
          // Bot can skip melding - force to discard phase and GUARANTEE completion
          gameState.turnPhase = TurnPhase.discard;
          absolutelyGuaranteedDiscard(botPlayer);
          break;

        case TurnPhase.discard:
          // ABSOLUTELY GUARANTEED turn completion - no more failures allowed
          absolutelyGuaranteedDiscard(botPlayer);
          break;
      }
    } catch (e) {
      DebugLogger.error('Error in forceCompleteBotTurn: $e');
      absolutelyGuaranteedDiscard(botPlayer);
    }
  }

  /// ABSOLUTELY GUARANTEED bot turn completion - finds lowest point card and discards it
  /// This method CANNOT fail and will always advance the turn
  void absolutelyGuaranteedDiscard(Player botPlayer) {
    DebugLogger.debug('ABSOLUTELY GUARANTEED DISCARD for ${botPlayer.name}');
    final gameState = gameController.gameState;

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

        // BYPASS normal discard validation - manually execute
        botPlayer.removeCardFromHand(cardToDiscard);
        gameState.discardPile.add(cardToDiscard);
        gameState.recentActions.add(
          GameAction(
            message: 'forced discard of ${cardToDiscard.displayName}',
            playerName: botPlayer.name,
          ),
        );

        // Check for foot pickup after discard
        _finishForcedDiscard(botPlayer);
        return;
      }

      // STEP 2b: Check if bot needs to pick up foot first
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

        _finishForcedDiscard(botPlayer);
        return;
      }

      // STEP 3: Handle empty hand/foot scenario properly
      if (botPlayer.currentHand.isEmpty) {
        if (botPlayer.canGoOut) {
          // Bot should go out instead of discarding
          DebugLogger.debug(
            'Bot ${botPlayer.name} forcing go out - empty hand with required books',
          );
          endRoundForBot(
            botPlayer,
            actionMessage: '🎉 went out and ended the round!',
          );
          return;
        } else {
          // Bot has empty hand but can't go out - this is a critical game logic error
          DebugLogger.error(
            'CRITICAL: Bot ${botPlayer.name} has empty hand but cannot go out!',
          );
          DebugLogger.error('  - On foot: ${botPlayer.hasPickedUpFoot}');
          DebugLogger.error('  - Has clean book: ${botPlayer.hasCleanBook}');
          DebugLogger.error('  - Has dirty book: ${botPlayer.hasDirtyBook}');
          DebugLogger.error(
            '  - This indicates a serious bug in meld planning logic',
          );

          // Force advance turn to prevent infinite loop
          _completeTurnAndNotify(botPlayer);
          onStateChanged();
          return;
        }
      }

      _completeTurnAndNotify(botPlayer);
      onStateChanged();
    } catch (e) {
      DebugLogger.error('CRITICAL ERROR in absolutelyGuaranteedDiscard: $e');
      // Even if everything fails, force advance turn to prevent infinite loops
      _completeTurnAndNotify(botPlayer);
      onStateChanged();
    }
  }

  /// Guaranteed turn completion that tries multiple strategies to complete the turn
  void guaranteedTurnCompletion(Player botPlayer) {
    final playerName = botPlayer.name;

    // Option 1: Try discarding every card using controller validation
    if (botPlayer.currentHand.isNotEmpty) {
      // Try each card until one works (some might fail due to game state)
      for (final card in [...botPlayer.currentHand]) {
        if (gameController.discardCard(card)) {
          // Use captured player name to avoid race conditions after turn advancement
          gameController.gameState.recentActions.add(
            GameAction(
              message: 'completed turn with discard',
              playerName: playerName,
            ),
          );
          return;
        }
      }
      // If controller failed for all cards, log it but continue to emergency
      gameController.gameState.recentActions.add(
        GameAction(
          message:
              'all discard attempts failed - escalating to emergency completion',
          playerName: playerName,
        ),
      );
    }

    // Option 2: Pick up foot if hand is empty and foot available
    if (botPlayer.isHandEmpty && !botPlayer.hasPickedUpFoot) {
      botPlayer.pickUpFoot();
      gameController.gameState.recentActions.add(
        GameAction(message: 'picked up foot pile', playerName: playerName),
      );
      // Now try to discard from foot - try every card
      if (botPlayer.currentHand.isNotEmpty) {
        for (final card in [...botPlayer.currentHand]) {
          if (gameController.discardCard(card)) {
            return;
          }
        }
      }
    }

    // Option 3: Check if bot can go out (end round)
    if (botPlayer.canGoOut) {
      endRoundForBot(
        botPlayer,
        actionMessage: '🎉 went out and ended the round!',
      );
      return;
    }

    // If all guaranteed methods failed, use emergency completion
    // This will manually force a discard to complete the turn
    emergencyCompleteBotTurn(botPlayer);
  }

  /// EMERGENCY: Complete bot turn when all normal methods fail
  void emergencyCompleteBotTurn(Player botPlayer) {
    final gameState = gameController.gameState;
    DebugLogger.debug('EMERGENCY completion for ${botPlayer.name}');

    try {
      // STEP 1: Try controller discard one more time on all cards
      if (botPlayer.currentHand.isNotEmpty) {
        for (final card in [...botPlayer.currentHand]) {
          if (gameController.discardCard(card)) {
            gameController.gameState.recentActions.add(
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

        _finishForcedDiscard(botPlayer);
        return;
      }

      // STEP 4: Check if bot needs foot pickup before anything else
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

          _finishForcedDiscard(botPlayer);
          return;
        }
      }

      // Empty hand/foot with books already satisfied — go out without discarding.
      if (botPlayer.currentHand.isEmpty && botPlayer.canGoOut) {
        endRoundForBot(
          botPlayer,
          actionMessage: '🎉 went out and ended the round!',
        );
        return;
      }

      // STEP 6: ABSOLUTE LAST RESORT - no cards available
      DebugLogger.error(
        'ABSOLUTE LAST RESORT: No cards available, cannot force discard',
      );
      DebugLogger.error(
        'Bot ${botPlayer.name} has no cards in hand or foot - advancing turn',
      );

      gameState.recentActions.add(
        GameAction(
          message: 'emergency state recovery - skipped discard',
          playerName: botPlayer.name,
        ),
      );

      // Complete turn without polluting discard pile with synthetic cards
      _completeTurnAndNotify(botPlayer);
      onStateChanged();
    } catch (e) {
      DebugLogger.error('CRITICAL ERROR in emergencyCompleteBotTurn: $e');
      // Even if everything fails, force advance turn to prevent infinite loops
      _completeTurnAndNotify(botPlayer);
      onStateChanged();
    }
  }

  /// Log bot action for better user visibility (only for actions not logged by game state)
  void logBotActionForUser(Player botPlayer, BotDecision decision) {
    String? actionDescription;
    switch (decision.action) {
      // Skip actions already logged by game state to prevent duplicates
      case 'drawFromDeck':
      case 'drawFromDiscard':
      case 'createMeld':
      case 'createMultipleMelds':
      case 'addToMeld':
        return; // Don't log duplicate actions
      case 'noMeld':
        actionDescription = '⏭️ chose not to meld';
        break;
      case 'goOut':
        actionDescription = '🎉 went out and ended the round!';
        break;
      // Skip 'discard' - already logged by game state to prevent duplicates
      case 'discard':
        return; // Don't log duplicate discard actions
      default:
        actionDescription = decision.action;
        break;
    }

    // Log to game state for UI display with explicit bot player name
    final gameState = gameController.gameState;
    gameState.recentActions.add(
      GameAction(message: actionDescription, playerName: botPlayer.name),
    );

    // Keep only the last N actions to avoid memory issues
    if (gameState.recentActions.length > GameConfig.maxRecentActions) {
      gameState.recentActions.removeAt(0);
    }
  }

  /// Generate strategic reasoning for bot decisions for analytics
  String generateBotReasoning(
    Player bot,
    BotDecision decision,
    GameState gameState,
  ) {
    try {
      final personality = botAI.personalityManager.getPersonality(bot.id);
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
          if (handSize <= 3 && bot.canGoOutWithBooks) {
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
    } catch (e) {
      return 'Bot ${bot.name} executed ${decision.action} (error in reasoning generation)';
    }
  }

  /// Check if bot turn processing is in progress
  bool get isProcessingBotTurn => _isProcessingBotTurn;

  /// Reset bot processing state (use in error recovery)
  void resetProcessingState() {
    _isProcessingBotTurn = false;
  }
}
