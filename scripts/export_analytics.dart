#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hand_foot_game_flutter/firebase_options.dart';

/// Export analytics data from Firebase for external analysis
class AnalyticsExporter {
  static late FirebaseFirestore _firestore;

  /// Initialize Firebase connection
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _firestore = FirebaseFirestore.instance;
      print('✅ Connected to Firebase');
    } catch (e) {
      print('❌ Failed to initialize Firebase: $e');
      exit(1);
    }
  }

  /// Export comprehensive analytics data
  static Future<Map<String, dynamic>> exportAnalyticsData({
    int limitDays = 30,
    bool includeRawData = false,
  }) async {
    print('📊 Exporting analytics data (last $limitDays days)...');

    final cutoffDate = DateTime.now().subtract(Duration(days: limitDays));

    final exportData = <String, dynamic>{
      'exportTimestamp': DateTime.now().toIso8601String(),
      'limitDays': limitDays,
      'summary': {},
      'personalityPerformance': {},
      'challengingScenarios': {},
      'sessionData': [],
    };

    try {
      // Get all game sessions
      print('  Fetching game sessions...');
      final sessionsQuery = await _firestore
          .collection('game_sessions')
          .where('startTime', isGreaterThan: Timestamp.fromDate(cutoffDate))
          .orderBy('startTime', descending: true)
          .limit(1000)
          .get();

      print('  Found ${sessionsQuery.docs.length} sessions');

      // Process session data
      final personalities = <String, Map<String, dynamic>>{};
      final seedPerformance = <String, Map<int, List<Map<String, dynamic>>>>{};

      for (final doc in sessionsQuery.docs) {
        final data = doc.data();
        final sessionData = Map<String, dynamic>.from(data);

        if (includeRawData) {
          exportData['sessionData'].add(sessionData);
        }

        // Analyze bot performance by personality
        final botPerformance =
            sessionData['botPerformance'] as Map<String, dynamic>? ?? {};
        final finalScores = List<int>.from(sessionData['finalScores'] ?? []);
        final gameSeed = sessionData['gameSeed'] as int?;

        for (final entry in botPerformance.entries) {
          final botData = entry.value as Map<String, dynamic>;
          final personality = botData['personality'] as String?;

          if (personality != null) {
            // Initialize personality data
            if (!personalities.containsKey(personality)) {
              personalities[personality] = {
                'totalGames': 0,
                'wins': 0,
                'totalScore': 0,
                'totalPlayDowns': 0,
                'totalFootTransitions': 0,
                'totalBooks': 0,
                'totalCleanBooks': 0,
              };
            }

            final personalityStats = personalities[personality]!;
            personalityStats['totalGames'] =
                (personalityStats['totalGames'] as int) + 1;
            personalityStats['totalScore'] =
                (personalityStats['totalScore'] as int) +
                (botData['finalScore'] as int? ?? 0);

            if (botData['hasPlayedDown'] == true) {
              personalityStats['totalPlayDowns'] =
                  (personalityStats['totalPlayDowns'] as int) + 1;
            }

            if (botData['hasPickedUpFoot'] == true) {
              personalityStats['totalFootTransitions'] =
                  (personalityStats['totalFootTransitions'] as int) + 1;
            }

            final bookCount = botData['bookCount'] as int? ?? 0;
            final cleanBookCount = botData['cleanBookCount'] as int? ?? 0;
            personalityStats['totalBooks'] =
                (personalityStats['totalBooks'] as int) + bookCount;
            personalityStats['totalCleanBooks'] =
                (personalityStats['totalCleanBooks'] as int) + cleanBookCount;

            // Check if won (highest score)
            if (finalScores.isNotEmpty) {
              final maxScore = finalScores.reduce((a, b) => a > b ? a : b);
              if (botData['finalScore'] == maxScore) {
                personalityStats['wins'] =
                    (personalityStats['wins'] as int) + 1;
              }
            }

            // Track performance by seed for challenging scenario analysis
            if (gameSeed != null) {
              if (!seedPerformance.containsKey(personality)) {
                seedPerformance[personality] = {};
              }
              if (!seedPerformance[personality]!.containsKey(gameSeed)) {
                seedPerformance[personality]![gameSeed] = [];
              }

              seedPerformance[personality]![gameSeed]!.add({
                'score': botData['finalScore'],
                'won':
                    finalScores.isNotEmpty &&
                    botData['finalScore'] ==
                        finalScores.reduce((a, b) => a > b ? a : b),
                'playedDown': botData['hasPlayedDown'],
                'pickedUpFoot': botData['hasPickedUpFoot'],
                'books': bookCount,
                'sessionId': doc.id,
              });
            }
          }
        }
      }

      // Calculate performance metrics for each personality
      for (final entry in personalities.entries) {
        final personality = entry.key;
        final stats = entry.value;
        final totalGames = stats['totalGames'] as int;

        if (totalGames > 0) {
          exportData['personalityPerformance'][personality] = {
            'totalGames': totalGames,
            'winRate': (stats['wins'] as int) / totalGames,
            'averageScore': (stats['totalScore'] as int) / totalGames,
            'playDownSuccessRate':
                (stats['totalPlayDowns'] as int) / totalGames,
            'footTransitionRate':
                (stats['totalFootTransitions'] as int) / totalGames,
            'averageBooksPerGame': (stats['totalBooks'] as int) / totalGames,
            'averageCleanBooksPerGame':
                (stats['totalCleanBooks'] as int) / totalGames,
            'rawStats': stats,
          };
        }
      }

      // Find challenging scenarios (seeds with poor performance)
      for (final personalityEntry in seedPerformance.entries) {
        final personality = personalityEntry.key;
        final seeds = personalityEntry.value;

        final challengingSeeds = <Map<String, dynamic>>[];

        for (final seedEntry in seeds.entries) {
          final seed = seedEntry.key;
          final performances = seedEntry.value;

          if (performances.length >= 2) {
            // Need multiple games on same seed
            final wins = performances.where((p) => p['won'] == true).length;
            final avgScore =
                performances
                    .map((p) => p['score'] as int)
                    .reduce((a, b) => a + b) /
                performances.length;
            final winRate = wins / performances.length;

            challengingSeeds.add({
              'seed': seed,
              'games': performances.length,
              'winRate': winRate,
              'averageScore': avgScore.round(),
              'difficulty': 1.0 - winRate,
              'performances': performances,
            });
          }
        }

        // Sort by difficulty (worst performance first)
        challengingSeeds.sort(
          (a, b) =>
              (b['difficulty'] as double).compareTo(a['difficulty'] as double),
        );

        exportData['challengingScenarios'][personality] = challengingSeeds
            .take(10)
            .toList();
      }

      // Overall summary
      exportData['summary'] = {
        'totalSessions': sessionsQuery.docs.length,
        'personalitiesAnalyzed': personalities.keys.length,
        'dateRange': {
          'from': cutoffDate.toIso8601String(),
          'to': DateTime.now().toIso8601String(),
        },
        'totalBotInstances': personalities.values.fold(
          0,
          (total, stats) => total + (stats['totalGames'] as int),
        ),
        'readyForAnalysis':
            sessionsQuery.docs.length >= 20 &&
            personalities.values.fold(
                  0,
                  (total, stats) => total + (stats['totalGames'] as int),
                ) >=
                50,
      };

      print('✅ Analytics data exported successfully');
      return exportData;
    } catch (e) {
      print('❌ Error exporting analytics: $e');
      return {'error': 'Export failed: $e'};
    }
  }

  /// Export data formatted for Claude analysis
  static Future<Map<String, dynamic>> exportForClaude({
    int limitDays = 14,
    bool includeRawData = false,
  }) async {
    final data = await exportAnalyticsData(
      limitDays: limitDays,
      includeRawData: includeRawData,
    );

    return {
      'context': {
        'purpose':
            'Bot performance analysis for Hand & Foot card game AI improvement',
        'gameDescription':
            'Multi-player card game with AI bots of different personalities competing against human players',
        'personalities': {
          'conservative':
              'Cautious play style - avoids risks, higher strategic buffer, waits for safer opportunities',
          'aggressive':
              'Fast aggressive play - takes more risks, lower thresholds, prioritizes speed over optimization',
          'bookBuilder':
              'Focuses on completing books (7+ card melds) for bonus points, more patient with meld building',
          'adaptive':
              'Adjusts strategy dynamically based on game state, opponent behavior, and round progression',
        },
        'keyMetrics': {
          'winRate': 'Percentage of games won by this personality (0.0 to 1.0)',
          'averageScore': 'Mean final score across all games played',
          'playDownSuccessRate':
              'Rate of successfully meeting initial meld requirements',
          'footTransitionRate':
              'Rate of successfully transitioning from hand to foot cards',
          'averageBooksPerGame':
              'Average number of books (7+ card melds) completed per game',
          'challengingScenarios':
              'Game seeds where this personality performs poorly (for improvement focus)',
        },
        'analysisQuestions': [
          'Which personalities perform best overall and why?',
          'What are the key performance gaps between personalities?',
          'Which specific game scenarios cause the most problems for each personality?',
          'Are the personalities well-balanced against each other?',
          'What specific improvements would you recommend for each personality?',
          'Which challenging seeds should be prioritized for AI development focus?',
        ],
      },
      'analyticsData': data,
    };
  }
}

