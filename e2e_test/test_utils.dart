import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hand_foot_game_flutter/main.dart' as app;

/// Utility class for E2E testing with improved timing and state management
class E2ETestUtils {
  /// Start the app with clean state and proper initialization
  static Future<void> startAppWithCleanState(WidgetTester tester) async {
    // Try to clear any saved games, but don't fail if SharedPreferences isn't available
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      // SharedPreferences not available in this test environment, continue
      print('⚠️ SharedPreferences not available in test environment');
    }

    // Start the app
    app.main();

    // Wait for initial build and stabilize
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Handle potential save game dialog if it appears
    await _handleSaveGameDialog(tester);
  }

  /// Handle save game dialog if it appears
  static Future<void> _handleSaveGameDialog(WidgetTester tester) async {
    if (find.text('Save Game Found').evaluate().isNotEmpty) {
      await tester.tap(find.text('New Game'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }
  }

  /// Safe tap with automatic timing and error handling
  static Future<void> safeTap(
    WidgetTester tester,
    Finder finder, {
    String? debugLabel,
  }) async {
    if (finder.evaluate().isNotEmpty) {
      await tester.tap(finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      if (debugLabel != null) {
        print('✅ $debugLabel');
      }
    } else {
      if (debugLabel != null) {
        print('⚠️ $debugLabel - element not found');
      }
    }
  }

  /// Wait for element to appear with timeout
  static Future<bool> waitForElement(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 3),
    String? debugLabel,
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      await tester.pump();
      if (finder.evaluate().isNotEmpty) {
        if (debugLabel != null) {
          print('✅ $debugLabel found');
        }
        return true;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (debugLabel != null) {
      print('⚠️ $debugLabel not found within timeout');
    }
    return false;
  }

  /// Stabilize the app state after actions
  static Future<void> stabilize(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Clean shutdown to prevent setState after dispose
  static Future<void> cleanShutdown(WidgetTester tester) async {
    // Allow any pending animations or timers to complete
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Additional pumps to ensure clean state
    for (int i = 0; i < 3; i++) {
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
}
