import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../game/game_controller.dart';
import '../config/game_config.dart';
import 'enhanced_bot_ai.dart';
import 'bot_decision.dart';
import 'bot_personality.dart';
import 'web_llm_service.dart';
import '../utils/debug_logger.dart';

/// Enhanced bot AI that combines LLM strategic reasoning with rule-based tactical execution.
///
/// This class extends the existing EnhancedBotAI to add LLM capabilities while preserving
/// all existing personality traits, strategic logic, and emergency handling.
class LLMEnhancedBotAI extends EnhancedBotAI {
  final WebLLMService _webLLMService;
  bool _isLLMEnabled;

  // Performance tracking
  int _llmDecisions = 0;
  int _ruleBasedDecisions = 0;
  int _llmFailures = 0;

  LLMEnhancedBotAI({super.seed, bool enableLLM = true})
    : _webLLMService = WebLLMService(),
      _isLLMEnabled = enableLLM;

  /// Initialize LLM service if enabled
  Future<void> initializeLLM() async {
    if (!_isLLMEnabled) {
      return;
    }

    try {
      print('LLMEnhancedBotAI: Initializing web LLM service...');
      final success = await _webLLMService.initialize();

      if (success) {
        print('LLMEnhancedBotAI: Web LLM service ready');
      } else {
        print(
          'LLMEnhancedBotAI: LLM initialization failed, using rule-based only',
        );
        print('Error: ${_webLLMService.lastError}');
      }
    } catch (e) {
      print('LLMEnhancedBotAI: LLM initialization error: $e');
    }
  }

  /// Enhanced decision making that combines LLM strategy with rule-based execution
  @override
  BotDecision makeDecision(Player bot, GameController controller) {
    // Synchronous wrapper for async decision making
    // This maintains compatibility with existing synchronous interface
    return _makeDecisionSync(bot, controller);
  }

  /// Synchronous decision wrapper for backward compatibility
  BotDecision _makeDecisionSync(Player bot, GameController controller) {
    try {
      // Set personality context (inherited from parent)
      personalityManager.setCurrentPlayerContext(bot.id);

      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'LLMEnhancedBotAI sync decision - LLM enabled: $_isLLMEnabled, available: ${_webLLMService.isAvailable}',
      );

      // For sync mode, always use rule-based (LLM requires async)
      final decision = super.makeDecision(bot, controller);
      _ruleBasedDecisions++;

      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'Sync rule-based decision: ${decision.action}',
      );

