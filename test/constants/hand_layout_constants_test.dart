import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/constants/hand_layout_constants.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/utils/game_responsive_layout.dart';
import 'package:hand_foot_game_flutter/widgets/game_hand_display.dart';
import 'package:hand_foot_game_flutter/widgets/playing_card_widget.dart';

void main() {
  group('HandLayoutConstants', () {
    test('handCardCenterInStack matches bottom-aligned hand cards', () {
      const sizes = GameCardSizes.normalPhone;
      const stackHeight = 113.0;
      final center = HandLayoutConstants.handCardCenterInStack(
        0,
        sizes,
        stackHeight,
      );

      expect(
        center.dy,
        stackHeight - HandLayoutConstants.handCardWidgetHeight(sizes) / 2,
      );
      expect(center.dx, HandLayoutConstants.handCardWidgetWidth(sizes) / 2);
    });

    testWidgets('animation center aligns with rendered hand card on phone', (
      tester,
    ) async {
      final handStackKey = GlobalKey();
      final player = Player(id: 'human', name: 'You', type: PlayerType.human)
        ..currentHand.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
        ]);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: Scaffold(
              body: GameHandDisplay(
                player: player,
                selectedCardIndices: const [],
                handStackKey: handStackKey,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final stackBox =
          handStackKey.currentContext!.findRenderObject() as RenderBox;
      final stackTopLeft = stackBox.localToGlobal(Offset.zero);
      final sizes = GameResponsiveLayout.handSizes(
        handStackKey.currentContext!,
        cardCount: player.currentHand.length,
      );
      final animationCenter =
          stackTopLeft +
          HandLayoutConstants.handCardCenterInStack(
            0,
            sizes,
            stackBox.size.height,
          );

      final handCardBox = tester.renderObject<RenderBox>(
        find.byType(PlayingCardWidget).first,
      );
      final handCardCenter =
          handCardBox.localToGlobal(Offset.zero) +
          handCardBox.size.center(Offset.zero);

      expect(animationCenter.dx, closeTo(handCardCenter.dx, 1));
      expect(animationCenter.dy, closeTo(handCardCenter.dy, 1));
    });
  });
}
