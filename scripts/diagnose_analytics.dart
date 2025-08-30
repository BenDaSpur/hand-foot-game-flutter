#!/usr/bin/env dart

import 'dart:io';

/// Comprehensive analytics diagnostic to find why data isn't appearing
Future<void> main() async {
  print('🔍 Analytics Diagnostic Tool');
  print('============================');
  print('');

  var issuesFound = 0;
  var checksCompleted = 0;

  // Check 1: Firebase Configuration
  print('📋 CHECK 1: Firebase Configuration');
  print('-----------------------------------');
  checksCompleted++;

  final firebaseOptions = File('lib/firebase_options.dart');
  var isStubConfig = false;

  if (firebaseOptions.existsSync()) {
    final content = await firebaseOptions.readAsString();
    print('✅ Firebase configuration file exists');

    if (content.contains('stub')) {
      print('🚨 CRITICAL ISSUE: Using STUB Firebase configuration');
      print('   → This means NO DATA will be saved to Firestore');
      print('   → Analytics code runs but data goes nowhere');
      print('   → This is the likely cause of missing data');
      isStubConfig = true;
      issuesFound++;
    } else if (content.contains('projectId')) {
      print('✅ Production Firebase project detected');
    }
  } else {
    print('❌ Firebase configuration file missing');
    issuesFound++;
  }
  print('');

  // Check 2: Analytics Integration
  print('📋 CHECK 2: Analytics Integration');
  print('---------------------------------');
  checksCompleted++;

  final mainFile = File('lib/main.dart');
  if (mainFile.existsSync()) {
    final mainContent = await mainFile.readAsString();

    if (mainContent.contains('AnalyticsConfigService.initialize()')) {
      print('✅ Analytics initialization in main.dart');
    } else {
      print('❌ Analytics initialization missing from main.dart');
      issuesFound++;
    }
  }

  final gameScreen = File('lib/screens/game_screen.dart');
  if (gameScreen.existsSync()) {
    final gameContent = await gameScreen.readAsString();

    if (gameContent.contains('_startAnalyticsSession')) {
      print('✅ Analytics session start integrated');
    } else {
      print('❌ Analytics session start missing');
      issuesFound++;
    }

    if (gameContent.contains('_endAnalyticsSession')) {
      print('✅ Analytics session end integrated');
    } else {
      print('❌ Analytics session end missing');
      issuesFound++;
    }

    if (gameContent.contains('_logBotDecision')) {
      print('✅ Bot decision logging integrated');
    } else {
      print('❌ Bot decision logging missing');
      issuesFound++;
    }
  }
  print('');

  // Check 3: Game Completion Flow
  print('📋 CHECK 3: Game Completion Flow');
  print('---------------------------------');
  checksCompleted++;

  if (gameScreen.existsSync()) {
    final gameContent = await gameScreen.readAsString();

    // Check if _endAnalyticsSession is called in game end handler
    if (gameContent.contains('_handleGameEnd') &&
        gameContent.contains('_endAnalyticsSession();')) {
      print('✅ Analytics session ends when game completes');
    } else {
      print('❌ Analytics session may not end when game completes');
      issuesFound++;
    }
  }
  print('');

  // Check 4: Dependencies
  print('📋 CHECK 4: Dependencies');
  print('-------------------------');
  checksCompleted++;

  final pubspec = File('pubspec.yaml');
  if (pubspec.existsSync()) {
    final pubspecContent = await pubspec.readAsString();

    final requiredDeps = [
      'firebase_core',
      'cloud_firestore',
      'firebase_analytics',
      'shared_preferences',
      'logging',
    ];

    var missingDeps = 0;
    for (final dep in requiredDeps) {
      if (pubspecContent.contains('$dep:')) {
        print('✅ $dep dependency found');
      } else {
        print('❌ $dep dependency missing');
        missingDeps++;
      }
    }

    if (missingDeps > 0) {
      issuesFound++;
    }
  }
  print('');

  // Check 5: Recent Game Activity
  print('📋 CHECK 5: Recent Game Activity');
  print('---------------------------------');
  checksCompleted++;

  // Check if there are any logs or evidence of recent gameplay
  final possibleLogFiles = ['flutter_logs.txt', '.dart_tool/flutter.log'];

  var foundLogs = false;
  for (final logPath in possibleLogFiles) {
    final logFile = File(logPath);
    if (logFile.existsSync()) {
      print('✅ Found log file: $logPath');
      foundLogs = true;
      break;
    }
  }

  if (!foundLogs) {
    print('⚠️  No log files found');
    print('   → Run app in debug mode to see analytics logs');
  }
  print('');

  // Summary and Recommendations
  print('📊 DIAGNOSTIC SUMMARY');
  print('=====================');
  print('Checks completed: $checksCompleted');
  print('Issues found: $issuesFound');
  print('');

  if (isStubConfig) {
    print('🚨 PRIMARY ISSUE: STUB Firebase Configuration');
    print('==============================================');
    print('');
    print('Your app is configured to use a stub Firebase project,');
    print('which means analytics data is not actually saved.');
    print('');
    print('🛠️  SOLUTIONS:');
    print('');
    print('IMMEDIATE (Test analytics system):');
    print('  dart scripts/generate_mock_analytics.dart');
    print('  → Creates realistic test data for Claude analysis');
    print('');
    print('LONG-TERM (Real data collection):');
    print('  1. Set up real Firebase project:');
    print('     • npm install -g firebase-tools');
    print('     • firebase login');
    print('     • firebase init firestore');
    print('');
    print('  2. Or use Firebase emulator:');
    print('     • firebase emulators:start --only firestore');
    print('     • Update app to connect to localhost:8080');
    print('');
  } else if (issuesFound > 0) {
    print('🛠️  FIX REQUIRED ISSUES:');
    print('========================');
    print('Fix the ❌ issues listed above, then:');
    print('1. flutter clean && flutter pub get');
    print('2. Play 2-3 complete games');
    print('3. Check Firebase Console for data');
  } else {
    print('🤔 MYSTERY: Everything looks good but no data');
    print('==============================================');
    print('');
    print('Try these debugging steps:');
    print('1. Run app with: flutter run --verbose');
    print('2. Look for analytics log messages');
    print('3. Complete at least one full game');
    print('4. Check Firebase Console > Firestore');
    print('');
    print('If still no data, the issue might be:');
    print('• Network connectivity during gameplay');
    print('• Firebase security rules blocking writes');
    print('• Analytics disabled in app settings');
  }

  print('');
  print('📞 NEED HELP?');
  print('=============');
  print(
    'Share the output of this diagnostic with Claude for specific guidance!',
  );
}
