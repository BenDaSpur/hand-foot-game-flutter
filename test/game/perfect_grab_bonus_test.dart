@Tags(['perfect_grab'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/config/game_config.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Perfect grab bonus', () {
    late List<Player> players;
    late GameController controller;

    setUp(() {
      players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot 1', type: PlayerType.bot),
        Player(id: '3', name: 'Bot 2', type: PlayerType.bot),
      ];
      controller = GameController(players: players, seed: 4242);
    });

    test('completeRoundStart awards bonus to human player', () {
      controller.initializeGame(dealCards: false);

      final human = players.firstWhere((p) => p.type == PlayerType.human);
      expect(human.score, 0);

      controller.completeRoundStart(earnedPerfectGrabBonus: true);

      expect(human.score, GameConfig.perfectGrabBonus);
      for (final player in players) {
        expect(player.hand.length, 11);
        expect(player.foot.length, 11);
      }
      expect(controller.gameState.discardPile.length, 1);
      expect(controller.gameState.phase, GamePhase.playing);
    });

    test('completeRoundStart without bonus deals normally', () {
      controller.initializeGame(dealCards: false);
      final human = players.firstWhere((p) => p.type == PlayerType.human);

      controller.completeRoundStart(earnedPerfectGrabBonus: false);

      expect(human.score, 0);
      expect(controller.gameState.phase, GamePhase.playing);
    });

    test('prepareNewRoundDeal shuffles without dealing until completion', () {
      controller.initializeGame();
      controller.gameState.phase = GamePhase.roundEnd;
      controller.gameState.round = 2;

      for (final player in players) {
        player.hand.addAll(
          List.generate(3, (_) => controller.gameState.deck.drawCard()!),
        );
      }

      controller.prepareNewRoundDeal();

      for (final player in players) {
        expect(player.hand, isEmpty);
        expect(player.foot, isEmpty);
      }
      expect(controller.gameState.phase, GamePhase.playing);
      expect(controller.gameState.discardPile, isEmpty);

      controller.completeRoundStart(earnedPerfectGrabBonus: false);

      for (final player in players) {
        expect(player.hand.length, 11);
        expect(player.foot.length, 11);
      }
    });

    test('completeRoundStart skips bonus when no human player exists', () {
      final botOnlyPlayers = [
        Player(id: '2', name: 'Bot 1', type: PlayerType.bot),
        Player(id: '3', name: 'Bot 2', type: PlayerType.bot),
      ];
      final botController = GameController(players: botOnlyPlayers, seed: 99);
      botController.initializeGame(dealCards: false);

      botController.completeRoundStart(earnedPerfectGrabBonus: true);

      for (final player in botOnlyPlayers) {
        expect(player.score, 0);
      }
      expect(botController.gameState.phase, GamePhase.playing);
    });

    test('initializeGame still deals immediately by default for tests', () {
      controller.initializeGame();

      for (final player in players) {
        expect(player.hand.length, 11);
        expect(player.foot.length, 11);
      }
    });
  });
}
