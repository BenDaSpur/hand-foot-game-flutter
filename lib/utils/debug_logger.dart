import 'package:flutter/foundation.dart';

/// Centralized debug logging utility for consistent debug output across the app.
///
/// All debug prints are automatically removed in release builds through the use
/// of assert() blocks, improving production performance while maintaining
/// comprehensive debugging during development.
class DebugLogger {
  /// Log a debug message (removed in release builds)
  static void debug(String message) {
    assert(() {
      if (kDebugMode) {
        print('DEBUG: $message');
      }
      return true;
    }());
  }

  /// Log a warning message (removed in release builds)
  static void warning(String message) {
    assert(() {
      if (kDebugMode) {
        print('WARNING: $message');
      }
      return true;
    }());
  }

  /// Log an error message (always shown, even in release builds)
  static void error(String message) {
    print('ERROR: $message');
  }

  /// Log bot-specific debug information (removed in release builds)
  static void botDebug(String botId, String botName, String message) {
    assert(() {
      if (kDebugMode) {
        print('DEBUG: Bot $botId ($botName) - $message');
      }
      return true;
    }());
  }

  /// Log game state information (removed in release builds)
  static void gameState(
    String phase,
    String turnPhase,
    int round,
    String currentPlayer,
  ) {
    assert(() {
      if (kDebugMode) {
        print(
          'DEBUG: GameState - Phase: $phase, TurnPhase: $turnPhase, Round: $round, CurrentPlayer: $currentPlayer',
        );
      }
      return true;
    }());
  }

  /// Log method entry/exit for tracing (removed in release builds)
  static void trace(String methodName, [String? additionalInfo]) {
    assert(() {
      if (kDebugMode) {
        final info = additionalInfo != null ? ' - $additionalInfo' : '';
        print('TRACE: $methodName$info');
      }
      return true;
    }());
  }
}
