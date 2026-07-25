@Tags(['privacy'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/services/firebase_service.dart';
import 'package:hand_foot_game_flutter/services/game_save_service.dart';

/// Regression coverage for the action log leaking opponents' cards online.
///
/// Every multiplayer player is created with `PlayerType.human`, so keying
/// privacy off the player type used to put the acting player's exact drawn
/// cards into the shared Firestore document, where every other client read
/// and rendered them.
void main() {
  GameState buildGameState({
    required bool multiplayer,
    PlayerType secondPlayerType = PlayerType.human,
  }) {
    final players = [
      Player(id: 'alice', name: 'Alice', type: PlayerType.human),
      Player(id: 'bob', name: 'Bob', type: secondPlayerType),
    ];
    final gameState = GameState(
      players: players,
      deck: Deck.createHandAndFootDeck(players.length, seed: 4242),
      phase: GamePhase.playing,
    );
    if (multiplayer) {
      // Alice is the person sitting at this device.
      gameState.setMultiplayerMode(true, 'alice');
    }
    return gameState;
  }

  List<PlayingCard> newlyDrawnCards(Player player) {
    return player.newlyDrawnCardIndices
        .where((index) => index < player.currentHand.length)
        .map((index) => player.currentHand[index])
        .toList();
  }

  List<String> serializedMessages(GameState gameState) {
    final serialized = FirebaseService.gameStateToMapForTesting(gameState);
    final actions = serialized['recentActions'] as List<dynamic>;
    return actions
        .cast<Map<String, dynamic>>()
        .map((action) => action['message'] as String)
        .toList();
  }

  group('Drawn cards in the shared action log', () {
    test('shared message records only the count, never the cards', () {
      final gameState = buildGameState(multiplayer: true);

      expect(gameState.drawFromDeck(), isTrue);

      final action = gameState.recentActions.last;
      final drawnCards = newlyDrawnCards(gameState.players[0]);
      expect(drawnCards, hasLength(2));

      expect(action.message, '🎴 drew 2 cards from deck');
      for (final card in drawnCards) {
        expect(
          action.message.contains(card.compactName),
          isFalse,
          reason: 'shared log leaked ${card.compactName}',
        );
      }
    });

    test('acting player still sees their own cards locally', () {
      final gameState = buildGameState(multiplayer: true);

      expect(gameState.drawFromDeck(), isTrue);

      final action = gameState.recentActions.last;
      final drawnCards = newlyDrawnCards(gameState.players[0]);

      expect(action.privateMessage, isNotNull);
      for (final card in drawnCards) {
        expect(action.displayMessage, contains(card.compactName));
      }
      expect(action.toString(), startsWith('Alice: '));
    });

    test(
      'serialized game state carries no card identities or private text',
      () {
        final gameState = buildGameState(multiplayer: true);

        expect(gameState.drawFromDeck(), isTrue);
        final drawnCards = newlyDrawnCards(gameState.players[0]);

        final serialized = FirebaseService.gameStateToMapForTesting(gameState);
        final actions = (serialized['recentActions'] as List<dynamic>)
            .cast<Map<String, dynamic>>();

        expect(actions, isNotEmpty);
        for (final action in actions) {
          expect(action.containsKey('privateMessage'), isFalse);
          final message = action['message'] as String;
          for (final card in drawnCards) {
            expect(
              message.contains(card.compactName),
              isFalse,
              reason: 'synced log leaked ${card.compactName}',
            );
          }
        }
      },
    );

    test('a remote client restoring the state sees no card details', () {
      final gameState = buildGameState(multiplayer: true);
      expect(gameState.drawFromDeck(), isTrue);
      final drawnCards = newlyDrawnCards(gameState.players[0]);

      final restored = FirebaseService.gameStateFromMapForTesting(
        FirebaseService.gameStateToMapForTesting(gameState),
      );

      final action = restored.recentActions.last;
      expect(action.privateMessage, isNull);
      expect(action.displayMessage, '🎴 drew 2 cards from deck');
      for (final card in drawnCards) {
        expect(action.displayMessage.contains(card.compactName), isFalse);
      }
    });

    test('solo play still shows the human their draw and hides the bot\'s', () {
      final gameState = buildGameState(
        multiplayer: false,
        secondPlayerType: PlayerType.bot,
      );

      expect(gameState.drawFromDeck(), isTrue);
      final humanAction = gameState.recentActions.last;
      final humanCards = newlyDrawnCards(gameState.players[0]);
      for (final card in humanCards) {
        expect(humanAction.displayMessage, contains(card.compactName));
      }

      gameState.nextPlayer();
      expect(gameState.drawFromDeck(), isTrue);
      final botAction = gameState.recentActions.last;
      final botCards = newlyDrawnCards(gameState.players[1]);

      expect(botAction.playerName, 'Bob');
      expect(botAction.privateMessage, isNull);
      for (final card in botCards) {
        expect(botAction.displayMessage.contains(card.compactName), isFalse);
      }
    });
  });

  group('Cards taken from the discard pile', () {
    test('shared message records only the count, never the cards', () {
      final gameState = buildGameState(multiplayer: true);
      final alice = gameState.players[0];

      gameState.discardPile.addAll(const [
        PlayingCard(suit: Suit.clubs, rank: CardRank.four),
        PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
        PlayingCard(suit: Suit.spades, rank: CardRank.king),
      ]);
      alice.dealHand(const [
        PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
      ]);
      alice.hasPlayedDown = true;

      expect(gameState.unlockDiscard(), isTrue);

      final pickupMessages = serializedMessages(
        gameState,
      ).where((message) => message.contains('more cards from discard pile'));
      expect(pickupMessages, isNotEmpty);
      for (final message in pickupMessages) {
        expect(message.contains('9 ♥'), isFalse);
        expect(message.contains('4 ♣'), isFalse);
      }
    });
  });

  group('Local solo save keeps the human their own card details', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('reloaded solo game still names the cards the human drew', () async {
      final gameState = buildGameState(
        multiplayer: false,
        secondPlayerType: PlayerType.bot,
      );

      expect(gameState.drawFromDeck(), isTrue);
      final drawnCards = newlyDrawnCards(gameState.players[0]);
      expect(drawnCards, hasLength(2));

      await GameSaveService.saveGame(gameState, 4242);
      final saved = await GameSaveService.loadGame();
      expect(saved, isNotNull);

      final restored = GameSaveService.restoreGameController(saved!);
      expect(restored, isNotNull);

      final restoredAction = restored!.gameState.recentActions.last;
      expect(restoredAction.playerName, 'Alice');
      for (final card in drawnCards) {
        expect(
          restoredAction.displayMessage,
          contains(card.compactName),
          reason: 'reloaded solo log hid ${card.compactName} from its owner',
        );
      }
    });

    test('reloaded solo game still hides the bot\'s draw', () async {
      final gameState = buildGameState(
        multiplayer: false,
        secondPlayerType: PlayerType.bot,
      );

      gameState.nextPlayer();
      expect(gameState.drawFromDeck(), isTrue);
      final botCards = newlyDrawnCards(gameState.players[1]);

      await GameSaveService.saveGame(gameState, 4242);
      final restored = GameSaveService.restoreGameController(
        (await GameSaveService.loadGame())!,
      );

      final restoredAction = restored!.gameState.recentActions.last;
      expect(restoredAction.playerName, 'Bob');
      expect(restoredAction.privateMessage, isNull);
      for (final card in botCards) {
        expect(
          restoredAction.displayMessage.contains(card.compactName),
          isFalse,
        );
      }
    });

    test(
      'the same draw is detailed in the local save and bare in the synced doc',
      () async {
        final gameState = buildGameState(multiplayer: true);

        expect(gameState.drawFromDeck(), isTrue);
        final drawnCards = newlyDrawnCards(gameState.players[0]);

        await GameSaveService.saveGame(gameState, 4242);
        final localSave = (await GameSaveService.loadGame())!;
        final localActions = (localSave['recentActions'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        final localDraw = localActions.last;
        for (final card in drawnCards) {
          expect(localDraw['privateMessage'], contains(card.compactName));
        }

        final synced = FirebaseService.gameStateToMapForTesting(gameState);
        final syncedActions = (synced['recentActions'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        expect(syncedActions, isNotEmpty);
        for (final action in syncedActions) {
          expect(action.containsKey('privateMessage'), isFalse);
          for (final card in drawnCards) {
            expect(
              (action['message'] as String).contains(card.compactName),
              isFalse,
              reason: 'synced log leaked ${card.compactName}',
            );
          }
        }
      },
    );
  });

  group('Message sanitizing', () {
    test('strips card lists from emoji-prefixed draw messages', () {
      final gameState = buildGameState(
        multiplayer: false,
        secondPlayerType: PlayerType.bot,
      );
      gameState.currentPlayerIndex = 1; // Bot

      gameState.logAction('🎯 drew: K ♥, Q ♠');

      expect(gameState.recentActions.last.message, '🎯 drew');
    });

    test('leaves messages without the draw marker untouched', () {
      final gameState = buildGameState(
        multiplayer: false,
        secondPlayerType: PlayerType.bot,
      );
      gameState.currentPlayerIndex = 1; // Bot

      // Deliberately not a public action, so the sanitizer really does run on
      // this message and still finds nothing to strip.
      gameState.logAction('🤔 thought about it for a while');

      expect(
        gameState.recentActions.last.message,
        '🤔 thought about it for a while',
      );
      expect(
        GameState.sanitizeLogMessage('🤔 thought about it for a while'),
        '🤔 thought about it for a while',
      );
    });

    test('trims the card list but keeps the rest of the message', () {
      expect(GameState.sanitizeLogMessage('🎯 drew: K ♥, Q ♠'), '🎯 drew');
      expect(GameState.sanitizeLogMessage('Alice drew: K ♥'), 'Alice drew');
      expect(
        GameState.sanitizeLogMessage(
          'took 2 more cards from discard pile: 9 ♥, 4 ♣',
        ),
        'took 2 more cards from discard pile',
      );
    });
  });

  group('Inbound messages from the network', () {
    test('a leaky message written by an old client is sanitized on read', () {
      final gameState = buildGameState(multiplayer: true);
      expect(gameState.drawFromDeck(), isTrue);
      final drawnCards = newlyDrawnCards(gameState.players[0]);

      // Simulate a client that predates the privacy rules writing the card
      // list straight into the shared document.
      final document = FirebaseService.gameStateToMapForTesting(gameState);
      final actions = (document['recentActions'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final leakyText =
          '🎯 drew: ${drawnCards.map((card) => card.compactName).join(', ')}';
      actions.last['message'] = leakyText;

      final restored = FirebaseService.gameStateFromMapForTesting(document);

      final received = restored.recentActions.last;
      expect(received.message, '🎯 drew');
      for (final card in drawnCards) {
        expect(
          received.displayMessage.contains(card.compactName),
          isFalse,
          reason: 'inbound log leaked ${card.compactName}',
        );
      }
    });

    test(
      'a leaky discard-pickup message from an old client is sanitized on read',
      () {
        final gameState = buildGameState(multiplayer: true);
        expect(gameState.drawFromDeck(), isTrue);

        final document = FirebaseService.gameStateToMapForTesting(gameState);
        final actions = (document['recentActions'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        const leakyText = 'took 2 more cards from discard pile: 9 ♥, 4 ♣';
        actions.last['message'] = leakyText;

        final restored = FirebaseService.gameStateFromMapForTesting(document);

        final received = restored.recentActions.last;
        expect(received.message, 'took 2 more cards from discard pile');
        expect(received.displayMessage.contains('9 ♥'), isFalse);
        expect(received.displayMessage.contains('4 ♣'), isFalse);
      },
    );
  });
}
