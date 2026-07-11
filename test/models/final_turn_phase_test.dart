import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/config/solo_game_settings.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

const _noFinalTurnSettings = SoloGameSettings(
  botCount: 2,
  botPersonalities: [BotPersonality.adaptive, BotPersonality.conservative],
  enableGoingOutBonus: true,
  enableFinalTurnAfterGoingOut: false,
);

const _withFinalTurnSettings = SoloGameSettings(
  botCount: 2,
  botPersonalities: [BotPersonality.adaptive, BotPersonality.conservative],
  enableGoingOutBonus: true,
  enableFinalTurnAfterGoingOut: true,
);

void main() {
  group('Final turn phase', () {
    test('disabled setting ends round immediately on go-out', () {
      final players = [
        Player(id: '1', name: 'You', type: PlayerType.human),
        Player(id: '2', name: 'Rita', type: PlayerType.bot),
        Player(id: '3', name: 'Bob', type: PlayerType.bot),
      ];
      final gameState = GameState(
        players: players,
        deck: Deck.createHandAndFootDeck(players.length),
        soloSettings: _noFinalTurnSettings,
      );

      gameState.phase = GamePhase.playing;
      _setupPlayerToGoOut(players[0]);
      gameState.currentPlayerIndex = 0;

      final ended = gameState.handlePlayerWentOut();

      expect(ended, isTrue);
      expect(gameState.phase, GamePhase.roundEnd);
      expect(gameState.finalTurnPhaseActive, isFalse);
    });

    test('enabled setting starts final turn phase for other players', () {
      final players = [
        Player(id: '1', name: 'You', type: PlayerType.human),
        Player(id: '2', name: 'Rita', type: PlayerType.bot),
        Player(id: '3', name: 'Bob', type: PlayerType.bot),
      ];
      final gameState = GameState(
        players: players,
        deck: Deck.createHandAndFootDeck(players.length),
        soloSettings: _withFinalTurnSettings,
      );

      gameState.phase = GamePhase.playing;
      _setupPlayerToGoOut(players[0]);
      gameState.currentPlayerIndex = 0;

      final ended = gameState.handlePlayerWentOut();

      expect(ended, isFalse);
      expect(gameState.phase, GamePhase.playing);
      expect(gameState.finalTurnPhaseActive, isTrue);
      expect(gameState.playersAwaitingFinalTurn, {1, 2});
      expect(gameState.currentPlayerIndex, 1);
    });

    test('final turns complete after each other player takes one turn', () {
      final players = [
        Player(id: '1', name: 'You', type: PlayerType.human),
        Player(id: '2', name: 'Rita', type: PlayerType.bot),
        Player(id: '3', name: 'Bob', type: PlayerType.bot),
      ];
      final gameState = GameState(
        players: players,
        deck: Deck.createHandAndFootDeck(players.length),
        soloSettings: _withFinalTurnSettings,
      );

      gameState.phase = GamePhase.playing;
      _setupPlayerToGoOut(players[0]);
      gameState.currentPlayerIndex = 0;
      gameState.handlePlayerWentOut();

      expect(gameState.currentPlayerIndex, 1);
      expect(gameState.completeTurn(), isFalse);
      expect(gameState.currentPlayerIndex, 2);
      expect(gameState.completeTurn(), isTrue);
      expect(gameState.phase, GamePhase.roundEnd);
      expect(gameState.finalTurnPhaseActive, isFalse);
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
