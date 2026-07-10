import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ai/bot_config.dart';
import '../config/analytics_metadata.dart';
import '../services/firebase_constants.dart';
import '../services/game_analytics_logger.dart';
import '../theme/balatro_theme.dart';

/// Identifiers shown in the game menu for Firestore lookup and support.
class GameSessionInfo {
  final String? gameId;
  final String? analyticsSessionId;
  final String? gameSeed;
  final String? playerId;

  const GameSessionInfo({
    this.gameId,
    this.analyticsSessionId,
    this.gameSeed,
    this.playerId,
  });

  bool get hasAnyInfo {
    return gameId != null ||
        analyticsSessionId != null ||
        gameSeed != null ||
        playerId != null;
  }

  String get clipboardText {
    final lines = <String>[];

    if (gameId != null) {
      lines.add('Game ID: $gameId');
      lines.add('Firestore: ${FirebaseConstants.gamesCollection}/$gameId');
    }

    final sessionId =
        analyticsSessionId ?? GameAnalyticsLogger.currentSessionId;
    if (sessionId != null) {
      lines.add('Session: $sessionId');
      lines.add(
        'Firestore: ${GameAnalyticsLogger.gameSessionsCollection}/$sessionId',
      );
    }

    lines.add('App: ${AnalyticsMetadata.appVersion}');
    lines.add('Bot AI: ${BotConfig.botAiVersion}');

    if (gameSeed != null) {
      lines.add('Seed: $gameSeed');
    }

    if (playerId != null) {
      lines.add('Player: $playerId');
    }

    return lines.join('\n');
  }
}

/// Shared menu section for session / Firestore lookup info (solo + multiplayer).
class GameSessionInfoMenu {
  static const String copyValue = 'copy_session_info';

  static List<PopupMenuEntry<String>> buildItems(GameSessionInfo info) {
    final sessionId =
        info.analyticsSessionId ?? GameAnalyticsLogger.currentSessionId;

    return [
      const PopupMenuItem<String>(
        enabled: false,
        height: 28,
        child: Text(
          'SESSION INFO',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: BalatroTheme.neonBlue,
          ),
        ),
      ),
      if (info.gameId != null) _infoLine('Game', info.gameId!, monospace: true),
      if (sessionId != null) _infoLine('Session', _truncate(sessionId)),
      _infoLine(
        'App',
        '${AnalyticsMetadata.appVersion} · ${BotConfig.botAiVersion}',
      ),
      if (info.gameSeed != null) _infoLine('Seed', info.gameSeed!),
      const PopupMenuDivider(),
      const PopupMenuItem<String>(
        value: copyValue,
        child: Row(
          children: [
            Icon(Icons.copy_all, color: BalatroTheme.neonBlue, size: 18),
            SizedBox(width: 8),
            Text('Copy Session Info'),
          ],
        ),
      ),
      const PopupMenuDivider(),
    ];
  }

  static PopupMenuItem<String> _infoLine(
    String label,
    String value, {
    bool monospace = false,
  }) {
    return PopupMenuItem<String>(
      enabled: false,
      height: 34,
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          color: Colors.white70,
          fontFamily: monospace ? 'monospace' : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  static String _truncate(String value, {int maxLength = 22}) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength)}…';
  }

  static Future<void> copyToClipboard(
    BuildContext context,
    GameSessionInfo info,
  ) async {
    await Clipboard.setData(ClipboardData(text: info.clipboardText));

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Session info copied to clipboard'),
        backgroundColor: BalatroTheme.neonBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
