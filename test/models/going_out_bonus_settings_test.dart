import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/config/solo_game_settings.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Going out bonus settings', () {
    test('applies +100 bonus when enabled', () {
      final players = [
        Player(id: '1', name: 'You', type: PlayerType.human),
        Player(id: '2', name: 'Rita', type: PlayerType.bot),
      ];
      final settings = SoloGameSettings(
        botCount: 1,
        botPersonalities: [BotPersonality.adaptive],
        enableGoingOutBonus: true,
        enableFinalTurnAfterGoingOut: false,
      );
      final gameState = GameState(
        players: players,
        deck: Deck.createHandAndFootDeck(players.length),
        soloSettings: settings,
      );

      _setupPlayerToGoOut(players[1]);
      gameState.currentPlayerIndex = 1;
      gameState.handlePlayerWentOut();

      expect(players[1].score, greaterThan(players[0].score));
      expect(players[1].roundScoreHistory.single.goingOutBonus, 100);
    });

    test('skips bonus when disabled', () {
      final players = [
        Player(id: '1', name: 'You', type: PlayerType.human),
        Player(id: '2', name: 'Rita', type: PlayerType.bot),
      ];
      final settings = SoloGameSettings(
        botCount: 1,
        botPersonalities: [BotPersonality.adaptive],
        enableGoingOutBonus: false,
        enableFinalTurnAfterGoingOut: false,
      );
      final gameState = GameState(
        players: players,
        deck: Deck.createHandAndFootDeck(players.length),
        soloSettings: settings,
      );

      _setupPlayerToGoOut(players[1]);
      gameState.currentPlayerIndex = 1;
      gameState.handlePlayerWentOut();

      expect(players[1].roundScoreHistory.single.goingOutBonus, 0);
    });
  });
}

void _setupPlayerToGoOut(Player player) {
  player.hand.clear();
  player.foot.clear();
  player.melds.clear();

  final cleanBook = Meld.createMeld([
    const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
    const PlayingCard(suit: Suit.spades, rank: CardRank.king),
    const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
    const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
    const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
    const PlayingCard(suit: Suit.spades, rank: CardRank.king),
    const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
  ])!;

  final dirtyBook = Meld.createMeld([
    const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
    const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
    const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
    const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
    const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
    const PlayingCard(suit: Suit.spades, rank: CardRank.two),
    const PlayingCard(rank: CardRank.joker),
  ])!;

  player.melds.add(cleanBook);
  player.melds.add(dirtyBook);
  player.hasPlayedDown = true;
  player.hasPickedUpFoot = true;
}
