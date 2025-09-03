import 'dart:async';
import '../models/game_state.dart';
import '../models/player.dart';
import 'bot_personality.dart';

/// Stub implementation of WebLLMService for non-web platforms (tests, mobile)
class WebLLMService {
  // Singleton
  static final WebLLMService _instance = WebLLMService._internal();
  factory WebLLMService() => _instance;
  WebLLMService._internal();

  /// Initialize (stub - always returns false for non-web)
  Future<bool> initialize() async {
    print(
      'WebLLMService: Stub implementation - web LLM not available on this platform',
    );
    return false;
  }

  /// Check if LLM is available (always false for non-web)
  bool get isAvailable => false;

  /// Get last error
  String? get lastError => 'Web LLM not supported on this platform';

  /// Generate strategic decision (stub - returns null)
  Future<String?> generateStrategicDecision({
    required GameState gameState,
    required Player botPlayer,
    required BotPersonality personality,
    required Map<String, dynamic> context,
  }) async {
    // Return null - will trigger fallback to rule-based logic
    return null;
  }

  /// Generate intelligent fallback response (not supported on non-web)
  String? generateIntelligentFallback(
    GameState gameState,
    Player botPlayer,
    BotPersonality personality,
    Map<String, dynamic> context,
  ) {
    return null; // Not supported on non-web platforms
  }

  /// Parse response (stub)
  Map<String, String> parseResponse(String response) {
    return {'action': 'DRAW_DECK', 'reasoning': 'Stub implementation'};
  }

  /// Check if should use LLM (always false for stub)
  bool shouldUseLLMForDecision({
    required GameState gameState,
    required Player botPlayer,
    required Map<String, dynamic> context,
  }) {
    return false; // Never use LLM on non-web platforms
  }

  /// Dispose (stub)
  void dispose() {
    print('WebLLMService: Stub disposed');
  }

  /// Reset (stub)
  void reset() {
    print('WebLLMService: Stub reset');
  }

  /// Get status
  Map<String, dynamic> getStatus() {
    return {
      'isInitialized': false,
      'isLoading': false,
      'isAvailable': false,
      'lastError': 'Web LLM not supported on this platform',
      'cacheSize': 0,
      'platform': 'Mobile/Desktop',
      'onnxAvailable': false,
    };
  }
}
