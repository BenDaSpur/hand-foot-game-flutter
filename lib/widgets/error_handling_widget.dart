import 'package:flutter/material.dart';
import '../theme/balatro_theme.dart';

/// Comprehensive error handling widget for multiplayer games
/// Provides user-friendly error messages and recovery options
class ErrorHandlingWidget extends StatelessWidget {
  final String title;
  final String message;
  final String? details;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final bool isNetworkError;

  const ErrorHandlingWidget({
    super.key,
    required this.title,
    required this.message,
    this.details,
    this.onRetry,
    this.onDismiss,
    this.isNetworkError = false,
  });

  /// Factory for network errors
  factory ErrorHandlingWidget.networkError({
    String? message,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    return ErrorHandlingWidget(
      title: 'Connection Error',
      message:
          message ??
          'Lost connection to the game server. Your game progress is safe.',
      isNetworkError: true,
      onRetry: onRetry,
      onDismiss: onDismiss,
    );
  }

  /// Factory for game state errors
  factory ErrorHandlingWidget.gameStateError({
    String? message,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    return ErrorHandlingWidget(
      title: 'Game Error',
      message:
          message ??
          'Something went wrong with the game state. Please try again.',
      onRetry: onRetry,
      onDismiss: onDismiss,
    );
  }

  /// Factory for sync errors
  factory ErrorHandlingWidget.syncError({
    String? message,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    return ErrorHandlingWidget(
      title: 'Sync Error',
      message:
          message ?? 'Failed to sync game state. Other players may be ahead.',
      isNetworkError: true,
      onRetry: onRetry,
      onDismiss: onDismiss,
    );
  }

  /// Sanitizes error messages for user display while preserving details for logging
  static String sanitizeErrorMessage(
    String errorMessage, {
    bool preserveDetails = false,
  }) {
    if (preserveDetails) {
      // For logging - return full error but remove sensitive paths
      return errorMessage
          .replaceAll(RegExp(r'/Users/[^/]+'), '/Users/***')
          .replaceAll(RegExp(r'\\Users\\[^\\]+'), '\\Users\\***')
          .replaceAll(RegExp(r'file:///[^\s]+'), 'file:///***/');
    }

    // For user display - provide friendly messages
    final lowerError = errorMessage.toLowerCase();

    // Check specific service errors first before generic network errors
    if (lowerError.contains('firebase') || lowerError.contains('database')) {
      return 'Game service is temporarily unavailable. Please try again later.';
    }

    if (lowerError.contains('timeout')) {
      return 'The request timed out. Please try again.';
    }

    if (lowerError.contains('permission') ||
        lowerError.contains('unauthorized')) {
      return 'You do not have permission to perform this action.';
    }

    if (lowerError.contains('format') ||
        lowerError.contains('parse') ||
        lowerError.contains('invalid')) {
      return 'Invalid game data detected. Please restart the game.';
    }

    // Generic network errors last
    if (lowerError.contains('network') || lowerError.contains('connection')) {
      return 'Unable to connect to the game server. Please check your internet connection.';
    }

    // Generic fallback message
    return 'An unexpected error occurred. Please try again or contact support if the problem persists.';
  }

  /// Creates a user-friendly error message from an exception
  static String createUserFriendlyMessage(Object error) {
    String errorString = error.toString();

    // Log full error for debugging (in production, this would go to a logging service)
    // ignore: avoid_print
    print(
      'Full error for logging: ${sanitizeErrorMessage(errorString, preserveDetails: true)}',
    );

    // Return sanitized message for user
    return sanitizeErrorMessage(errorString);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BalatroTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Error header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isNetworkError ? Icons.wifi_off : Icons.error,
                  color: Colors.red,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Error message
          Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),

          if (details != null) ...[
            const SizedBox(height: 8),
            Text(
              details!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onDismiss != null)
                TextButton(
                  onPressed: onDismiss,
                  child: Text(
                    'Dismiss',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),

              if (onRetry != null) ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BalatroTheme.neonBlue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Error dialog utility methods
class GameErrorDialog {
  /// Show a network error dialog
  static void showNetworkError(
    BuildContext context, {
    String? message,
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
        ),
        content: ErrorHandlingWidget.networkError(
          message: message,
          onRetry: () {
            Navigator.of(context).pop();
            onRetry?.call();
          },
          onDismiss: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  /// Show a game state error dialog
  static void showGameStateError(
    BuildContext context, {
    String? message,
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
        ),
        content: ErrorHandlingWidget.gameStateError(
          message: message,
          onRetry: () {
            Navigator.of(context).pop();
            onRetry?.call();
          },
          onDismiss: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  /// Show a sync error snackbar
  static void showSyncError(
    BuildContext context, {
    String? message,
    VoidCallback? onRetry,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.withValues(alpha: 0.9),
        content: Row(
          children: [
            Icon(Icons.sync_problem, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message ?? 'Failed to sync. Retrying...',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Show a connection restored snackbar
  static void showConnectionRestored(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green.withValues(alpha: 0.9),
        content: Row(
          children: const [
            Icon(Icons.wifi, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text(
              'Connection restored! Game synchronized.',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
