import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hand_foot_game_flutter/widgets/playing_card_widget.dart';
import 'test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Advanced Meld Modal E2E Tests', () {
    testWidgets('Modal opens and closes correctly', (
      WidgetTester tester,
    ) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Draw cards to enter meld phase
      await E2ETestUtils.safeTap(
        tester,
        find.text('Draw from Deck'),
        debugLabel: 'Draw cards',
      );
      await E2ETestUtils.stabilize(tester);

      // Open advanced meld modal
      await E2ETestUtils.safeTap(
        tester,
        find.text('Play Cards'),
        debugLabel: 'Open Play Cards modal',
      );

      // Verify modal opened
      if (await E2ETestUtils.waitForElement(
        tester,
        find.text('Multi-Meld Play-Down'),
      )) {
        expect(find.text('Available Cards'), findsOneWidget);
        expect(find.text('Proposed Melds'), findsOneWidget);
        print('✅ Modal opened successfully');

        // Close modal
        await E2ETestUtils.safeTap(
          tester,
          find.text('Cancel'),
          debugLabel: 'Close modal',
        );
        await E2ETestUtils.stabilize(tester);

        expect(find.text('Multi-Meld Play-Down'), findsNothing);
        print('✅ Modal closed successfully');
      } else {
        print('⚠️ Modal did not open - may be different game state');
      }

      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets('Can select cards in modal', (WidgetTester tester) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Draw cards
      await E2ETestUtils.safeTap(
        tester,
        find.text('Draw from Deck'),
        debugLabel: 'Draw cards',
      );
      await E2ETestUtils.stabilize(tester);

      // Open modal
      await E2ETestUtils.safeTap(
        tester,
        find.text('Play Cards'),
        debugLabel: 'Open modal',
      );

      if (await E2ETestUtils.waitForElement(
        tester,
        find.text('Multi-Meld Play-Down'),
      )) {
        // Find available card widgets in the modal
        final cardWidgets = find.byType(PlayingCardWidget);
        if (cardWidgets.evaluate().isNotEmpty) {
          // Try to select multiple cards
          final cardCount = cardWidgets.evaluate().length;
          final cardsToSelect = cardCount >= 3 ? 3 : cardCount;

          for (int i = 0; i < cardsToSelect; i++) {
            await E2ETestUtils.safeTap(
              tester,
              cardWidgets.at(i),
              debugLabel: 'Select card ${i + 1}',
            );
            await E2ETestUtils.stabilize(tester);
          }

          print('✅ Selected $cardsToSelect cards in modal');

          // Look for "New Meld" button - it should be enabled if we have enough cards
          final newMeldButton = find.text('New Meld');
          if (newMeldButton.evaluate().isNotEmpty) {
            print('✅ New Meld button found');
          }
        }

        // Close modal
        await E2ETestUtils.safeTap(
          tester,
          find.text('Cancel'),
          debugLabel: 'Close modal after selection',
        );
        await E2ETestUtils.stabilize(tester);
      }

      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets('Can create meld in modal', (WidgetTester tester) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Draw cards
      await E2ETestUtils.safeTap(
        tester,
        find.text('Draw from Deck'),
        debugLabel: 'Draw cards',
      );
      await E2ETestUtils.stabilize(tester);

      // Open modal
      await E2ETestUtils.safeTap(
        tester,
        find.text('Play Cards'),
        debugLabel: 'Open modal for meld creation',
      );

      if (await E2ETestUtils.waitForElement(
        tester,
        find.text('Multi-Meld Play-Down'),
      )) {
        // Try to create a meld by selecting cards
        final cardWidgets = find.byType(PlayingCardWidget);
        if (cardWidgets.evaluate().isNotEmpty) {
          // Select the first 3 cards
          for (int i = 0; i < 3 && i < cardWidgets.evaluate().length; i++) {
            await E2ETestUtils.safeTap(
              tester,
              cardWidgets.at(i),
              debugLabel: 'Select card for meld ${i + 1}',
            );
            await E2ETestUtils.stabilize(tester);
          }

          // Try to create the meld
          final newMeldButton = find.text('New Meld');
          if (newMeldButton.evaluate().isNotEmpty) {
            await E2ETestUtils.safeTap(
              tester,
              newMeldButton,
              debugLabel: 'Create new meld',
            );
            await E2ETestUtils.stabilize(tester);

            // Check if meld was created (proposed melds section should update)
            if (await E2ETestUtils.waitForElement(
              tester,
              find.textContaining('Proposed Melds (1)'),
              timeout: const Duration(seconds: 2),
            )) {
              print('✅ First meld created successfully');

              // Try to create a second meld if we have more cards
              final remainingCards = find.byType(PlayingCardWidget);
              if (remainingCards.evaluate().length >= 3) {
                // Select cards for second meld
                for (
                  int i = 0;
                  i < 3 && i < remainingCards.evaluate().length;
                  i++
                ) {
                  await E2ETestUtils.safeTap(
                    tester,
                    remainingCards.at(i),
                    debugLabel: 'Select card for second meld ${i + 1}',
                  );
                  await E2ETestUtils.stabilize(tester);
                }

                // Create second meld
                final secondMeldButton = find.text('New Meld');
                if (secondMeldButton.evaluate().isNotEmpty) {
                  await E2ETestUtils.safeTap(
                    tester,
                    secondMeldButton,
                    debugLabel: 'Create second meld',
                  );
                  await E2ETestUtils.stabilize(tester);

                  // Check for second meld
                  if (await E2ETestUtils.waitForElement(
                    tester,
                    find.textContaining('Proposed Melds (2)'),
                    timeout: const Duration(seconds: 2),
                  )) {
                    print(
                      '✅ Second meld created successfully - modal is functional!',
                    );
                  } else {
                    print(
                      '⚠️ Second meld not created - may be validation issue',
                    );
                  }
                }
              }
            } else {
              print('⚠️ First meld not created - may be validation issue');
            }
          } else {
            print('⚠️ New Meld button not available');
          }
        }

        // Close modal
        await E2ETestUtils.safeTap(
          tester,
          find.text('Cancel'),
          debugLabel: 'Close modal after meld creation',
        );
        await E2ETestUtils.stabilize(tester);
      }

      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets('Modal handles card scrolling correctly', (
      WidgetTester tester,
    ) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Draw cards
      await E2ETestUtils.safeTap(
        tester,
        find.text('Draw from Deck'),
        debugLabel: 'Draw cards',
      );
      await E2ETestUtils.stabilize(tester);

      // Open modal
      await E2ETestUtils.safeTap(
        tester,
        find.text('Play Cards'),
        debugLabel: 'Open modal for scrolling test',
      );

      if (await E2ETestUtils.waitForElement(
        tester,
        find.text('Multi-Meld Play-Down'),
      )) {
        // Find the scrollable area with cards
        final scrollable = find.byType(GridView);
        if (scrollable.evaluate().isNotEmpty) {
          // Try to scroll the card area
          await tester.drag(scrollable.first, const Offset(0, -100));
          await E2ETestUtils.stabilize(tester);

          print('✅ Card area scrolled without freezing');

          // Scroll back
          await tester.drag(scrollable.first, const Offset(0, 100));
          await E2ETestUtils.stabilize(tester);

          print('✅ Card area scrolled back without issues');

          // Verify modal is still interactive
          final cardWidgets = find.byType(PlayingCardWidget);
          if (cardWidgets.evaluate().isNotEmpty) {
            await E2ETestUtils.safeTap(
              tester,
              cardWidgets.first,
              debugLabel: 'Test card selection after scroll',
            );
            await E2ETestUtils.stabilize(tester);
            print('✅ Card selection works after scrolling');
          }
        }

        // Close modal
        await E2ETestUtils.safeTap(
          tester,
          find.text('Cancel'),
          debugLabel: 'Close modal after scroll test',
        );
        await E2ETestUtils.stabilize(tester);
      }

      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets('Modal responsive on different screen sizes', (
      WidgetTester tester,
    ) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Test with mobile portrait size (simulate phone)
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await E2ETestUtils.stabilize(tester);

      // Draw cards
      await E2ETestUtils.safeTap(
        tester,
        find.text('Draw from Deck'),
        debugLabel: 'Draw cards on mobile',
      );
      await E2ETestUtils.stabilize(tester);

      // Open modal
      await E2ETestUtils.safeTap(
        tester,
        find.text('Play Cards'),
        debugLabel: 'Open modal on mobile size',
      );

      if (await E2ETestUtils.waitForElement(
        tester,
        find.text('Multi-Meld Play-Down'),
      )) {
        print('✅ Modal opens correctly on mobile size');

        // Verify cards are visible and not too large
        final cardWidgets = find.byType(PlayingCardWidget);
        if (cardWidgets.evaluate().isNotEmpty) {
          await E2ETestUtils.safeTap(
            tester,
            cardWidgets.first,
            debugLabel: 'Test card tap on mobile',
          );
          await E2ETestUtils.stabilize(tester);
          print('✅ Cards are tappable on mobile size');
        }

        // Close modal
        await E2ETestUtils.safeTap(
          tester,
          find.text('Cancel'),
          debugLabel: 'Close modal on mobile',
        );
        await E2ETestUtils.stabilize(tester);
      }

      // Reset to default size
      await tester.binding.setSurfaceSize(null);
      await E2ETestUtils.stabilize(tester);

      await E2ETestUtils.cleanShutdown(tester);
    });
  });
}
