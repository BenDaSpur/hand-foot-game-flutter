import 'dart:math';
import 'game_analytics_logger.dart';
import '../ai/bot_personality.dart';

/// Monitor personality distinctiveness to ensure they remain meaningfully different
class PersonalityMonitor {
  /// Check if personalities are becoming too similar
  static Future<Map<String, dynamic>> analyzePersonalityDistinctiveness({
    int limitDays = 7,
  }) async {
    final results = <String, dynamic>{
      'distinctivenessScore': 0.0,
      'concernLevel': 'low', // low, medium, high
      'recommendations': <String>[],
      'metrics': <String, dynamic>{},
    };

    // Get performance data for all personalities
    final personalityData = <String, Map<String, dynamic>>{};
    for (final personality in BotPersonality.values) {
      final analytics = await GameAnalyticsLogger.getBotPerformanceAnalytics(
        personality: personality,
        limitDays: limitDays,
      );
      if (analytics != null) {
        personalityData[personality.name] = analytics;
      }
    }

    if (personalityData.length < 2) {
      results['concernLevel'] = 'high';
      results['recommendations'].add(
        'Insufficient data to analyze distinctiveness',
      );
      return results;
    }

    // Analyze key behavioral differences
    final behaviorMetrics = [
      'winRate',
      'averageScore',
      'playDownSuccessRate',
      'footTransitionRate',
      'bookCompletionRate',
    ];

    double totalVariance = 0.0;
    final metricAnalysis = <String, dynamic>{};

    for (final metric in behaviorMetrics) {
      final values = personalityData.values
          .where((data) => data.containsKey(metric))
          .map((data) => (data[metric] as num).toDouble())
          .toList();

      if (values.length >= 2) {
        final variance = _calculateVariance(values);
        final mean = values.reduce((a, b) => a + b) / values.length;
        final coefficientOfVariation = variance > 0
            ? sqrt(variance) / mean
            : 0.0;

        totalVariance += coefficientOfVariation;
        metricAnalysis[metric] = {
          'variance': variance,
          'coefficientOfVariation': coefficientOfVariation,
          'values': Map.fromIterables(
            personalityData.keys,
            personalityData.values.map((data) => data[metric]),
          ),
        };
      }
    }

    // Calculate overall distinctiveness score (0-1, higher = more distinct)
    final avgCoefficientOfVariation = totalVariance / behaviorMetrics.length;
    final distinctivenessScore = min(
      1.0,
      avgCoefficientOfVariation * 2,
    ); // Scale to 0-1

    results['distinctivenessScore'] = distinctivenessScore;
    results['metrics'] = metricAnalysis;

    // Determine concern level and recommendations
    if (distinctivenessScore < 0.1) {
      results['concernLevel'] = 'high';
      results['recommendations'].addAll([
        'URGENT: Personalities are too similar - consider reverting some aggressiveness changes',
        'Conservative bots should have significantly different win rates and play styles',
        'BookBuilder should show higher book completion rates than others',
      ]);
    } else if (distinctivenessScore < 0.25) {
      results['concernLevel'] = 'medium';
      results['recommendations'].addAll([
        'Monitor personality differences closely',
        'Consider tuning specific personality constants to increase differentiation',
        'Ensure conservative vs aggressive playstyles remain distinct',
      ]);
    } else {
      results['concernLevel'] = 'low';
      results['recommendations'].add(
        'Personalities maintain good distinctiveness',
      );
    }

    return results;
  }

  static double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final sumSquaredDeviations = values
        .map((x) => pow(x - mean, 2))
        .reduce((a, b) => a + b);

    return sumSquaredDeviations / values.length;
  }
}