      return decision;
    } catch (e) {
      print('LLMEnhancedBotAI: Error in sync decision making: $e');
      _llmFailures++;

      // Fallback to parent logic
      return super.makeDecision(bot, controller);
    }
  }

  /// Async decision making - the real implementation for LLM inference
  Future<BotDecision> makeDecisionAsync(
    Player bot,
    GameController controller,
  ) async {
    final gameState = controller.gameState;

    try {
      // Set personality context (inherited from parent)
      personalityManager.setCurrentPlayerContext(bot.id);

      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'LLMEnhancedBotAI async decision - LLM enabled: $_isLLMEnabled, available: ${_webLLMService.isAvailable}',
      );

      // Check if we should use LLM for this decision
      if (_shouldUseLLMForDecision(bot, gameState, controller)) {
        return await _makeLLMEnhancedDecisionAsync(bot, controller);
      } else {
        // Use existing sophisticated rule-based logic
        final decision = super.makeDecision(bot, controller);
        _ruleBasedDecisions++;

        DebugLogger.botDebug(
          bot.id,
          bot.name,
          'Async rule-based decision: ${decision.action}',
        );

        return decision;
      }
    } catch (e) {
      print('LLMEnhancedBotAI: Error in async decision making: $e');
      _llmFailures++;

      // Fallback to parent logic
      return super.makeDecision(bot, controller);
    }
  }

  /// Determine if LLM should be used for this specific decision
  bool _shouldUseLLMForDecision(
    Player bot,
    GameState gameState,
    GameController controller,
  ) {
    // Don't use LLM if not available or disabled
    if (!_isLLMEnabled || !_webLLMService.isAvailable) {
      return false;
    }

    // Always use rule-based for emergency situations (keeps existing emergency logic intact)
    if (_isEmergencyState(bot, gameState)) {
      return false;
    }

    // Build context for decision
    final context = _buildDecisionContext(bot, gameState, controller);

    // Use web LLM service's logic to determine if this warrants strategic analysis
    return _webLLMService.shouldUseLLMForDecision(
      gameState: gameState,
      botPlayer: bot,
      context: context,
    );
  }

  /// Check if this is an emergency state that requires fast rule-based response
  bool _isEmergencyState(Player bot, GameState gameState) {
    // Hand size emergencies (use existing thresholds)
    if (bot.currentHand.length >= 14) {
      return true;
    }

    // Opponent about to go out
    final dangerousOpponents = gameState.players
        .where(
          (p) =>
              p.id != bot.id && p.hasPickedUpFoot && p.currentHand.length <= 3,
        )
        .length;

    if (dangerousOpponents > 0) {
      return true;
    }

    // Deck running low
    if (gameState.deck.size <= 10) {
      return true;
    }

    return false;
  }

  /// Build decision context for LLM analysis
  Map<String, dynamic> _buildDecisionContext(
    Player bot,
    GameState gameState,
    GameController controller,
  ) {
    final context = <String, dynamic>{};

    // Basic game state info
    context['turnPhase'] = gameState.turnPhase.name;
    context['canGoOut'] = _canGoOutImmediately(bot, gameState);

    // Discard pile information
    if (gameState.discardPile.isNotEmpty) {
      context['discardPileTop'] = gameState.discardPile.last.toString();
      context['canUnlockDiscardPile'] = _canUnlockDiscardPile(
        bot,
        gameState,
        controller,
      );
    }

    // Opponent analysis
    context['opponentThreat'] = _assessOpponentThreat(gameState, bot);
    context['isLeading'] = _isPlayerLeading(bot, gameState);

    // Strategic opportunities
    context['possibleMelds'] = _countPossibleMelds(bot);
    context['nearBooks'] = _countNearBooks(bot);
    context['hasCleanBook'] = _hasCleanBook(bot);
    context['hasDirtyBook'] = _hasDirtyBook(bot);

    // Round information
    context['playDownRequirement'] = GameConfig.getPlayDownRequirement(
      gameState.round,
    );
    context['currentRound'] = gameState.round;

    return context;
  }

  /// Make decision using LLM strategic reasoning (async version)
  Future<BotDecision> _makeLLMEnhancedDecisionAsync(
    Player bot,
    GameController controller,
  ) async {
    try {
      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'Using LLM for strategic decision (async)',
      );

      // Run LLM inference with proper async handling
      return await _runLLMDecisionWithTimeoutAsync(bot, controller);
    } catch (e) {
      print('LLMEnhancedBotAI: LLM decision failed: $e');
      _llmFailures++;

      // Fallback to rule-based decision
      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'LLM failed, using rule-based fallback',
      );
      final decision = super.makeDecision(bot, controller);
      _ruleBasedDecisions++;
      return decision;
    }
  }

  /// Run LLM decision with proper async timeout and fallback
  Future<BotDecision> _runLLMDecisionWithTimeoutAsync(
    Player bot,
    GameController controller,
  ) async {
    final gameState = controller.gameState;
    final context = _buildDecisionContext(bot, gameState, controller);
    final personality = personalityManager.getPersonality(bot.id);

    try {
      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'Running LLM inference for ${personality.name} personality...',
      );

      // Generate LLM response with timeout
      final llmResponse = await _webLLMService.generateStrategicDecision(
        gameState: gameState,
        botPlayer: bot,
        personality: personality,
        context: context,
      );

      if (llmResponse != null && llmResponse.isNotEmpty) {
        _llmDecisions++;

        // Parse LLM response to decision
        final decision = _parseLLMResponseToDecision(
          llmResponse,
          bot,
          controller,
        );

        DebugLogger.botDebug(
          bot.id,
          bot.name,
          'LLM decision: ${decision.action} (reasoning: ${llmResponse.split(' - ').length > 1 ? llmResponse.split(' - ')[1] : 'strategic'})',
        );

        return decision;
      } else {
        // LLM returned empty/null response, fallback
        DebugLogger.botDebug(
          bot.id,
          bot.name,
          'LLM returned empty response, using fallback',
        );
        _llmFailures++;
        final decision = super.makeDecision(bot, controller);
        _ruleBasedDecisions++;
        return decision;
      }
    } catch (e) {
      print('LLMEnhancedBotAI: LLM inference error: $e');
      _llmFailures++;

      // Fallback to rule-based
      final decision = super.makeDecision(bot, controller);
      _ruleBasedDecisions++;
      return decision;
    }
  }

  /// Parse LLM response and convert to BotDecision
  BotDecision _parseLLMResponseToDecision(
    String llmResponse,
    Player bot,
    GameController controller,
  ) {
    final parsed = _webLLMService.parseResponse(llmResponse);
    final action = parsed['action'] ?? 'DRAW_DECK';

    DebugLogger.botDebug(bot.id, bot.name, 'Parsing LLM action: $action');

    // Convert LLM action to BotDecision format
    switch (action) {
      case 'DRAW_DECK':
        return BotDecision(action: 'drawFromDeck');
      case 'DRAW_DISCARD':
        return BotDecision(action: 'drawFromDiscardPile');
      case 'MELD':
        // For meld decisions, use rule-based logic to determine what to meld
        // LLM made the strategic decision to meld, but rules determine how
        return _createRuleBasedMeldDecision(bot, controller);
      case 'DISCARD':
        // LLM decided to discard, use rule-based logic to pick which card
        return _createRuleBasedDiscardDecision(bot, controller);
      case 'GO_OUT':
        return BotDecision(action: 'goOut');
      case 'END_MELD':
        return BotDecision(action: 'endMeld');
      default:
        // Fallback for unrecognized actions
        DebugLogger.botDebug(
          bot.id,
          bot.name,
          'Unrecognized LLM action: $action, using fallback',
        );
        return super.makeDecision(bot, controller);
    }
  }

  /// Create meld decision using rule-based logic after LLM strategic choice
  BotDecision _createRuleBasedMeldDecision(
    Player bot,
    GameController controller,
  ) {
    // Use the parent's sophisticated meld analysis
    return super.makeDecision(bot, controller);
  }

  /// Create discard decision using rule-based logic after LLM strategic choice
  BotDecision _createRuleBasedDiscardDecision(
    Player bot,
    GameController controller,
  ) {
    // Use the parent's sophisticated discard logic
    return super.makeDecision(bot, controller);
  }

  // Helper methods for context building

  bool _canGoOutImmediately(Player bot, GameState gameState) {
    return GameConfig.canGoOut(bot) && bot.currentHand.length <= 1;
  }

  bool _canUnlockDiscardPile(
    Player bot,
    GameState gameState,
    GameController controller,
  ) {
    // Use the game state's unlock validation logic
    try {
      return gameState.canUnlockDiscard();
    } catch (e) {
      return false;
    }
  }

  int _assessOpponentThreat(GameState gameState, Player bot) {
    int threat = 0;

    for (final opponent in gameState.players) {
      if (opponent.id == bot.id) continue;

      // High threat: opponent has foot and small hand
      if (opponent.hasPickedUpFoot && opponent.currentHand.length <= 5) {
        threat += 3;
      }
      // Medium threat: opponent has played down and reasonable hand
      else if (opponent.hasPlayedDown && opponent.currentHand.length <= 10) {
        threat += 2;
      }
      // Low threat: opponent hasn't played down but has small hand
      else if (opponent.currentHand.length <= 15) {
        threat += 1;
      }
    }

    return threat;
  }

  bool _isPlayerLeading(Player bot, GameState gameState) {
    final scores = gameState.players.map((p) => p.score).toList()..sort();
    return bot.score >= scores.last;
  }

  int _countPossibleMelds(Player bot) {
    final hand = bot.currentHand;
    final rankCounts = <String, int>{};

    for (final card in hand) {
      if (!card.rank.name.contains('three')) {
        rankCounts[card.rank.name] = (rankCounts[card.rank.name] ?? 0) + 1;
      }
    }

    return rankCounts.values.where((count) => count >= 2).length;
  }

  int _countNearBooks(Player bot) {
    return bot.melds.where((meld) => meld.cards.length >= 5).length;
  }

  bool _hasCleanBook(Player bot) {
    return bot.melds.any((meld) => meld.cards.length >= 7 && meld.isClean);
  }

  bool _hasDirtyBook(Player bot) {
    return bot.melds.any((meld) => meld.cards.length >= 7 && !meld.isClean);
  }

  /// Enable or disable LLM functionality
  void setLLMEnabled(bool enabled) {
    _isLLMEnabled = enabled;
    if (enabled) {
      initializeLLM();
    }
    print('LLMEnhancedBotAI: LLM ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Get LLM usage statistics
  Map<String, dynamic> getLLMStats() {
    final total = _llmDecisions + _ruleBasedDecisions;
    return {
      'llmDecisions': _llmDecisions,
      'ruleBasedDecisions': _ruleBasedDecisions,
      'llmFailures': _llmFailures,
      'llmUsagePercent': total > 0
          ? (_llmDecisions / total * 100).toStringAsFixed(1)
          : '0.0',
      'isLLMAvailable': _webLLMService.isAvailable,
      'llmServiceStatus': _webLLMService.getStatus(),
    };
  }

  /// Reset LLM statistics
  void resetLLMStats() {
    _llmDecisions = 0;
    _ruleBasedDecisions = 0;
    _llmFailures = 0;
    _webLLMService.reset();
  }

  /// Dispose resources
  void dispose() {
    _webLLMService.dispose();
    // Note: EnhancedBotAI doesn't have dispose method
  }

  // Expose parent methods for direct access if needed

  /// Get personality manager from parent
  @override
  BotPersonalityManager get personalityManager => super.personalityManager;

  /// Assign personality to bot (preserves existing functionality)
  @override
  void assignPersonality(String playerId, BotPersonality personality) {
    super.assignPersonality(playerId, personality);

    if (kDebugMode) {
      print(
        'LLMEnhancedBotAI: Assigned ${personality.name} personality to $playerId',
      );
    }
  }

  /// Auto-assign random personalities (preserves existing functionality)
  @override
  void assignRandomPersonalities(List<Player> botPlayers) {
    super.assignRandomPersonalities(botPlayers);

    if (kDebugMode) {
      print(
        'LLMEnhancedBotAI: Auto-assigned personalities to ${botPlayers.length} bots',
      );
      for (final bot in botPlayers.where((p) => p.type == PlayerType.bot)) {
        final personality = personalityManager.getPersonality(bot.id);
        print('  ${bot.name}: ${personality.name}');
      }
    }
  }

  /// Get detailed decision info for debugging
  Map<String, dynamic> getDecisionInfo(Player bot, GameState gameState) {
    final personality = personalityManager.getPersonality(bot.id);
    final constants = personalityManager.getConstants(bot.id);

    return {
      'botName': bot.name,
      'personality': personality.name,
      'hasPlayedDown': bot.hasPlayedDown,
      'hasPickedUpFoot': bot.hasPickedUpFoot,
      'handSize': bot.currentHand.length,
      'meldCount': bot.melds.length,
      'score': bot.score,
      'personalityConstants': {
        'strategicBufferPoints': constants.strategicBufferPoints,
        'aggressivenessMultiplier': constants.aggressivenessMultiplier,
        'bookCompletionPriority': constants.bookCompletionPriority,
      },
      'llmStats': getLLMStats(),
    };
  }

  /// Get current decision making mode for logging
  String getDecisionMode() {
    if (!_isLLMEnabled) return 'rule-based-only';
    if (!_webLLMService.isAvailable) return 'rule-based-fallback';
    return 'web-llm-enhanced';
  }
}
