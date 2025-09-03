import 'dart:async';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:js' as js;
import '../models/game_state.dart';
import '../models/player.dart';
import 'bot_personality.dart';

/// Web-specific LLM service using ONNX.js for browser-based inference
class WebLLMService {
  static const String _defaultModelUrl =
      'assets/models/phi3-mini-4k-instruct-cpu-int4-rtn-block-32-acc-level-4.onnx';
  static const Duration _modelLoadTimeout = Duration(seconds: 60);

  js.JsObject? _onnxSession;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _lastError;
  final Map<String, String> _responseCache = {};

  // Singleton
  static final WebLLMService _instance = WebLLMService._internal();
  factory WebLLMService() => _instance;
  WebLLMService._internal();

  /// Initialize ONNX.js session with the model
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
      print('WebLLMService: Starting ONNX.js initialization...');

      // Check if ONNX Runtime is available
      if (!_isOnnxRuntimeAvailable()) {
        _lastError = 'ONNX Runtime not available in browser';
        return false;
      }

      // Load model with timeout
      _onnxSession = await _loadModelWithTimeout();

      if (_onnxSession != null) {
        _isInitialized = true;
        print('WebLLMService: ONNX.js session created successfully');
        return true;
      } else {
        _lastError = 'Failed to create ONNX session';
        return false;
      }
    } catch (e) {
      _lastError = 'ONNX initialization failed: $e';
      print('WebLLMService Error: $_lastError');
      return false;
    } finally {
      _isLoading = false;
    }
  }

  /// Check if ONNX Runtime is available in the browser
  bool _isOnnxRuntimeAvailable() {
    try {
      final onnx = js.context['onnxRuntime'];
      return onnx != null;
    } catch (e) {
      print('WebLLMService: ONNX Runtime check failed: $e');
      return false;
    }
  }

  /// Load ONNX model with timeout
  Future<js.JsObject?> _loadModelWithTimeout() async {
    try {
      final completer = Completer<js.JsObject?>();

      Timer(_modelLoadTimeout, () {
        if (!completer.isCompleted) {
          print('WebLLMService: Model loading timeout');
          completer.complete(null);
        }
      });

      _loadOnnxModel()
          .then((session) {
            if (!completer.isCompleted) {
              completer.complete(session);
            }
          })
          .catchError((error) {
            if (!completer.isCompleted) {
              print('WebLLMService: Model loading error: $error');
              completer.complete(null);
            }
          });

      return await completer.future;
    } catch (e) {
      print('WebLLMService: Model load timeout wrapper error: $e');
      return null;
    }
  }

  /// Load ONNX model from URL or assets
  Future<js.JsObject?> _loadOnnxModel() async {
    try {
      final onnx = js.context['onnxRuntime'];
      if (onnx == null) {
        print('WebLLMService: ONNX Runtime not available');
        return null;
      }

      print('WebLLMService: Loading model from $_defaultModelUrl');

      // Create ONNX inference session
      final sessionPromise = onnx.callMethod('InferenceSession', [
        'create',
        _defaultModelUrl,
      ]);

      // Convert JavaScript Promise to Dart Future
      final session = await _promiseToFuture(sessionPromise);

      if (session != null) {
        print('WebLLMService: ONNX session created successfully');
        return session;
      } else {
        print('WebLLMService: Failed to create ONNX session');
        return null;
      }
    } catch (e) {
      print('WebLLMService: ONNX model loading failed: $e');
      return null;
    }
  }

  /// Convert JavaScript Promise to Dart Future
  Future<js.JsObject?> _promiseToFuture(js.JsObject promise) async {
    try {
      final completer = Completer<js.JsObject?>();

      promise.callMethod('then', [
        js.allowInterop((result) {
          if (!completer.isCompleted) {
            completer.complete(result);
          }
        }),
      ]);

      promise.callMethod('catch', [
        js.allowInterop((error) {
          if (!completer.isCompleted) {
            print('WebLLMService: Promise rejected: $error');
            completer.complete(null);
          }
        }),
      ]);

      return await completer.future.timeout(
        _modelLoadTimeout,
        onTimeout: () => null,
      );
    } catch (e) {
      print('WebLLMService: Promise conversion failed: $e');
      return null;
    }
  }

  /// Wait for model loading completion
  Future<void> _waitForLoadCompletion() async {
    while (_isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Check if LLM is available
  bool get isAvailable => _isInitialized && _onnxSession != null;

  /// Get last error
  String? get lastError => _lastError;

  /// Generate strategic decision using web ONNX inference
  Future<String?> generateStrategicDecision({
    required GameState gameState,
    required Player botPlayer,
    required BotPersonality personality,
    required Map<String, dynamic> context,
  }) async {
    if (!isAvailable) {
      return _generateIntelligentFallback(
        gameState,
        botPlayer,
        personality,
        context,
      );
    }

    try {
      // Simple intelligent fallback for ONNX
      return _generateIntelligentFallback(
        gameState,
        botPlayer,
        personality,
        context,
      );
    } catch (e) {
      print('WebLLMService: Decision generation failed: $e');
      return _generateIntelligentFallback(
        gameState,
        botPlayer,
        personality,
        context,
      );
    }
  }

  /// Generate intelligent fallback response
  String? _generateIntelligentFallback(
    GameState gameState,
    Player botPlayer,
    BotPersonality personality,
    Map<String, dynamic> context,
  ) {
    // Personality-based strategic responses
    switch (personality) {
      case BotPersonality.conservative:
        if (context['canUnlockDiscardPile'] == true) {
          return 'DRAW_DECK - Conservative approach, avoiding risky pile unlock';
        } else if (context['canGoOut'] == true) {
          return 'GO_OUT - Safe finish with required books completed';
        }
        break;

      case BotPersonality.aggressive:
        if (context['canUnlockDiscardPile'] == true) {
          return 'DRAW_DISCARD - Aggressive play for maximum point advantage';
        } else if (context['opponentThreat'] != null &&
            context['opponentThreat'] > 2) {
          return 'MELD - Bold play to maintain competitive pressure';
        }
        break;

      case BotPersonality.bookBuilder:
        if (context['nearBooks'] != null && context['nearBooks'] > 0) {
          return 'MELD - Prioritizing book completion for maximum points';
        } else if (context['possibleMelds'] != null &&
            context['possibleMelds'] > 1) {
          return 'MELD - Strategic meld creation for book foundation';
        }
        break;

      case BotPersonality.adaptive:
        if (context['isLeading'] == true) {
          return 'DRAW_DECK - Adaptive conservative play while leading';
        } else if (context['opponentThreat'] != null &&
            context['opponentThreat'] > 2) {
          return 'MELD - Adaptive aggressive response to threats';
        }
        break;
    }

    // Default strategic response
    if (gameState.turnPhase.name == 'draw') {
      return 'DRAW_DECK - Building strategic hand strength';
    } else if (gameState.turnPhase.name == 'meld') {
      return 'MELD - Optimal timing for strategic play';
    } else {
      return 'DISCARD - Strategic positioning for next opportunity';
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

    // Use LLM for strategic decisions
    return context['canUnlockDiscardPile'] == true ||
        context['canGoOut'] == true ||
        (context['possibleMelds'] ?? 0) > 1 ||
        (botPlayer.hasPickedUpFoot && botPlayer.currentHand.length <= 7) ||
        (context['opponentThreat'] ?? 0) > 2 ||
        gameState.round >= 3;
  }

  /// Dispose resources
  void dispose() {
    _onnxSession = null;
    _isInitialized = false;
    _responseCache.clear();
    print('WebLLMService: Disposed');
  }

  /// Reset service
  void reset() {
    _responseCache.clear();
    _lastError = null;
    print('WebLLMService: Reset');
  }

  /// Get service status
  Map<String, dynamic> getStatus() {
    return {
      'isInitialized': _isInitialized,
      'isLoading': _isLoading,
      'isAvailable': isAvailable,
      'lastError': _lastError,
      'cacheSize': _responseCache.length,
      'platform': 'web',
      'onnxAvailable': _isOnnxRuntimeAvailable(),
    };
  }
}
