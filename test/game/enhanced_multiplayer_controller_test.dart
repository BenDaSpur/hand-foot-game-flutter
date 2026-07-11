import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/game/enhanced_multiplayer_controller.dart';
import 'package:hand_foot_game_flutter/game/network_adapter.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';

void main() {
  group('EnhancedMultiplayerController Tests', () {
    late TestMockNetworkAdapter mockAdapter;
    late EnhancedMultiplayerController? controller;

    setUp(() {
      mockAdapter = TestMockNetworkAdapter();
    });

    tearDown(() async {
      controller?.dispose();
      controller = null;
      mockAdapter.dispose();
    });

    group('Controller Creation', () {
      test('should create game controller successfully', () async {
        mockAdapter._mockUserId = 'test-user';
        mockAdapter._mockGameId = 'TEST123';

        controller = await EnhancedMultiplayerController.createGame(
          hostPlayerName: 'TestHost',
          maxPlayers: 4,
          networkAdapter: mockAdapter,
        );

        expect(controller, isNotNull);
        expect(controller!.gameId, equals('TEST123'));
        expect(controller!.currentUserId, equals('test-user'));
        expect(controller!.isHost, isTrue);
      });

      test('should join game successfully', () async {
        mockAdapter._mockUserId = 'test-user';
        mockAdapter._mockJoinSuccess = true;

        controller = await EnhancedMultiplayerController.joinGame(
          gameId: 'TEST123',
          playerName: 'TestPlayer',
          networkAdapter: mockAdapter,
        );

        expect(controller, isNotNull);
        expect(controller!.gameId, equals('TEST123'));
        expect(controller!.currentUserId, equals('test-user'));
        expect(controller!.isHost, isFalse);
      });

      test('should return null if user ID not available', () async {
        mockAdapter._mockUserId = null;

        controller = await EnhancedMultiplayerController.createGame(
          hostPlayerName: 'TestHost',
          maxPlayers: 4,
          networkAdapter: mockAdapter,
        );

        expect(controller, isNull);
      });

      test('should return null if game creation fails', () async {
        mockAdapter._mockUserId = 'test-user';
        mockAdapter._mockGameId = null;

        controller = await EnhancedMultiplayerController.createGame(
          hostPlayerName: 'TestHost',
          maxPlayers: 4,
          networkAdapter: mockAdapter,
        );

        expect(controller, isNull);
      });
    });

    group('Game Actions with Network Synchronization', () {
      setUp(() async {
        mockAdapter._mockUserId = 'test-user';
        mockAdapter._mockGameId = 'TEST123';

        controller = await EnhancedMultiplayerController.createGame(
          hostPlayerName: 'TestHost',
          maxPlayers: 4,
          networkAdapter: mockAdapter,
        );
      });

      test('should prevent actions from non-current users', () {
        // Add a second player to the game
        final secondPlayer = Player(
          id: 'other-user',
          name: 'OtherPlayer',
          type: PlayerType.human,
        );
        controller!.gameState.players.add(secondPlayer);

        // Set current player to the second player (index 1)
        controller!.gameState.currentPlayerIndex = 1;

        final result = controller!.drawFromDeck();
        expect(result, isFalse);
        expect(mockAdapter.syncCalls, equals(0));
      });

      test('should sync game state after successful actions', () {
        // Ensure current user is the active player
        controller!.gameState.currentPlayerIndex = 0;
        controller!.gameState.turnPhase = TurnPhase.draw;

        final result = controller!.drawFromDeck();
        expect(result, isTrue);
        expect(mockAdapter.syncCalls, equals(1));
      });

      test(
        'should queue multiple network operations to prevent race conditions',
        () async {
          controller!.gameState.currentPlayerIndex = 0;
          controller!.gameState.turnPhase = TurnPhase.draw;

          // Simulate multiple concurrent operations
          final futures = <Future<bool>>[];
          for (int i = 0; i < 5; i++) {
            futures.add(Future(() => controller!.drawFromDeck()));
          }

          await Future.wait(futures);

          // Verify operations were queued (sync calls should be limited)
          expect(mockAdapter.syncCalls, lessThan(5));
        },
      );
    });

    group('Connection Management', () {
      setUp(() async {
        mockAdapter._mockUserId = 'test-user';
        mockAdapter._mockGameId = 'TEST123';

        controller = await EnhancedMultiplayerController.createGame(
          hostPlayerName: 'TestHost',
          maxPlayers: 4,
          networkAdapter: mockAdapter,
        );
      });

      test('should handle connection loss gracefully', () async {
        expect(controller!.isOnline, isTrue);

        mockAdapter.simulateDisconnection();
        await Future.delayed(const Duration(milliseconds: 100));

        expect(controller!.isOnline, isFalse);
      });

      test('should handle connection restoration', () async {
        mockAdapter.simulateDisconnection();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(controller!.isOnline, isFalse);

        mockAdapter.simulateReconnection();
        await Future.delayed(const Duration(milliseconds: 100));

        expect(controller!.isOnline, isTrue);
      });

      test('should provide connection stream', () {
        expect(controller!.connectionStream, isA<Stream<bool>>());
      });

      test('should provide game state stream', () {
        expect(controller!.gameStateStream, isA<Stream<GameState>>());
      });
    });

    group('Game State Delegation', () {
      setUp(() async {
        mockAdapter._mockUserId = 'test-user';
        mockAdapter._mockGameId = 'TEST123';

        controller = await EnhancedMultiplayerController.createGame(
          hostPlayerName: 'TestHost',
          maxPlayers: 4,
          networkAdapter: mockAdapter,
        );
      });

      test('should delegate read-only operations correctly', () {
        expect(controller!.isGameOver, isA<bool>());
        expect(controller!.winner, isA<Player?>());
        expect(controller!.currentRound, isA<int>());
        expect(controller!.leaderboard, isA<List<Player>>());
        expect(controller!.getGameStatus(), isA<Map<String, dynamic>>());
      });

      test('should handle multiplayer-specific properties', () {
        expect(controller!.isHost, isTrue);
        expect(controller!.userId, equals('test-user'));
        expect(controller!.isOnline, isTrue);
      });
    });

    group('Leave Game', () {
      test('should call network adapter leaveGame', () async {
        mockAdapter._mockUserId = 'test-user';
        mockAdapter._mockGameId = 'TEST123';

        controller = await EnhancedMultiplayerController.createGame(
          hostPlayerName: 'TestHost',
          maxPlayers: 4,
          networkAdapter: mockAdapter,
        );

        final result = await controller!.leaveGame();

        expect(result, isTrue);
        expect(mockAdapter.leaveGameCalled, isTrue);
      });
    });

    group('Disposal', () {
      test('should clean up resources properly', () async {
        mockAdapter._mockUserId = 'test-user';
        mockAdapter._mockGameId = 'TEST123';

        controller = await EnhancedMultiplayerController.createGame(
          hostPlayerName: 'TestHost',
          maxPlayers: 4,
          networkAdapter: mockAdapter,
        );

        expect(controller, isNotNull);

        controller!.dispose();

        // Verify network adapter was disposed
        expect(mockAdapter.isDisposed, isTrue);
      });
    });
  });
}

/// Enhanced MockNetworkAdapter for testing with additional test capabilities
class TestMockNetworkAdapter extends MockNetworkAdapter {
  String? _mockUserId;
  String? _mockGameId;
  bool _mockJoinSuccess = false;
  bool leaveGameCalled = false;
  int syncCalls = 0;
  bool isDisposed = false;

  // Public setters for easier testing
  set mockUserId(String? value) => _mockUserId = value;
  set mockGameId(String? value) => _mockGameId = value;
  set mockJoinSuccess(bool value) => _mockJoinSuccess = value;

  @override
  Future<String?> getCurrentUserId() async => _mockUserId;

  @override
  Future<String?> createGame({
    required String hostPlayerName,
    required int maxPlayers,
  }) async => _mockGameId;

  @override
  Future<bool> joinGame({
    required String gameId,
    required String playerName,
  }) async => _mockJoinSuccess;

  @override
  Future<bool> syncGameState(String gameId, GameState gameState) async {
    syncCalls++;
    await Future.delayed(
      const Duration(milliseconds: 10),
    ); // Simulate network delay
    return true;
  }

  @override
  Future<bool> leaveGame(String gameId) async {
    leaveGameCalled = true;
    return true;
  }

  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }
}
