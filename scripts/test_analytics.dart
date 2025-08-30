#!/usr/bin/env dart

import 'dart:io';

/// Simple test to check if analytics are working
Future<void> main() async {
  print('🧪 Analytics System Test');
  print('========================');

  // Check if Firebase is configured
  final firebaseOptions = File('lib/firebase_options.dart');
  if (firebaseOptions.existsSync()) {
    print('✅ Firebase configuration file exists');

    // Read the config to see if it's a stub or real
    final content = await firebaseOptions.readAsString();
    if (content.contains('stub')) {
      print('⚠️  WARNING: Using STUB Firebase configuration');
      print('   Analytics will not persist to a real database');
      print('   This is normal for local development');
    } else {
      print('✅ Production Firebase configuration detected');
    }
  } else {
    print('❌ Firebase configuration missing');
    return;
  }

  // Check main.dart integration
  final mainFile = File('lib/main.dart');
  if (mainFile.existsSync()) {
    final mainContent = await mainFile.readAsString();

    if (mainContent.contains('AnalyticsConfigService.initialize()')) {
      print('✅ Analytics initialization found in main.dart');
    } else {
      print('❌ Analytics initialization missing from main.dart');
    }

    if (mainContent.contains('FirebaseService.initialize()')) {
      print('✅ Firebase initialization found in main.dart');
    } else {
      print('❌ Firebase initialization missing from main.dart');
    }
  }

  // Check game screen integration
  final gameScreen = File('lib/screens/game_screen.dart');
  if (gameScreen.existsSync()) {
    final gameContent = await gameScreen.readAsString();

    if (gameContent.contains('_startAnalyticsSession')) {
      print('✅ Analytics session tracking found in game screen');
    } else {
      print('❌ Analytics session tracking missing from game screen');
    }

    if (gameContent.contains('_logBotDecision')) {
      print('✅ Bot decision logging found in game screen');
    } else {
      print('❌ Bot decision logging missing from game screen');
    }
  }

  print('');
  print('📊 DATA COLLECTION STATUS');
  print('=========================');
  print('Analytics will start collecting data when you:');
  print('1. ✅ Have Firebase properly configured (production, not stub)');
  print('2. ✅ Launch the app (initializes analytics)');
  print('3. ✅ Play singleplayer games (creates game_sessions)');
  print('4. ✅ Have bot opponents (creates bot_decisions)');
  print('');
  print('📋 TROUBLESHOOTING');
  print('==================');
  print('If no data appears after playing games:');
  print('');
  print('1. Check Firebase Console logs:');
  print('   - Go to Firebase Console > Functions > Logs');
  print('   - Look for any error messages');
  print('');
  print('2. Check app debug output:');
  print('   - Run app in debug mode');
  print('   - Look for "📊 Started game analytics session" messages');
  print('');
  print('3. Verify analytics are enabled:');
  print('   - Analytics are enabled by default');
  print('   - Check SharedPreferences if manually disabled');
  print('');
  print('4. Check internet connection:');
  print('   - Analytics require network connectivity');
  print('   - Offline games won\'t sync until connected');
  print('');
  print('5. Firebase project permissions:');
  print('   - Ensure your Firebase project allows writes');
  print('   - Check Firestore security rules');
  print('');
  print('🎮 TO CREATE TEST DATA:');
  print('=======================');
  print('1. Launch the app');
  print('2. Start a singleplayer game');
  print('3. Play for a few turns (let bots make decisions)');
  print('4. Finish the game or let it complete');
  print('5. Check Firebase Console > Firestore > game_sessions');
  print('');
  print('After 2-3 completed games, you should see data in Firebase!');
}
