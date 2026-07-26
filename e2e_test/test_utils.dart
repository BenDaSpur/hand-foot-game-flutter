import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_app.dart';

/// Utility class for E2E testing with improved timing and state management
class E2ETestUtils {
  /// Phone-sized surface large enough to avoid compact score-chip overflows.
  static void _ensureTestSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Start the app with clean state and deterministic seed
  static Future<void> startAppWithCleanState(WidgetTester tester) async {
    _ensureTestSurface(tester);
    // e2e_test/ is outside package:flutter_test's test/ visibility root
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});

    // Try to clear any saved games, but don't fail if SharedPreferences isn't available
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      // SharedPreferences not available in this test environment, continue
      print('⚠️ SharedPreferences not available in test environment');
    }

    // Start the app with deterministic seed for consistent testing
    await tester.pumpWidget(const TestApp(seed: 12345));

    // Allow initial frames (GameScreen may show Perfect Grab briefly)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Skip Perfect Grab if it appears (non-testSeed path / race)
    await _dismissPerfectGrabIfPresent(tester);

    // Wait for game UI to stabilize without hanging on infinite animations
    await _pumpUntilGameReady(tester);

    // Handle potential save game dialog if it appears
    await _handleSaveGameDialog(tester);
  }

  /// Dismiss the round-start Perfect Grab dialog when present.
  static Future<void> _dismissPerfectGrabIfPresent(WidgetTester tester) async {
    final skipButton = find.text('Skip (no bonus)');
    if (skipButton.evaluate().isEmpty &&
        find.text('Perfect Grab').evaluate().isEmpty &&
        find.text('GET READY').evaluate().isEmpty) {
      return;
    }

    if (skipButton.evaluate().isNotEmpty) {
      await tester.tap(skipButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }

    // Intro screen: open skip after GET READY if needed
    if (find.text('GET READY').evaluate().isNotEmpty) {
      await tester.tap(find.text('GET READY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    if (find.text('Skip (no bonus)').evaluate().isNotEmpty) {
      await tester.tap(find.text('Skip (no bonus)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// Pump until core game chrome is visible, with a hard timeout.
  static Future<void> _pumpUntilGameReady(WidgetTester tester) async {
    final endTime = DateTime.now().add(const Duration(seconds: 8));
    while (DateTime.now().isBefore(endTime)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('HAND & FOOT').evaluate().isNotEmpty &&
          find.text('ROUND 1').evaluate().isNotEmpty) {
        // Extra settle frames for hand/actions
        await tester.pump(const Duration(milliseconds: 200));
        return;
      }
      // Keep dismissing Perfect Grab if it appears late
      await _dismissPerfectGrabIfPresent(tester);
    }
  }

  /// Handle save game dialog if it appears
  static Future<void> _handleSaveGameDialog(WidgetTester tester) async {
    if (find.text('Save Game Found').evaluate().isNotEmpty) {
      await tester.tap(find.text('New Game'));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// Safe tap with automatic timing and error handling
  static Future<void> safeTap(
    WidgetTester tester,
    Finder finder, {
    String? debugLabel,
  }) async {
    if (finder.evaluate().isNotEmpty) {
      await tester.tap(finder.first);
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
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) {
        if (debugLabel != null) {
          print('✅ $debugLabel found');
        }
        return true;
      }
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
    // Prefer timed pumps over pumpAndSettle (bot timers/animations may never idle)
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}
