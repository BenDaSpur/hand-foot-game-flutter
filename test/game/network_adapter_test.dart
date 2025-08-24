import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/game/network_adapter.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';

void main() {
  group('NetworkAdapter Tests', () {
    group('MockNetworkAdapter Tests', () {
      late MockNetworkAdapter adapter;

      setUp(() {
        adapter = MockNetworkAdapter();
      });

      tearDown(() {
        adapter.dispose();
      });

      group('Connection Management', () {
        test('should start with connected state', () {
          expect(adapter.isConnected, isTrue);
        });

        test('should provide connection stream', () {
          expect(adapter.connectionStream, isA<Stream<bool>>());
        });

        test('should handle disconnection simulation', () async {
          expect(adapter.isConnected, isTrue);

          adapter.simulateDisconnection();

          expect(adapter.isConnected, isFalse);
        });

        test('should handle reconnection simulation', () async {
          adapter.simulateDisconnection();
          expect(adapter.isConnected, isFalse);

          adapter.simulateReconnection();

          expect(adapter.isConnected, isTrue);
        });

        test('should emit connection changes on stream', () async {
          final connectionEvents = <bool>[];
          final subscription = adapter.connectionStream.listen(
            connectionEvents.add,
          );

          adapter.simulateDisconnection();
          await Future.delayed(const Duration(milliseconds: 10));

          adapter.simulateReconnection();
          await Future.delayed(const Duration(milliseconds: 10));

          await subscription.cancel();
          expect(connectionEvents, contains(false));
          expect(connectionEvents, contains(true));
        });
      });

      group('Game Management', () {
        test('should create game with valid parameters', () async {
          final gameId = await adapter.createGame(
            hostPlayerName: 'TestHost',
            maxPlayers: 4,
          );

          expect(gameId, isNotNull);
          expect(gameId, startsWith('MOCK'));
        });

        test('should fail to create game when disconnected', () async {
          adapter.simulateDisconnection();

          final gameId = await adapter.createGame(
            hostPlayerName: 'TestHost',
            maxPlayers: 4,
          );

          expect(gameId, isNull);
        });

        test('should join game successfully', () async {
          // First create a game
          await adapter.createGame(hostPlayerName: 'TestHost', maxPlayers: 4);

          final success = await adapter.joinGame(
            gameId: 'TEST123',
            playerName: 'TestPlayer',
          );

          expect(success, isTrue);
        });

        test('should fail to join game when disconnected', () async {
          adapter.simulateDisconnection();

          final success = await adapter.joinGame(
            gameId: 'TEST123',
            playerName: 'TestPlayer',
          );

          expect(success, isFalse);
        });

        test('should start game successfully', () async {
          final success = await adapter.startGame('TEST123');
          expect(success, isTrue);
        });
      });

      group('Game State Management', () {
        test('should sync game state when connected', () async {
          final players = [
            Player(id: '1', name: 'Player1', type: PlayerType.human),
            Player(id: '2', name: 'Player2', type: PlayerType.bot),
          ];
          final gameState = GameState(
            players: players,
            deck: Deck.createHandAndFootDeck(players.length),
          );

          final success = await adapter.syncGameState('TEST123', gameState);
          expect(success, isTrue);
        });

        test('should fail to sync when disconnected', () async {
          adapter.simulateDisconnection();

          final players = [
            Player(id: '1', name: 'Player1', type: PlayerType.human),
          ];
          final gameState = GameState(
            players: players,
            deck: Deck.createHandAndFootDeck(players.length),
          );

          final success = await adapter.syncGameState('TEST123', gameState);
          expect(success, isFalse);
        });

        test('should provide game state stream', () {
          expect(
            adapter.listenToGameState('TEST123'),
            isA<Stream<GameState?>>(),
          );
        });

        test('should provide lobby stream', () {
          expect(
            adapter.listenToGameLobby('TEST123'),
            isA<Stream<Map<String, dynamic>?>>(),
          );
        });
      });

      group('User Management', () {
        test('should provide user ID', () async {
          final userId = await adapter.getCurrentUserId();
          expect(userId, isNotNull);
          expect(userId, startsWith('mock-user-'));
        });

        test('should provide user name', () async {
          final userName = await adapter.getCurrentUserName();
          expect(userName, equals('Mock User'));
        });
      });

      group('Security and Validation', () {
        test('should validate game actions correctly', () {
          final validAction = {'type': 'drawFromDeck', 'playerId': 'user123'};

          expect(adapter.validateGameAction(validAction, 'user123'), isTrue);

          final invalidAction = {
            'type': 'drawFromDeck',
            // Missing playerId
          };

          expect(adapter.validateGameAction(invalidAction, 'user123'), isFalse);
        });

        test('should validate player authorization', () {
          expect(
            adapter.validatePlayerAuthorization(
              'game123',
              'user123',
              'drawFromDeck',
            ),
            isTrue,
          );
          expect(
            adapter.validatePlayerAuthorization('', 'user123', 'drawFromDeck'),
            isFalse,
          );
          expect(
            adapter.validatePlayerAuthorization('game123', '', 'drawFromDeck'),
            isFalse,
          );
          expect(
            adapter.validatePlayerAuthorization('game123', 'user123', ''),
            isFalse,
          );
        });

        test('should sanitize input correctly', () {
          final input = {
            'playerName': 'TestPlayer',
            'gameId': 'GAME123',
            'data': {'nested': 'value'},
          };

          final sanitized = adapter.sanitizeInput(input);
          expect(sanitized, isA<Map<String, dynamic>>());
          expect(sanitized['playerName'], equals('TestPlayer'));
          expect(sanitized['gameId'], equals('GAME123'));
        });
      });

      group('Connection Health and Optimization', () {
        test('should check connection health', () async {
          expect(await adapter.checkConnectionHealth(), isTrue);

          adapter.simulateDisconnection();
          expect(await adapter.checkConnectionHealth(), isFalse);
        });

        test('should provide ping stream', () {
          expect(adapter.pingStream, isA<Stream<int>>());
        });

        test('should handle bandwidth optimization', () async {
          // Should not throw
          await adapter.optimizeBandwidth(lowBandwidthMode: true);
        });

        test('should configure reconnection settings', () async {
          // Should not throw
          await adapter.configureReconnection(
            retryInterval: const Duration(seconds: 3),
            maxRetries: 5,
            exponentialBackoff: false,
          );
        });
      });

      group('Player Presence Management', () {
        test('should provide player presence stream', () {
          expect(
            adapter.listenToPlayerPresence('game123'),
            isA<Stream<Map<String, bool>>>(),
          );
        });

        test('should update player presence', () async {
          // Should not throw
          await adapter.updatePlayerPresence('game123', true);
        });

        test('should handle presence stream data', () async {
          final presenceEvents = <Map<String, bool>>[];
          final subscription = adapter
              .listenToPlayerPresence('game123')
              .listen(presenceEvents.add);

          // Wait longer than the 5-second period for the periodic stream
          await Future.delayed(const Duration(seconds: 6));
          await subscription.cancel();

          expect(presenceEvents, isNotEmpty);
          expect(presenceEvents.first, isA<Map<String, bool>>());
        });
      });
    });

    group('FirebaseNetworkAdapter Input Validation', () {
      late FirebaseNetworkAdapter adapter;

      setUp(() {
        adapter = FirebaseNetworkAdapter();
      });

      tearDown(() {
        adapter.dispose();
      });

      group('Game Action Validation', () {
        test('should validate required fields', () {
          final validAction = {'type': 'drawFromDeck', 'playerId': 'user123'};

          expect(adapter.validateGameAction(validAction, 'user123'), isTrue);
        });

        test('should reject actions missing required fields', () {
          final missingType = {'playerId': 'user123'};
          expect(adapter.validateGameAction(missingType, 'user123'), isFalse);

          final missingPlayerId = {'type': 'drawFromDeck'};
          expect(
            adapter.validateGameAction(missingPlayerId, 'user123'),
            isFalse,
          );
        });

        test('should reject actions with wrong player ID', () {
          final wrongPlayer = {'type': 'drawFromDeck', 'playerId': 'wrongUser'};

          expect(adapter.validateGameAction(wrongPlayer, 'user123'), isFalse);
        });

        test('should reject invalid action types', () {
          final invalidAction = {'type': 'hackTheGame', 'playerId': 'user123'};

          expect(adapter.validateGameAction(invalidAction, 'user123'), isFalse);
        });

        test('should validate action-specific requirements', () {
          final validMeld = {
            'type': 'createMeld',
            'playerId': 'user123',
            'cards': [
              {'rank': 'ace', 'suit': 'spades'},
            ],
          };
          expect(adapter.validateGameAction(validMeld, 'user123'), isTrue);

          final invalidMeld = {
            'type': 'createMeld',
            'playerId': 'user123',
            // Missing cards array
          };
          expect(adapter.validateGameAction(invalidMeld, 'user123'), isFalse);

          final validDiscard = {
            'type': 'discardCard',
            'playerId': 'user123',
            'card': {'rank': 'king', 'suit': 'hearts'},
          };
          expect(adapter.validateGameAction(validDiscard, 'user123'), isTrue);

          final invalidDiscard = {
            'type': 'discardCard',
            'playerId': 'user123',
            // Missing card
          };
          expect(
            adapter.validateGameAction(invalidDiscard, 'user123'),
            isFalse,
          );
        });
      });

      group('Input Sanitization', () {
        test('should sanitize string values', () {
          final input = {
            'playerName': 'Test<script>alert("xss")</script>Player',
            'message': 'Hello & "welcome" to the \'game\'!',
          };

          final sanitized = adapter.sanitizeInput(input);
          expect(sanitized['playerName'], equals('TestPlayer'));
          expect(sanitized['message'], equals('Hello  welcome to the game!'));
        });

        test('should remove dangerous keys', () {
          final input = {
            'playerName': 'TestPlayer',
            '_privateKey': 'secret',
            'adminAccess': 'true',
            'normalField': 'value',
          };

          final sanitized = adapter.sanitizeInput(input);
          expect(sanitized.containsKey('_privateKey'), isFalse);
          expect(sanitized.containsKey('adminAccess'), isFalse);
          expect(sanitized.containsKey('normalField'), isTrue);
        });

        test('should sanitize nested objects and arrays', () {
          final input = {
            'nested': {'playerName': 'Test<>Player', '_secret': 'hidden'},
            'array': ['normal', 'Test"Player', 'admin'],
          };

          final sanitized = adapter.sanitizeInput(input);
          final nestedSanitized = sanitized['nested'] as Map<String, dynamic>;
          expect(nestedSanitized['playerName'], equals('TestPlayer'));
          expect(nestedSanitized.containsKey('_secret'), isFalse);

          final arraySanitized = sanitized['array'] as List;
          expect(arraySanitized[1], equals('TestPlayer'));
        });
      });

      group('Player Authorization', () {
        test('should validate basic authorization parameters', () {
          expect(
            adapter.validatePlayerAuthorization(
              'game123',
              'user123',
              'drawFromDeck',
            ),
            isTrue,
          );
        });

        test('should reject empty parameters', () {
          expect(
            adapter.validatePlayerAuthorization('', 'user123', 'drawFromDeck'),
            isFalse,
          );
          expect(
            adapter.validatePlayerAuthorization('game123', '', 'drawFromDeck'),
            isFalse,
          );
          expect(
            adapter.validatePlayerAuthorization('game123', 'user123', ''),
            isFalse,
          );
        });

        test('should handle host-only actions', () {
          expect(
            adapter.validatePlayerAuthorization(
              'game123',
              'host123',
              'startGame',
            ),
            isTrue,
          );
          expect(
            adapter.validatePlayerAuthorization(
              'game123',
              'host123',
              'deleteGame',
            ),
            isTrue,
          );
        });
      });
    });
  });
}
