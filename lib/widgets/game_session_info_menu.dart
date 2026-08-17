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

    if (analyticsSessionId != null) {
      lines.add('Session: $analyticsSessionId');
      lines.add(
        'Firestore: ${GameAnalyticsLogger.gameSessionsCollection}/$analyticsSessionId',
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
  static const double _panelWidth = 252;

  static List<PopupMenuEntry<String>> buildItems(GameSessionInfo info) {
    return [
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        enabled: false,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: _SessionInfoPanel(info: info),
      ),
      const PopupMenuItem<String>(
        value: copyValue,
        height: 40,
        child: Row(
          children: [
            Icon(Icons.copy_all, color: BalatroTheme.neonBlue, size: 18),
            SizedBox(width: 10),
            Text('Copy IDs'),
          ],
        ),
      ),
    ];
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
        content: const Text(
          'Session info copied to clipboard',
          style: TextStyle(color: BalatroTheme.primaryText),
        ),
        backgroundColor: BalatroTheme.neonBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _SessionInfoPanel extends StatelessWidget {
  final GameSessionInfo info;

  const _SessionInfoPanel({required this.info});

  static const TextStyle _labelStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    color: Colors.white38,
  );

  static const TextStyle _valueStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    height: 1.25,
  );

  static const TextStyle _monoValueStyle = TextStyle(
    fontSize: 10,
    fontFamily: 'monospace',
    color: Colors.white70,
    height: 1.3,
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: GameSessionInfoMenu._panelWidth,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: BalatroTheme.neonBlue.withValues(alpha: 0.22),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'SUPPORT REFERENCE',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: BalatroTheme.neonBlue,
              ),
            ),
            const SizedBox(height: 8),
            if (info.gameId != null) ...[
              const Text('Game ID', style: _labelStyle),
              const SizedBox(height: 2),
              Text(
                info.gameId!,
                style: _valueStyle.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 18,
                  color: BalatroTheme.neonGreen,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (info.analyticsSessionId != null) ...[
              const Text('Analytics session', style: _labelStyle),
              const SizedBox(height: 2),
              Text(
                info.analyticsSessionId!,
                style: _monoValueStyle,
                maxLines: 2,
                softWrap: true,
              ),
              const SizedBox(height: 8),
            ],
            const Text('Versions', style: _labelStyle),
            const SizedBox(height: 2),
            Text('App ${AnalyticsMetadata.appVersion}', style: _valueStyle),
            Text('Bot ${BotConfig.botAiVersion}', style: _monoValueStyle),
          ],
        ),
      ),
    );
  }
}
