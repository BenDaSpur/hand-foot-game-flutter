import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/game_analytics_logger.dart';

/// Debug helper for analytics data export and sharing
class AnalyticsDebugHelper {
  /// Quick check if analytics data is ready for analysis
  static Future<void> checkAnalyticsStatus() async {
    final summary = await GameAnalyticsLogger.getAnalyticsSummary();

    if (kDebugMode) {
      print('\n=== ANALYTICS STATUS ===');
      print('Data Available: ${summary['dataAvailable']}');
      print('Total Sessions: ${summary['totalSessions']}');
      print('Total Bot Instances: ${summary['totalBotInstances']}');
      print('Ready for Analysis: ${summary['readyForAnalysis']}');

      final recommended = summary['recommendedMinimum'] as Map<String, dynamic>;
      print('\nRecommended Minimum:');
      print(
        '  Sessions: ${recommended['sessions']} (have: ${recommended['currentSessions']})',
      );
      print(
        '  Bot Instances: ${recommended['botInstances']} (have: ${recommended['currentBotInstances']})',
      );

      if (summary['readyForAnalysis'] == true) {
        print('\n✅ Analytics data is ready for sharing with Claude!');
        print('Use exportAnalyticsForClaud() to get JSON data.');
      } else {
        print('\n⏳ More gameplay data needed for meaningful analysis.');
      }
      print('========================\n');
    }
  }

  /// Export analytics data formatted for Claude analysis
  static Future<String> exportAnalyticsForClaude({
    int? limitDays,
    bool includeRawData = false,
  }) async {
    final data = await GameAnalyticsLogger.exportAnalyticsData(
      limitDays: limitDays ?? 14, // Default to 2 weeks
      includeDetailedLogs: includeRawData,
    );

    // Add context for Claude
    final claudeData = {
      'context': {
        'purpose': 'Bot performance analysis for Hand & Foot card game',
        'gameDescription':
            'Multi-player card game with AI bots of different personalities',
        'personalities': {
          'conservative': 'Cautious play, avoids risks, prioritizes safety',
          'aggressive':
              'Fast play, takes risks, prioritizes speed over optimization',
          'bookBuilder':
              'Focuses on completing books (7+ card melds) for bonuses',
          'adaptive': 'Adjusts strategy based on game state and opponents',
        },
        'metrics': {
          'winRate': 'Percentage of games won (0.0 to 1.0)',
          'averageScore': 'Mean final score across all games',
          'playDownSuccessRate': 'Success rate for initial meld requirement',
          'footTransitionRate': 'Success rate for picking up foot cards',
          'bookCompletionRate': 'Rate of completing 7+ card melds',
          'averageRounds': 'Mean number of rounds per game',
          'averageGameDuration': 'Mean game duration in seconds',
        },
        'requestedAnalysis': [
          'Which personalities perform best overall?',
          'What are the main performance differences between personalities?',
          'Which specific game scenarios cause problems for each personality?',
          'Recommendations for improving bot performance',
          'Suggestions for balancing personalities against each other',
        ],
      },
      'data': data,
    };

    // Return formatted JSON
    try {
      final encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(claudeData);
    } catch (e) {
      return 'Error exporting data: $e';
    }
  }

  /// Copy analytics data to clipboard for easy sharing
  static Future<void> copyAnalyticsToClipboard({
    int? limitDays,
    bool includeRawData = false,
  }) async {
    try {
      final jsonData = await exportAnalyticsForClaude(
        limitDays: limitDays,
        includeRawData: includeRawData,
      );

      await Clipboard.setData(ClipboardData(text: jsonData));

      if (kDebugMode) {
        print('✅ Analytics data copied to clipboard!');
        print('You can now paste this data when sharing with Claude.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to copy analytics data: $e');
      }
    }
  }

  /// Export personality comparison for focused analysis
  static Future<String> exportPersonalityComparison({
    List<String>? focusMetrics,
    int? limitDays,
  }) async {
    final comparison = await GameAnalyticsLogger.exportPersonalityComparison(
      limitDays: limitDays ?? 14,
      metrics:
          focusMetrics ??
          [
            'winRate',
            'averageScore',
            'playDownSuccessRate',
            'bookCompletionRate',
            'averageRounds',
          ],
    );

    final claudeComparison = {
      'context': {
        'purpose': 'Personality performance comparison for bot balancing',
        'question':
            'How do different bot personalities compare? Which need improvement?',
      },
      'comparison': comparison,
    };

    final encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(claudeComparison);
  }

  /// Print analytics summary to console for quick debug
  static Future<void> printAnalyticsSummary() async {
    if (!kDebugMode) return;

    final summary = await GameAnalyticsLogger.getAnalyticsSummary();
    final comparison = await GameAnalyticsLogger.exportPersonalityComparison(
      limitDays: 14,
    );

    print('\n${'=' * 50}');
    print('ANALYTICS SUMMARY');
    print('=' * 50);

    print('Total Sessions: ${summary['totalSessions']}');
    print('Bot Instances: ${summary['totalBotInstances']}');
    print('Ready: ${summary['readyForAnalysis'] ? "YES" : "NO"}');

    if (comparison.containsKey('rankings')) {
      final rankings = comparison['rankings'] as Map<String, dynamic>;

      print('\nWIN RATE RANKINGS:');
      final winRateRanking = rankings['winRate'] as List? ?? [];
      for (int i = 0; i < winRateRanking.length; i++) {
        final entry = winRateRanking[i];
        final winRate = ((entry['value'] as double) * 100).toStringAsFixed(1);
        print('  ${i + 1}. ${entry['personality']}: $winRate%');
      }

      print('\nAVERAGE SCORE RANKINGS:');
      final scoreRanking = rankings['averageScore'] as List? ?? [];
      for (int i = 0; i < scoreRanking.length; i++) {
        final entry = scoreRanking[i];
        print('  ${i + 1}. ${entry['personality']}: ${entry['value']} pts');
      }
    }

    print('${'=' * 50}\n');
  }
}
