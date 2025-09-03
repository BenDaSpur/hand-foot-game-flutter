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

      // Check if ONNX Runtime is available, with retries
      final onnxAvailable = await _waitForOnnxRuntime();
      if (!onnxAvailable) {
        print(
          'WebLLMService: ONNX Runtime not available after wait, using intelligent fallback',
        );
        _lastError = null; // Clear error since fallback is valid
        _isInitialized = true; // Enable intelligent fallback
        return true;
      }

      // Load model with timeout
      _onnxSession = await _loadModelWithTimeout();

      if (_onnxSession != null) {
        _isInitialized = true;
        print('WebLLMService: ONNX.js session created successfully');
        return true;
      } else {
        print('WebLLMService: ONNX session failed, using intelligent fallback');
        _lastError = null; // Clear error since fallback is valid
        _isInitialized = true; // Enable intelligent fallback
        return true;
      }
    } catch (e) {
      print(
        'WebLLMService: ONNX initialization failed, using intelligent fallback: $e',
      );
      _lastError = null; // Clear error since fallback is valid
      _isInitialized = true; // Enable intelligent fallback
      return true;
    } finally {
      _isLoading = false;
    }
  }

  /// Check if ONNX Runtime is available in the browser
  bool _isOnnxRuntimeAvailable() {
    try {
      final onnxRuntime = js.context['onnxRuntime'];
      final ort = js.context['ort'];
      final available = onnxRuntime != null || ort != null;
      print(
        'WebLLMService: Checking ONNX Runtime availability - onnxRuntime: ${onnxRuntime != null}, ort: ${ort != null}, available: $available',
      );
      return available;
    } catch (e) {
      print('WebLLMService: ONNX Runtime check failed: $e');
      return false;
    }
  }

  /// Wait for ONNX Runtime to become available with retries
  Future<bool> _waitForOnnxRuntime() async {
    const maxAttempts = 10;
    const delayBetweenAttempts = Duration(milliseconds: 500);

    print('WebLLMService: Starting ONNX Runtime availability check...');

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (_isOnnxRuntimeAvailable()) {
        print('WebLLMService: ONNX Runtime available on attempt $attempt');
        return true;
      }

      print(
        'WebLLMService: ONNX Runtime not ready, attempt $attempt/$maxAttempts',
      );

      // Additional debugging - check what's actually in js.context
      try {
        // Check specifically for different ONNX variations
        final hasOrt = js.context.hasProperty('ort');
        final hasOnnxRuntime = js.context.hasProperty('onnxRuntime');
        final hasOnnx = js.context.hasProperty('onnx');
        print(
          'WebLLMService: ort=$hasOrt, onnxRuntime=$hasOnnxRuntime, onnx=$hasOnnx',
        );
      } catch (e) {
        print('WebLLMService: Error checking context: $e');
      }

      await Future.delayed(delayBetweenAttempts);
    }

    print(
      'WebLLMService: ONNX Runtime not available after $maxAttempts attempts',
    );
    return false;
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
      // Try both the mapped onnxRuntime and original ort
      final onnx = js.context['onnxRuntime'] ?? js.context['ort'];

      if (onnx == null) {
        print(
          'WebLLMService: ONNX Runtime not available (neither onnxRuntime nor ort found)',
        );
        return null;
      }

      print(
        'WebLLMService: Using ONNX Runtime object: ${onnx != null ? 'found' : 'not found'}',
      );

      print('WebLLMService: Loading model from $_defaultModelUrl');

      // Create ONNX inference session with proper options for web
      final sessionOptions = js.JsObject.jsify({
        'executionProviders': ['wasm'],
        'graphOptimizationLevel': 'all',
      });

      print('WebLLMService: Creating ONNX inference session...');
      final sessionPromise = onnx['InferenceSession'].callMethod('create', [
        _defaultModelUrl,
        sessionOptions,
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

  /// Check if LLM is available (including intelligent fallback)
  bool get isAvailable => _isInitialized;

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
      // Try actual ONNX inference if session is available
      if (_onnxSession != null) {
        print('WebLLMService: Using ONNX inference for decision making');
        return await _runOnnxInference(
          gameState,
          botPlayer,
          personality,
          context,
        );
      } else {
        print(
          'WebLLMService: ONNX session not available, using intelligent fallback',
        );
        return _generateIntelligentFallback(
          gameState,
          botPlayer,
          personality,
          context,
        );
      }
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

  /// Generate intelligent fallback response for ALL game situations
  String? _generateIntelligentFallback(
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

  /// Run actual ONNX inference for decision making
  Future<String?> _runOnnxInference(
    GameState gameState,
    Player botPlayer,
    BotPersonality personality,
    Map<String, dynamic> context,
  ) async {
    try {
      // Build prompt for Phi-3 model
      final prompt = _buildLLMPrompt(
        gameState,
        botPlayer,
        personality,
        context,
      );
      print(
        'WebLLMService: Running ONNX inference with prompt length: ${prompt.length}',
      );

      // For now, Phi-3 inference is complex (requires tokenization, etc.)
      // So we'll use enhanced intelligent fallback until proper tokenization is implemented
      print(
        'WebLLMService: ONNX inference not fully implemented yet, using enhanced fallback',
      );

      // TODO: Implement proper Phi-3 tokenization, inference, and decoding
      // This would require:
      // 1. Tokenizer for Phi-3
      // 2. Input tensor creation
      // 3. Model inference
      // 4. Output decoding

      return _generateIntelligentFallback(
        gameState,
        botPlayer,
        personality,
        context,
      );
    } catch (e) {
      print('WebLLMService: ONNX inference error: $e');
      return _generateIntelligentFallback(
        gameState,
        botPlayer,
        personality,
        context,
      );
    }
  }

  /// Build LLM prompt for Phi-3 model
  String _buildLLMPrompt(
    GameState gameState,
    Player botPlayer,
    BotPersonality personality,
    Map<String, dynamic> context,
  ) {
    final prompt = StringBuffer();

    // System prompt
    prompt.writeln('<|system|>');
    prompt.writeln(
      'You are a ${personality.name} AI player in a Hand & Foot card game. ',
    );
    prompt.writeln('Make strategic decisions based on the game state. ');
    prompt.writeln(
      'Respond with exactly one action: DRAW_DECK, DRAW_DISCARD, MELD, DISCARD, GO_OUT, or END_MELD',
    );
    prompt.writeln('<|end|>');

    // User prompt with game context
    prompt.writeln('<|user|>');
    prompt.writeln('Game State:');
    prompt.writeln('- Round: ${gameState.round}');
    prompt.writeln('- Turn Phase: ${gameState.turnPhase.name}');
    prompt.writeln('- Hand Size: ${botPlayer.currentHand.length}');
    prompt.writeln('- Has Played Down: ${botPlayer.hasPlayedDown}');
    prompt.writeln('- Has Picked Up Foot: ${botPlayer.hasPickedUpFoot}');
    prompt.writeln('- Can Go Out: ${context['canGoOut'] ?? false}');
    prompt.writeln(
      '- Can Unlock Discard: ${context['canUnlockDiscardPile'] ?? false}',
    );
    prompt.writeln('- Possible Melds: ${context['possibleMelds'] ?? 0}');
    prompt.writeln('- Opponent Threat: ${context['opponentThreat'] ?? 0}');

    prompt.writeln(
      'What should I do? Respond with action and brief reasoning.',
    );
    prompt.writeln('<|end|>');

    prompt.writeln('<|assistant|>');

    return prompt.toString();
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
      'platform': 'Web',
      'onnxAvailable': _isOnnxRuntimeAvailable(),
    };
  }
}
