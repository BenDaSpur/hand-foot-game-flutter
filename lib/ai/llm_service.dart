import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import 'bot_personality.dart';
import 'web_llm_service.dart';
import 'mobile_llm_service_stub.dart'
    if (dart.library.io) 'mobile_llm_service.dart';

/// Universal LLM service that works across all platforms (web, mobile, macOS)
class LLMService {
  static LLMService? _instance;
  static LLMService get instance => _instance ??= LLMService._internal();

  LLMService._internal();

  WebLLMService? _webLLMService;
  MobileLLMService? _mobileLLMService;
  bool _isInitialized = false;

  /// Initialize the appropriate LLM service based on platform
  Future<bool> initialize() async {
    if (_isInitialized) {
      return isAvailable;
    }

    try {
      print('LLMService: Initializing for platform: ${_getPlatformName()}');

      if (kIsWeb) {
        // Web platform - use ONNX.js
        _webLLMService = WebLLMService();
        _isInitialized = await _webLLMService!.initialize();
      } else {
        // Mobile/Desktop platforms - use TensorFlow Lite
        _mobileLLMService = MobileLLMService();
        _isInitialized = await _mobileLLMService!.initialize();
      }

      print(
        'LLMService: Initialization ${_isInitialized ? 'successful' : 'failed'} for ${_getPlatformName()}',
      );
      return _isInitialized;
    } catch (e) {
      print('LLMService: Initialization error: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Check if LLM is available on current platform
  bool get isAvailable {
    if (kIsWeb) {
      return _webLLMService?.isAvailable ?? false;
    } else {
      return _mobileLLMService?.isAvailable ?? false;
    }
  }

  /// Get last error from the active service
  String? get lastError {
    if (kIsWeb) {
      return _webLLMService?.lastError;
    } else {
      return _mobileLLMService?.lastError;
    }
  }

  /// Generate strategic decision using the appropriate LLM service
  Future<String?> generateStrategicDecision({
    required GameState gameState,
    required Player botPlayer,
    required BotPersonality personality,
    required Map<String, dynamic> context,
  }) async {
    if (!isAvailable) {
      return null; // Will trigger fallback to rule-based logic
    }

    try {
      if (kIsWeb) {
        return await _webLLMService!.generateStrategicDecision(
          gameState: gameState,
          botPlayer: botPlayer,
          personality: personality,
          context: context,
        );
      } else {
        return await _mobileLLMService!.generateStrategicDecision(
          gameState: gameState,
          botPlayer: botPlayer,
          personality: personality,
          context: context,
        );
      }
    } catch (e) {
      print('LLMService: Decision generation failed: $e');
      return null; // Trigger fallback
    }
  }

  /// Parse response to extract action and reasoning
  Map<String, String> parseResponse(String response) {
    if (kIsWeb) {
      return _webLLMService?.parseResponse(response) ??
          {'action': 'DRAW_DECK', 'reasoning': 'Web service unavailable'};
    } else {
      return _mobileLLMService?.parseResponse(response) ??
          {'action': 'DRAW_DECK', 'reasoning': 'Mobile service unavailable'};
    }
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

    if (kIsWeb) {
      return _webLLMService?.shouldUseLLMForDecision(
            gameState: gameState,
            botPlayer: botPlayer,
            context: context,
          ) ??
          false;
    } else {
      return _mobileLLMService?.shouldUseLLMForDecision(
            gameState: gameState,
            botPlayer: botPlayer,
            context: context,
          ) ??
          false;
    }
  }

  /// Get comprehensive service status
  Map<String, dynamic> getStatus() {
    final baseStatus = {
      'platform': _getPlatformName(),
      'isInitialized': _isInitialized,
      'isAvailable': isAvailable,
      'lastError': lastError,
      'activeService': kIsWeb ? 'WebLLMService' : 'MobileLLMService',
    };

    if (kIsWeb && _webLLMService != null) {
      baseStatus.addAll(_webLLMService!.getStatus());
    } else if (!kIsWeb && _mobileLLMService != null) {
      baseStatus.addAll(_mobileLLMService!.getStatus());
    }

    return baseStatus;
  }

  /// Reset the active service
  void reset() {
    if (kIsWeb) {
      _webLLMService?.reset();
    } else {
      _mobileLLMService?.reset();
    }
    print('LLMService: Reset for ${_getPlatformName()}');
  }

  /// Dispose resources
  void dispose() {
    if (kIsWeb) {
      _webLLMService?.dispose();
      _webLLMService = null;
    } else {
      _mobileLLMService?.dispose();
      _mobileLLMService = null;
    }
    _isInitialized = false;
    print('LLMService: Disposed for ${_getPlatformName()}');
  }

  /// Get human-readable platform name
  String _getPlatformName() {
    if (kIsWeb) {
      return 'Web';
    } else {
      return 'Mobile/Desktop';
    }
  }
}
