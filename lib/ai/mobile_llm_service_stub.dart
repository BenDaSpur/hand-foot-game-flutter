import 'dart:async';
import '../models/game_state.dart';
import '../models/player.dart';
import 'bot_personality.dart';

/// Stub implementation of MobileLLMService for web platform
class MobileLLMService {
  /// Initialize (stub - always returns false for web)
  Future<bool> initialize() async {
    print(
      'MobileLLMService: Stub implementation - TensorFlow Lite not available on web',
    );
    return false;
  }

  /// Check if LLM is available (always false for web)
  bool get isAvailable => false;

  /// Get last error
  String? get lastError => 'TensorFlow Lite not supported on web platform';

  /// Generate strategic decision (stub - returns null)
  Future<String?> generateStrategicDecision({
    required GameState gameState,
    required Player botPlayer,
    required BotPersonality personality,
    required Map<String, dynamic> context,
  }) async {
    // Return null - will trigger fallback to WebLLMService
    return null;
  }

  /// Parse response (stub)
  Map<String, String> parseResponse(String response) {
    return {'action': 'DRAW_DECK', 'reasoning': 'Web stub implementation'};
  }

  /// Check if should use LLM (always false for stub)
  bool shouldUseLLMForDecision({
    required GameState gameState,
    required Player botPlayer,
    required Map<String, dynamic> context,
  }) {
    return false; // Never use LLM on web platform stub
  }

  /// Dispose (stub)
  void dispose() {
    print('MobileLLMService: Web stub disposed');
  }

  /// Reset (stub)
  void reset() {
    print('MobileLLMService: Web stub reset');
  }

  /// Get status
  Map<String, dynamic> getStatus() {
    return {
      'isInitialized': false,
      'isLoading': false,
      'isAvailable': false,
      'lastError': 'TensorFlow Lite not supported on web platform',
      'cacheSize': 0,
      'platform': 'Web',
      'interpreterAvailable': false,
      'modelPath': 'N/A',
    };
  }
}
