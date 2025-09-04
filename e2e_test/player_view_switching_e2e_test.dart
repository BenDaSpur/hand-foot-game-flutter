import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Player View Switching E2E Tests', () {
    testWidgets('Player view switching works correctly', (
      WidgetTester tester,
    ) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      print('✅ Game started successfully');

      // Wait for initial UI to stabilize
      await E2ETestUtils.stabilize(tester);

      // Verify we start in our own view
      expect(find.text('Your Melds:'), findsOneWidget);
      expect(find.text('Back to yours'), findsNothing);

      print('✅ Confirmed starting in own melds view');

      // Look for bot player cards to tap on
      final botNames = [
        'Clara', 'Carl', 'Bob', 'Rita', 'Ben', 'Penny', 'Alex', 'Sue',
        'Bot 1', 'Bot 2', 'Bot 3', // fallback names
      ];

      String? firstBotFound;
      for (final botName in botNames) {
        if (find.textContaining(botName).evaluate().isNotEmpty) {
          firstBotFound = botName;
          break;
        }
      }

      if (firstBotFound == null) {
        throw Exception('No bot players found to test view switching');
      }

      print('✅ Found bot player: $firstBotFound');

      // Tap on a bot player to view their melds
      await E2ETestUtils.safeTap(
        tester,
        find.textContaining(firstBotFound).first,
        debugLabel: 'Switch to $firstBotFound view',
      );
      await E2ETestUtils.stabilize(tester);

      // Verify we switched to bot's view
      expect(find.textContaining('$firstBotFound\'s Melds:'), findsOneWidget);
      expect(find.text('Back to yours'), findsOneWidget);
      expect(find.text('Your Melds:'), findsNothing);

      print('✅ Successfully switched to bot\'s melds view');
      print('✅ Confirmed "Back to yours" button is visible');

      // Test tapping "Back to yours" button
      await E2ETestUtils.safeTap(
        tester,
        find.text('Back to yours'),
        debugLabel: 'Back to own view',
      );
      await E2ETestUtils.stabilize(tester);

      // Verify we're back to our own view
      expect(find.text('Your Melds:'), findsOneWidget);
      expect(find.text('Back to yours'), findsNothing);
      expect(find.textContaining('$firstBotFound\'s Melds:'), findsNothing);

      print('✅ Successfully returned to own melds view');
      print('✅ Confirmed "Back to yours" button is hidden');

      print('✅ Player view switching test complete');
      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets(
      'Clicking on own player when viewing bot melds returns to own view',
      (WidgetTester tester) async {
        await E2ETestUtils.startAppWithCleanState(tester);

        // Wait for initial UI to stabilize
        await E2ETestUtils.stabilize(tester);

        // Find a bot to switch to first
        final botNames = [
          'Clara', 'Carl', 'Bob', 'Rita', 'Ben', 'Penny', 'Alex', 'Sue',
          'Bot 1', 'Bot 2', 'Bot 3', // fallback names
        ];

        String? firstBotFound;
        for (final botName in botNames) {
          if (find.textContaining(botName).evaluate().isNotEmpty) {
            firstBotFound = botName;
            break;
          }
        }

        if (firstBotFound == null) {
          throw Exception('No bot players found to test view switching');
        }

        // Switch to bot's view first
        await E2ETestUtils.safeTap(
          tester,
          find.textContaining(firstBotFound).first,
          debugLabel: 'Switch to $firstBotFound view',
        );
        await E2ETestUtils.stabilize(tester);

        // Verify we're viewing bot's melds
        expect(find.textContaining('$firstBotFound\'s Melds:'), findsOneWidget);
        expect(find.text('Back to yours'), findsOneWidget);

        print('✅ Currently viewing bot\'s melds');

        // Now tap on our own player card ("You")
        await E2ETestUtils.safeTap(
          tester,
          find.textContaining('You').first,
          debugLabel: 'Switch back to own view by clicking You',
        );
        await E2ETestUtils.stabilize(tester);

        // Add extra stabilization and debug info
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        // Debug: Print what we can find
        print('DEBUG: Looking for melds header text after clicking You');
        print(
          'DEBUG: Found "Your Melds:": ${find.text('Your Melds:').evaluate().length}',
        );
        print(
          'DEBUG: Found "Back to yours": ${find.text('Back to yours').evaluate().length}',
        );

        // Verify we're back to our own view
        expect(find.text('Your Melds:'), findsOneWidget);
        expect(find.text('Back to yours'), findsNothing);
        expect(find.textContaining('$firstBotFound\'s Melds:'), findsNothing);

        print(
          '✅ Successfully returned to own view by clicking own player card',
        );
        print('✅ "Back to yours" button correctly hidden');

        await E2ETestUtils.cleanShutdown(tester);
      },
    );

    testWidgets('Switching between multiple bot players works correctly', (
      WidgetTester tester,
    ) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Wait for initial UI to stabilize
      await E2ETestUtils.stabilize(tester);

      // Find at least two different bots
      final botNames = [
        'Clara', 'Carl', 'Bob', 'Rita', 'Ben', 'Penny', 'Alex', 'Sue',
        'Bot 1', 'Bot 2', 'Bot 3', // fallback names
      ];

      final foundBots = <String>[];
      for (final botName in botNames) {
        if (find.textContaining(botName).evaluate().isNotEmpty) {
          foundBots.add(botName);
          if (foundBots.length >= 2) break;
        }
      }

      if (foundBots.length < 2) {
        throw Exception(
          'Need at least 2 bot players to test switching between them',
        );
      }

      final firstBot = foundBots[0];
      final secondBot = foundBots[1];

      print('✅ Found bots to test: $firstBot and $secondBot');

      // Switch to first bot's view
      await E2ETestUtils.safeTap(
        tester,
        find.textContaining(firstBot).first,
        debugLabel: 'Switch to $firstBot view',
      );
      await E2ETestUtils.stabilize(tester);

      // Verify we're viewing first bot's melds
      expect(find.textContaining('$firstBot\'s Melds:'), findsOneWidget);
      expect(find.text('Back to yours'), findsOneWidget);

      print('✅ Viewing $firstBot\'s melds');

      // Switch to second bot's view
      await E2ETestUtils.safeTap(
        tester,
        find.textContaining(secondBot).first,
        debugLabel: 'Switch to $secondBot view',
      );
      await E2ETestUtils.stabilize(tester);

      // Verify we're viewing second bot's melds
      expect(find.textContaining('$secondBot\'s Melds:'), findsOneWidget);
      expect(find.text('Back to yours'), findsOneWidget);
      expect(find.textContaining('$firstBot\'s Melds:'), findsNothing);

      print('✅ Successfully switched from $firstBot to $secondBot');
      print('✅ "Back to yours" button remains visible');

      // Switch back to first bot
      await E2ETestUtils.safeTap(
        tester,
        find.textContaining(firstBot).first,
        debugLabel: 'Switch back to $firstBot view',
      );
      await E2ETestUtils.stabilize(tester);

      // Verify we're viewing first bot's melds again
      expect(find.textContaining('$firstBot\'s Melds:'), findsOneWidget);
      expect(find.text('Back to yours'), findsOneWidget);
      expect(find.textContaining('$secondBot\'s Melds:'), findsNothing);

      print('✅ Successfully switched back to $firstBot');

      // Return to own view
      await E2ETestUtils.safeTap(
        tester,
        find.text('Back to yours'),
        debugLabel: 'Return to own view',
      );
      await E2ETestUtils.stabilize(tester);

      // Verify we're back to our own view
      expect(find.text('Your Melds:'), findsOneWidget);
      expect(find.text('Back to yours'), findsNothing);

      print('✅ Successfully returned to own view');
      print('✅ Multiple bot switching test complete');

      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets('Header text changes correctly when switching views', (
      WidgetTester tester,
    ) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Wait for initial UI to stabilize
      await E2ETestUtils.stabilize(tester);

      // Verify initial header text
      expect(find.text('Your Melds:'), findsOneWidget);

      // Find a bot to switch to
      final botNames = [
        'Clara', 'Carl', 'Bob', 'Rita', 'Ben', 'Penny', 'Alex', 'Sue',
        'Bot 1', 'Bot 2', 'Bot 3', // fallback names
      ];

      String? firstBotFound;
      for (final botName in botNames) {
        if (find.textContaining(botName).evaluate().isNotEmpty) {
          firstBotFound = botName;
          break;
        }
      }

      if (firstBotFound == null) {
        throw Exception('No bot players found to test header text');
      }

      print('✅ Testing header text changes with bot: $firstBotFound');

      // Switch to bot's view
      await E2ETestUtils.safeTap(
        tester,
        find.textContaining(firstBotFound).first,
        debugLabel: 'Switch to $firstBotFound for header test',
      );
      await E2ETestUtils.stabilize(tester);

      // Verify header text changed to bot's name
      expect(find.textContaining('$firstBotFound\'s Melds:'), findsOneWidget);
      expect(find.text('Your Melds:'), findsNothing);

      print('✅ Header text correctly shows "$firstBotFound\'s Melds:"');

      // Switch back to own view
      await E2ETestUtils.safeTap(
        tester,
        find.text('Back to yours'),
        debugLabel: 'Return to own view for header test',
      );
      await E2ETestUtils.stabilize(tester);

      // Verify header text changed back to "Your Melds:"
      expect(find.text('Your Melds:'), findsOneWidget);
      expect(find.textContaining('$firstBotFound\'s Melds:'), findsNothing);

      print('✅ Header text correctly shows "Your Melds:" again');
      print('✅ Header text changes test complete');

      await E2ETestUtils.cleanShutdown(tester);
    });
  });
}
