#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'package:hand_foot_game_flutter/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hand_foot_game_flutter/services/game_analytics_logger.dart';
import 'package:hand_foot_game_flutter/services/personality_monitor.dart';
import 'package:hand_foot_game_flutter/services/analytics_batcher.dart';

/// Monitor analytics health and personality distinctiveness
Future<void> main(List<String> args) async {
  print('🔍 Analytics Health Monitor');
  print('============================');

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    print('✅ Connected to Firebase\n');

    // Check analytics data readiness
    print('📊 ANALYTICS READINESS');
    print('----------------------');
    final summary = await GameAnalyticsLogger.getAnalyticsSummary(limitDays: 7);

    print('Total Sessions: ${summary['totalSessions']}');
    print('Bot Instances: ${summary['totalBotInstances']}');
    print('Ready: ${summary['readyForAnalysis'] ? "✅ YES" : "⏳ NO"}');

    final recommended = summary['recommendedMinimum'] as Map<String, dynamic>;
    print('Progress:');
    print(
      '  Sessions: ${recommended['currentSessions']}/${recommended['sessions']}',
    );
    print(
      '  Bot Instances: ${recommended['currentBotInstances']}/${recommended['botInstances']}',
    );

    // Check personality distinctiveness
    print('\n🎭 PERSONALITY DISTINCTIVENESS');
    print('------------------------------');
    final distinctiveness =
        await PersonalityMonitor.analyzePersonalityDistinctiveness(
          limitDays: 7,
        );

    final score = distinctiveness['distinctivenessScore'] as double;
    final concern = distinctiveness['concernLevel'] as String;

    print('Distinctiveness Score: ${(score * 100).toStringAsFixed(1)}%');
    print('Concern Level: ${concern.toUpperCase()}');

    // Color code the concern level
    if (concern == 'high') {
      print('🚨 URGENT: Personalities may be too similar!');
    } else if (concern == 'medium') {
      print('⚠️  WARNING: Monitor personality differences closely');
    } else {
      print('✅ OK: Personalities maintain good distinctiveness');
    }

    // Show recommendations
    final recommendations = distinctiveness['recommendations'] as List<String>;
    if (recommendations.isNotEmpty) {
      print('\nRecommendations:');
      for (final rec in recommendations) {
        print('  • $rec');
      }
    }

    // Show batch statistics
    print('\n📦 BATCH STATISTICS');
    print('-------------------');
    final batchStats = AnalyticsBatcher.getBatchStats();
    print('Batching Enabled: ${batchStats['enabled']}');
    print('Total Pending: ${batchStats['totalPending']}');

    final collections = batchStats['collections'] as Map<String, dynamic>;
    for (final entry in collections.entries) {
      final collection = entry.key;
      final stats = entry.value as Map<String, dynamic>;
      print(
        '  $collection: ${stats['pending']} pending, timer: ${stats['timerRemaining']}',
      );
    }

    // Generate monitoring report
    final report = {
      'timestamp': DateTime.now().toIso8601String(),
      'analyticsSummary': summary,
      'personalityDistinctiveness': distinctiveness,
      'batchStatistics': batchStats,
    };

    if (args.contains('--save-report')) {
      final reportFile = 'analytics_health_report.json';
      await File(
        reportFile,
      ).writeAsString(JsonEncoder.withIndent('  ').convert(report));
      print('\n💾 Health report saved to: $reportFile');
    }

    // Overall health assessment
    print('\n🏥 OVERALL HEALTH');
    print('------------------');

    if (summary['readyForAnalysis'] == true && concern == 'low') {
      print('🟢 EXCELLENT: Analytics system is healthy and ready');
    } else if (summary['readyForAnalysis'] == true && concern == 'medium') {
      print('🟡 GOOD: Analytics ready but monitor personality distinctiveness');
    } else if (concern == 'high') {
      print('🔴 CRITICAL: Personality distinctiveness issues detected');
    } else {
      print('🟡 DEVELOPING: More gameplay data needed for full analysis');
    }

    print('\nFor detailed analysis, run: ./scripts/export_analytics.sh');
  } catch (e) {
    print('❌ Monitoring failed: $e');
    exit(1);
  }
}
