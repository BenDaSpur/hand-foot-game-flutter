import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/utils/game_responsive_layout.dart';
import 'package:hand_foot_game_flutter/widgets/meld_widget.dart';

void main() {
  group('preferTouchSizedMeldAddButton', () {
    test('native always prefers touch targets', () {
      expect(preferTouchSizedMeldAddButton(isWeb: false, width: 390), isTrue);
      expect(preferTouchSizedMeldAddButton(isWeb: false, width: 1200), isTrue);
    });

    test('web prefers touch on phone width and compact on desktop', () {
      expect(
        preferTouchSizedMeldAddButton(
          isWeb: true,
          width: GameResponsiveLayout.normalPhoneBreakpoint,
        ),
        isTrue,
      );
      expect(preferTouchSizedMeldAddButton(isWeb: true, width: 1200), isFalse);
    });
  });

  group('MeldWidget add button', () {
    late Meld meld;

    setUp(() {
      meld = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ])!;
    });

    testWidgets('touch-sized +N taps select-all callback', (tester) async {
      var selected = false;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 800)),
          child: MaterialApp(
            home: Scaffold(
              body: MeldWidget(
                meld: meld,
                meldIndex: 0,
                canAddCards: true,
                compatibleCardsInHand: 1,
                onSelectAllCards: (_) => selected = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('+1'), findsOneWidget);
      expect(find.byType(InkWell), findsOneWidget);

      await tester.tap(find.text('+1'));
      expect(selected, isTrue);
    });
  });
}