/// Main function to run the export
Future<void> main(List<String> args) async {
  print('🔥 Hand & Foot Analytics Exporter');
  print('================================');

  // Parse command line arguments
  var limitDays = 14;
  var includeRawData = false;
  var outputFile = 'analytics_export.json';
  var claudeFormat = true;

  for (int i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--days':
        if (i + 1 < args.length) {
          limitDays = int.tryParse(args[i + 1]) ?? 14;
          i++;
        }
        break;
      case '--include-raw':
        includeRawData = true;
        break;
      case '--output':
        if (i + 1 < args.length) {
          outputFile = args[i + 1];
          i++;
        }
        break;
      case '--basic-format':
        claudeFormat = false;
        break;
      case '--help':
        print('Usage: dart run scripts/export_analytics.dart [options]');
        print('Options:');
        print('  --days <number>     Number of days to export (default: 14)');
        print('  --include-raw       Include raw session data');
        print(
          '  --output <file>     Output filename (default: analytics_export.json)',
        );
        print(
          '  --basic-format      Export basic format instead of Claude-optimized',
        );
        print('  --help              Show this help message');
        return;
    }
  }

  print('📋 Configuration:');
  print('  Days: $limitDays');
  print('  Include raw data: $includeRawData');
  print('  Output file: $outputFile');
  print('  Claude format: $claudeFormat');
  print('');

  try {
    // Initialize Firebase
    await AnalyticsExporter.initialize();

    // Export data
    final data = claudeFormat
        ? await AnalyticsExporter.exportForClaude(
            limitDays: limitDays,
            includeRawData: includeRawData,
          )
        : await AnalyticsExporter.exportAnalyticsData(
            limitDays: limitDays,
            includeRawData: includeRawData,
          );

    // Write to file
    print('💾 Writing to $outputFile...');
    final file = File(outputFile);
    final encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(data));

    print('✅ Export completed successfully!');
    print('📄 File saved: ${file.absolute.path}');

    // Show summary
    if (data.containsKey('analyticsData')) {
      final analyticsData = data['analyticsData'] as Map<String, dynamic>;
      final summary = analyticsData['summary'] as Map<String, dynamic>;
      print('');
      print('📊 Data Summary:');
      print('  Total Sessions: ${summary['totalSessions']}');
      print('  Bot Instances: ${summary['totalBotInstances']}');
      print(
        '  Ready for Analysis: ${summary['readyForAnalysis'] ? "✅ YES" : "⏳ Need more data"}',
      );
      print('  Personalities: ${summary['personalitiesAnalyzed']}');
    } else if (data.containsKey('summary')) {
      final summary = data['summary'] as Map<String, dynamic>;
      print('');
      print('📊 Data Summary:');
      print('  Total Sessions: ${summary['totalSessions']}');
      print('  Bot Instances: ${summary['totalBotInstances']}');
      print(
        '  Ready for Analysis: ${summary['readyForAnalysis'] ? "✅ YES" : "⏳ Need more data"}',
      );
    }

    print('');
    print('🚀 You can now share $outputFile with Claude for AI analysis!');
  } catch (e) {
    print('❌ Export failed: $e');
    exit(1);
  }
}
