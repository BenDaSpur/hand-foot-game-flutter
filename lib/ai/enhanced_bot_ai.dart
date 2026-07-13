import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/player.dart';
import '../models/card.dart';
import '../models/meld.dart';
import '../models/game_state.dart';
import '../game/game_controller.dart';
import '../config/game_config.dart';
import 'bot_decision.dart';
import 'bot_personality.dart';
import 'bot_game_analyzer.dart';
import 'bot_meld_analyzer.dart';
import 'bot_foot_transition_manager.dart';
import 'bot_end_game_manager.dart';
import 'bot_game_context.dart';
import 'bot_discard_analyzer.dart';
import 'bot_config.dart';
import '../utils/debug_logger.dart';

/// Enhanced Bot AI coordinator that orchestrates all bot decision-making.
///
/// This class serves as the main interface for bot AI decisions, coordinating
/// between specialized managers for different aspects of gameplay including
/// personality, game analysis, meld analysis, foot transitions, and end game.
class EnhancedBotAI {
  // Core components
  final BotPersonalityManager _personalityManager;
  final BotGameAnalyzer _gameAnalyzer;
  final BotMeldAnalyzer _meldAnalyzer;
  final BotFootTransitionManager _footTransitionManager;
  final BotEndGameManager _endGameManager;
  final BotDiscardAnalyzer _discardAnalyzer;

  // Random number generator for decision variability
  final math.Random _random;

  // Multi-meld play-down state tracking (legacy - now disabled)
  List<List<PlayingCard>>? _plannedMelds;
  bool _inMultiMeldSequence = false;

  // Performance optimization: Cache pressure analysis results
  Map<String, DateTime>? _lastPressureAnalysis;
  Map<String, BotDecision?>? _cachedPressureResponse;

  // Performance optimization: Cache meld analysis results
  Map<String, List<List<PlayingCard>>>? _cachedPossibleMelds;
  String? _lastMeldCacheKey;

  // All strategic constants now centralized in BotConfig

  factory EnhancedBotAI({int? seed}) {
    final meldAnalyzer = BotMeldAnalyzer();
    final random = seed != null ? math.Random(seed) : math.Random();
    return EnhancedBotAI._(
      personalityManager: BotPersonalityManager(),
      gameAnalyzer: BotGameAnalyzer(),
      meldAnalyzer: meldAnalyzer,
      footTransitionManager: BotFootTransitionManager(
        meldAnalyzer: meldAnalyzer,
      ),
      endGameManager: BotEndGameManager(meldAnalyzer: meldAnalyzer),
      discardAnalyzer: BotDiscardAnalyzer(),
      random: random,
    );
  }

  EnhancedBotAI._({
    required BotPersonalityManager personalityManager,
    required BotGameAnalyzer gameAnalyzer,
    required BotMeldAnalyzer meldAnalyzer,
    required BotFootTransitionManager footTransitionManager,
    required BotEndGameManager endGameManager,
    required BotDiscardAnalyzer discardAnalyzer,
    required math.Random random,
  }) : _personalityManager = personalityManager,
       _gameAnalyzer = gameAnalyzer,
       _meldAnalyzer = meldAnalyzer,
       _footTransitionManager = footTransitionManager,
       _endGameManager = endGameManager,
       _discardAnalyzer = discardAnalyzer,
       _random = random;

  /// Main entry point for bot decisions
  BotDecision makeDecision(Player bot, GameController controller) {
    final context = BotGameContext(controller.gameState, controller);
    return _makeDecisionWithContext(bot, context);
  }

