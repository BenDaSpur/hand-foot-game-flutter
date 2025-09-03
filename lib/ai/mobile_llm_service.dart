import 'dart:async';
import '../models/game_state.dart';
import '../models/player.dart';
import 'bot_personality.dart';

/// Mobile and desktop LLM service using intelligent fallback
class MobileLLMService {
  static const String _modelAssetPath =
      'assets/models/phi3-mini-4k-instruct-cpu-int4-rtn-block-32-acc-level-4.tflite';

  // Service state for intelligent fallback system
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _lastError;
  final Map<String, String> _responseCache = {};

  /// Initialize intelligent fallback service
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    if (_isLoading) {
      await _waitForLoadCompletion();
      return _isInitialized;
    }

    _isLoading = true;
    _lastError = null;

    try {
      print('MobileLLMService: Initializing intelligent fallback service...');

      // For now, always use intelligent fallback
      // TensorFlow Lite implementation can be added later when needed
      print(
        'MobileLLMService: Using intelligent fallback (TensorFlow Lite implementation planned for future)',
      );

      _lastError = null; // Clear error since fallback is valid
      _isInitialized =
          true; // Mark as initialized to enable intelligent fallback
      return true;
    } catch (e) {
      print('MobileLLMService: Initialization failed: $e');
      _lastError = 'Initialization failed: $e';
      _isInitialized = false;
      return false;
    } finally {
      _isLoading = false;
    }
  }

  /// Wait for model loading completion
  Future<void> _waitForLoadCompletion() async {
    while (_isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Check if LLM is available (includes intelligent fallback)
  bool get isAvailable => _isInitialized;

  /// Get last error
  String? get lastError => _lastError;

  /// Generate strategic decision using TensorFlow Lite inference
  Future<String?> generateStrategicDecision({
    required GameState gameState,
    required Player botPlayer,
    required BotPersonality personality,
    required Map<String, dynamic> context,
  }) async {
    if (!isAvailable) {
      return generateIntelligentFallback(
        gameState,
        botPlayer,
        personality,
        context,
      );
    }

    try {
      // Use intelligent fallback system for strategic decisions
      print(
        'MobileLLMService: Using intelligent fallback for strategic reasoning',
      );
      return generateIntelligentFallback(
        gameState,
        botPlayer,
        personality,
        context,
      );
    } catch (e) {
      print('MobileLLMService: Decision generation failed: $e');
      return generateIntelligentFallback(
        gameState,
        botPlayer,
        personality,
        context,
      );
    }
  }

  /// Generate intelligent fallback response for ALL game situations
  String? generateIntelligentFallback(
    GameState gameState,
    Player botPlayer,
    BotPersonality personality,
    Map<String, dynamic> context,
  ) {
    // ENHANCED: Comprehensive decision making for ALL game situations

    // High priority: Go out if possible (end round)
    if (context['canGoOut'] == true) {
      return 'GO_OUT - ${personality.name} bot ending round with victory!';
    }

    // Phase-specific decisions based on current turn phase
    switch (gameState.turnPhase.name) {
      case 'draw':
        // Draw phase decisions
        if (context['canUnlockDiscardPile'] == true) {
          switch (personality) {
            case BotPersonality.conservative:
              return 'DRAW_DECK - Conservative bot avoiding risky discard pile';
            case BotPersonality.aggressive:
              return 'DRAW_DISCARD - Aggressive bot taking discard pile for advantage';
            case BotPersonality.bookBuilder:
              return 'DRAW_DISCARD - Book-building bot using discard pile strategically';
            case BotPersonality.adaptive:
              final isLeading = context['isLeading'] == true;
              return isLeading
                  ? 'DRAW_DECK - Adaptive bot playing safe while leading'
                  : 'DRAW_DISCARD - Adaptive bot taking calculated risk';
          }
        } else {
          // Standard deck draw with personality flavor
          return 'DRAW_DECK - ${personality.name} bot drawing from deck to build hand';
        }

      case 'meld':
        // Meld phase decisions
        final possibleMelds = context['possibleMelds'] ?? 0;
        final hasPlayedDown = botPlayer.hasPlayedDown;

        if (possibleMelds > 0) {
          if (!hasPlayedDown) {
            return 'MELD - ${personality.name} bot playing down for Round ${gameState.round}';
          } else {
            return 'MELD - ${personality.name} bot building toward books ($possibleMelds possible melds)';
          }
        } else {
          return 'END_MELD - ${personality.name} bot holding cards strategically';
        }

      case 'discard':
        // Discard phase - always need to discard something
        final handSize = botPlayer.currentHand.length;
        if (handSize <= 3 && botPlayer.hasPickedUpFoot) {
          return 'DISCARD - ${personality.name} bot positioning for endgame';
        } else {
          return 'DISCARD - ${personality.name} bot discarding strategically ($handSize cards)';
        }

      default:
        // Fallback for any unknown phase
        return 'DRAW_DECK - ${personality.name} bot making safe default move';
    }
  }

  /// Parse response to extract action and reasoning
  Map<String, String> parseResponse(String response) {
    final parts = response.trim().split(' - ');
    if (parts.length >= 2) {
      return {
        'action': parts[0].trim().toUpperCase(),
        'reasoning': parts.sublist(1).join(' - ').trim(),
      };
    }

    return {'action': 'DRAW_DECK', 'reasoning': 'Default safe action'};
  }

  /// Check if should use LLM for this decision
  bool shouldUseLLMForDecision({
    required GameState gameState,
    required Player botPlayer,
    required Map<String, dynamic> context,
  }) {
    if (!isAvailable) {
      return false; // Always use fallback if not available
    }

    // MODIFIED: Always use LLM for ALL decisions when service is available
    return true;
  }

  /// Dispose resources
  void dispose() {
    // No interpreter to close since using intelligent fallback
    _isInitialized = false;
    _responseCache.clear();
    _lastError = null;
    print('MobileLLMService: Disposed');
  }

  /// Reset service
  void reset() {
    _responseCache.clear();
    _lastError = null;
    print('MobileLLMService: Reset');
  }

  /// Get service status
  Map<String, dynamic> getStatus() {
    return {
      'isInitialized': _isInitialized,
      'isLoading': _isLoading,
      'isAvailable': isAvailable,
      'lastError': _lastError,
      'cacheSize': _responseCache.length,
      'platform': 'Mobile/Desktop',
      'interpreterAvailable':
          false, // Using intelligent fallback instead of TensorFlow Lite
      'modelPath': _modelAssetPath,
    };
  }
}
