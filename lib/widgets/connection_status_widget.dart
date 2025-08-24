import 'package:flutter/material.dart';
import '../theme/balatro_theme.dart';
import '../game/enhanced_multiplayer_controller.dart';

/// Widget that displays real-time connection status for multiplayer games
/// Provides visual feedback about network connectivity and sync state
class ConnectionStatusWidget extends StatelessWidget {
  final EnhancedMultiplayerController? controller;
  final bool compact;
  final bool showText;

  const ConnectionStatusWidget({
    super.key,
    required this.controller,
    this.compact = false,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    if (controller == null) {
      return const SizedBox.shrink(); // Hide for singleplayer
    }

    return StreamBuilder<bool>(
      stream: controller!.connectionStream,
      initialData: controller!.isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        final statusColor = isOnline ? Colors.green : Colors.red;
        final statusText = isOnline ? 'Connected' : 'Offline';
        final statusIcon = isOnline ? Icons.wifi : Icons.wifi_off;

        if (compact) {
          return _buildCompactIndicator(statusColor, statusIcon, statusText);
        } else {
          return _buildFullIndicator(
            statusColor,
            statusIcon,
            statusText,
            isOnline,
          );
        }
      },
    );
  }

  Widget _buildCompactIndicator(Color color, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          if (showText) ...[
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFullIndicator(
    Color color,
    IconData icon,
    String text,
    bool isOnline,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: BalatroTheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!isOnline)
                Text(
                  'Game continues offline',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Extension to easily add connection status to any widget
extension ConnectionStatusExtension on Widget {
  Widget withConnectionStatus(
    EnhancedMultiplayerController? controller, {
    bool compact = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (controller != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ConnectionStatusWidget(
              controller: controller,
              compact: compact,
            ),
          ),
        this,
      ],
    );
  }
}
