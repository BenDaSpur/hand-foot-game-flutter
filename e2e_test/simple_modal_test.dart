import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'test_utils.dart';

/// Simple, deterministic tests for modal functionality
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Simple Modal Functionality Tests', () {
    testWidgets('App launches successfully', (WidgetTester tester) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Basic smoke test - app should launch without crashing
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsWidgets);

      print('✅ App launched successfully');
      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets('Game UI elements are present', (WidgetTester tester) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Check for basic game UI elements (flexible checks)
      final hasRoundText = find.textContaining('Round').evaluate().isNotEmpty;
      final hasPlayerText = find.textContaining('You').evaluate().isNotEmpty;
      final hasButtons = find.byType(ElevatedButton).evaluate().isNotEmpty;

      // At least some basic UI should be present
      expect(hasButtons, isTrue, reason: 'Should have at least one button');

      // Log what we found
      print(
        '✅ Game UI check: Round=$hasRoundText, Player=$hasPlayerText, Buttons=$hasButtons',
      );

      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets('Can perform basic game action', (WidgetTester tester) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Try to find any available button and tap it
      final buttons = find.byType(ElevatedButton);
      if (buttons.evaluate().isNotEmpty) {
        // Get the first enabled button
        for (final element in buttons.evaluate()) {
          final button = element.widget as ElevatedButton;
          if (button.onPressed != null) {
            await tester.tap(find.byWidget(button));
            await E2ETestUtils.stabilize(tester);
            print('✅ Successfully interacted with button');
            break;
          }
        }
      }

      // Verify app is still responsive
      expect(find.byType(Scaffold), findsWidgets);

      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets('Modal interaction if available', (WidgetTester tester) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Look for specific game buttons
      await _tryInteraction(tester, 'Draw from Deck');
      await _tryInteraction(tester, 'Play Cards');

      // If a dialog appeared, try to close it
      final dialogs = find.byType(Dialog);
      if (dialogs.evaluate().isNotEmpty) {
        print('✅ Dialog detected');
        await _tryInteraction(tester, 'Cancel');
        await _tryInteraction(tester, 'Close');
        await _tryInteraction(tester, 'OK');
      }

      await E2ETestUtils.cleanShutdown(tester);
    });
  });
}

/// Helper to safely try button interactions
Future<void> _tryInteraction(WidgetTester tester, String buttonText) async {
  final button = find.text(buttonText);
  if (button.evaluate().isNotEmpty) {
    await E2ETestUtils.safeTap(tester, button, debugLabel: buttonText);
    await E2ETestUtils.stabilize(tester);
  }
}
