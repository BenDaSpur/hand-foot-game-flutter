import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/config/solo_game_settings.dart';
import 'package:hand_foot_game_flutter/game/managers/meld_manager.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

/// Regression for gameSeed 700168 (session_17870056010721072):
/// Ben melded out on Round 2; the human never got a final turn.
void main() {
  group('Final turn after meld go-out (seed 700168)', () {
    test(
      'MeldManager multi-meld go-out starts final-turn phase for other players',
      () {
        final human = Player(id: '1', name: 'You', type: PlayerType.human);
        final alex = Player(id: '2', name: 'Alex', type: PlayerType.bot);
        final ben = Player(id: '3', name: 'Ben', type: PlayerType.bot);
        final gameState = GameState(
          players: [human, alex, ben],
          deck: Deck.createHandAndFootDeck(3, seed: 700168),
          soloSettings: SoloGameSettings(
            botCount: 2,
            botPersonalities: [
              BotPersonality.adaptive,
              BotPersonality.bookBuilder,
            ],
            enableGoingOutBonus: true,
            enableFinalTurnAfterGoingOut: true,
          ),
        );
        final meldManager = MeldManager(gameState);

        gameState.phase = GamePhase.playing;
        gameState.turnPhase = TurnPhase.meld;
        gameState.hasDrawnFromDeck = true;
        gameState.currentPlayerIndex = 2;

        ben.hasPlayedDown = true;
        ben.hasPickedUpFoot = true;
        ben.hand.clear();
        ben.foot.clear();
        ben.melds.clear();
        ben.melds.addAll([
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
            const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
            const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
          ])!,
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
            const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
            const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
          ])!,
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
            const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
          ])!,
        ]);
        // Empty the foot by adding the last three cards onto the ace meld.
        ben.foot.addAll([
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.two),
        ]);

        final success = meldManager.createMultipleMeldsFromIndices([
          [0, 1, 2],
        ], skipPlayDownCheck: true);

        expect(success, isTrue);
        expect(ben.canGoOut, isTrue);
        expect(gameState.phase, GamePhase.playing);
        expect(gameState.finalTurnPhaseActive, isTrue);
        expect(gameState.playerWhoWentOutIndex, 2);
        expect(gameState.playersAwaitingFinalTurn.contains(0), isTrue);
        expect(gameState.playersAwaitingFinalTurn.contains(1), isTrue);
        expect(gameState.currentPlayerIndex, isNot(2));
      },
    );
  });
}
