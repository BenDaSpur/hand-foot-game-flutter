import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_app.dart';

/// Utility class for E2E testing with improved timing and state management
class E2ETestUtils {
  /// Desktop-sized surface: tall phone sizes put the action dock outside the
  /// Chrome integration-test hit-test viewport, so taps miss Play Cards/etc.
  static void _ensureTestSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 900);
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
    const step = Duration(milliseconds: 100);
    const timeout = Duration(seconds: 8);
    final maxIterations = timeout.inMilliseconds ~/ step.inMilliseconds;

    for (var i = 0; i < maxIterations; i++) {
      await tester.pump(step);
      if (find.text('HAND & FOOT').evaluate().isNotEmpty &&
          find.text('ROUND 1').evaluate().isNotEmpty) {
        // Extra settle frames for hand/actions
        await tester.pump(const Duration(milliseconds: 200));
        return;
      }
      // Keep dismissing Perfect Grab if it appears late
      await _dismissPerfectGrabIfPresent(tester);
    }

    throw TestFailure(
      'Timed out after ${timeout.inSeconds}s waiting for game chrome '
      '(HAND & FOOT / ROUND 1)',
    );
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
    if (finder.evaluate().isEmpty) {
      if (debugLabel != null) {
        print('⚠️ $debugLabel - element not found');
      }
      return;
    }

    // Invoke Material button callbacks directly when possible. Integration
    // tests on Chrome often fail hit-tests against the bottom action dock
    // while the card-fly overlay (or live binding timing) is settling.
    final invoked = await _invokeButtonStyleOnPressed(tester, finder);
    if (invoked) {
      if (debugLabel != null) {
        print('✅ $debugLabel');
      }
      return;
    }

    final target = finder.first;
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    if (debugLabel != null) {
      print('✅ $debugLabel');
    }
  }

  /// Waits for a [ButtonStyleButton] ancestor to enable, then calls onPressed.
  static Future<bool> _invokeButtonStyleOnPressed(
    WidgetTester tester,
    Finder finder,
  ) async {
    const step = Duration(milliseconds: 100);
    const timeout = Duration(seconds: 5);
    final maxIterations = timeout.inMilliseconds ~/ step.inMilliseconds;

    for (var i = 0; i < maxIterations; i++) {
      if (finder.evaluate().isEmpty) {
        return false;
      }

      final buttonFinder = find.ancestor(
        of: finder.first,
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      );
      if (buttonFinder.evaluate().isEmpty) {
        return false;
      }

      final button = tester.widget<ButtonStyleButton>(buttonFinder.first);
      final onPressed = button.onPressed;
      if (onPressed != null) {
        onPressed();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        return true;
      }

      // Button disabled (e.g. card-fly isAnimating) — skip overlay and wait.
      await _dismissCardFlyOverlayIfPresent(tester);
      await tester.pump(step);
      await Future<void>.delayed(step);
    }

    return false;
  }

  /// Wait for element to appear with timeout
  static Future<bool> waitForElement(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 3),
    String? debugLabel,
  }) async {
    const step = Duration(milliseconds: 100);
    final maxIterations = timeout.inMilliseconds ~/ step.inMilliseconds;

    for (var i = 0; i < maxIterations; i++) {
      await tester.pump(step);
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

  /// Stabilize the app state after actions.
  ///
  /// IntegrationTest uses a live binding, so card-fly animations advance in
  /// wall time. Avoid synthetic corner-taps here — they dismiss open menus.
  static Future<void> stabilize(WidgetTester tester) async {
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Skip the full-screen card-fly GestureDetector when it is blocking input.
  ///
  /// Only used while waiting for a disabled action button to enable — never
  /// during general stabilize (corner taps dismiss PopupMenus).
  static Future<void> _dismissCardFlyOverlayIfPresent(
    WidgetTester tester,
  ) async {
    final overlay = find.byWidgetPredicate(
      (widget) =>
          widget is GestureDetector &&
          widget.behavior == HitTestBehavior.opaque &&
          widget.onTap != null,
    );
    if (overlay.evaluate().isEmpty) {
      return;
    }

    // Tap a corner of the overlay (skip handler) away from action buttons.
    await tester.tapAt(const Offset(12, 12));
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();
  }

  /// Clean shutdown to prevent setState after dispose
  static Future<void> cleanShutdown(WidgetTester tester) async {
    // Prefer timed pumps over pumpAndSettle (bot timers/animations may never idle)
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}
