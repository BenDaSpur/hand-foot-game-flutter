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