  /// Internal decision-making method using BotGameContext for decoupling
  BotDecision _makeDecisionWithContext(Player bot, BotGameContext context) {
    final gameState = context.gameState;

    try {
      // Set context for personality-based decisions
      _personalityManager.setCurrentPlayerContext(bot.id);

      // Final turn after another player went out — maximize melded points, no holding.
      if (gameState.finalTurnPhaseActive &&
          gameState.isPlayerAwaitingFinalTurn(bot)) {
        return _makeFinalTurnScoringDecision(bot, context);
      }

      // CRITICAL: Finish the round when books are met — discard/meld last cards
      // before going out (empty hand required for canGoOut).
      if (gameState.turnPhase == TurnPhase.discard ||
          gameState.turnPhase == TurnPhase.meld) {
        final controller = context.controller as GameController?;
        if (controller != null) {
          final finishDecision = _endGameManager.buildFinishRoundDecision(
            bot,
            controller,
            gameState.turnPhase,
          );
          if (finishDecision != null) {
            DebugLogger.debug(
              '${bot.name}: CRITICAL - Finishing round (${finishDecision.action})',
            );
            return finishDecision;
          }
        }
      }

      // DEBUG: Log decision context (removed in release builds)
      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'makeDecision in phase ${gameState.turnPhase}',
      );

      // NEW: Dynamic adaptive personality adjustment
      _applyAdaptivePersonalityAdjustment(bot, gameState);

      // Update game analysis
      _gameAnalyzer.updateOpponentAnalysis(gameState, bot);
      _gameAnalyzer.incrementTurnCount(bot.id);

      // Clear meld cache if needed
      if (gameState.turnPhase == TurnPhase.meld || gameState.hasDrawnFromDeck) {
        _meldAnalyzer.clearCache();
      }

      // Calculate early game status to prevent emergency panic on normal starting hands
      final handSize = bot.currentHand.length;
      final isEarlyGame = _isEarlyGamePhase(bot);

      // NEW: Opponent pressure detection and competitive response (with caching)
      final pressureResponse = _evaluateOpponentPressureWithCaching(
        bot,
        context,
        gameState,
      );

      // If under pressure AND have large hand, bypass early game grace
      if (pressureResponse != null &&
          handSize >= BotConfig.criticalHandSizeThreshold) {
        DebugLogger.botDebug(
          bot.id,
          bot.name,
          'Competitive pressure with large hand - forcing emergency meld instead of pressure response',
        );
        // Continue to emergency logic below instead of returning pressure response
      } else if (pressureResponse != null) {
        DebugLogger.botDebug(
          bot.id,
          bot.name,
          'Applying pressure response: ${pressureResponse.action}',
        );
        return pressureResponse;
      }

      // CRITICAL EMERGENCY: Hand size protocols override ALL other logic
      // But only after bot has had enough turns to play normally
      final botTurnCount = _gameAnalyzer.getTurnCount(bot.id);
      final hasCompetitivePressure = pressureResponse != null;
      // Only bypass early game if we have competitive pressure AND have had enough turns
      final shouldBypassEarlyGame =
          (!isEarlyGame || hasCompetitivePressure) &&
          botTurnCount >= BotConfig.minTurnsForEmergency;

      if (handSize >= BotConfig.criticalHandSizeThreshold &&
          shouldBypassEarlyGame) {
        // PANIC MODE: But still try conservative play-down first if not played down yet
        if (gameState.turnPhase == TurnPhase.meld) {
          List<List<PlayingCard>> emergencyMelds;

          // If not played down, try conservative play-down even in emergency
          if (!bot.hasPlayedDown) {
            final controller = context.controller as GameController?;
            if (controller == null) {
              return BotDecision(action: 'noMeld');
            }
            emergencyMelds = _meldAnalyzer.findBestPlayDownCombination(
              bot,
              controller,
              gameState.playDownRequirement,
            );
            if (emergencyMelds.isEmpty) {
              // Conservative failed, fall back to maximal as last resort
              emergencyMelds = _meldAnalyzer.findMaximalMeldCombination(
                bot,
                controller,
              );
            }
          } else {
            // Already played down, use maximal for foot transition
            final controller = context.controller as GameController?;
            if (controller == null) {
              return BotDecision(action: 'noMeld');
            }
            emergencyMelds = _meldAnalyzer.findMaximalMeldCombination(
              bot,
              controller,
            );
          }

          if (emergencyMelds.isNotEmpty) {
            final meldType = bot.hasPlayedDown
                ? 'maximal'
                : 'conservative emergency';
            DebugLogger.botDebug(
              bot.id,
              bot.name,
              'CRITICAL EMERGENCY (turn $botTurnCount): Hand size $handSize exceeds $BotConfig.criticalHandSizeThreshold - using $meldType combination (${emergencyMelds.length} melds)',
            );

            if (emergencyMelds.length == 1) {
              return BotDecision(
                action: 'createMeld',
                data: emergencyMelds.first,
                skipPlayDownCheck: bot.hasPlayedDown,
              );
            } else {
              return BotDecision(
                action: 'createMultipleMelds',
                data: emergencyMelds,
                skipPlayDownCheck: bot.hasPlayedDown,
              );
            }
          }
        }
      }

      if (handSize >= BotConfig.emergencyHandSizeThreshold &&
          shouldBypassEarlyGame) {
        // EMERGENCY MODE: Use maximal meld combination for aggressive melding
        if (gameState.turnPhase == TurnPhase.meld) {
          // If not played down, force emergency play-down with enhanced combination
          if (!bot.hasPlayedDown) {
            return _handleEmergencyPlayDown(bot, context);
          }

          // Post-play-down: Use maximal meld combination
          final controller = context.controller as GameController?;
          if (controller == null) {
            return BotDecision(action: 'noMeld');
          }
          final maximalMelds = _meldAnalyzer.findMaximalMeldCombination(
            bot,
            controller,
          );
          if (maximalMelds.isNotEmpty) {
            DebugLogger.botDebug(
              bot.id,
              bot.name,
              'EMERGENCY (turn $botTurnCount): Hand size $handSize exceeds $BotConfig.emergencyHandSizeThreshold - using maximal meld combination (${maximalMelds.length} melds)',
            );

            if (maximalMelds.length == 1) {
              return BotDecision(
                action: 'createMeld',
                data: maximalMelds.first,
              );
            } else {
              return BotDecision(
                action: 'createMultipleMelds',
                data: maximalMelds,
              );
            }
          }
        }
        // In draw phase with emergency hand size - still draw to get to meld phase
        if (gameState.turnPhase == TurnPhase.draw) {
          DebugLogger.botDebug(
            bot.id,
            bot.name,
            'EMERGENCY (turn $botTurnCount): Hand size $handSize - forcing quick draw to reach meld phase',
          );
          return BotDecision(action: 'drawFromDeck');
        }
      }

      // SPECIAL EMERGENCY: Bot with too many cards and no play-down
      if (handSize >= BotConfig.playDownEmergencyThreshold &&
          !bot.hasPlayedDown &&
          shouldBypassEarlyGame &&
          gameState.turnPhase == TurnPhase.meld) {
        DebugLogger.botDebug(
          bot.id,
          bot.name,
          'PLAY-DOWN EMERGENCY: $handSize cards without play-down - forcing any viable meld',
        );
        final emergencyPlayDown = _handleEmergencyPlayDown(bot, context);
        // Safety check: if emergency play-down fails, fall back to normal logic
        if (emergencyPlayDown.action != 'noMeld') {
          return emergencyPlayDown;
        }
        // Continue to normal logic if emergency play-down couldn't find viable melds
      }

      // PANIC MODE: Override normal logic for bots in terrible situations
      if (bot.score < -100 && !bot.hasPlayedDown) {
        return _handlePanicMode(bot, context, gameState);
      }

      // Route to appropriate decision handler based on turn phase with enhanced error handling
      BotDecision decision;
      try {
        decision = switch (gameState.turnPhase) {
          TurnPhase.draw => _makeDrawDecision(bot, context),
          TurnPhase.meld => _makeMeldDecision(bot, context),
          TurnPhase.discard => _makeDiscardDecision(bot, context),
        };

        // Validate decision before returning
        if (!_isValidDecision(decision, bot, context)) {
          DebugLogger.botDebug(
            bot.id,
            bot.name,
            'Invalid decision ${decision.action}, falling back to safe choice',
          );
          decision = _getSafeDecision(gameState.turnPhase, bot, context);
        }
      } catch (e) {
        DebugLogger.botDebug(
          bot.id,
          bot.name,
          'Decision error: $e, using emergency fallback',
        );
        decision = _getSafeDecision(gameState.turnPhase, bot, context);
      }

      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'makeDecision returning: ${decision.action}',
      );
      return decision;
    } catch (e, stackTrace) {
      DebugLogger.error('Bot decision failed for ${bot.id}: $e');
      DebugLogger.error('Stack trace: $stackTrace');
      // Emergency fallback
      return gameState.turnPhase == TurnPhase.draw
          ? BotDecision(action: 'drawFromDeck')
          : BotDecision(action: 'noMeld');
    }
  }

  /// Handle draw phase decisions
  BotDecision _makeDrawDecision(Player bot, BotGameContext context) {
    final gameState = context.gameState;

    // DEBUG: Log draw decision context (removed in release builds)
    DebugLogger.botDebug(
      bot.id,
      bot.name,
      '_makeDrawDecision - hasPlayedDown=${bot.hasPlayedDown}, melds=${bot.melds.length}, inMultiMeld=$_inMultiMeldSequence',
    );

    // Note: In Hand & Foot, bots must always draw in draw phase to advance turn

    // If continuing multi-meld sequence, draw from deck to proceed to meld phase
    // Multi-meld sequence should continue in meld phase, not skip drawing
    if (_inMultiMeldSequence) {
      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'Returning drawFromDeck (multi-meld sequence)',
      );
      return BotDecision(action: 'drawFromDeck');
    }

    // Human analytics: prefer deck draws while accumulating (0 unlock events in 87 sessions)
    if (_isInHumanAccumulationWindow(bot, context) &&
        gameState.discardPile.isNotEmpty) {
      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'Accumulation phase - drawing from deck (human pattern)',
      );
      return BotDecision(action: 'drawFromDeck');
    }

    // Evaluate discard pile opportunity - ALLOW PRE-PLAY-DOWN for valuable piles
    if (gameState.discardPile.isNotEmpty) {
      try {
        final riskTolerance = _personalityManager.calculateRiskTolerance(
          gameState,
          bot,
        );

        // Enhanced: also check for pre-play-down opportunities if pile is very valuable
        final shouldTake = _shouldTakeDiscardPile(bot, context, riskTolerance);
        final canUnlock = context.canUnlockDiscard();

        if (shouldTake && canUnlock) {
          DebugLogger.botDebug(
            bot.id,
            bot.name,
            'Returning drawFromDiscard (discard pile opportunity)',
          );
          return BotDecision(action: 'drawFromDiscard');
        }
        // Pre-play-down: play down first so we can unlock the pile on a future turn
        if (shouldTake && !canUnlock && !bot.hasPlayedDown) {
          if (_couldUnlockDiscardPileIfPlayedDown(bot, gameState)) {
            DebugLogger.botDebug(
              bot.id,
              bot.name,
              'Valuable discard pile blocked - prioritizing play-down first',
            );
            final playDownDecision = _handlePlayDownDecision(bot, context);
            if (playDownDecision.action != 'noMeld') {
              return playDownDecision;
            }
          }
        }
      } catch (e) {
        DebugLogger.warning(
          'Risk tolerance calculation failed for bot ${bot.id}: $e',
        );
        // Skip discard pile evaluation and continue to default
      }
    }

    // NEW: Even more aggressive - check discard pile before playing down if pile is huge
    if (gameState.discardPile.length >= 8 && !bot.hasPlayedDown) {
      try {
        final riskTolerance = _personalityManager.calculateRiskTolerance(
          gameState,
          bot,
        );
        if (_shouldTakeDiscardPile(
              bot,
              context,
              riskTolerance * 2.0,
            ) && // 2x risk tolerance for huge piles
            context.canUnlockDiscard()) {
          DebugLogger.botDebug(
            bot.id,
            bot.name,
            'Returning drawFromDiscard (huge pile, pre-play-down)',
          );
          return BotDecision(action: 'drawFromDiscard');
        }
      } catch (e) {
        // Continue to default if error
      }
    }

    // NEW: FOOT PHASE URGENCY - Avoid drawing from deck if in foot with few cards
    if (bot.hasPickedUpFoot && bot.currentHand.length <= 6) {
      // Check if we can go out after melding - if so, consider NOT drawing
      if (bot.canGoOutWithBooks && bot.currentHand.length <= 3) {
        DebugLogger.botDebug(
          bot.id,
          bot.name,
          'FOOT URGENCY: Avoiding deck draw, should focus on going out (${bot.currentHand.length} cards)',
        );
        // Still draw, but this signals the meld phase should prioritize going out
      }
    }

    // Default to drawing from deck
    DebugLogger.botDebug(bot.id, bot.name, 'Returning drawFromDeck (default)');
    return BotDecision(action: 'drawFromDeck');
  }

  /// Handle meld phase decisions
  BotDecision _makeMeldDecision(Player bot, BotGameContext context) {
    // Empty hand: skip meld (discard/go-out handled in discard phase)
    if (bot.currentHand.isEmpty) {
      return BotDecision(action: 'noMeld');
    }

    // PRIORITY 0: Complete hand pile → foot (multi-meld to avoid 1-card trap)
    final handPileFootCompletion = _makeCompleteHandPileForFootDecision(
      bot,
      context,
    );
    if (handPileFootCompletion != null) {
      return handPileFootCompletion;
    }

    // PRIORITY 0: Check if bot should rush to go out
    if (_shouldRushToGoOut(bot, context.gameState)) {
      final handSize = bot.currentHand.length;

      // If very few cards (≤3), skip melding entirely to go out fastest
      if (handSize <= 3) {
        DebugLogger.debug(
          '${bot.name}: ULTRA RUSH - skipping meld with $handSize cards to go out immediately',
        );
        return BotDecision(action: 'noMeld');
      }

      // If moderate cards (4+), meld everything possible to minimize hand size
      DebugLogger.debug(
        '${bot.name}: RUSHING TO GO OUT - melding everything possible ($handSize cards)',
      );

      // Try to meld all remaining cards to minimize hand size for going out
      final cardsToAdd = _meldAnalyzer.findCardsToAddToExistingMelds(
        bot,
        (context.controller as GameController?) ??
            (throw StateError('Controller required for meld analysis')),
      );
      if (cardsToAdd.isNotEmpty) {
        DebugLogger.debug(
          '${bot.name}: Adding to existing meld to reduce hand size',
        );
        return BotDecision(action: 'addToMeld', data: cardsToAdd.first);
      }

      // Try to create new melds to reduce hand size
      final possibleMelds = _getCachedPossibleMelds(bot, context);
      if (possibleMelds.isNotEmpty) {
        DebugLogger.debug('${bot.name}: Creating new meld to reduce hand size');
        return BotDecision(
          action: 'createMeld',
          data: _selectBestNewMeld(bot, possibleMelds),
        );
      }

      // If no melds possible, proceed to discard phase
      DebugLogger.debug(
        '${bot.name}: No melds possible - ready to discard and go out',
      );
      return BotDecision(action: 'noMeld');
    }

    // PRIORITY 0a: Rush hand pile → foot before opponents go out
    final handToFootRush = _makeHandToFootRushDecision(bot, context);
    if (handToFootRush != null) {
      return handToFootRush;
    }

    // PRIORITY 0b: Foot phase — melt large hands and complete book pairs (all personalities)
    final footPhaseDecision = _handleFootPhaseMeldDecision(bot, context);
    if (footPhaseDecision != null) {
      return footPhaseDecision;
    }

    // Draw-loop guard: played down with large hand should meld, not draw repeatedly.
    // Skip during human-style accumulation (8–14) or burst-meld threshold (15+).
    if (bot.hasPlayedDown &&
        bot.currentHand.length >= BotConfig.drawLoopMeldHandThreshold &&
        !_isInHumanAccumulationWindow(bot, context) &&
        !_shouldExecuteDumpStrategy(bot, context)) {
      final drawLoopMeld = _forceMeldForLargePlayedDownHand(bot, context);
      if (drawLoopMeld != null) {
        return drawLoopMeld;
      }
    }

    // EMERGENCY PROTOCOLS: Check for catastrophic hand size failures FIRST
    // BUT: Give bots grace period early in round when large hands are normal
    // AND: Require minimum turns before emergency can activate
    final handSize = bot.currentHand.length;
    final isEarlyGame = _isEarlyGamePhase(bot);
    final botTurnCount = _gameAnalyzer.getTurnCount(bot.id);

    // Check if competitive pressure should override early game grace
    // Note: This method is called from makeDecision, so we don't have access to pressureResponse
    // We need to check pressure here, but this should be cached from the earlier call
    final hasCompetitivePressure =
        _evaluateOpponentPressureWithCaching(bot, context, context.gameState) !=
        null;
    // Only bypass early game if enough turns have passed
    final shouldBypassEarlyGame =
        (!isEarlyGame || hasCompetitivePressure) &&
        botTurnCount >= BotConfig.minTurnsForEmergency;

    if (handSize >= BotConfig.criticalHandSizeThreshold &&
        shouldBypassEarlyGame) {
      // PANIC MODE: Any meld is better than none
      final anyPossibleMelds = _getCachedPossibleMelds(bot, context);
      if (anyPossibleMelds.isNotEmpty) {
        final panicMeld = _selectBestNewMeld(bot, anyPossibleMelds);
        DebugLogger.botDebug(
          bot.id,
          bot.name,
          'CRITICAL EMERGENCY (turn $botTurnCount): Hand size $handSize exceeds $BotConfig.criticalHandSizeThreshold - forcing meld creation',
        );
        return BotDecision(
          action: 'createMeld',
          data: panicMeld,
          skipPlayDownCheck:
              true, // Force creation regardless of play-down requirements
        );
      }
      // Ultimate fallback: If somehow no melds possible even with 30+ cards,
      // continue to emergency mode rather than crash
    }

    // Also require minimum turns for emergency mode
    if (handSize >= BotConfig.emergencyHandSizeThreshold &&
        !isEarlyGame &&
        botTurnCount >= BotConfig.minTurnsForEmergency) {
      // EMERGENCY MODE: Force aggressive meld creation
      if (bot.hasPlayedDown) {
        // Already played down - meld anything possible
        final emergencyMelds = _getCachedPossibleMelds(bot, context);
        if (emergencyMelds.isNotEmpty) {
          final urgentMeld = _selectBestNewMeld(bot, emergencyMelds);
          return BotDecision(action: 'createMeld', data: urgentMeld);
        }
      } else {
        // Force play-down even with suboptimal points
        return _handleEmergencyPlayDown(bot, context);
      }
    }

    // Multi-meld sequences should happen within a single turn, not across turns
    // Clear any stale multi-meld state that violates Hand & Foot rules
    if (_inMultiMeldSequence) {
      _plannedMelds = null;
      _inMultiMeldSequence = false;
    }

    // ADAPTIVE PERSONALITY FIX: Force aggressive melding in foot phase with large hands
    // (covered for all personalities by _handleFootPhaseMeldDecision above)

    // Check for end game decisions (after emergency protocols)
    final controller = context.controller as GameController?;
    if (controller == null) return BotDecision(action: 'noMeld');
    final endGameDecision = _endGameManager.handleEndGame(bot, controller);
    if (endGameDecision != null) {
      return endGameDecision;
    }

    // NEW: Check if we can play ALL cards to immediately see foot
    if (bot.hasPlayedDown && !bot.hasPickedUpFoot) {
      if (!_isInHumanAccumulationWindow(bot, context)) {
        final canPlayAllDecision = _checkCanPlayAllCards(bot, context);
        if (canPlayAllDecision != null) {
          return canPlayAllDecision;
        }
      }
    }

    // Handle play-down if not yet played down
    if (!bot.hasPlayedDown) {
      return _handlePlayDownDecision(bot, context);
    }

    // Human pattern: accumulate before foot transition / incremental melds
    if (_shouldAccumulateHandLikeHuman(bot, context)) {
      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'Human-style accumulation: holding ${bot.currentHand.length} cards before burst',
      );
      return BotDecision(action: 'noMeld');
    }

    // Personality/time-pressure holding outside the human accumulation window
    if (!_isInHumanAccumulationWindow(bot, context) &&
        _shouldHoldCardsStrategically(bot, context)) {
      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'Strategic hold: personality/time-pressure limits',
      );
      return BotDecision(action: 'noMeld');
    }

    // Human pattern: burst-meld at 15+ before foot-transition discard paths
    if (_shouldExecuteDumpStrategy(bot, context)) {
      final dumpDecision = _executeDumpStrategy(bot, context);
      if (dumpDecision.action != 'noMeld') {
        return dumpDecision;
      }
    }

    // Check for foot transition decisions
    final controllerForFoot = context.controller as GameController?;
    if (controllerForFoot == null) {
      return BotDecision(action: 'noMeld');
    }
    final footTransitionDecision = _footTransitionManager.handleFootTransition(
      bot,
      controllerForFoot,
    );
    if (footTransitionDecision != null) {
      return footTransitionDecision;
    }

    // Check competitive positioning threat
    if (_isCompetitivelyThreatened(bot, context)) {
      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'COMPETITIVE THREAT DETECTED: Switching to aggressive catch-up mode',
      );
      return _handleCompetitiveThreat(bot, context);
    }

    // Opponents on foot are racing to go out — stop hoarding and melt hand down
    if (_opponentOnFootPressure(context, bot)) {
      if (!bot.hasPickedUpFoot && _shouldExecuteDumpStrategy(bot, context)) {
        return _executeDumpStrategy(bot, context);
      }

      final rushCardsToAdd = _filterWildCardAdditions(
        _meldAnalyzer.findCardsToAddToExistingMelds(bot, controller),
        bot,
      );
      if (rushCardsToAdd.isNotEmpty) {
        return BotDecision(action: 'addToMeld', data: rushCardsToAdd.first);
      }

      final rushMelds = _getCachedPossibleMelds(bot, context);
      if (rushMelds.isNotEmpty) {
        return BotDecision(
          action: 'createMeld',
          data: _meldAnalyzer.findBestMeld(rushMelds, bot: bot),
        );
      }
    }

    // Look for meld opportunities (fallback for conservative play)
    final rawCardsToAdd = _meldAnalyzer.findCardsToAddToExistingMelds(
      bot,
      controller,
    );
    final cardsToAdd = _filterWildCardAdditions(rawCardsToAdd, bot);
    if (cardsToAdd.isNotEmpty) {
      if (bot.hasPickedUpFoot && bot.hasDirtyBook && !bot.hasCleanBook) {
        final cleanAdditions = _filterCleanBookPriorityAdditions(
          bot,
          cardsToAdd,
        );
        if (cleanAdditions.isNotEmpty) {
          return BotDecision(action: 'addToMeld', data: cleanAdditions.first);
        }
      }
      return BotDecision(action: 'addToMeld', data: cardsToAdd.first);
    }

    // Try to create new melds with book balance consideration
    final possibleMelds = _getCachedPossibleMelds(bot, context);
    if (possibleMelds.isNotEmpty) {
      // Pass bot context to consider book balance
      final bestMeld = _meldAnalyzer.findBestMeld(possibleMelds, bot: bot);
      return BotDecision(action: 'createMeld', data: bestMeld);
    }

    // No meld opportunities
    return BotDecision(action: 'noMeld');
  }

  /// Handle discard phase decisions
  BotDecision _makeDiscardDecision(Player bot, BotGameContext context) {
    // CORE RULE: Bots MUST always discard a card in discard phase
    // The ONLY exception is if they have no cards and can go out (end round/game)

    // Exception: Bot has no cards - check if they can go out properly
    if (bot.currentHand.isEmpty) {
      if (bot.canGoOut) {
        return BotDecision(action: 'goOut'); // Ends round - no discard needed
      } else {
        // Critical bug: Bot emptied hand but can't go out (missing books or not on foot)
        print(
          'CRITICAL BUG: Bot ${bot.name} has empty hand but cannot go out!',
        );
        print('  - On foot: ${bot.hasPickedUpFoot}');
        print('  - Has clean book: ${bot.hasCleanBook}');
        print('  - Has dirty book: ${bot.hasDirtyBook}');
        print('  - This indicates poor meld planning in earlier phases');
        return BotDecision(action: 'error'); // Invalid state
      }
    }

    // RULE ENFORCEMENT: Bot must discard a card to follow Hand & Foot rules
    PlayingCard? cardToDiscard;
    if (bot.hasPlayedDown &&
        !bot.hasPickedUpFoot &&
        bot.currentHand.length <= BotConfig.handPileFootCompletionMaxHand) {
      cardToDiscard = _chooseHandPileTransitionDiscard(bot);
    }
    cardToDiscard ??= _chooseCardToDiscard(bot, context.gameState);
    if (cardToDiscard == null) {
      return BotDecision(action: 'error');
    }

    // COMPETITIVE STRATEGY: Enhanced card selection for discarding
    // Note: The actual go-out will happen AFTER the discard if bot ends up with 0 cards
    // and meets the going out requirements. This is handled by the game controller.

    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// EMERGENCY: Handle emergency play-down when hand size is critical
  BotDecision _handleEmergencyPlayDown(Player bot, BotGameContext context) {
    final gameState = context.gameState;
    final possibleMelds = _getCachedPossibleMelds(bot, context);
    final playDownRequirement = gameState.playDownRequirement;

    if (possibleMelds.isEmpty) {
      return BotDecision(action: 'noMeld');
    }

    // EMERGENCY: Try any combination that gets close to requirement
    final controller = context.controller as GameController?;
    if (controller == null) return BotDecision(action: 'noMeld');
    final bestCombination = _meldAnalyzer.findBestPlayDownCombination(
      bot,
      controller,
      playDownRequirement, // Use full requirement, no bypasses
    );

    if (bestCombination.isNotEmpty) {
      if (bestCombination.length == 1) {
        // Emergency play-down must still meet full requirements
        final emergencyValue = bestCombination.first.fold<int>(
          0,
          (sum, card) => sum + card.pointValue,
        );

        if (emergencyValue >= playDownRequirement) {
          return BotDecision(action: 'createMeld', data: bestCombination.first);
        } else {
          DebugLogger.warning(
            '${bot.name}: Emergency play-down rejected - insufficient value ($emergencyValue < $playDownRequirement)',
          );
          return BotDecision(action: 'noMeld');
        }
      } else {
        return BotDecision(
          action: 'createMultipleMelds',
          data: bestCombination,
        );
      }
    }

    // ULTRA EMERGENCY: If even 80% requirement fails, validate we have valid melds before proceeding
    if (possibleMelds.isNotEmpty) {
      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'ULTRA EMERGENCY: Evaluating ${possibleMelds.length} available melds',
      );

      // Safety check: Ensure we have valid meld data
      final validMelds = possibleMelds
          .where((meld) => meld.isNotEmpty && meld.length >= 3)
          .toList();

      if (validMelds.isEmpty) {
        DebugLogger.warning(
          '${bot.name}: Ultra emergency - no valid melds found',
        );
        return BotDecision(action: 'noMeld');
      }

      // Try to find the best single meld as last resort
      final bestSingleMeld = _meldAnalyzer.findBestMeld(validMelds, bot: bot);

      // Validate the selected meld has minimum requirements
      if (bestSingleMeld.isEmpty || bestSingleMeld.length < 3) {
        DebugLogger.warning(
          '${bot.name}: Best meld is invalid (${bestSingleMeld.length} cards)',
        );
        return BotDecision(action: 'noMeld');
      }

      // Ultra emergency must still meet full requirements
      final emergencyValue = bestSingleMeld.fold<int>(
        0,
        (sum, card) => sum + card.pointValue,
      );

      if (emergencyValue >= gameState.playDownRequirement) {
        return BotDecision(action: 'createMeld', data: bestSingleMeld);
      } else {
        DebugLogger.warning(
          '${bot.name}: Ultra emergency play-down rejected - insufficient value ($emergencyValue < ${gameState.playDownRequirement})',
        );
        return BotDecision(action: 'noMeld');
      }
    }

    return BotDecision(action: 'noMeld');
  }

  /// Check if bot should rush to go out (affects discard and meld priorities)
  bool _shouldRushToGoOut(Player bot, GameState gameState) {
    if (!bot.hasPickedUpFoot || !bot.canGoOutWithBooks) {
      return false;
    }

    if (!_shouldRushToGoOutCore(bot, gameState)) {
      return false;
    }

    if (_shouldDelayRushForLowOpponentPenalty(bot, gameState)) {
      DebugLogger.debug(
        '${bot.name}: Delaying rush go-out — opponents have little unplayed-card penalty',
      );
      return false;
    }

    return true;
  }

  /// Core rush-go-out evaluation (before opponent-penalty delay).
  bool _shouldRushToGoOutCore(Player bot, GameState gameState) {
    // Scenario 1: Bot should go out based on book count and hand size
    final bookCount = bot.melds.where((m) => m.isBook).length;

    // ULTRA-AGGRESSIVE: If bot has 4+ books, go out with even more cards
    if (bookCount >= 4 && bot.currentHand.length <= 12) {
      DebugLogger.debug(
        '${bot.name}: EMERGENCY GO OUT - has $bookCount books with ${bot.currentHand.length} cards',
      );
      return true;
    }

    // AGGRESSIVE: If bot has 3+ books, go out with fewer cards
    if (bookCount >= 3 && bot.currentHand.length <= 8) {
      DebugLogger.debug(
        '${bot.name}: PRIORITY GO OUT - has $bookCount books with ${bot.currentHand.length} cards',
      );
      return true;
    }

    // STANDARD: Original threshold for 2 books
    if (bot.currentHand.length <= 6) {
      DebugLogger.debug(
        '${bot.name}: Rushing to go out - few cards left (${bot.currentHand.length})',
      );
      return true;
    }

    // Scenario 2: COMPETITIVE URGENCY - Opponent is close to winning (7000+ points)
    final maxOpponentScore = gameState.players
        .where((p) => p.id != bot.id)
        .map((p) => p.score)
        .fold(0, (max, score) => score > max ? score : max);

    if (maxOpponentScore >= 7000) {
      DebugLogger.debug(
        '${bot.name}: PANIC MODE - Opponent has $maxOpponentScore points, rushing to go out!',
      );
      return true;
    }

    // Scenario 3: IMMEDIATE BOOK THREAT - Opponent has massive books and small hand (any round)
    for (final opponent in gameState.players) {
      if (opponent.id == bot.id) continue;

      final opponentBooks = opponent.melds.where((m) => m.isBook).length;
      final opponentHasGoingOutBooks = opponent.canGoOutWithBooks;

      if (opponentBooks >= 6 &&
          opponentHasGoingOutBooks &&
          opponent.currentHand.length <= 5) {
        DebugLogger.debug(
          '${bot.name}: BOOK THREAT PANIC - Opponent has $opponentBooks books and ${opponent.currentHand.length} cards, must rush!',
        );
        return true;
      }
    }

    // Scenario 4: Round 3+ and opponent is far ahead - end round to limit their scoring
    if (gameState.round >= 3 && maxOpponentScore > bot.score + 1500) {
      DebugLogger.debug(
        '${bot.name}: DEFENSIVE RUSH - Opponent ahead by ${maxOpponentScore - bot.score}, rushing to end round',
      );
      return true;
    }

    // Scenario 5: EMERGENCY 3s MANAGEMENT - Bot has 8+ cards mostly 3s, needs to rush out
    final threeCount = bot.currentHand.where((card) => card.isThree).length;
    if (bot.currentHand.length >= 8 &&
        threeCount >= 6 &&
        bot.currentHand.length <= 12) {
      DebugLogger.debug(
        '${bot.name}: 3s EMERGENCY - $threeCount 3s in ${bot.currentHand.length} cards, rushing to go out',
      );
      return true;
    }

    // Scenario 6: BookBuilder specific - if they have 2+ books, rush to go out instead of over-accumulating
    final personality = _personalityManager.getPersonality(bot.id);
    if (personality == BotPersonality.bookBuilder &&
        bot.melds.where((m) => m.isBook).length >= 2 &&
        bot.currentHand.length <= 8) {
      DebugLogger.debug(
        '${bot.name}: BookBuilder rushing to end with ${bot.melds.where((m) => m.isBook).length} books',
      );
      return true;
    }

    return false;
  }

  /// Check if bot is competitively threatened by opponents
  bool _isCompetitivelyThreatened(Player bot, BotGameContext context) {
    final gameState = context.gameState;
    final botHandSize = bot.currentHand.length;

    // Check all opponents
    for (final opponent in gameState.players) {
      if (opponent.id == bot.id) continue;

      final handSizeGap = botHandSize - opponent.currentHand.length;
      final meldGap = opponent.melds.length - bot.melds.length;

      // Threatened if opponent has significant advantage
      if (handSizeGap >= BotConfig.competitiveThreatHandSizeGap ||
          meldGap >= 3) {
        return true;
      }

      // Threatened if opponent is close to going out
      if (opponent.hasPickedUpFoot && opponent.currentHand.length <= 5) {
        return true;
      }
    }

    return false;
  }

  /// Handle competitive threat by switching to aggressive mode
  BotDecision _handleCompetitiveThreat(Player bot, BotGameContext context) {
    // Force meld creation if possible
    final possibleMelds = _getCachedPossibleMelds(bot, context);
    if (possibleMelds.isNotEmpty) {
      final urgentMeld = _selectBestNewMeld(bot, possibleMelds);
      return BotDecision(action: 'createMeld', data: urgentMeld);
    }

    // Try adding to existing melds
    final controller = context.controller as GameController?;
    if (controller == null) return BotDecision(action: 'noMeld');
    final cardsToAdd = _meldAnalyzer.findCardsToAddToExistingMelds(
      bot,
      controller,
    );
    if (cardsToAdd.isNotEmpty) {
      return BotDecision(action: 'addToMeld', data: cardsToAdd.first);
    }

    // Fall back to no meld if nothing possible
    return BotDecision(action: 'noMeld');
  }

  /// Handle play-down decision logic
  BotDecision _handlePlayDownDecision(Player bot, BotGameContext context) {
    final gameState = context.gameState;
    final possibleMelds = _getCachedPossibleMelds(bot, context);
    final playDownRequirement = gameState.playDownRequirement;
    final turnCount = _gameAnalyzer.getTurnCount(bot.id);

    if (possibleMelds.isEmpty) {
      return BotDecision(action: 'noMeld');
    }

    // ENHANCED PERSONALITY-BASED URGENCY: Use personality-specific patience, not global
    final personalityConstants = _personalityManager.currentConstants;
    final personalityTurnLimit =
        personalityConstants.maxTurnsBeforeForcePlayDown;

    // CRITICAL COMPETITIVE URGENCY: Check if opponents are close to winning
    final maxOpponentScore = gameState.players
        .where((p) => p.id != bot.id)
        .map((p) => p.score)
        .fold(0, (max, score) => score > max ? score : max);

    final isUnderCompetitivePressure =
        maxOpponentScore >= 6500; // Opponent close to 8500 win condition
    final isUnderSeverePressure =
        maxOpponentScore >= 7500; // Opponent very close to winning

    // ROUND-SPECIFIC STRATEGY ADJUSTMENTS - Based on 3-round gameplay analysis
    double roundUrgencyMultiplier;
    switch (gameState.round) {
      case 1:
        roundUrgencyMultiplier = isUnderSeverePressure
            ? 0.1
            : (isUnderCompetitivePressure ? 0.5 : 1.0);
        break;
      case 2:
        roundUrgencyMultiplier = isUnderSeverePressure
            ? 0.1
            : (isUnderCompetitivePressure ? 0.3 : 0.8);
        break;
      case 3:
      default:
        roundUrgencyMultiplier = isUnderSeverePressure
            ? 0.05
            : (isUnderCompetitivePressure ? 0.1 : 0.3);
        break;
    }

    final urgentTurnLimit = (personalityTurnLimit * roundUrgencyMultiplier)
        .round()
        .clamp(1, personalityTurnLimit); // At least 1 turn patience

    // CRITICAL: Force play-down if hand size is dangerously large (prevents 26-card accumulation)
    final personality = _personalityManager.getPersonality(bot.id);
    final handSize = bot.currentHand.length;
    final shouldForcePlayDown =
        (personality == BotPersonality.bookBuilder && handSize >= 22) ||
        (isUnderCompetitivePressure && handSize >= 18) ||
        (isUnderSeverePressure && handSize >= 15) ||
        (handSize >= 25); // Universal emergency threshold

    if (shouldForcePlayDown) {
      DebugLogger.debug(
        '${bot.name}: FORCING play-down due to large hand size ($handSize) or competitive pressure',
      );
    }

    // PRIORITY 1: Always play down if we can meet requirements (regardless of patience)
    final controller = context.controller as GameController?;
    if (controller == null) return BotDecision(action: 'noMeld');
    final bestCombination = _meldAnalyzer.findBestPlayDownCombination(
      bot,
      controller,
      playDownRequirement,
    );

    DebugLogger.botDebug(
      bot.id,
      bot.name,
      'PlayDown analysis: combinations=${bestCombination.length}, requirement=$playDownRequirement, turns=$turnCount, urgentLimit=$urgentTurnLimit',
    );

    if (bestCombination.isNotEmpty) {
      // Check if we should play down now based on value vs patience
      final combinationValue = bestCombination.fold<int>(
        0,
        (sum, cards) =>
            sum +
            cards.fold<int>(0, (cardSum, card) => cardSum + card.pointValue),
      );

      // ROUND 3 EMERGENCY: Reduce requirement drastically to get into game quickly
      final adjustedRequirement = gameState.round >= 3
          ? (playDownRequirement * 0.8)
                .round() // Accept 80% in Round 3+
          : playDownRequirement;

      final meetsRequirement = combinationValue >= adjustedRequirement;
      final hasModerateExcess =
          combinationValue >= (adjustedRequirement + 10); // Reasonable excess
      final hasWaitedEnough = turnCount >= urgentTurnLimit;
      final lateRoundUrgency = gameState.round >= 3;

      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'PlayDown decision: meets=$meetsRequirement ($combinationValue >= $adjustedRequirement), excess=$hasModerateExcess, waited=$hasWaitedEnough, late=$lateRoundUrgency',
      );

      // AGGRESSIVE FIX: Play down immediately if we meet basic requirement OR under pressure
      // No need to wait for excess points - this was causing bots to accumulate cards
      if (meetsRequirement || shouldForcePlayDown) {
        if (shouldForcePlayDown && !meetsRequirement) {
          DebugLogger.debug(
            '${bot.name}: EMERGENCY play-down despite not meeting full requirement ($combinationValue/$adjustedRequirement)',
          );
        }
        return _executePlayDown(bestCombination);
      }

      // Redundant aggressive bot logic removed - all bots now play down immediately when meeting requirements
    }

    // FALLBACK: If forced to play-down but no valid combinations found, create any meld possible
    if (shouldForcePlayDown && bestCombination.isEmpty) {
      DebugLogger.debug(
        '${bot.name}: Forced play-down but no valid combinations - attempting any meld',
      );
      final anyPossibleMelds = _getCachedPossibleMelds(bot, context);
      if (anyPossibleMelds.isNotEmpty) {
        return BotDecision(
          action: 'createMeld',
          data: anyPossibleMelds.first,
          skipPlayDownCheck: true, // Bypass point requirements due to pressure
        );
      }
    }

    // Check for strategic play-down opportunity
    final riskTolerance = _personalityManager.calculateRiskTolerance(
      gameState,
      bot,
    );
    // AGGRESSIVE FIX: Don't increase requirement beyond base + small buffer
    // (Removed thresholdModifier - was making bots too conservative)
    final adjustedRequirement =
        (playDownRequirement + BotConfig.strongPlayDownBuffer).clamp(
          playDownRequirement,
          playDownRequirement + 20, // Max 20 extra points, not multiplicative
        );

    // Get controller once for all meld analyzer calls in this method
    final controllerForMeld = context.controller as GameController?;
    if (controllerForMeld == null) return BotDecision(action: 'noMeld');

    // Try natural melds first (preferred)
    final naturalMelds = _meldAnalyzer.findNaturalMeldOpportunities(
      bot,
      controllerForMeld,
    );
    final naturalCombination = _findBestNaturalCombination(
      naturalMelds,
      adjustedRequirement,
    );
    if (naturalCombination.isNotEmpty) {
      return _executePlayDown(naturalCombination);
    }

    // AGGRESSIVE FIX: Consider wild melds much more readily
    if (riskTolerance > 0.6) {
      // Reduced from 1.2 - much more willing to use wilds
      final wildCombination = _meldAnalyzer.findBestPlayDownCombination(
        bot,
        controllerForMeld,
        adjustedRequirement,
      );
      if (wildCombination.isNotEmpty) {
        return _executePlayDown(wildCombination);
      }
    }

    // EMERGENCY PLAY-DOWN: If in high rounds and still haven't played down, be desperate
    if (gameState.round >= 3 && !bot.hasPlayedDown) {
      final desperateCombination = _meldAnalyzer.findBestPlayDownCombination(
        bot,
        controllerForMeld,
        playDownRequirement, // Use base requirement, no buffer
      );
      if (desperateCombination.isNotEmpty) {
        return _executePlayDown(desperateCombination);
      }
    }

    // ULTRA EMERGENCY: Round 4+ without play-down — only legal analyzer combinations
    final isLateRoundWithoutPlaydown =
        gameState.round >= 4 && !bot.hasPlayedDown;
    if (isLateRoundWithoutPlaydown && possibleMelds.isNotEmpty) {
      final legalPlayDown = _meldAnalyzer.findBestPlayDownCombination(
        bot,
        controllerForMeld,
        playDownRequirement,
      );
      if (legalPlayDown.isNotEmpty) {
        return _executePlayDown(legalPlayDown);
      }
      return BotDecision(action: 'noMeld');
    }

    // NEGATIVE SCORE/HAND EMERGENCY: If bot has terrible score OR terrible hand value
    final handPenalty = bot.currentHand.fold<int>(
      0,
      (sum, card) => sum + (card.pointValue < 0 ? card.pointValue : 0),
    );
    if ((bot.score < -50 || handPenalty < -250) &&
        !bot.hasPlayedDown &&
        possibleMelds.isNotEmpty) {
      final legalPlayDown = _meldAnalyzer.findBestPlayDownCombination(
        bot,
        controllerForMeld,
        playDownRequirement,
      );
      if (legalPlayDown.isNotEmpty) {
        return _executePlayDown(legalPlayDown);
      }
      final qualifyingEmergency = possibleMelds
          .where(
            (meld) =>
                meld.fold<int>(0, (sum, card) => sum + card.pointValue) >=
                playDownRequirement,
          )
          .toList();
      if (qualifyingEmergency.isNotEmpty) {
        return BotDecision(
          action: 'createMeld',
          data: _selectBestNewMeld(bot, qualifyingEmergency),
        );
      }
      return BotDecision(action: 'noMeld');
    }

    return BotDecision(action: 'noMeld');
  }

  /// Handle panic mode for bots with terrible scores
  BotDecision _handlePanicMode(
    Player bot,
    BotGameContext context,
    GameState gameState,
  ) {
    DebugLogger.botDebug(
      bot.id,
      bot.name,
      'PANIC MODE activated (score: ${bot.score})',
    );

    final possibleMelds = _getCachedPossibleMelds(bot, context);
    final playDownRequirement = gameState.playDownRequirement;

    switch (gameState.turnPhase) {
      case TurnPhase.draw:
        // In panic mode, always draw from deck (fastest)
        return BotDecision(action: 'drawFromDeck');

      case TurnPhase.meld:
        // Pre-play-down: only legal full play-down combinations or melds meeting requirement.
        if (possibleMelds.isNotEmpty) {
          final controllerPanic = context.controller as GameController?;
          if (!bot.hasPlayedDown) {
            if (controllerPanic != null) {
              final legalPlayDown = _meldAnalyzer.findBestPlayDownCombination(
                bot,
                controllerPanic,
                playDownRequirement,
              );
              if (legalPlayDown.isNotEmpty) {
                return _executePlayDown(legalPlayDown);
              }
            }
            final qualifyingPanic = possibleMelds
                .where(
                  (meld) =>
                      meld.fold<int>(0, (sum, card) => sum + card.pointValue) >=
                      playDownRequirement,
                )
                .toList();
            if (qualifyingPanic.isNotEmpty) {
              return BotDecision(
                action: 'createMeld',
                data: _selectBestNewMeld(bot, qualifyingPanic),
              );
            }
            return BotDecision(action: 'noMeld');
          }
          final qualifyingPanic = possibleMelds
              .where(
                (meld) =>
                    meld.fold<int>(0, (sum, card) => sum + card.pointValue) >=
                    (playDownRequirement * 0.7).round(),
              )
              .toList();
          final desperateMeld = qualifyingPanic.isNotEmpty
              ? _selectBestNewMeld(bot, qualifyingPanic)
              : _selectBestNewMeld(bot, possibleMelds);
          return BotDecision(action: 'createMeld', data: desperateMeld);
        }
        return BotDecision(action: 'noMeld');

      case TurnPhase.discard:
        // CRITICAL FIX: Always ensure bot can discard to prevent infinite loops
        final hand = bot.currentHand;

        // If bot has no cards, they're stuck - emergency completion needed
        if (hand.isEmpty) {
          DebugLogger.warning(
            'Bot ${bot.name} has no cards in discard phase - emergency completion',
          );
          return BotDecision(action: 'endTurn');
        }

        // Discard highest penalty cards immediately
        final penaltyCards = hand.where((card) => card.pointValue < 0).toList();
        if (penaltyCards.isNotEmpty) {
          penaltyCards.sort(
            (a, b) => a.pointValue.compareTo(b.pointValue),
          ); // Most negative first
          return BotDecision(action: 'discard', data: penaltyCards.first);
        }

        // Discard highest value cards to minimize damage
        final sortedHand = List<PlayingCard>.from(hand);
        sortedHand.sort(
          (a, b) => b.pointValue.compareTo(a.pointValue),
        ); // Highest first
        return BotDecision(action: 'discard', data: sortedHand.first);
    }
  }

  /// Execute a play-down sequence (single or multi-meld)
  BotDecision _executePlayDown(List<List<PlayingCard>> melds) {
    if (melds.length > 1) {
      // Multi-meld initial play-down: use multi-meld creation to ensure all melds
      // are validated together and meet the play-down requirement as a group
      return BotDecision(
        action: 'createMultipleMelds',
        data: melds,
        skipPlayDownCheck: false, // Let the system validate the total points
      );
    } else {
      // Single meld play-down
      return BotDecision(action: 'createMeld', data: melds.first);
    }
  }

  /// Enhanced discard pile unlocking logic for competitive play
  bool _shouldTakeDiscardPile(
    Player bot,
    BotGameContext context,
    double riskTolerance,
  ) {
    final gameState = context.gameState;
    final discardPile = gameState.discardPile;

    if (discardPile.isEmpty) {
      return false;
    }

    final constants = _personalityManager.currentConstants;
    final pileValue = discardPile.fold<int>(
      0,
      (sum, card) => sum + card.pointValue,
    );
    final pileSize = discardPile.length;

    // Enhanced strategic analysis
    final bookStatus = _analyzeBookRequirements(bot);
    final opponentThreat = _assessOpponentThreat(gameState, bot);

    // Dynamic thresholds based on multiple factors
    var adjustedValueThreshold =
        constants.valuablePileThreshold / riskTolerance;
    var adjustedSizeThreshold = constants.largePileThreshold / riskTolerance;

    // Book completion urgency - take piles if they help complete books
    if (bookStatus['needsBookBalance'] == true) {
      adjustedValueThreshold *= BotConfig
          .defensiveDiscardMultiplier; // More willing to take pile for books
      adjustedSizeThreshold *= BotConfig
          .aggressiveDiscardMultiplier; // Lower size threshold for book completion
    }

    // Opponent threat adjustment - be more aggressive when opponents are dangerous
    if (opponentThreat > 0.6) {
      adjustedValueThreshold *=
          0.5; // MUCH more aggressive when threatened (was 0.6)
      adjustedSizeThreshold *=
          0.6; // Lower threshold when opponents are close (was 0.7)
    }

    // Round pressure - later rounds require more aggressive pile taking
    if (gameState.round >= 3) {
      adjustedValueThreshold *=
          0.6; // MUCH more aggressive in late rounds (was 0.8)
      adjustedSizeThreshold *= 0.7; // Lower threshold in high rounds (was 0.9)
    }

    // NEW: Human exploitation - humans avoid discard pile, so we should take it more
    final humanPlayers = gameState.players.where(
      (p) => p.type == PlayerType.human,
    );
    if (humanPlayers.any(
      (h) => h.currentHand.length > 15 && !h.hasPlayedDown,
    )) {
      // If human is accumulating and avoiding discard pile, we should take it
      adjustedValueThreshold *=
          0.5; // MUCH more willing to take piles humans ignore (was 0.7)
      adjustedSizeThreshold *=
          0.6; // Take smaller piles to deny human resources (was 0.8)
    }

    // NEW: Exploit large discard piles (45+ cards observed, but bots ignore them)
    if (pileSize >= GameConfig.largeDiscardPileThreshold) {
      adjustedValueThreshold *=
          0.2; // Take huge piles very aggressively (was 0.3)
      adjustedSizeThreshold *= 0.3; // Almost always take large piles (was 0.4)
    } else if (pileSize >= GameConfig.mediumDiscardPileThreshold) {
      adjustedValueThreshold *=
          0.4; // Take medium-large piles more aggressively (was 0.6)
      adjustedSizeThreshold *=
          0.5; // Lower threshold for medium piles (was 0.7)
    }

    // NEW: Competitive pile denial - take piles that would benefit opponents
    if (pileSize >= 5 &&
        _pileWouldBenefitOpponents(discardPile, gameState, bot)) {
      adjustedValueThreshold *= BotConfig
          .competitiveDiscardMultiplier; // Take piles to deny opponents
    }

    // ENHANCED pre-play-down logic - MUCH more aggressive
    if (!bot.hasPlayedDown) {
      final playDownRequirement = gameState.playDownRequirement;
      final currentMeldPotential = _calculateCurrentMeldPotential(bot, context);

      // If pile helps meet play-down requirement, be EXTREMELY aggressive
      if (currentMeldPotential + (pileValue * 0.4) >= playDownRequirement) {
        adjustedValueThreshold *=
            0.2; // EXTREMELY aggressive for play-down opportunities
      }

      // OVERRIDE: Make all personalities much more aggressive about discard pile
      final aggressiveMultiplier =
          0.4; // Extremely aggressive for all personalities

      return pileValue > adjustedValueThreshold * aggressiveMultiplier ||
          pileSize >=
              BotConfig
                  .minimumDiscardPileSize; // Take any pile with minimum cards if not played down
    }

    // Enhanced post-play-down logic - consider hand management and foot transition
    final isInFoot = bot.hasPickedUpFoot;
    final handSize = bot.currentHand.length;

    // NEW: FOOT PHASE URGENCY - if in foot with few cards, prioritize going out
    if (isInFoot && handSize <= BotConfig.footPhaseUrgencyThreshold) {
      // Check if we should be rushing to go out instead of taking discard pile
      if (handSize <= 2 && bot.canGoOutWithBooks) {
        return false; // Don't take pile, focus on going out
      }
      return pileValue >
          adjustedValueThreshold *
              BotConfig
                  .aggressiveDiscardMultiplier; // Actually MORE aggressive in foot
    }

    // If hand is getting large, prioritize pile taking to prevent getting stuck
    if (handSize >= 15) {
      adjustedValueThreshold *= 0.6; // Very aggressive with large hands
      adjustedSizeThreshold *= 0.7; // Lower threshold to prevent hand overflow
    }

    // Standard post-play-down thresholds with competitive adjustments
    return pileValue >
            adjustedValueThreshold * 0.7 || // 30% lower value threshold
        pileSize >=
            (adjustedSizeThreshold - 2).clamp(
              2,
              adjustedSizeThreshold,
            ); // Even lower size threshold
  }

  /// Check if bot could unlock discard pile if they had already played down
  bool _couldUnlockDiscardPileIfPlayedDown(Player bot, GameState gameState) {
    if (gameState.discardPile.isEmpty) return false;
    final topCard = gameState.topDiscard;
    if (topCard == null || topCard.isWild || topCard.isThree) return false;

    // Check if player has at least 2 matching natural cards
    final matchingCards = bot.currentHand
        .where((card) => card.rank == topCard.rank && !card.isWild)
        .toList();

    return matchingCards.length >= 2;
  }

  /// Find best natural meld combination for play-down
  /// Enhanced to prefer having both clean and mixed melds for book diversity
  List<List<PlayingCard>> _findBestNaturalCombination(
    List<List<PlayingCard>> naturalMelds,
    int requirement,
  ) {
    if (naturalMelds.isEmpty) return [];

    // Try single melds first
    for (final meld in naturalMelds) {
      final value = _meldAnalyzer.calculateTotalMeldValue([meld]);
      if (value >= requirement) {
        return [meld];
      }
    }

    // Try two-meld combinations - prefer one clean and one that could become dirty
    List<List<PlayingCard>>? bestMixedCombination;
    int bestMixedScore = 0;

    for (int i = 0; i < naturalMelds.length; i++) {
      for (int j = i + 1; j < naturalMelds.length; j++) {
        final combination = [naturalMelds[i], naturalMelds[j]];
        final value = _meldAnalyzer.calculateTotalMeldValue(combination);
        if (value >= requirement) {
          // Check if this gives us meld diversity (different ranks)
          final rank1 = naturalMelds[i].first.rank;
          final rank2 = naturalMelds[j].first.rank;

          // Score based on potential for book diversity
          int score = value;
          if (rank1 != rank2) score += 50; // Bonus for different ranks

          // Extra bonus if one meld is larger (closer to book)
          if (naturalMelds[i].length >= 5 || naturalMelds[j].length >= 5) {
            score += 30;
          }

          if (score > bestMixedScore) {
            bestMixedScore = score;
            bestMixedCombination = combination;
          }
        }
      }
    }

    if (bestMixedCombination != null) {
      return bestMixedCombination;
    }

    return [];
  }

  /// Choose the best card to discard
  PlayingCard? _chooseCardToDiscard(Player bot, GameState gameState) {
    final hand = bot.currentHand;
    // Safe guard against empty hands - return null instead of crashing
    if (hand.isEmpty) {
      return null;
    }

    // Use enhanced discard analyzer for smarter decisions
    // This considers opponent needs and defensive discarding
    try {
      final smartDiscard = _discardAnalyzer.chooseCardToDiscard(
        bot,
        gameState,
        analyzer: _gameAnalyzer,
      );
      // Log defensive discard decisions in debug mode
      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'Smart discard selected: ${smartDiscard.displayName}',
      );
      return smartDiscard;
    } catch (e) {
      // Fall back to legacy logic if analyzer fails
      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'Smart discard failed ($e), using legacy logic',
      );
    }

    // COMPETITIVE ENHANCEMENT: Check if bot should rush to go out
    final shouldRush = _shouldRushToGoOut(bot, gameState);

    // COMPETITIVE URGENCY: Check if opponents are close to winning
    final maxOpponentScore = gameState.players
        .where((p) => p.id != bot.id)
        .map((p) => p.score)
        .fold(0, (max, score) => score > max ? score : max);
    final isUnderSeverePressure = maxOpponentScore >= 7500;

    // Enhanced Priority 1: Discard 3s aggressively when rushing or under pressure
    final threes = hand.where((card) => card.rank == CardRank.three).toList();
    if (threes.isNotEmpty) {
      // When rushing to go out or under severe pressure, prioritize getting rid of 3s quickly
      if (shouldRush || isUnderSeverePressure) {
        // Sort by point value (most negative first) - red 3s are worse penalties
        threes.sort((a, b) => a.pointValue.compareTo(b.pointValue));
        return threes.first; // Always take worst 3 first when rushing
      }

      // Normal 3s discard logic
      threes.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      final bestValue = threes.first.pointValue;
      final bestThrees = threes
          .where((card) => card.pointValue == bestValue)
          .toList();
      return _selectRandomly(bestThrees) ??
          threes.first; // Fallback to first 3 if selection fails
    }

    // Priority 2: Check if we should hold wild cards strategically
    final wildCards = hand.where((card) => card.isWild).toList();
    final stillOnHandPile = bot.hasPlayedDown && !bot.hasPickedUpFoot;

    // If we're still on hand pile and have wild cards, keep them for foot transition
    // unless we have too many (excessive holding is bad)
    if (stillOnHandPile && wildCards.isNotEmpty && wildCards.length < 8) {
      // Don't discard wilds - they're valuable for foot transition
      // Continue to find other cards to discard
    }

    // Priority 3: ENHANCED discard logic with clean book preservation
    final rankCounts = <CardRank, int>{};
    for (final card in hand) {
      if (!card.isWild) {
        rankCounts[card.rank] = (rankCounts[card.rank] ?? 0) + 1;
      }
    }

    // Check if bot has clean books for strategic decision-making
    final hasCleanBook = bot.melds.any((m) => m.isClean && m.cards.length >= 7);
    final cleanMeldsNearBook = bot.melds
        .where((m) => m.isClean && m.cards.length >= 5)
        .toList();

    // Find singletons but PROTECT potential clean book cards
    final protectedSingletons = <PlayingCard>[];
    final safeSingletons = <PlayingCard>[];

    for (final card in hand) {
      if (!card.isWild && (rankCounts[card.rank] ?? 0) <= 1) {
        // Check if this card could help complete a clean meld
        final couldHelpCleanMeld = cleanMeldsNearBook.any(
          (meld) => meld.rank == card.rank && !card.isWild,
        );

        if (!hasCleanBook && couldHelpCleanMeld) {
          protectedSingletons.add(card); // Protect for clean book building
        } else {
          safeSingletons.add(card); // Safe to discard
        }
      }
    }

    // COMPETITIVE URGENCY: Under severe pressure, still prioritize 3s but be more aggressive with singletons
    if (isUnderSeverePressure && safeSingletons.isNotEmpty) {
      // Even under pressure, prioritize penalty cards first if any exist in safe singletons
      final penaltyCards = safeSingletons
          .where((card) => card.rank == CardRank.three)
          .toList();
      if (penaltyCards.isNotEmpty) {
        DebugLogger.debug(
          '${bot.name}: Under severe pressure but still prioritizing 3s',
        );
        return penaltyCards.first;
      }

      // If no 3s in safe singletons, then discard highest value
      safeSingletons.sort((a, b) => b.pointValue.compareTo(a.pointValue));
      DebugLogger.debug(
        '${bot.name}: Under severe pressure - discarding high-value card ${safeSingletons.first.displayName}',
      );
      return safeSingletons.first;
    }

    // Normal case: Prefer safe singletons with lowest point value
    if (safeSingletons.isNotEmpty) {
      safeSingletons.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      final bestValue = safeSingletons.first.pointValue;
      final bestSingletons = safeSingletons
          .where((card) => card.pointValue == bestValue)
          .toList();
      return _selectRandomly(bestSingletons) ??
          safeSingletons.first; // Fallback to first safe singleton
    }

    // If no safe singletons, use protected ones only if absolutely necessary
    if (protectedSingletons.isNotEmpty) {
      protectedSingletons.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      final bestValue = protectedSingletons.first.pointValue;
      final bestProtected = protectedSingletons
          .where((card) => card.pointValue == bestValue)
          .toList();
      return _selectRandomly(bestProtected) ??
          protectedSingletons.first; // Fallback to first protected
    }

    // Fallback: Discard lowest value card (ALWAYS avoid wilds unless no choice)
    List<PlayingCard> sortedHand = List<PlayingCard>.from(
      hand.where((card) => !card.isWild),
    );

    if (sortedHand.isEmpty) {
      // Emergency: Only wilds left, must discard lowest value wild
      sortedHand = List<PlayingCard>.from(hand);
    }

    sortedHand.sort((a, b) => a.pointValue.compareTo(b.pointValue));
    // Add variability: if there are multiple cards of the same low value, randomly pick one
    final bestValue = sortedHand.first.pointValue;
    final bestCards = sortedHand
        .where((card) => card.pointValue == bestValue)
        .toList();
    return _selectRandomly(bestCards) ??
        sortedHand.first; // Fallback to first card
  }

  /// Whether the bot is in the human-style hand-building window (draw/discards, few melds).
  bool _isInHumanAccumulationWindow(Player bot, BotGameContext context) {
    if (!bot.hasPlayedDown || _opponentOnFootPressure(context, bot)) {
      return false;
    }
    final handSize = bot.currentHand.length;
    if (bot.hasPickedUpFoot &&
        handSize >= BotConfig.footPhaseAggressiveMeldingThreshold) {
      return false;
    }
    return handSize >= BotConfig.humanAccumulationMinHand &&
        handSize <= BotConfig.humanAccumulationMaxHand;
  }

  /// Human analytics: accumulate in 8–14 range unless bursting at threshold.
  bool _shouldAccumulateHandLikeHuman(Player bot, BotGameContext context) {
    if (!_isInHumanAccumulationWindow(bot, context)) {
      return false;
    }
    if (_shouldExecuteDumpStrategy(bot, context)) {
      return false;
    }

    // On hand pile without books — meld toward play-down/books, don't hoard
    if (bot.hasPlayedDown && !bot.hasPickedUpFoot) {
      final bookCount = bot.melds.where((m) => m.cards.length >= 7).length;
      if (bookCount == 0) {
        return false;
      }
    }

    // Allow trimming melds that drop hand below accumulation window (e.g. 8→5)
    final controller = context.controller as GameController?;
    if (controller != null) {
      final melds = _getCachedPossibleMelds(bot, context);
      if (melds.isNotEmpty) {
        final bestMeld = _meldAnalyzer.findBestMeld(melds, bot: bot);
        final handAfterMeld = bot.currentHand.length - bestMeld.length;
        if (handAfterMeld < BotConfig.humanAccumulationMinHand) {
          return false;
        }
      }
    }

    return true;
  }

  /// Strategic holding decision: Should bot hold cards instead of melding immediately?
  /// This implements the superior "accumulate-and-dump" strategy for better discard pile unlocking
  /// Enhanced with personality-based holding tolerance and time-based pressure
  bool _shouldHoldCardsStrategically(Player bot, BotGameContext context) {
    final gameState = context.gameState;
    final handSize = bot.currentHand.length;
    final turnCount = _gameAnalyzer.getTurnCount(bot.id);
    final personality = _personalityManager.getPersonality(bot.id);

    if (handSize == 0) {
      return false;
    }

    if (_shouldCompleteHandPileForFoot(bot, context)) {
      return false;
    }

    // On foot without both book types — keep melding, never hoard toward go-out
    if (bot.hasPickedUpFoot && !bot.canGoOutWithBooks) {
      return false;
    }

    // Calculate time-based pressure: worry more the longer we've been in hand without reaching foot
    final timePressure = _calculateTimePressure(bot, turnCount, personality);
    final personalityHoldingLimit = _getPersonalityHoldingLimit(
      personality,
      timePressure,
    );

    // Don't hold if hand exceeds personality-based limit (adjusted for time pressure)
    if (handSize >= personalityHoldingLimit) return false;

    // Never hold a tiny hand pile — finish the transition
    if (!bot.hasPickedUpFoot) {
      if (handSize <= BotConfig.handToFootCriticalHandSize) {
        return false;
      }
      if (personality == BotPersonality.aggressive &&
          handSize <= BotConfig.handToFootRushAggressiveThreshold) {
        return false;
      }
      // Played down but no books yet — keep melding, don't hoard on hand pile
      final bookCount = bot.melds.where((m) => m.cards.length >= 7).length;
      if (bot.hasPlayedDown && bookCount == 0 && handSize <= 7) {
        return false;
      }
    }

    // Race to foot when opponents are already on foot (human-style tempo play)
    if (_opponentOnFootPressure(context, bot) && !bot.hasPickedUpFoot) {
      return false;
    }

    // Never hold large hands on foot — must melt down to go out (all personalities)
    if (bot.hasPickedUpFoot &&
        handSize >= BotConfig.footPhaseAggressiveMeldingThreshold) {
      return false;
    }

    // Don't hold if opponents are close to going out (competitive pressure)
    _gameAnalyzer.updateOpponentAnalysis(gameState, bot);
    final opponentAnalysis = _gameAnalyzer.opponentAnalysis;
    for (final analysis in opponentAnalysis.values) {
      if (analysis.handSize <= 3) return false; // Opponent close to going out
    }

    // Hold cards if we have good discard pile unlocking potential
    final unlockPotential = _calculateDiscardPileUnlockPotential(
      bot,
      gameState,
    );

    // Hold if we have decent hand size for unlocking opportunities
    // More cards = more potential matches for discard pile
    if (handSize >= 10 && unlockPotential >= 3) {
      return true; // Increased thresholds to be more aggressive
    }

    // Be more aggressive about round requirements - don't hold as much
    final playDownRequirement = gameState.playDownRequirement;
    if (handSize >= 12 &&
        _shouldHoldForRoundRequirement(
          bot,
          context,
          playDownRequirement,
          handSize,
        )) {
      return true; // Only hold if hand is already large
    }

    // Strategic book completion: hold if we can complete books in later rounds
    if (_shouldHoldForBookCompletion(bot, gameState, personality)) {
      return true;
    }

    // Hold if we can potentially dump everything soon
    final dumpPotential = _calculateDumpPotential(bot, context);
    if (dumpPotential >= 0.8) {
      return true; // Increased threshold - be more selective about holding
    }

    return false;
  }

  /// Should execute dump strategy: meld everything and go to foot
  bool _shouldExecuteDumpStrategy(Player bot, BotGameContext context) {
    final gameState = context.gameState;
    final handSize = bot.currentHand.length;
    final playDownRequirement = gameState.playDownRequirement;
    final stillOnHandPile = bot.hasPlayedDown && !bot.hasPickedUpFoot;
    final wildCards = bot.currentHand.where((c) => c.isWild).toList();

    // For initial play-down: check if we have enough meld potential for the round requirement
    if (!bot.hasPlayedDown) {
      final currentMeldPoints = _calculateCurrentMeldPotential(bot, context);
      // Only dump if we can meet the round requirement
      if (currentMeldPoints >= playDownRequirement) return true;
      return false; // Keep accumulating if we can't meet the requirement
    }

    // CRITICAL: If can go out, prioritize going out over accumulation
    if (bot.canGoOut && handSize <= 8) {
      DebugLogger.debug(
        '${bot.name}: Should prioritize going out over more accumulation',
      );
      return false; // Don't hold - prioritize discarding to go out
    }

    // Human pattern: burst-meld at ~15+ cards (matches 660 analytics events)
    if (handSize >= BotConfig.humanBurstMeldHandThreshold &&
        bot.hasPlayedDown) {
      final burstPotential = _calculateDumpPotential(bot, context);
      if (burstPotential >= BotConfig.humanBurstDumpPotential) {
        return true;
      }
      if (handSize >= BotConfig.humanBurstMeldHandThreshold + 2) {
        return true;
      }
    }

    // ENHANCED: Under competitive pressure, dump much more aggressively
    final dumpPotential = _calculateDumpPotential(bot, context);
    final maxOpponentScore = gameState.players
        .where((p) => p.id != bot.id)
        .map((p) => p.score)
        .fold(0, (max, score) => score > max ? score : max);

    final competitivePressureThreshold = maxOpponentScore >= 6500
        ? BotConfig.humanBurstMeldHandThreshold - 2
        : BotConfig.humanBurstMeldHandThreshold;

    // Burst when hand reaches human-style threshold (analytics: ~15 cards)
    if (handSize >= competitivePressureThreshold && bot.hasPlayedDown) {
      return true;
    }

    // NEW: Be more aggressive if on hand pile with wilds and close to foot
    if (stillOnHandPile && wildCards.isNotEmpty && handSize <= 10) {
      // If we have wilds and are close to foot, dump everything we can
      if (dumpPotential >= 0.5) return true; // Even lower threshold with wilds
    }

    final personality = _personalityManager.getPersonality(bot.id);

    // Never stall on a tiny hand pile
    if (stillOnHandPile && handSize <= BotConfig.handToFootCriticalHandSize) {
      return true;
    }

    // Opponent on foot — race to pick up foot before they go out
    if (stillOnHandPile &&
        _opponentOnFootPressure(context, bot) &&
        handSize <= BotConfig.handToFootRushOpponentOnFootThreshold) {
      return true;
    }

    // Aggressive bots transition earlier, especially under foot pressure
    if (stillOnHandPile && personality == BotPersonality.aggressive) {
      if (handSize <= BotConfig.handToFootRushAggressiveThreshold) {
        return true;
      }
      if (_opponentOnFootPressure(context, bot) &&
          handSize <=
              BotConfig.handToFootRushOpponentOnFootThreshold +
                  BotConfig.handToFootRushAggressiveOpponentPressureMargin) {
        return true;
      }
    }

    // Execute if we can go directly to foot
    final possibleMelds = _getCachedPossibleMelds(bot, context);
    final controller = context.controller as GameController?;
    if (controller == null) return false;
    final cardsToAdd = _meldAnalyzer.findCardsToAddToExistingMelds(
      bot,
      controller,
    );
    final totalMeldableCards =
        possibleMelds.fold<int>(0, (sum, meld) => sum + meld.length) +
        cardsToAdd.length;

    if (totalMeldableCards >= handSize - 1) {
      return true; // Can meld all but 1 card
    }

    return false;
  }

  /// Execute dump strategy: create all possible melds in this turn
  /// Enhanced with competitive book balance analysis
  BotDecision _executeDumpStrategy(Player bot, BotGameContext context) {
    // Enhanced book analysis
    final bookStatus = _analyzeBookRequirements(bot);
    final needsCleanBook = bookStatus['needsCleanBook'] as bool;
    final needsDirtyBook = bookStatus['needsDirtyBook'] as bool;
    final hasRequiredBooks = bookStatus['hasRequiredBooks'] as bool;

    // Priority 1: Add to existing melds with strategic book balance
    final controller = context.controller as GameController?;
    if (controller == null) return BotDecision(action: 'noMeld');
    final rawCardsToAdd = _meldAnalyzer.findCardsToAddToExistingMelds(
      bot,
      controller,
    );
    final cardsToAdd = _filterWildCardAdditions(rawCardsToAdd, bot);
    if (cardsToAdd.isNotEmpty) {
      // NEW: If bot has sufficient books (4+), prioritize any addition for going out
      final totalBooks = bot.melds.where((m) => m.isBook).length;
      if (hasRequiredBooks && totalBooks >= 4) {
        DebugLogger.debug(
          '${bot.name}: Has $totalBooks books - adding any card to reduce hand size',
        );
        return BotDecision(action: 'addToMeld', data: cardsToAdd.first);
      }

      // Strategic addition based on book requirements
      for (final addition in cardsToAdd) {
        final meld = addition['meld'] as Meld;
        final card = addition['card'] as PlayingCard;

        // If we need a clean book, prioritize keeping clean melds clean
        if (needsCleanBook && meld.isClean && !card.isWild) {
          return BotDecision(action: 'addToMeld', data: addition);
        }

        // If we need a dirty book, prioritize adding to dirty melds
        if (needsDirtyBook && !meld.isClean) {
          return BotDecision(action: 'addToMeld', data: addition);
        }

        // If we have both book types, prioritize largest melds for efficiency
        if (hasRequiredBooks && meld.cards.length >= 6) {
          return BotDecision(action: 'addToMeld', data: addition);
        }
      }

      // If no strategic match, take the first good addition
      return BotDecision(action: 'addToMeld', data: cardsToAdd.first);
    }

    // Priority 2: Create new melds with enhanced book balance strategy
    final handSize = bot.currentHand.length;

    // Human-style burst: multi-meld when hand is large enough
    if (handSize >= BotConfig.humanBurstMeldHandThreshold &&
        bot.hasPlayedDown) {
      final maximalMelds = _meldAnalyzer.findMaximalMeldCombination(
        bot,
        controller,
      );
      if (maximalMelds.isNotEmpty && maximalMelds.length >= 2) {
        DebugLogger.botDebug(
          bot.id,
          bot.name,
          'DUMP STRATEGY: Using maximal meld combination (${maximalMelds.length} melds) for hand size $handSize',
        );

        return BotDecision(action: 'createMultipleMelds', data: maximalMelds);
      }
    }

    final possibleMelds = _getCachedPossibleMelds(bot, context);
    if (possibleMelds.isNotEmpty) {
      // NEW: If bot has sufficient books (4+), create any meld to reduce hand size
      final totalBooks = bot.melds.where((m) => m.isBook).length;
      if (hasRequiredBooks && totalBooks >= 4) {
        DebugLogger.debug(
          '${bot.name}: Has $totalBooks books - creating any meld to reduce hand size',
        );
        return BotDecision(
          action: 'createMeld',
          data: _selectBestNewMeld(bot, possibleMelds),
        );
      }

      // Select meld type based on book requirements for competitive advantage
      List<PlayingCard>? strategicMeld;

      if (needsCleanBook) {
        final cleanCandidates = possibleMelds
            .where((meld) => !meld.any((card) => card.isWild))
            .toList();
        if (cleanCandidates.isNotEmpty) {
          strategicMeld = _selectBestNewMeld(bot, cleanCandidates);
        }
      } else if (needsDirtyBook) {
        final dirtyCandidates = possibleMelds
            .where((meld) => meld.any((card) => card.isWild))
            .toList();
        if (dirtyCandidates.isNotEmpty) {
          strategicMeld = _selectBestNewMeld(bot, dirtyCandidates);
        }
      }

      final selectedMeld =
          strategicMeld ?? _selectBestNewMeld(bot, possibleMelds);

      return BotDecision(action: 'createMeld', data: selectedMeld);
    }

    return BotDecision(action: 'noMeld');
  }

  /// Calculate potential for unlocking discard pile based on hand composition
  int _calculateDiscardPileUnlockPotential(Player bot, GameState gameState) {
    if (gameState.discardPile.isEmpty) return 0;

    final topCard = gameState.discardPile.last;
    final hand = bot.currentHand;

    // Count potential matching cards for unlocking
    int potential = 0;
    final rankCounts = <CardRank, int>{};

    for (final card in hand) {
      if (!card.isWild && !card.isThree) {
        rankCounts[card.rank] = (rankCounts[card.rank] ?? 0) + 1;
      }
    }

    // Check if we can unlock with the top card
    if (!topCard.isWild && !topCard.isThree) {
      final matchingCards = rankCounts[topCard.rank] ?? 0;
      if (matchingCards >= 2) {
        potential += 2; // Increased from 1 - Can unlock is very valuable
      }

      // Bonus for each additional matching card (more flexible unlocking)
      potential += (matchingCards - 2).clamp(0, 4); // Increased max bonus
    }

    // General unlock potential (pairs that could match future discards)
    for (final count in rankCounts.values) {
      if (count >= 2) potential++; // Each pair increases unlock potential
      if (count >= 3) potential++; // Extra bonus for triplets
    }

    // Bonus for wild cards (can help with unlocking)
    final wildCount = hand.where((card) => card.isWild).length;
    potential += (wildCount / 3).floor(); // Every 3 wilds adds potential

    return potential;
  }

  /// Calculate what percentage of hand can be melded (0.0 to 1.0)
  double _calculateDumpPotential(Player bot, BotGameContext context) {
    final handSize = bot.currentHand.length;
    if (handSize == 0) return 1.0;

    final possibleMelds = _getCachedPossibleMelds(bot, context);
    final controller = context.controller as GameController?;
    if (controller == null) return 0.0;
    final cardsToAdd = _meldAnalyzer.findCardsToAddToExistingMelds(
      bot,
      controller,
    );

    final meldableCards =
        possibleMelds.fold<int>(0, (sum, meld) => sum + meld.length) +
        cardsToAdd.length;

    return (meldableCards / handSize).clamp(0.0, 1.0);
  }

  /// Check if bot can play ALL cards to immediately transition to foot
  BotDecision? _checkCanPlayAllCards(Player bot, BotGameContext context) {
    final handSize = bot.currentHand.length;
    if (handSize == 0) {
      return null;
    }

    final controller = context.controller as GameController?;
    if (controller == null) {
      return null;
    }

    if (handSize == 1) {
      final cardsToAdd = _meldAnalyzer.findCardsToAddToExistingMelds(
        bot,
        controller,
      );
      if (cardsToAdd.isNotEmpty) {
        return BotDecision(action: 'addToMeld', data: cardsToAdd.first);
      }
    }

    final meldIndexPlan = _findCompleteHandMeldIndexPlan(bot);
    if (meldIndexPlan == null) {
      return null;
    }

    final meldCards = meldIndexPlan
        .map(
          (indices) => indices.map((index) => bot.currentHand[index]).toList(),
        )
        .toList();

    if (meldCards.length == 1) {
      return BotDecision(action: 'createMeld', data: meldCards.first);
    }

    return BotDecision(action: 'createMultipleMelds', data: meldCards);
  }

  /// Builds index-based new-meld candidates, preserving duplicate-deck cards.
  List<List<int>> _buildNewMeldIndexCandidates(Player bot) {
    final hand = bot.currentHand;
    final cardsByRank = <CardRank, List<int>>{};
    final wildIndices = <int>[];

    for (int i = 0; i < hand.length; i++) {
      final card = hand[i];
      if (card.isWild) {
        wildIndices.add(i);
      } else if (card.rank != CardRank.three) {
        cardsByRank.putIfAbsent(card.rank, () => []).add(i);
      }
    }

    final candidates = <List<int>>[];
    for (final entry in cardsByRank.entries) {
      final naturalIndices = entry.value;
      if (naturalIndices.length >= GameConfig.minTotalCardsForMeld) {
        candidates.add(List<int>.from(naturalIndices));
        continue;
      }

      if (naturalIndices.length >= GameConfig.minNaturalCardsForMeld &&
          wildIndices.isNotEmpty) {
        final wildsNeeded =
            GameConfig.minTotalCardsForMeld - naturalIndices.length;
        final availableWilds = wildIndices.take(wildsNeeded).toList();
        if (availableWilds.length == wildsNeeded) {
          candidates.add([...naturalIndices, ...availableWilds]);
        }
      }
    }

    return candidates;
  }

  /// Returns disjoint meld index groups that consume the entire hand, if any.
  List<List<int>>? _findCompleteHandMeldIndexPlan(Player bot) {
    final handSize = bot.currentHand.length;
    if (handSize == 0) {
      return null;
    }

    final candidates = _buildNewMeldIndexCandidates(bot);
    if (candidates.isEmpty) {
      return null;
    }

    final usedIndices = <int>{};
    final selectedMelds = <List<int>>[];
    List<List<int>>? completePlan;

    bool search(int candidateStart) {
      if (usedIndices.length == handSize) {
        completePlan = selectedMelds
            .map((indices) => List<int>.from(indices))
            .toList();
        return true;
      }

      for (int i = candidateStart; i < candidates.length; i++) {
        final meldIndices = candidates[i];
        if (meldIndices.any(usedIndices.contains)) {
          continue;
        }

        final cards = meldIndices
            .map((index) => bot.currentHand[index])
            .toList();
        if (Meld.createMeld(cards) == null) {
          continue;
        }

        selectedMelds.add(meldIndices);
        usedIndices.addAll(meldIndices);
        if (search(i + 1)) {
          return true;
        }
        usedIndices.removeAll(meldIndices);
        selectedMelds.removeLast();
      }

      return false;
    }

    if (!search(0)) {
      return null;
    }

    return completePlan;
  }

  /// True when the bot should melt its hand pile down to pick up foot urgently.
  bool _shouldRushHandToFoot(Player bot, BotGameContext context) {
    if (!bot.hasPlayedDown || bot.hasPickedUpFoot) {
      return false;
    }

    final handSize = bot.currentHand.length;
    if (handSize == 0) {
      return false;
    }

    if (handSize <= BotConfig.handToFootCriticalHandSize) {
      return true;
    }

    if (_opponentOnFootPressure(context, bot) &&
        handSize <= BotConfig.handToFootRushOpponentOnFootThreshold) {
      return true;
    }

    final personality = _personalityManager.getPersonality(bot.id);
    if (personality == BotPersonality.aggressive) {
      if (handSize <= BotConfig.handToFootRushAggressiveThreshold) {
        return true;
      }
      if (_opponentOnFootPressure(context, bot) &&
          handSize <=
              BotConfig.handToFootRushOpponentOnFootThreshold +
                  BotConfig.handToFootRushAggressiveOpponentPressureMargin) {
        return true;
      }
    }

    return false;
  }

  /// Melt the hand pile aggressively to reach foot before opponents go out.
  BotDecision? _makeHandToFootRushDecision(Player bot, BotGameContext context) {
    if (!_shouldRushHandToFoot(bot, context)) {
      return null;
    }

    DebugLogger.botDebug(
      bot.id,
      bot.name,
      'RUSH HAND→FOOT with ${bot.currentHand.length} cards',
    );

    final playAllDecision = _checkCanPlayAllCards(bot, context);
    if (playAllDecision != null) {
      return playAllDecision;
    }

    if (_shouldExecuteDumpStrategy(bot, context)) {
      final dumpDecision = _executeDumpStrategy(bot, context);
      if (dumpDecision.action != 'noMeld') {
        return dumpDecision;
      }
    }

    final controller = context.controller as GameController?;
    if (controller == null) {
      return null;
    }

    final handSize = bot.currentHand.length;
    final maximalMeldsDecision = _tryMaximalMeldsForHandPileCompletion(
      bot,
      controller,
      handSize,
      context,
    );
    if (maximalMeldsDecision != null) {
      return maximalMeldsDecision;
    }

    final cardsToAdd = _filterWildCardAdditions(
      _meldAnalyzer.findCardsToAddToExistingMelds(bot, controller),
      bot,
    );
    if (cardsToAdd.isNotEmpty) {
      return BotDecision(action: 'addToMeld', data: cardsToAdd.first);
    }

    final possibleMelds = _getCachedPossibleMelds(bot, context);
    if (possibleMelds.isNotEmpty) {
      return BotDecision(
        action: 'createMeld',
        data: _meldAnalyzer.findBestMeld(
          possibleMelds,
          bot: bot,
          preferLarger: true,
        ),
      );
    }

    final footTransition = _footTransitionManager.handleFootTransition(
      bot,
      controller,
    );
    if (footTransition != null) {
      return footTransition;
    }

    return null;
  }

  /// True when bot should empty the hand pile to pick up foot (any personality).
  bool _shouldCompleteHandPileForFoot(Player bot, BotGameContext context) {
    if (!bot.hasPlayedDown || bot.hasPickedUpFoot) {
      return false;
    }
    final handSize = bot.currentHand.length;
    if (handSize == 0) {
      return false;
    }
    if (handSize <= BotConfig.handPileFootCompletionMaxHand) {
      return true;
    }
    if (_opponentOnFootPressure(context, bot) &&
        handSize <= BotConfig.handToFootRushOpponentOnFootThreshold) {
      return true;
    }
    return false;
  }

  /// Multi-meld / sequential rush to clear hand pile and trigger foot pickup.
  BotDecision? _makeCompleteHandPileForFootDecision(
    Player bot,
    BotGameContext context,
  ) {
    if (!_shouldCompleteHandPileForFoot(bot, context)) {
      return null;
    }

    DebugLogger.botDebug(
      bot.id,
      bot.name,
      'HAND PILE→FOOT completion with ${bot.currentHand.length} cards',
    );

    final playAllDecision = _checkCanPlayAllCards(bot, context);
    if (playAllDecision != null) {
      return playAllDecision;
    }

    final controller = context.controller as GameController?;
    if (controller == null) {
      return null;
    }

    final handSize = bot.currentHand.length;
    final maximalMeldsDecision = _tryMaximalMeldsForHandPileCompletion(
      bot,
      controller,
      handSize,
      context,
    );
    if (maximalMeldsDecision != null) {
      return maximalMeldsDecision;
    }

    final rush = _makeHandToFootRushDecision(bot, context);
    if (rush != null) {
      return rush;
    }

    final cardsToAdd = _filterWildCardAdditions(
      _meldAnalyzer.findCardsToAddToExistingMelds(bot, controller),
      bot,
    );
    if (cardsToAdd.isNotEmpty) {
      return BotDecision(action: 'addToMeld', data: cardsToAdd.first);
    }

    final possibleMelds = _getCachedPossibleMelds(bot, context);
    if (possibleMelds.isNotEmpty) {
      return BotDecision(
        action: 'createMeld',
        data: _meldAnalyzer.findBestMeld(
          possibleMelds,
          bot: bot,
          preferLarger: true,
        ),
      );
    }

    final footTransition = _footTransitionManager.handleFootTransition(
      bot,
      controller,
    );
    if (footTransition != null) {
      return footTransition;
    }

    return null;
  }

  /// On final turn after another player went out: meld all scorable cards.
  BotDecision _makeFinalTurnScoringDecision(
    Player bot,
    BotGameContext context,
  ) {
    final gameState = context.gameState;
    final controller = context.controller as GameController?;

    switch (gameState.turnPhase) {
      case TurnPhase.draw:
        return BotDecision(action: 'drawFromDeck');
      case TurnPhase.meld:
        if (bot.currentHand.isEmpty) {
          return BotDecision(action: 'noMeld');
        }
        if (controller != null) {
          final playAll = _checkCanPlayAllCards(bot, context);
          if (playAll != null) {
            return playAll;
          }

          final maximalMelds = _meldAnalyzer.findMaximalMeldCombination(
            bot,
            controller,
          );
          if (maximalMelds.length >= 2) {
            return BotDecision(
              action: 'createMultipleMelds',
              data: maximalMelds,
            );
          }

          final cardsToAdd = _meldAnalyzer.findCardsToAddToExistingMelds(
            bot,
            controller,
          );
          if (cardsToAdd.isNotEmpty) {
            return BotDecision(action: 'addToMeld', data: cardsToAdd.first);
          }

          final possibleMelds = _getCachedPossibleMelds(bot, context);
          if (possibleMelds.isNotEmpty) {
            return BotDecision(
              action: 'createMeld',
              data: _meldAnalyzer.findBestMeld(
                possibleMelds,
                bot: bot,
                preferLarger: true,
              ),
            );
          }
        }
        return BotDecision(action: 'noMeld');
      case TurnPhase.discard:
        return _makeDiscardDecision(bot, context);
    }
  }

  /// Determine if we should hold cards based on round play-down requirements
  bool _shouldHoldForRoundRequirement(
    Player bot,
    BotGameContext context,
    int requirement,
    int handSize,
  ) {
    // Calculate current meld potential points
    final currentMeldPoints = _calculateCurrentMeldPotential(bot, context);

    // More aggressive round-specific strategy
    if (requirement <= 60) {
      // Round 1: 60 points - can often be done with 1 good meld
      // Hold if we're close but not quite there
      final isCloseToRequirement =
          currentMeldPoints >= 45 && currentMeldPoints < 60;
      final hasSufficientHandSize = handSize >= 6;
      return isCloseToRequirement && hasSufficientHandSize;
    } else if (requirement <= 90) {
      // Round 2: 90 points - usually needs 2 melds
      // More aggressive - lower thresholds
      final isInGoodRange = currentMeldPoints >= 60 && currentMeldPoints < 90;
      final hasLargeEnoughHand = handSize >= 8;
      return isInGoodRange && hasLargeEnoughHand;
    } else if (requirement <= 120) {
      // Round 3: 120 points - definitely needs multiple melds
      // More aggressive - lower hand size requirement
      return currentMeldPoints >= 80 &&
          currentMeldPoints < 120 &&
          handSize >= 9;
    } else {
      // Round 4+: 150+ points - requires significant accumulation
      // More aggressive - lower requirements
      return currentMeldPoints >= 100 &&
          currentMeldPoints < requirement &&
          handSize >= 11;
    }
  }

  /// Calculate total points from all possible melds we could make right now
  int _calculateCurrentMeldPotential(Player bot, BotGameContext context) {
    int totalPoints = 0;

    // Points from cards we could add to existing melds
    final controller = context.controller as GameController?;
    if (controller == null) return 0;
    final cardsToAdd = _meldAnalyzer.findCardsToAddToExistingMelds(
      bot,
      controller,
    );
    for (final addition in cardsToAdd) {
      final card = addition['card'] as PlayingCard;
      totalPoints += card.pointValue;
    }

    // Points from new melds we could create
    final possibleMelds = _getCachedPossibleMelds(bot, context);
    for (final meld in possibleMelds) {
      int meldValue = 0;
      for (final card in meld) {
        meldValue += card.pointValue;
      }
      // Add book bonus if meld is large enough
      if (meld.length >= GameConfig.bookSize) {
        // Estimate if it would be clean or dirty (simplified)
        final hasWilds = meld.any((card) => card.isWild);
        meldValue += hasWilds
            ? GameConfig.dirtyBookBonus
            : GameConfig.cleanBookBonus;
      }
      totalPoints += meldValue;
    }

    return totalPoints;
  }

  /// Assign personalities to bot players
  void assignPersonality(String playerId, BotPersonality personality) {
    _personalityManager.assignPersonality(playerId, personality);
  }

  /// Auto-assign random personalities to bot players
  void assignRandomPersonalities(List<Player> botPlayers) {
    _personalityManager.assignRandomPersonalities(botPlayers);
  }

  /// Clear all game data when game ends
  void clearGameData() {
    _personalityManager.clearPersonalityData();
    _gameAnalyzer.clearAnalysisData();
    _meldAnalyzer.clearCache();
    _plannedMelds = null;
    _inMultiMeldSequence = false;
    // Clear pressure analysis caches to prevent state contamination in tests
    _lastPressureAnalysis?.clear();
    _cachedPressureResponse?.clear();
    _lastPressureAnalysis = null;
    _cachedPressureResponse = null;
  }

  /// Filter out wild cards from add-to-meld opportunities unless in critical situations
  List<Map<String, dynamic>> _filterWildCardAdditions(
    List<Map<String, dynamic>> cardsToAdd,
    Player bot,
  ) {
    var result = cardsToAdd;
    // In critical situations, allow wild card usage
    bool criticalSituation = false;

    // 1. Need to play down and have no other option
    if (!bot.hasPlayedDown) {
      final rankCounts = <CardRank, int>{};
      for (final card in bot.currentHand) {
        if (!card.isWild && !card.isThree) {
          rankCounts[card.rank] = (rankCounts[card.rank] ?? 0) + 1;
        }
      }
      final naturalMeldCount = rankCounts.entries
          .where((e) => e.value >= 2)
          .length;
      if (naturalMeldCount == 0) {
        criticalSituation = true; // Must use wilds to play down
      }
    }
    // 2. Trying to get into foot (hand almost empty)
    else if (!bot.hasPickedUpFoot && bot.currentHand.length <= 4) {
      criticalSituation = true;
    }
    // 3. End game - need to complete books to go out
    else if (bot.hasPickedUpFoot &&
        bot.currentHand.length <=
            BotConfig.footPhaseAggressiveMeldingThreshold + 2) {
      final hasCleanBook = bot.hasCleanBook;
      final hasDirtyBook = bot.hasDirtyBook;

      if (!hasCleanBook || !hasDirtyBook) {
        // Mirror BotMeldAnalyzer: don't treat near-books as critical when we
        // already have a dirty book but need clean and hand still has cards.
        final suppressNearBookCritical =
            !hasCleanBook && hasDirtyBook && bot.currentHand.length > 2;
        final hasNearBooks = bot.melds.any((m) => m.cards.length >= 6);
        if (hasNearBooks && !suppressNearBookCritical) {
          criticalSituation = true;
        }
      }
    }

    // If not critical, filter out wild cards (with an extra guard below).
    if (!criticalSituation) {
      result = result.where((addition) {
        final card = addition['card'] as PlayingCard;
        return !card.isWild;
      }).toList();
    }

    // No clean book yet: never add wilds to naturals-only melds — use wilds only
    // on piles that are already dirty (building the dirty book lane).
    if (bot.hasPlayedDown && !bot.hasCleanBook) {
      if (bot.hasPickedUpFoot && bot.hasDirtyBook) {
        return _filterCleanBookPriorityAdditions(bot, result);
      }
      result = result.where((addition) {
        final card = addition['card'] as PlayingCard;
        if (!card.isWild) {
          return true;
        }
        final meld = addition['meld'] as Meld;
        final alreadyDirty = meld.cards.any((c) => c.isWild);
        return alreadyDirty;
      }).toList();
    }

    return result;
  }

  /// When dirty books exist but a clean book is still required, only add naturals
  /// to incomplete, non-wild melds — never inflate dirty piles toward completion.
  List<Map<String, dynamic>> _filterCleanBookPriorityAdditions(
    Player bot,
    List<Map<String, dynamic>> additions,
  ) {
    return additions.where((addition) {
      final meldIndex = addition['meldIndex'] as int;
      final card = addition['card'] as PlayingCard;
      final meld = bot.melds[meldIndex];
      if (meld.cards.length >= GameConfig.bookSize) {
        return false;
      }
      if (card.isWild) {
        return false;
      }
      return !meld.cards.any((existing) => existing.isWild);
    }).toList();
  }

  /// Helper method to randomly select from a list of equally good options
  /// Adds decision variability to make bot behavior less predictable
  T? _selectRandomly<T>(List<T> options) {
    if (options.isEmpty) {
      DebugLogger.warning(
        '_selectRandomly called with empty options list, returning null',
      );
      return null; // Graceful fallback instead of throwing exception
    }
    if (options.length == 1) {
      return options.first;
    }
    return options[_random.nextInt(options.length)];
  }

  /// Calculate time-based pressure: how worried should bot be about still being in hand
  double _calculateTimePressure(
    Player bot,
    int turnCount,
    BotPersonality personality,
  ) {
    // Base pressure increases linearly with turns
    double basePressure = turnCount / 10.0; // Moderate pressure after 10 turns

    // Personality modifiers
    switch (personality) {
      case BotPersonality.conservative:
        return basePressure * 0.7; // Less worried, can hold longer
      case BotPersonality.aggressive:
        return basePressure * 1.3; // More worried, wants to transition sooner
      case BotPersonality.bookBuilder:
        return basePressure * 0.8; // Slightly less worried, focused on books
      case BotPersonality.adaptive:
        return basePressure * 1.0; // Standard pressure
    }
  }

  /// Get personality-based hand size limit, adjusted for time pressure
  int _getPersonalityHoldingLimit(
    BotPersonality personality,
    double timePressure,
  ) {
    int baseLimit;

    switch (personality) {
      case BotPersonality.conservative:
        baseLimit = 13; // Was 15 — production showed excessive hand hoarding
        break;
      case BotPersonality.aggressive:
        baseLimit = 14;
        break;
      case BotPersonality.bookBuilder:
        baseLimit = 15;
        break;
      case BotPersonality.adaptive:
        baseLimit = 14;
        break;
    }

    // Reduce limit based on time pressure
    final pressureReduction = (timePressure * 5)
        .round(); // Up to 5 card reduction - more pressure
    final minLimit = switch (personality) {
      BotPersonality.adaptive => 5,
      BotPersonality.aggressive => 6,
      BotPersonality.bookBuilder => 7,
      BotPersonality.conservative => 6,
    };
    return (baseLimit - pressureReduction).clamp(minLimit, baseLimit);
  }

  /// True when any opponent has picked up foot — bots should race to transition.
  bool _opponentOnFootPressure(BotGameContext context, Player bot) {
    return context.players.any((p) => p.id != bot.id && p.hasPickedUpFoot);
  }

  /// Hand-size ceiling for multi-meld foot completion (5 normally, up to 8 under pressure).
  int _handPileMaximalMeldHandLimit(Player bot, BotGameContext context) {
    if (_opponentOnFootPressure(context, bot)) {
      return BotConfig.handToFootRushOpponentOnFootThreshold;
    }
    return BotConfig.handPileFootCompletionMaxHand;
  }

  /// Try multi-meld or single-meld completion when hand is small enough.
  BotDecision? _tryMaximalMeldsForHandPileCompletion(
    Player bot,
    GameController controller,
    int handSize,
    BotGameContext context,
  ) {
    if (handSize > _handPileMaximalMeldHandLimit(bot, context)) {
      return null;
    }

    final maximalMelds = _meldAnalyzer
        .findMaximalMeldCombination(bot, controller)
        .where((meld) => meld.length >= GameConfig.minTotalCardsForMeld)
        .toList();
    final minCardsToClear = _opponentOnFootPressure(context, bot)
        ? handSize - 2
        : handSize - 1;
    if (minCardsToClear < 1) {
      return null;
    }

    if (maximalMelds.length >= 2) {
      final cardsMeldable = maximalMelds.fold<int>(
        0,
        (sum, meld) => sum + meld.length,
      );
      if (cardsMeldable >= minCardsToClear) {
        return BotDecision(action: 'createMultipleMelds', data: maximalMelds);
      }
    } else if (maximalMelds.length == 1 &&
        maximalMelds.first.length >= minCardsToClear) {
      return BotDecision(action: 'createMeld', data: maximalMelds.first);
    }
    return null;
  }

  /// Discard choice when clearing a small hand pile toward foot pickup.
  PlayingCard? _chooseHandPileTransitionDiscard(Player bot) {
    final hand = bot.currentHand;
    if (hand.isEmpty) {
      return null;
    }

    final threes = hand.where((card) => card.rank == CardRank.three).toList();
    if (threes.isNotEmpty) {
      threes.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      return threes.first;
    }

    final sortedHand = List<PlayingCard>.from(hand);
    sortedHand.sort((a, b) => a.pointValue.compareTo(b.pointValue));
    return sortedHand.first;
  }

  /// Enhanced book completion strategy for competitive play
  bool _shouldHoldForBookCompletion(
    Player bot,
    GameState gameState,
    BotPersonality personality,
  ) {
    if (bot.hasPlayedDown && !bot.hasPickedUpFoot) {
      return false;
    }

    // Start considering book completion earlier (round 2+) for competitiveness
    if (gameState.round < 2) return false;

    // All personalities should consider book completion, not just BookBuilder
    bool shouldConsider = false;
    switch (personality) {
      case BotPersonality.bookBuilder:
        shouldConsider = true; // Always consider
        break;
      case BotPersonality.adaptive:
        shouldConsider = _random.nextDouble() > 0.2; // 80% chance
        break;
      case BotPersonality.conservative:
        shouldConsider = _random.nextDouble() > 0.4; // 60% chance
        break;
      case BotPersonality.aggressive:
        shouldConsider =
            _random.nextDouble() > 0.6; // 40% chance (focus on speed)
        break;
    }

    if (!shouldConsider) return false;

    // Enhanced book analysis - check both clean and dirty book requirements
    final bookStatus = _analyzeBookRequirements(bot);
    if (!bookStatus['hasNearCompleteBooks'] &&
        !bookStatus['needsBookBalance']) {
      return false;
    }

    // More aggressive about book completion when opponents are threatening
    _gameAnalyzer.updateOpponentAnalysis(gameState, bot);
    final opponentAnalysis = _gameAnalyzer.opponentAnalysis;

    // If any opponent is in foot with small hand, prioritize books more aggressively
    for (final analysis in opponentAnalysis.values) {
      if (analysis.hasPickedUpFoot && analysis.handSize <= 6) {
        return true; // Must complete books to have going out potential
      }
    }

    // Hold if we're close to completing books and in good position
    return bookStatus['hasNearCompleteBooks'] as bool;
  }

  /// Enhanced book requirements analysis for competitive play
  Map<String, dynamic> _analyzeBookRequirements(Player bot) {
    final analysis = <String, dynamic>{};

    // Count current book status
    int cleanBooks = 0;
    int dirtyBooks = 0;
    int nearCompleteBooks = 0;
    int nearCompleteCleanBooks = 0;
    int nearCompleteDirtyBooks = 0;

    for (final meld in bot.melds) {
      final isBook = meld.cards.length >= GameConfig.bookSize;
      final isNearComplete = meld.cards.length >= 6;

      if (isBook) {
        if (!meld.cards.any((c) => c.isWild)) {
          cleanBooks++;
        } else {
          dirtyBooks++;
        }
      } else if (isNearComplete) {
        nearCompleteBooks++;
        final allNatural = !meld.cards.any((c) => c.isWild);
        if (allNatural) {
          nearCompleteCleanBooks++;
        } else {
          nearCompleteDirtyBooks++;
        }
      }
    }

    // Strategic analysis for competitive play
    analysis['cleanBooks'] = cleanBooks;
    analysis['dirtyBooks'] = dirtyBooks;
    analysis['hasRequiredBooks'] = cleanBooks > 0 && dirtyBooks > 0;
    analysis['hasNearCompleteBooks'] = nearCompleteBooks > 0;
    analysis['needsCleanBook'] = cleanBooks == 0 && nearCompleteCleanBooks > 0;
    analysis['needsDirtyBook'] = dirtyBooks == 0 && nearCompleteDirtyBooks > 0;
    analysis['needsBookBalance'] =
        (cleanBooks == 0 && dirtyBooks > 0) ||
        (dirtyBooks == 0 && cleanBooks > 0);
    analysis['canGoOut'] = cleanBooks > 0 && dirtyBooks > 0;
    analysis['bookCompletionPotential'] = nearCompleteBooks;

    // NEW: Detect when bot has TOO MANY books and should focus on going out
    final totalBooks = cleanBooks + dirtyBooks;
    final hasRequiredBooks = cleanBooks > 0 && dirtyBooks > 0;
    analysis['hasExcessBooks'] = totalBooks >= 4; // Should prioritize going out
    analysis['shouldFocusOnGoingOut'] =
        hasRequiredBooks && totalBooks >= 3; // Switch to going out mode

    return analysis;
  }

  /// Assess threat level from opponents for competitive decision-making
  double _assessOpponentThreat(GameState gameState, Player botPlayer) {
    _gameAnalyzer.updateOpponentAnalysis(gameState, botPlayer);
    final opponentAnalysis = _gameAnalyzer.opponentAnalysis;

    if (opponentAnalysis.isEmpty) return 0.0;

    double maxThreat = 0.0;

    for (final analysis in opponentAnalysis.values) {
      double threat = 0.0;

      // Immediate threat - opponents in foot with few cards
      if (analysis.hasPickedUpFoot && analysis.handSize <= 3) {
        threat += 0.8; // Very high threat
      } else if (analysis.hasPickedUpFoot && analysis.handSize <= 6) {
        threat += 0.5; // High threat
      }

      // Development threat - opponents ahead in game phases
      if (analysis.hasPickedUpFoot && !botPlayer.hasPickedUpFoot) {
        threat += 0.3; // Ahead in development
      } else if (analysis.hasPlayedDown && !botPlayer.hasPlayedDown) {
        threat += 0.2; // Ahead in play-down
      }

      // Book completion threat
      if (analysis.hasNearCompleteBook) {
        threat += 0.2; // Close to completing books
      }

      // Score pressure
      if (analysis.score > botPlayer.score + 500) {
        threat += 0.1; // Score advantage
      }

      maxThreat = math.max(maxThreat, threat);
    }

    return maxThreat.clamp(0.0, 1.0);
  }

  /// NEW: Cached opponent pressure evaluation for performance
  BotDecision? _evaluateOpponentPressureWithCaching(
    Player bot,
    BotGameContext context,
    GameState gameState,
  ) {
    // Cache pressure analysis for performance (check max every 2 seconds)
    final now = DateTime.now();
    final lastCheck = _lastPressureAnalysis?[bot.id];

    if (lastCheck != null &&
        now.difference(lastCheck).inSeconds < 2 &&
        _cachedPressureResponse != null) {
      return _cachedPressureResponse![bot.id];
    }

    // Perform fresh analysis
    final result = _evaluateOpponentPressure(bot, context, gameState);

    // Cache the result
    _lastPressureAnalysis ??= {};
    _cachedPressureResponse ??= {};
    _lastPressureAnalysis![bot.id] = now;
    _cachedPressureResponse![bot.id] = result;

    return result;
  }

  /// NEW: Evaluate opponent pressure and return competitive counter-strategy
  BotDecision? _evaluateOpponentPressure(
    Player bot,
    BotGameContext context,
    GameState gameState,
  ) {
    final humanPlayers = gameState.players.where(
      (p) => p.type == PlayerType.human,
    );

    for (final human in humanPlayers) {
      // THREAT 1: Human accumulation strategy (like the 35-card pattern we observed)
      if (human.currentHand.length >= GameConfig.humanAccumulationThreat &&
          !human.hasPlayedDown) {
        return _counterHumanAccumulation(bot, context, gameState, human);
      }

      // THREAT 2: Human close to going out
      if (human.hasPickedUpFoot &&
          human.currentHand.length <= GameConfig.dangerousOpponentHandSize) {
        return _blockOpponentGoOut(bot, context, gameState, human);
      }

      // THREAT 3: Human building books faster than us
      if (_isOpponentOutpacingBooks(bot, human)) {
        return _accelerateBookBuilding(bot, context, gameState);
      }
    }

    return null; // No immediate pressure tactics needed
  }

  /// Counter human accumulation strategy - apply early pressure
  BotDecision? _counterHumanAccumulation(
    Player bot,
    BotGameContext context,
    GameState gameState,
    Player human,
  ) {
    final personality = _personalityManager.getPersonality(bot.id);

    // AGGRESSIVE BOTS: Speed demon counter-strategy
    if (personality == BotPersonality.aggressive) {
      return _executeSpeedDemonStrategy(bot, context, gameState, human);
    }

    // OTHER BOTS: General counter-tactics
    if (gameState.turnPhase == TurnPhase.draw &&
        gameState.discardPile.length >= 6) {
      // Take large discard piles to deny accumulation opportunities
      if (bot.hasPlayedDown && context.canUnlockDiscard()) {
        return BotDecision(action: 'drawFromDiscard');
      }
    }

    if (gameState.turnPhase == TurnPhase.meld &&
        bot.hasPickedUpFoot &&
        bot.currentHand.length <= 10 &&
        bot.canGoOutWithBooks) {
      // Rush to finish — meld what we can, then discard to go out
      return BotDecision(action: 'noMeld');
    }

    return null;
  }

  /// NEW: Speed demon strategy - end game before humans can accumulate
  BotDecision? _executeSpeedDemonStrategy(
    Player bot,
    BotGameContext context,
    GameState gameState,
    Player human,
  ) {
    // Must draw before melding — pressure tactics cannot skip the draw phase.
    if (gameState.turnPhase == TurnPhase.draw) {
      if (!gameState.hasDrawnFromDeck) {
        // Prefer discard pile when unlockable to speed up the game.
        if (gameState.discardPile.length >= 4 && context.canUnlockDiscard()) {
          return BotDecision(action: 'drawFromDiscard');
        }
        return BotDecision(action: 'drawFromDeck');
      }
      return null;
    }

    // Strategy: Play down immediately, rush to foot, go out ASAP to prevent human accumulation

    if (!bot.hasPlayedDown) {
      // EMERGENCY: Play down with minimum points if human accumulating - but ensure rule compliance
      final controller = context.controller as GameController?;
      if (controller == null) return null;
      final possibleMelds = controller.findPossibleMelds(bot);
      if (possibleMelds.isNotEmpty) {
        // Find a meld that meets the minimum play-down requirement
        final playDownRequirement = gameState.playDownRequirement;

        for (final meld in possibleMelds) {
          final meldValue = meld.fold<int>(
            0,
            (sum, card) => sum + card.pointValue,
          );
          if (meldValue >= playDownRequirement) {
            return BotDecision(action: 'createMeld', data: meld);
          }
        }

        // If no single meld meets requirement, try multi-meld combination
        final bestCombination = _meldAnalyzer.findBestPlayDownCombination(
          bot,
          controller,
          playDownRequirement,
        );
        if (bestCombination.isNotEmpty) {
          return _executePlayDown(bestCombination);
        }
      }
    }

    if (bot.hasPlayedDown && !bot.hasPickedUpFoot && bot.isHandEmpty) {
      // Foot pickup is handled automatically by the game engine after meld/discard
      return null;
    }

    if (bot.hasPickedUpFoot && bot.currentHand.length <= 12) {
      // Aggressive finish attempt when books are met
      if (bot.canGoOutWithBooks) {
        final controller = context.controller as GameController?;
        if (controller != null) {
          final finishDecision = _endGameManager.buildFinishRoundDecision(
            bot,
            controller,
            gameState.turnPhase,
          );
          if (finishDecision != null) {
            return finishDecision;
          }
        }
      }

      // If can't go out, rush to complete minimum required books
      final cleanBooks = bot.melds
          .where((m) => m.cards.length >= 7 && m.isClean)
          .length;
      final dirtyBooks = bot.melds
          .where((m) => m.cards.length >= 7 && !m.isClean)
          .length;

      if (cleanBooks == 0 || dirtyBooks == 0) {
        // Rush to complete missing book type
        return _rushToCompleteRequiredBooks(bot, context);
      }
    }

    return null;
  }

  /// Rush to complete required books for going out
  BotDecision? _rushToCompleteRequiredBooks(
    Player bot,
    BotGameContext context,
  ) {
    final cleanBooks = bot.melds
        .where((m) => m.cards.length >= 7 && m.isClean)
        .length;
    final dirtyBooks = bot.melds
        .where((m) => m.cards.length >= 7 && !m.isClean)
        .length;

    final needsClean = cleanBooks == 0;
    final needsDirty = dirtyBooks == 0;

    // Find near-complete melds of the needed type
    final minNearBookSize = needsClean && dirtyBooks > 0 && bot.hasPickedUpFoot
        ? 3
        : 5;

    for (int i = 0; i < bot.melds.length; i++) {
      final meld = bot.melds[i];
      if (meld.cards.length >= minNearBookSize) {
        // Near book
        final isClean = meld.isClean;

        if ((needsClean && isClean) || (needsDirty && !isClean)) {
          // Try to add cards to complete this book
          final addableCards = bot.currentHand
              .where((card) => meld.canAddCard(card))
              .where((card) => needsClean ? !card.isWild : true)
              .toList();
          if (addableCards.isNotEmpty) {
            return BotDecision(
              action: 'addToMeld',
              data: {'meldIndex': i, 'card': addableCards.first},
            );
          }
        }
      }
    }

    // If no near-complete books, create new meld of needed type
    final controller = context.controller as GameController?;
    if (controller == null) return null;
    final possibleMelds = controller.findPossibleMelds(bot);
    for (final meld in possibleMelds) {
      final isClean = !meld.any((card) => card.isWild);
      if ((needsClean && isClean) || (needsDirty && !isClean)) {
        return BotDecision(action: 'createMeld', data: meld);
      }
    }

    return null;
  }

  /// Foot-phase melding for all personalities: melt large hands and complete book pairs.
  BotDecision? _handleFootPhaseMeldDecision(
    Player bot,
    BotGameContext context,
  ) {
    if (!bot.hasPickedUpFoot) {
      return null;
    }

    final handSize = bot.currentHand.length;
    final controller = context.controller as GameController?;
    if (controller == null) {
      return null;
    }

    // Always try to complete the missing clean/dirty book type first
    final bookRush = _rushToCompleteRequiredBooks(bot, context);
    if (bookRush != null) {
      return bookRush;
    }

    // Missing go-out books — meld at any foot hand size (analytics: conservative
    // hoarded 3–7 cards in foot with 0–1 books, leading to empty-hand errors)
    if (!bot.canGoOutWithBooks) {
      final bookPairRush = _forceFootPhaseMeld(
        bot,
        context,
        prioritizeMissingBookType: true,
      );
      if (bookPairRush != null) {
        return bookPairRush;
      }

      final possibleMelds = _getCachedPossibleMelds(bot, context);
      if (possibleMelds.isNotEmpty) {
        return BotDecision(
          action: 'createMeld',
          data: _selectBestNewMeld(bot, possibleMelds),
        );
      }
    }

    // Opponent close to going out or large foot hand — melt aggressively
    final needsForcedMeld =
        _opponentThreateningGoOut(context.gameState, bot) ||
        handSize >= BotConfig.footPhaseAggressiveMeldingThreshold;
    if (needsForcedMeld) {
      final forced = _forceFootPhaseMeld(
        bot,
        context,
        prioritizeMissingBookType: true,
      );
      if (forced != null) {
        return forced;
      }
    }

    // Large foot hand: any meld beats drawing again
    if (handSize >= BotConfig.footPhaseAggressiveMeldingThreshold) {
      final anyMelds = _getCachedPossibleMelds(bot, context);
      if (anyMelds.isNotEmpty) {
        return BotDecision(
          action: 'createMeld',
          data: _selectBestNewMeld(bot, anyMelds),
        );
      }
    }

    return null;
  }

  /// Prevent draw loops when a bot has played down but holds a large hand.
  BotDecision? _forceMeldForLargePlayedDownHand(
    Player bot,
    BotGameContext context,
  ) {
    final controller = context.controller as GameController?;
    if (controller == null) {
      return null;
    }

    final additions = _filterWildCardAdditions(
      _meldAnalyzer.findCardsToAddToExistingMelds(bot, controller),
      bot,
    );
    if (additions.isNotEmpty) {
      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'Draw-loop guard: adding to meld with ${bot.currentHand.length} cards',
      );
      return BotDecision(action: 'addToMeld', data: additions.first);
    }

    final possibleMelds = _getCachedPossibleMelds(bot, context);
    if (possibleMelds.isNotEmpty) {
      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'Draw-loop guard: creating meld with ${bot.currentHand.length} cards',
      );
      return BotDecision(
        action: 'createMeld',
        data: _selectBestNewMeld(bot, possibleMelds),
      );
    }

    return null;
  }

  /// Force a meld/add in foot when hand is large or books are incomplete.
  BotDecision? _forceFootPhaseMeld(
    Player bot,
    BotGameContext context, {
    bool prioritizeMissingBookType = false,
  }) {
    final controller = context.controller as GameController?;
    if (controller == null) {
      return null;
    }

    final needsClean = !bot.hasCleanBook;
    final needsDirty = !bot.hasDirtyBook;
    final shouldPreferCleanOverDirty =
        prioritizeMissingBookType && needsClean && bot.hasDirtyBook;

    final filteredAdditions = _filterWildCardAdditions(
      _meldAnalyzer.findCardsToAddToExistingMelds(bot, controller),
      bot,
    );

    // Have dirty books but need clean — build a naturals-only lane, not more dirty piles
    if (shouldPreferCleanOverDirty) {
      final cleanMelds = _getCachedPossibleMelds(
        bot,
        context,
      ).where((meld) => !meld.any((card) => card.isWild)).toList();
      if (cleanMelds.isNotEmpty) {
        DebugLogger.botDebug(
          bot.id,
          bot.name,
          'FOOT: creating clean meld — have dirty books but need clean book',
        );
        return BotDecision(
          action: 'createMeld',
          data: _selectBestNewMeld(bot, cleanMelds),
        );
      }

      final naturalAdditions = _filterCleanBookPriorityAdditions(
        bot,
        filteredAdditions,
      );
      if (naturalAdditions.isNotEmpty) {
        return BotDecision(action: 'addToMeld', data: naturalAdditions.first);
      }
    }

    // Need dirty book but have clean — allow wild-heavy melds
    if (prioritizeMissingBookType && needsDirty && bot.hasCleanBook) {
      final dirtyMelds = _getCachedPossibleMelds(
        bot,
        context,
      ).where((meld) => meld.any((card) => card.isWild)).toList();
      if (dirtyMelds.isNotEmpty) {
        return BotDecision(
          action: 'createMeld',
          data: _selectBestNewMeld(bot, dirtyMelds),
        );
      }
    }

    var cardsToAdd = shouldPreferCleanOverDirty
        ? _filterCleanBookPriorityAdditions(bot, filteredAdditions)
        : filteredAdditions;

    if (cardsToAdd.isNotEmpty) {
      return BotDecision(action: 'addToMeld', data: cardsToAdd.first);
    }

    var possibleMelds = _getCachedPossibleMelds(bot, context);
    if (shouldPreferCleanOverDirty) {
      final cleanOnly = possibleMelds
          .where((meld) => !meld.any((card) => card.isWild))
          .toList();
      if (cleanOnly.isNotEmpty) {
        possibleMelds = cleanOnly;
      }
    }

    if (possibleMelds.isNotEmpty) {
      return BotDecision(
        action: 'createMeld',
        data: _selectBestNewMeld(bot, possibleMelds),
      );
    }

    return null;
  }

  /// True when an opponent is close to ending the round (human going out).
  bool _opponentThreateningGoOut(GameState gameState, Player bot) {
    for (final opponent in gameState.players) {
      if (opponent.id == bot.id) {
        continue;
      }

      final opponentBooks = opponent.melds
          .where((m) => m.cards.length >= GameConfig.bookSize)
          .length;

      if (opponent.canGoOutWithBooks && opponent.currentHand.length <= 10) {
        return true;
      }

      if (opponentBooks >= BotConfig.footPhaseOpponentBookPanicThreshold &&
          opponent.currentHand.length <= 10) {
        return true;
      }

      if (opponent.hasPickedUpFoot &&
          opponentBooks >= 2 &&
          opponent.currentHand.length <= 8) {
        return true;
      }
    }

    return false;
  }

  // Getters for testing and debugging

  /// Block opponent from going out
  BotDecision? _blockOpponentGoOut(
    Player bot,
    BotGameContext context,
    GameState gameState,
    Player opponent,
  ) {
    // Strategy: If opponent is close to going out, take defensive actions

    if (gameState.turnPhase == TurnPhase.draw) {
      // Take discard pile to prevent opponent from using it
      if (gameState.discardPile.isNotEmpty && context.canUnlockDiscard()) {
        return BotDecision(action: 'drawFromDiscard');
      }
    }

    if (gameState.turnPhase == TurnPhase.discard) {
      // Discard cards that are less useful to opponents
      final safestDiscard = _findSafestDiscardAgainstOpponent(bot, opponent);
      if (safestDiscard != null) {
        return BotDecision(action: 'discard', data: safestDiscard);
      }
    }

    return null;
  }

  /// Accelerate book building when opponent is outpacing us
  BotDecision? _accelerateBookBuilding(
    Player bot,
    BotGameContext context,
    GameState gameState,
  ) {
    if (gameState.turnPhase == TurnPhase.meld) {
      // Prioritize completing near-books over creating new melds
      for (int i = 0; i < bot.melds.length; i++) {
        final meld = bot.melds[i];
        if (meld.cards.length >= 5) {
          // Near-book
          final matchingCards = bot.currentHand
              .where((card) => meld.canAddCard(card))
              .toList();

          if (matchingCards.isNotEmpty) {
            return BotDecision(
              action: 'addToMeld',
              data: {'meldIndex': i, 'card': matchingCards.first},
            );
          }
        }
      }
    }

    return null;
  }

  /// Check if opponent is outpacing us in book building
  bool _isOpponentOutpacingBooks(Player bot, Player opponent) {
    final botBooks = bot.melds.where((Meld m) => m.cards.length >= 7).length;
    final opponentBooks = opponent.melds
        .where((Meld m) => m.cards.length >= 7)
        .length;

    // Opponent has more books, or same books but ahead in game phase
    return opponentBooks > botBooks ||
        (opponentBooks >= botBooks &&
            opponent.hasPickedUpFoot &&
            !bot.hasPickedUpFoot);
  }

  /// Find safest card to discard that minimizes opponent benefit
  PlayingCard? _findSafestDiscardAgainstOpponent(Player bot, Player opponent) {
    final possibleDiscards = bot.currentHand
        .where((card) => !card.isThree)
        .toList();

    if (possibleDiscards.isEmpty) return null;

    // Avoid discarding cards that opponent might need for their visible melds
    final opponentRanks = opponent.melds.map((m) => m.cards.first.rank).toSet();

    final saferDiscards = possibleDiscards
        .where((card) => !opponentRanks.contains(card.rank))
        .toList();

    if (saferDiscards.isNotEmpty) {
      return saferDiscards.first;
    }

    return possibleDiscards.first; // Fallback
  }

  /// Check if discard pile would significantly benefit opponents
  bool _pileWouldBenefitOpponents(
    List<PlayingCard> pile,
    GameState gameState,
    Player bot,
  ) {
    final opponents = gameState.players.where((p) => p.id != bot.id);

    for (final opponent in opponents) {
      // Check if pile contains cards that match opponent's visible melds
      final opponentRanks = opponent.melds
          .map((m) => m.cards.first.rank)
          .toSet();

      final beneficialCards = pile
          .where((card) => opponentRanks.contains(card.rank) || card.isWild)
          .length;

      // If more than 30% of pile would benefit opponent, consider taking it
      if (beneficialCards / pile.length > 0.3) {
        return true;
      }

      // If opponent is close to going out and pile has high-value cards
      if (opponent.hasPickedUpFoot && opponent.currentHand.length <= 8) {
        final highValueCards = pile
            .where((card) => card.pointValue > 10)
            .length;
        if (highValueCards >= 3) {
          return true; // Deny high-value cards to opponent close to going out
        }
      }
    }

    return false;
  }

  /// NEW: Dynamic adaptive personality adjustment based on opponent behavior
  void _applyAdaptivePersonalityAdjustment(Player bot, GameState gameState) {
    try {
      // Only apply to adaptive personality bots
      if (_personalityManager.getPersonality(bot.id) !=
          BotPersonality.adaptive) {
        return;
      }

      _personalityManager.resetAdaptiveConstants(bot.id);

      final humanPlayers = gameState.players.where(
        (p) => p.type == PlayerType.human,
      );

      // Only apply adaptive adjustments when there are human players (not in tests)
      if (humanPlayers.isEmpty) {
        return;
      }

      // Validate game state before making adaptations
      if (gameState.round < 1 || gameState.round > 10) {
        DebugLogger.botDebug(
          bot.id,
          bot.name,
          'Invalid round ${gameState.round}, skipping adaptive adjustment',
        );
        return;
      }

      for (final human in humanPlayers) {
        // ADAPTATION 1: Counter human accumulation with speed
        if (human.currentHand.length >= 20 &&
            !human.hasPlayedDown &&
            gameState.round <= 4) {
          // Human is accumulating - switch to aggressive mode to end game quickly
          _overrideAdaptiveConstants(bot, 'speed_counter', {
            'maxTurnsBeforeForcePlayDown': 1, // Strike fast
            'aggressivenessMultiplier': 1.8, // Be very aggressive
            'handPileValueThreshold': 20, // Take any pile to speed up
          });
          return;
        }

        // ADAPTATION 2: Match human book building with patience
        if (human.melds.length >= 8 && human.hasPlayedDown) {
          // Human is building many books - switch to book builder mode
          _overrideAdaptiveConstants(bot, 'book_matcher', {
            'maxTurnsBeforeForcePlayDown': 9, // Allow book building
            'bookCompletionPriority': 300, // Prioritize books heavily
            'aggressivenessMultiplier': 1.3, // Competitive book building
          });
          return;
        }

        // ADAPTATION 3: Human rushed to foot early — match tempo, don't stall
        if (human.hasPickedUpFoot &&
            human.currentHand.length <= 10 &&
            gameState.round <= 3) {
          _overrideAdaptiveConstants(bot, 'foot_pressure', {
            'maxTurnsBeforeForcePlayDown': 2,
            'footPileValueThreshold': 30,
            'aggressivenessMultiplier': 1.4,
            'bookCompletionPriority': 200,
          });
          return;
        }
      }

      // Default adaptive behavior if no specific pattern detected
      _overrideAdaptiveConstants(bot, 'default_adaptive', {
        'maxTurnsBeforeForcePlayDown': 4,
        'aggressivenessMultiplier': 1.1,
      });
    } catch (e) {
      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'Error in adaptive personality adjustment: $e',
      );
    }
  }

  /// Override adaptive bot constants for situational strategy
  void _overrideAdaptiveConstants(
    Player bot,
    String strategy,
    Map<String, dynamic> overrides,
  ) {
    _personalityManager.applyConstantOverrides(bot.id, strategy, overrides);
    DebugLogger.botDebug(bot.id, bot.name, 'Adaptive strategy: $strategy');
  }

  /// Validate bot decision to prevent game-breaking moves
  bool _isValidDecision(
    BotDecision decision,
    Player bot,
    BotGameContext context,
  ) {
    try {
      switch (decision.action) {
        case 'goOut':
          return bot.canGoOut && bot.hasPickedUpFoot;
        case 'createMeld':
          if (decision.data is! List<PlayingCard>) {
            return false;
          }
          final meldCards = decision.data as List<PlayingCard>;
          return meldCards.isNotEmpty &&
              BotEndGameManager.isSafeCreateMeld(bot, meldCards);
        case 'createMultipleMelds':
          return decision.data is List<List<PlayingCard>> &&
              (decision.data as List<List<PlayingCard>>).isNotEmpty;
        case 'addToMeld':
          if (decision.data is! Map<String, dynamic>) {
            return false;
          }
          final data = decision.data as Map<String, dynamic>;
          final meldIndex = data['meldIndex'] as int?;
          if (meldIndex == null ||
              meldIndex < 0 ||
              meldIndex >= bot.melds.length) {
            return false;
          }
          return BotEndGameManager.isSafeAddToMeld(bot, data);
        case 'discard':
          return decision.data is PlayingCard &&
              bot.hasHandCard(decision.data as PlayingCard);
        case 'drawFromDeck':
        case 'drawFromDiscard':
        case 'unlockDiscardPile':
        case 'noMeld':
        case 'endTurn':
          return true; // These are always safe
        case 'error':
          return _isRecoverableErrorState(bot);
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Empty-hand states should propagate `error` only when going out is impossible.
  bool _isRecoverableErrorState(Player bot) {
    return bot.currentHand.isEmpty && !bot.canGoOut;
  }

  /// Get safe fallback decision when normal logic fails
  BotDecision _getSafeDecision(
    TurnPhase turnPhase,
    Player bot,
    BotGameContext context,
  ) {
    switch (turnPhase) {
      case TurnPhase.draw:
        return BotDecision(action: 'drawFromDeck');
      case TurnPhase.meld:
        if (bot.currentHand.isEmpty) {
          if (context.canPlayerGoOut()) {
            return BotDecision(action: 'goOut');
          }
          return BotDecision(action: 'error');
        }
        // Try simple meld if possible, otherwise skip
        final possibleMelds = context.controller?.findPossibleMelds(bot) ?? [];
        if (possibleMelds.isNotEmpty && bot.hasPlayedDown) {
          return BotDecision(
            action: 'createMeld',
            data: _selectBestNewMeld(bot, possibleMelds),
          );
        }
        return BotDecision(action: 'noMeld');
      case TurnPhase.discard:
        // Check if bot has any cards at all
        if (bot.currentHand.isEmpty) {
          // Bot has no cards - this should trigger going out or error recovery
          if (context.canPlayerGoOut()) {
            return BotDecision(action: 'goOut');
          }
          return BotDecision(action: 'error');
        }

        // Find any valid discard
        final nonThreeCards = bot.currentHand
            .where((card) => !card.isThree)
            .toList();
        if (nonThreeCards.isNotEmpty) {
          return BotDecision(action: 'discard', data: nonThreeCards.first);
        }
        // Emergency: discard any card (even 3s if that's all we have)
        return BotDecision(action: 'discard', data: bot.currentHand.first);
    }
  }

  /// Get possible melds with caching to avoid repeated expensive computations
  List<List<PlayingCard>> _getCachedPossibleMelds(
    Player bot,
    BotGameContext context,
  ) {
    // Create cache key based on hand contents and game state
    final handString = bot.currentHand
        .map((c) => '${c.rank.name}-${c.suit?.name ?? 'J'}')
        .join(',');
    final cacheKey = '${handString}_${context.round}_${bot.melds.length}';

    // Return cached result if valid
    if (_lastMeldCacheKey == cacheKey && _cachedPossibleMelds != null) {
      return _cachedPossibleMelds![cacheKey] ?? [];
    }

    // Compute and cache new result
    // Note: This requires controller for findPossibleMelds, but we've decoupled
    // most of the bot logic to use BotGameContext
    final controller = context.controller;
    if (controller == null) {
      return []; // No controller available (test context)
    }
    final result = _meldAnalyzer.getPossibleMelds(
      bot,
      controller as GameController,
    );
    _cachedPossibleMelds = {cacheKey: result};
    _lastMeldCacheKey = cacheKey;

    return result;
  }

  /// Highest-scoring new meld via analyzer (clean/dirty balance); never uses raw list order from [findPossibleMelds].
  List<PlayingCard> _selectBestNewMeld(
    Player bot,
    List<List<PlayingCard>> possibleMelds,
  ) {
    assert(possibleMelds.isNotEmpty);
    return _meldAnalyzer.findBestMeld(
      possibleMelds,
      bot: bot,
      preferLarger: true,
    );
  }

  /// Delay rushing go-out when opponents would barely be penalized (thin hands / foot already empty).
  bool _shouldDelayRushForLowOpponentPenalty(Player bot, GameState gameState) {
    for (final opponent in gameState.players) {
      if (opponent.id == bot.id) continue;
      if (opponent.canGoOutWithBooks && opponent.currentHand.length <= 5) {
        return false;
      }
    }

    var maxOpponentPenalty = 0;
    for (final p in gameState.players) {
      if (p.id == bot.id) continue;
      final penalty = p.calculateAllUnplayedCardsValue();
      if (penalty > maxOpponentPenalty) maxOpponentPenalty = penalty;
    }

    if (maxOpponentPenalty >= BotConfig.rushDelayOpponentPenaltyCeiling) {
      return false;
    }

    if (bot.currentHand.length <= 2) return false;

    final maxOpponentScore = gameState.players
        .where((p) => p.id != bot.id)
        .map((p) => p.score)
        .fold(0, (max, score) => score > max ? score : max);

    if (maxOpponentScore >= 7000) return false;

    return true;
  }

  /// Helper method to check if bot is in early game phase where large hands are normal
  bool _isEarlyGamePhase(Player bot) {
    final botTurnCount = _gameAnalyzer.getTurnCount(bot.id);
    return botTurnCount <= GameConfig.earlyGameTurnThreshold;
  }

  // Getters for testing and debugging

  @visibleForTesting
  bool shouldCompleteHandPileForFoot(Player bot, BotGameContext context) {
    return _shouldCompleteHandPileForFoot(bot, context);
  }

  @visibleForTesting
  BotDecision? makeCompleteHandPileForFootDecision(
    Player bot,
    BotGameContext context,
  ) {
    return _makeCompleteHandPileForFootDecision(bot, context);
  }

  @visibleForTesting
  BotDecision makeFinalTurnScoringDecision(Player bot, BotGameContext context) {
    return _makeFinalTurnScoringDecision(bot, context);
  }

  @visibleForTesting
  bool shouldRushHandToFoot(Player bot, BotGameContext context) {
    return _shouldRushHandToFoot(bot, context);
  }

  @visibleForTesting
  BotDecision? makeHandToFootRushDecision(Player bot, BotGameContext context) {
    return _makeHandToFootRushDecision(bot, context);
  }

  Map<String, OpponentAnalysis> get opponentAnalysis =>
      _gameAnalyzer.opponentAnalysis;
  BotPersonalityManager get personalityManager => _personalityManager;
  BotGameAnalyzer get gameAnalyzer => _gameAnalyzer;
  BotMeldAnalyzer get meldAnalyzer => _meldAnalyzer;
  bool get inMultiMeldSequence => _inMultiMeldSequence;
  List<List<PlayingCard>>? get plannedMelds => _plannedMelds;
}

/// Specific exception type for bot decision-making errors
class BotDecisionException implements Exception {
  final String message;

  const BotDecisionException(this.message);

  @override
  String toString() => 'BotDecisionException: $message';
}
