import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Going Out After Meld Creation Tests', () {
    late GameState gameState;
    late Player player;

    setUp(() {
      player = Player(id: '1', name: 'Test Player', type: PlayerType.human);
      final players = [player];
      final deck = Deck();
      gameState = GameState(players: players, deck: deck);

      // Set up game state for melding phase
      gameState.phase = GamePhase.playing;
      gameState.turnPhase = TurnPhase.meld;
      gameState.hasDrawnFromDeck = true;
    });

    test('should end round when player goes out via playMeld()', () {
      // Set up player who has already played down and is ready to go out
      player.hasPlayedDown = true;
      player.hasPickedUpFoot = true;

      // Create existing clean and dirty books to meet going out requirements
      final cleanBook = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ])!;

      final dirtyBook = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        const PlayingCard(
          suit: Suit.clubs,
          rank: CardRank.two,
        ), // Wild card makes it dirty
      ])!;

      player.melds.addAll([cleanBook, dirtyBook]);

      // Player has exactly 3 cards in foot (last cards)
      final lastCards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ];
      player.foot.addAll(lastCards);

      expect(player.canGoOutWithBooks, isTrue);
      expect(player.foot.length, equals(3));
      expect(gameState.phase, equals(GamePhase.playing));

      // Play the last meld - this should end the round
      final success = gameState.playMeld(lastCards);

      expect(success, isTrue);
      expect(player.foot.isEmpty, isTrue);
      expect(
        gameState.phase,
        equals(GamePhase.roundEnd),
      ); // Round should have ended
    });

    test('should end round when player goes out via playMeldBypass()', () {
      // Set up player who has already played down and is ready to go out
      player.hasPlayedDown = true;
      player.hasPickedUpFoot = true;

      // Create existing clean and dirty books
      final cleanBook = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ])!;

      final dirtyBook = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.two), // Wild card
      ])!;

      player.melds.addAll([cleanBook, dirtyBook]);

      // Player has exactly 3 cards in foot
      final lastCards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.jack),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.jack),
      ];
      player.foot.addAll(lastCards);

      expect(player.canGoOutWithBooks, isTrue);
      expect(gameState.phase, equals(GamePhase.playing));

      // Play the last meld using bypass method - this should end the round
      final success = gameState.playMeldBypass(lastCards);

      expect(success, isTrue);
      expect(player.foot.isEmpty, isTrue);
      expect(
        gameState.phase,
        equals(GamePhase.roundEnd),
      ); // Round should have ended
    });

    test('should end round when player goes out via addToMeld()', () {
      // Set up player who has already played down and is ready to go out
      player.hasPlayedDown = true;
      player.hasPickedUpFoot = true;

      // Create existing clean and dirty books
      final cleanBook = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ])!;

      final dirtyBook = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.two), // Wild card
      ])!;

      // Create a third meld (not yet a book) that we'll add to
      final incompleteMeld = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ])!;

      player.melds.addAll([cleanBook, dirtyBook, incompleteMeld]);

      // Player has exactly 1 card in foot (last card to add to meld)
      final lastCard = const PlayingCard(suit: Suit.spades, rank: CardRank.ace);
      player.foot.add(lastCard);

      expect(player.canGoOutWithBooks, isTrue);
      expect(gameState.phase, equals(GamePhase.playing));

      // Add the last card to existing meld - this should end the round
      final success = gameState.addToMeld(
        2,
        lastCard,
      ); // Add to third meld (index 2)

      expect(success, isTrue);
      expect(player.foot.isEmpty, isTrue);
      expect(
        gameState.phase,
        equals(GamePhase.roundEnd),
      ); // Round should have ended
    });

    test('should refuse emptying the foot when go-out books are missing', () {
      // Set up player who has played down but doesn't meet going out requirements
      player.hasPlayedDown = true;
      player.hasPickedUpFoot = true;

      // Create only a clean book (missing dirty book requirement)
      final cleanBook = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ])!;

      player.melds.add(cleanBook);

      // Player has last 3 cards but can't go out yet (no dirty book)
      final lastCards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ];
      player.foot.addAll(lastCards);

      expect(player.canGoOutWithBooks, isFalse); // Missing dirty book
      expect(gameState.phase, equals(GamePhase.playing));

      // Emptying the foot without both books is refused (prevents soft-lock)
      final success = gameState.playMeld(lastCards);

      expect(success, isFalse);
      expect(player.foot.length, equals(3));
      expect(player.melds.length, equals(1));
      expect(gameState.phase, equals(GamePhase.playing));
    });

    test('should NOT end round when player still has cards left', () {
      // Set up player who meets book requirements but still has cards
      player.hasPlayedDown = true;
      player.hasPickedUpFoot = true;

      // Create existing clean and dirty books
      final cleanBook = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ])!;

      final dirtyBook = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.two), // Wild card
      ])!;

      player.melds.addAll([cleanBook, dirtyBook]);

      // Player has 6 cards in foot (not empty after melding)
      final footCards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.jack),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
      ];
      player.foot.addAll(footCards);

      final cardsToMeld = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ];

      expect(player.canGoOutWithBooks, isTrue); // Has required books
      expect(gameState.phase, equals(GamePhase.playing));

      // Play a meld but player still has 3 cards left - should NOT end round
      final success = gameState.playMeld(cardsToMeld);

      expect(success, isTrue);
      expect(player.foot.length, equals(3)); // Still has cards
      expect(
        gameState.phase,
        equals(GamePhase.playing),
      ); // Round should NOT have ended
    });

    test(
      'should handle edge case: completing book requirement through melding',
      () {
        // Test where player creates their final required book via melding
        player.hasPlayedDown = true;
        player.hasPickedUpFoot = true;

        // Create only a clean book (missing dirty book)
        final cleanBook = Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ])!;

        player.melds.add(cleanBook);

        // Player's last 7 cards will create a dirty book and empty their foot
        final lastCards = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
          const PlayingCard(
            suit: Suit.clubs,
            rank: CardRank.two,
          ), // Wild makes it dirty
        ];
        player.foot.addAll(lastCards);

        expect(player.canGoOutWithBooks, isFalse); // No dirty book yet
        expect(gameState.phase, equals(GamePhase.playing));

        // Create the dirty book with last 7 cards - this should create required book AND end round
        final success = gameState.playMeld(lastCards);

        expect(success, isTrue);
        expect(player.foot.isEmpty, isTrue);
        expect(player.canGoOutWithBooks, isTrue); // Now has both book types
        expect(
          gameState.phase,
          equals(GamePhase.roundEnd),
        ); // Round should have ended
      },
    );
  });
}
