import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_decision.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/config/solo_game_settings.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/screens/managers/bot_turn_manager.dart';
import 'package:hand_foot_game_flutter/services/analytics/bot_decision_analytics_snapshot.dart';

final _immediateRoundEndSettings = SoloGameSettings(
  botCount: 1,
  botPersonalities: [BotPersonality.adaptive],
  enableGoingOutBonus: true,
  enableFinalTurnAfterGoingOut: false,
);

void main() {
  group('BotTurnManager execution', () {
    late GameController gameController;
    late Player botPlayer;
    late BotTurnManager turnManager;

    setUp(() {
      final players = [
        Player(id: 'human', name: 'You', type: PlayerType.human),
        Player(id: 'bot1', name: 'Clara', type: PlayerType.bot),
      ];
      gameController = GameController(
        players: players,
        seed: 454749,
        soloSettings: _immediateRoundEndSettings,
      );
      gameController.initializeGame();
      botPlayer = players[1];
      botPlayer.hasPlayedDown = true;
      gameController.gameState.currentPlayerIndex = 1;

      turnManager = BotTurnManager(
        gameController: gameController,
        botAI: EnhancedBotAI(seed: 454749),
        onStateChanged: () {},
        logHumanAction: (_) {},
        logBotDecision:
            ({
              required String botId,
              required String decision,
              required String reasoning,
              Map<String, dynamic>? context,
              BotDecisionAnalyticsSnapshot? gameStateSnapshot,
            }) {},
      );
    });

    test('executes unlockDiscardPile without failing', () {
      gameController.gameState.turnPhase = TurnPhase.draw;
      gameController.gameState.discardPile.add(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
      );
      botPlayer.dealHand([
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
      ]);
      botPlayer.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        ])!,
      );

      final success = turnManager.executeBotDecision(
        BotDecision(action: 'unlockDiscardPile'),
        botPlayer,
      );

      expect(success, isTrue);
      expect(gameController.gameState.turnPhase, TurnPhase.meld);
    });

    test('discards using rank+suit match for duplicate deck cards', () {
      final kingOne = const PlayingCard(suit: Suit.hearts, rank: CardRank.king);
      final kingTwo = const PlayingCard(suit: Suit.hearts, rank: CardRank.king);
      botPlayer.dealHand([kingOne, kingTwo]);
      gameController.gameState.turnPhase = TurnPhase.discard;
      gameController.gameState.hasDrawnFromDeck = true;

      final duplicateReference = PlayingCard(
        suit: Suit.hearts,
        rank: CardRank.king,
      );

      final success = turnManager.executeBotDecision(
        BotDecision(action: 'discard', data: duplicateReference),
        botPlayer,
      );

      expect(success, isTrue);
      expect(botPlayer.currentHand.length, 1);
    });

    test('error decision recovers by completing turn instead of failing', () {
      botPlayer.dealHand([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
        const PlayingCard(suit: Suit.spades, rank: CardRank.six),
      ]);
      gameController.gameState.turnPhase = TurnPhase.discard;
      gameController.gameState.hasDrawnFromDeck = true;
      final startingPlayerIndex = gameController.gameState.currentPlayerIndex;

      final success = turnManager.executeBotDecision(
        BotDecision(action: 'error'),
        botPlayer,
      );

      expect(success, isTrue);
      expect(
        gameController.gameState.currentPlayerIndex,
        isNot(startingPlayerIndex),
      );
    });

    test('tryForceMeld adds to existing meld before force discard', () {
      botPlayer.dealHand([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
      ]);
      botPlayer.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
          const PlayingCard(suit: Suit.spades, rank: CardRank.eight),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.eight),
        ])!,
      );
      gameController.gameState.turnPhase = TurnPhase.meld;
      gameController.gameState.hasDrawnFromDeck = true;
      final meldSizeBefore = botPlayer.melds.first.cards.length;

      final melded = turnManager.tryForceMeld(botPlayer);

      expect(melded, isTrue);
      expect(botPlayer.melds.first.cards.length, greaterThan(meldSizeBefore));
    });

    test('endRoundForBot ends round and is idempotent', () {
      _setupBotToGoOut(botPlayer);
      var stateChangedCount = 0;
      turnManager = BotTurnManager(
        gameController: gameController,
        botAI: EnhancedBotAI(seed: 454749),
        onStateChanged: () {
          stateChangedCount++;
        },
        logHumanAction: (_) {},
        logBotDecision:
            ({
              required String botId,
              required String decision,
              required String reasoning,
              Map<String, dynamic>? context,
              BotDecisionAnalyticsSnapshot? gameStateSnapshot,
            }) {},
      );

      turnManager.endRoundForBot(botPlayer);

      expect(gameController.gameState.phase, GamePhase.roundEnd);
      expect(gameController.gameState.round, 2);
      expect(stateChangedCount, 1);

      turnManager.endRoundForBot(botPlayer);

      expect(gameController.gameState.phase, GamePhase.roundEnd);
      expect(gameController.gameState.round, 2);
      expect(stateChangedCount, 1);
    });

    test('goOut decision ends round through endRoundForBot', () {
      _setupBotToGoOut(botPlayer);

      final success = turnManager.executeBotDecision(
        BotDecision(action: 'goOut'),
        botPlayer,
      );

      expect(success, isTrue);
      expect(gameController.gameState.phase, GamePhase.roundEnd);
      expect(gameController.gameState.round, 2);
    });

    test('error recovery ends round when bot can go out', () {
      _setupBotToGoOut(botPlayer);
      botPlayer.hand.clear();
      botPlayer.foot.clear();
      gameController.gameState.turnPhase = TurnPhase.draw;

      final success = turnManager.executeBotDecision(
        BotDecision(action: 'error'),
        botPlayer,
      );

      expect(success, isTrue);
      expect(gameController.gameState.phase, GamePhase.roundEnd);
      expect(gameController.gameState.round, 2);
    });

    test('addToMeld go-out keeps human final turn '
        '(session 700168 / Ben regression)', () {
      // Repro: Ben (bookBuilder) melds last foot card → GameState starts
      // final-turn phase, then validateGameStateAfterMeld must NOT call
      // endRoundForBot again (that incorrectly removed the human).
      final human = Player(id: '1', name: 'You', type: PlayerType.human);
      final alex = Player(id: '2', name: 'Alex', type: PlayerType.bot);
      final ben = Player(id: '3', name: 'Ben', type: PlayerType.bot);
      final controller = GameController(
        players: [human, alex, ben],
        seed: 700168,
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
      controller.initializeGame();

      _setupBotToGoOut(ben);
      // Leave one natural on the foot that completes go-out when added.
      ben.hand.clear();
      ben.foot.clear();
      final lastKing = const PlayingCard(
        suit: Suit.diamonds,
        rank: CardRank.king,
      );
      ben.foot.add(lastKing);
      expect(ben.canGoOut, isFalse);
      expect(ben.canGoOutWithBooks, isTrue);

      controller.gameState.currentPlayerIndex = 2;
      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;

      final manager = BotTurnManager(
        gameController: controller,
        botAI: EnhancedBotAI(seed: 700168),
        onStateChanged: () {},
        logHumanAction: (_) {},
        logBotDecision:
            ({
              required String botId,
              required String decision,
              required String reasoning,
              Map<String, dynamic>? context,
              BotDecisionAnalyticsSnapshot? gameStateSnapshot,
            }) {},
      );

      final success = manager.executeBotDecision(
        BotDecision(
          action: 'addToMeld',
          data: {'meldIndex': 0, 'card': lastKing},
        ),
        ben,
      );

      expect(success, isTrue);
      expect(ben.canGoOut, isTrue);
      expect(controller.gameState.phase, GamePhase.playing);
      expect(controller.gameState.finalTurnPhaseActive, isTrue);
      expect(controller.gameState.playerWhoWentOutIndex, 2);
      // Human must still be awaiting (or currently taking) their final turn.
      expect(
        controller.gameState.playersAwaitingFinalTurn.contains(0) ||
            controller.gameState.currentPlayerIndex == 0,
        isTrue,
        reason: 'Human must receive a final turn after Ben melds out',
      );
      expect(
        controller.gameState.currentPlayerIndex,
        isNot(2),
        reason: 'Play should have advanced off Ben after go-out',
      );
    });

    test('forceCompleteBotTurn stops after forced meld go-out '
        '(keeps human final turn)', () {
      final human = Player(id: '1', name: 'You', type: PlayerType.human);
      final alex = Player(id: '2', name: 'Alex', type: PlayerType.bot);
      final ben = Player(id: '3', name: 'Ben', type: PlayerType.bot);
      final controller = GameController(
        players: [human, alex, ben],
        seed: 700168,
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
      controller.initializeGame();

      _setupBotToGoOut(ben);
      ben.hand.clear();
      ben.foot.clear();
      final lastKing = const PlayingCard(
        suit: Suit.diamonds,
        rank: CardRank.king,
      );
      ben.foot.add(lastKing);

      controller.gameState.currentPlayerIndex = 2;
      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;

      final manager = BotTurnManager(
        gameController: controller,
        botAI: EnhancedBotAI(seed: 700168),
        onStateChanged: () {},
        logHumanAction: (_) {},
        logBotDecision:
            ({
              required String botId,
              required String decision,
              required String reasoning,
              Map<String, dynamic>? context,
              BotDecisionAnalyticsSnapshot? gameStateSnapshot,
            }) {},
      );

      manager.forceCompleteBotTurn(ben);

      expect(ben.canGoOut, isTrue);
      expect(controller.gameState.phase, GamePhase.playing);
      expect(controller.gameState.finalTurnPhaseActive, isTrue);
      expect(controller.gameState.playerWhoWentOutIndex, 2);
      expect(
        controller.gameState.playersAwaitingFinalTurn.contains(0) ||
            controller.gameState.currentPlayerIndex == 0,
        isTrue,
        reason: 'Human must keep final turn after forced meld go-out',
      );
      expect(controller.gameState.currentPlayerIndex, isNot(2));
    });

    test(
      'forceCompleteBotTurn is a no-op when the bot is no longer current player',
      () {
        gameController.gameState.turnPhase = TurnPhase.meld;
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
          const PlayingCard(suit: Suit.spades, rank: CardRank.eight),
        ]);
        final handBefore = botPlayer.currentHand.length;
        final discardBefore = gameController.gameState.discardPile.length;

        // Simulate continue-game / UI handoff back to the human mid-recovery.
        gameController.gameState.currentPlayerIndex = 0;

        turnManager.forceCompleteBotTurn(botPlayer);

        expect(botPlayer.currentHand.length, handBefore);
        expect(gameController.gameState.discardPile.length, discardBefore);
        expect(gameController.gameState.currentPlayerIndex, 0);
        expect(gameController.gameState.turnPhase, TurnPhase.meld);
      },
    );
  });

  group('EnhancedBotAI error propagation', () {
    late GameController gameController;
    late Player botPlayer;
    late EnhancedBotAI botAI;

    setUp(() {
      final players = [
        Player(id: 'human', name: 'You', type: PlayerType.human),
        Player(id: 'bot1', name: 'Clara', type: PlayerType.bot),
      ];
      gameController = GameController(players: players, seed: 1);
      gameController.initializeGame();
      botPlayer = players[1];
      botAI = EnhancedBotAI(seed: 1);
      botPlayer.hand.clear();
      botPlayer.foot.clear();
      botPlayer.hasPlayedDown = true;
      botPlayer.hasPickedUpFoot = true;
      gameController.gameState.currentPlayerIndex = 1;
      gameController.gameState.turnPhase = TurnPhase.discard;
      gameController.gameState.hasDrawnFromDeck = true;
    });

    test('preserves error decision for empty hand without books', () {
      final decision = botAI.makeDecision(botPlayer, gameController);

      expect(decision.action, equals('error'));
    });
  });
}

void _setupBotToGoOut(Player player) {
  player.hand.clear();
  player.foot.clear();
  player.melds.clear();

  player.melds.add(
    Meld.createMeld([
      const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
      const PlayingCard(suit: Suit.spades, rank: CardRank.king),
      const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
      const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
      const PlayingCard(suit: Suit.spades, rank: CardRank.king),
      const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
    ])!,
  );
  player.melds.add(
    Meld.createMeld([
      const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
      const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
      const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
      const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
      const PlayingCard(suit: Suit.spades, rank: CardRank.two),
      const PlayingCard(rank: CardRank.joker),
    ])!,
  );
  player.hasPlayedDown = true;
  player.hasPickedUpFoot = true;
}
