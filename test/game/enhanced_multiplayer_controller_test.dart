import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hand_foot_game_flutter/game/enhanced_multiplayer_controller.dart';
import 'package:hand_foot_game_flutter/game/network_adapter.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/multiplayer_lifecycle.dart';

void main() {
  group('EnhancedMultiplayerController Tests', () {
    late TestMockNetworkAdapter mockAdapter;
    late EnhancedMultiplayerController? controller;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
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

    group('Discard Pile Unlock', () {
      setUp(() async {
        mockAdapter._mockUserId = 'test-user';
        mockAdapter._mockGameId = 'TEST123';

        controller = await EnhancedMultiplayerController.createGame(
          hostPlayerName: 'TestHost',
          maxPlayers: 4,
          networkAdapter: mockAdapter,
        );
      });

      /// Puts the local player in a draw phase where taking the discard pile
      /// is legal: they have played down and hold two matching naturals.
      void setUpUnlockableDiscardPile() {
        final gameState = controller!.gameState;
        gameState.currentPlayerIndex = 0;
        gameState.turnPhase = TurnPhase.draw;
        gameState.hasDrawnFromDeck = false;
        gameState.discardPile
          ..clear()
          ..add(const PlayingCard(suit: Suit.spades, rank: CardRank.king));

        final player = gameState.currentPlayer;
        player.dealHand(const [
          PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
        ]);
        player.hasPlayedDown = true;
      }

      test('offers unlockDiscardPile during the draw phase', () {
        setUpUnlockableDiscardPile();

        expect(controller!.canUnlockDiscard(), isTrue);
        expect(
          controller!.getAvailableActions(),
          contains('unlockDiscardPile'),
        );
        expect(controller!.canPerformAction('unlockDiscardPile'), isTrue);
      });

      test('actually performs the unlock instead of silently failing', () {
        setUpUnlockableDiscardPile();
        final player = controller!.gameState.currentPlayer;

        expect(controller!.unlockDiscardPile(), isTrue);

        expect(controller!.gameState.discardPile, isEmpty);
        expect(player.melds, hasLength(1));
        expect(player.melds.first.rank, CardRank.king);
        expect(mockAdapter.syncCalls, equals(1));
      });

      test('is unavailable once the player has drawn from the deck', () {
        setUpUnlockableDiscardPile();
        controller!.gameState.hasDrawnFromDeck = true;
        controller!.gameState.turnPhase = TurnPhase.meld;

        expect(controller!.canUnlockDiscard(), isFalse);
        expect(
          controller!.getAvailableActions(),
          isNot(contains('unlockDiscardPile')),
        );
        expect(controller!.unlockDiscardPile(), isFalse);
      });

      test('is unavailable when it is not the local player\'s turn', () {
        setUpUnlockableDiscardPile();
        controller!.gameState.players.add(
          Player(id: 'other-user', name: 'Other', type: PlayerType.human),
        );
        controller!.gameState.currentPlayerIndex = 1;

        expect(controller!.getAvailableActions(), isEmpty);
        expect(controller!.unlockDiscardPile(), isFalse);
      });

      test('cannot be taken twice in the same turn', () {
        final gameState = controller!.gameState;
        gameState.currentPlayerIndex = 0;
        gameState.turnPhase = TurnPhase.draw;
        gameState.hasDrawnFromDeck = false;

        // Taking the pile removes the top card plus five more, so the queen
        // sits seven deep and is left on top once the king pickup is done.
        gameState.discardPile
          ..clear()
          ..addAll(const [
            PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
            PlayingCard(suit: Suit.hearts, rank: CardRank.five),
            PlayingCard(suit: Suit.spades, rank: CardRank.six),
            PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
            PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
            PlayingCard(suit: Suit.spades, rank: CardRank.nine),
            PlayingCard(suit: Suit.spades, rank: CardRank.king),
          ]);

        final player = gameState.currentPlayer;
        player.dealHand(const [
          PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        ]);
        player.hasPlayedDown = true;

        expect(controller!.unlockDiscardPile(), isTrue);

        // The pile still has cards and the new top card matches two naturals
        // the player is holding, so only the once-per-turn rule stands in the
        // way of a second pickup.
        expect(gameState.discardPile, isNotEmpty);
        expect(gameState.topDiscard!.rank, CardRank.queen);
        expect(gameState.hasTakenDiscardThisTurn, isTrue);

        expect(controller!.canUnlockDiscard(), isFalse);
        expect(
          controller!.getAvailableActions(),
          isNot(contains('unlockDiscardPile')),
        );
        expect(controller!.unlockDiscardPile(), isFalse);
        expect(player.melds.map((meld) => meld.rank), [CardRank.king]);
      });

      test('the meld phase never offers taking the pile', () {
        setUpUnlockableDiscardPile();
        // Reach the meld phase the way an unlock does: without setting
        // hasDrawnFromDeck.
        controller!.gameState.turnPhase = TurnPhase.meld;
        controller!.gameState.hasTakenDiscardThisTurn = true;

        expect(
          controller!.getAvailableActions(),
          isNot(contains('unlockDiscardPile')),
        );
      });

      test('taking the pile again is allowed on a later turn', () {
        setUpUnlockableDiscardPile();

        expect(controller!.unlockDiscardPile(), isTrue);
        expect(controller!.gameState.hasTakenDiscardThisTurn, isTrue);

        controller!.gameState.players.add(
          Player(id: 'other-user', name: 'Other', type: PlayerType.human),
        );
        controller!.gameState.nextPlayer();
        controller!.gameState.nextPlayer();

        expect(controller!.gameState.hasTakenDiscardThisTurn, isFalse);
      });
    });

    group('Action Log Privacy', () {
      setUp(() async {
        mockAdapter._mockUserId = 'test-user';
        mockAdapter._mockGameId = 'TEST123';

        controller = await EnhancedMultiplayerController.createGame(
          hostPlayerName: 'TestHost',
          maxPlayers: 4,
          networkAdapter: mockAdapter,
        );
      });

      /// Builds the snapshot the server would hand back for [actions]: the
      /// shared document stores only `message`, so every private detail is
      /// stripped on the way through.
      GameState serverSnapshot(List<GameAction> actions) {
        final gameState = controller!.gameState;
        return GameState(
          players: List.of(gameState.players),
          deck: Deck.fromCards(gameState.deck.cards),
          discardPile: List.of(gameState.discardPile),
          recentActions: actions
              .map(
                (action) => GameAction.withTimestamp(
                  message: action.message,
                  playerName: action.playerName,
                  timestamp: action.timestamp,
                ),
              )
              .toList(),
          phase: GamePhase.playing,
          currentPlayerIndex: gameState.currentPlayerIndex,
          turnPhase: gameState.turnPhase,
        );
      }

      /// Delivers [state] the way Firestore does, through the adapter stream,
      /// so the controller takes its real `_updateLocalGameState` sync path.
      Future<void> deliverServerSnapshot(GameState state) async {
        // The controller ignores inbound snapshots while it is pushing its own
        // state, so let any in-flight sync drain first.
        await Future.delayed(const Duration(milliseconds: 60));
        mockAdapter.simulateGameStateUpdate(state);
        await Future.delayed(const Duration(milliseconds: 60));
      }

      /// Puts the controller past first-sync so later snapshots exercise the
      /// steady-state path rather than `initializeFromServerState`.
      Future<void> completeFirstSync() async {
        await deliverServerSnapshot(serverSnapshot(const []));
        expect(controller!.gameState.phase, GamePhase.playing);
      }

      test('server echo does not erase the local card detail', () async {
        await completeFirstSync();

        final gameState = controller!.gameState;
        gameState.currentPlayerIndex = 0;
        gameState.turnPhase = TurnPhase.draw;

        expect(controller!.drawFromDeck(), isTrue);
        final drawAction = gameState.recentActions.last;
        final localDetail = drawAction.privateMessage;
        expect(localDetail, isNotNull);

        // An opponent action only the server knows about proves the snapshot
        // really was applied rather than quietly ignored.
        final opponentAction = GameAction.withTimestamp(
          message: '🗑️ discarded 4 ♣',
          playerName: 'Other',
          timestamp: DateTime.now(),
        );
        await deliverServerSnapshot(
          serverSnapshot([drawAction, opponentAction]),
        );

        expect(controller!.gameState.recentActions, hasLength(2));
        final merged = controller!.gameState.recentActions.first;
        expect(merged.privateMessage, equals(localDetail));
        expect(merged.message, '🎴 drew 2 cards from deck');
      });

      test(
        'a stale snapshot before the echo does not lose the card detail',
        () async {
          await completeFirstSync();

          final gameState = controller!.gameState;
          gameState.currentPlayerIndex = 0;
          gameState.turnPhase = TurnPhase.draw;

          expect(controller!.drawFromDeck(), isTrue);
          final drawAction = gameState.recentActions.last;
          final localDetail = drawAction.privateMessage;
          expect(localDetail, isNotNull);

          // A snapshot written before our draw arrives first and replaces the
          // log wholesale, so no copy of the detail survives in the list.
          await deliverServerSnapshot(serverSnapshot(const []));
          expect(controller!.gameState.recentActions, isEmpty);

          // Our own echo finally lands, carrying only the shared text.
          await deliverServerSnapshot(serverSnapshot([drawAction]));

          final merged = controller!.gameState.recentActions.last;
          expect(
            merged.privateMessage,
            equals(localDetail),
            reason: 'the drawing player must still see their own cards',
          );
          expect(merged.displayMessage, equals(localDetail));
        },
      );

      test('the sync path switches privacy to the viewer id', () async {
        await completeFirstSync();

        final gameState = controller!.gameState;
        gameState.players.add(
          Player(id: 'other-user', name: 'Other', type: PlayerType.human),
        );
        gameState.currentPlayerIndex = 1;
        gameState.turnPhase = TurnPhase.draw;
        gameState.hasDrawnFromDeck = false;

        expect(gameState.drawFromDeck(), isTrue);

        // Under the singleplayer fallback this human player's draw would keep
        // its card list, so a null detail proves the viewer-id branch ran.
        final action = gameState.recentActions.last;
        expect(action.privateMessage, isNull);
        expect(action.displayMessage, '🎴 drew 2 cards from deck');
      });

      test('sync preserves final-turn-after-go-out fields', () async {
        await completeFirstSync();

        final gameState = controller!.gameState;
        gameState.players.add(
          Player(id: 'other-user', name: 'Other', type: PlayerType.human),
        );

        final remote = GameState(
          players: List.of(gameState.players),
          deck: Deck.fromCards(gameState.deck.cards),
          discardPile: List.of(gameState.discardPile),
          recentActions: const [],
          phase: GamePhase.playing,
          turnPhase: TurnPhase.meld,
          currentPlayerIndex: 1,
          finalTurnPhaseActive: true,
          playerWhoWentOutIndex: 0,
          playersAwaitingFinalTurn: {1},
        );

        await deliverServerSnapshot(remote);

        expect(controller!.gameState.finalTurnPhaseActive, isTrue);
        expect(controller!.gameState.playerWhoWentOutIndex, 0);
        expect(controller!.gameState.playersAwaitingFinalTurn, {1});
        expect(controller!.gameState.currentPlayerIndex, 1);
      });

      test(
        'stuck go-out snapshot recovers and syncs after _isUpdating clears',
        () async {
          await completeFirstSync();
          final syncCallsBefore = mockAdapter.syncCalls;

          final wentOut = Player(
            id: 'test-user',
            name: 'TestHost',
            type: PlayerType.human,
          );
          wentOut.hasPlayedDown = true;
          wentOut.hasPickedUpFoot = true;
          wentOut.melds.addAll([
            Meld.createMeld([
              const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
              const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
              const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
              const PlayingCard(suit: Suit.spades, rank: CardRank.king),
              const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
              const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
              const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
            ])!,
            Meld.createMeld([
              const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
              const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
              const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
              const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
              const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
              const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
              const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
            ])!,
          ]);

          final opponent = Player(
            id: 'other-user',
            name: 'Other',
            type: PlayerType.human,
          );
          opponent.hand.addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
          ]);

          // Legacy stuck document: empty winner, still "playing", no final-turn
          // fields. Recovery must sync only after _isUpdating is cleared.
          final stuckSnapshot = GameState(
            players: [wentOut, opponent],
            deck: Deck.fromCards(controller!.gameState.deck.cards),
            discardPile: List.of(controller!.gameState.discardPile),
            recentActions: const [],
            phase: GamePhase.playing,
            turnPhase: TurnPhase.draw,
            currentPlayerIndex: 0,
          );

          expect(wentOut.canGoOut, isTrue);

          await deliverServerSnapshot(stuckSnapshot);
          // Allow the post-finally recovery sync (queued network op) to finish.
          await Future.delayed(const Duration(milliseconds: 80));

          expect(controller!.gameState.phase, GamePhase.roundEnd);
          expect(mockAdapter.syncCalls, greaterThan(syncCallsBefore));
          expect(mockAdapter.lastSyncedGameState?.phase, GamePhase.roundEnd);
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

    group('End Game For Everyone', () {
      test('host should call network adapter endGameForEveryone', () async {
        mockAdapter._mockUserId = 'test-user';
        mockAdapter._mockGameId = 'TEST123';

        controller = await EnhancedMultiplayerController.createGame(
          hostPlayerName: 'TestHost',
          maxPlayers: 4,
          networkAdapter: mockAdapter,
        );

        final result = await controller!.endGameForEveryone(
          endReason: 'host_ended',
        );

        expect(result, isTrue);
        expect(mockAdapter.endGameForEveryoneCalled, isTrue);
        expect(mockAdapter.lastEndGameReason, 'host_ended');
      });

      test('non-host should not end game for everyone', () async {
        mockAdapter._mockUserId = 'guest-user';
        mockAdapter._mockJoinSuccess = true;

        // Join path marks isHost from FirebaseService.getGame which is null
        // offline, so force a host controller and verify guest path via a
        // second adapter-backed host check: create as host then flip by
        // using leave-only guest semantics through a fresh join controller.
        final hostAdapter = TestMockNetworkAdapter();
        hostAdapter.mockUserId = 'host-user';
        hostAdapter.mockGameId = 'HOST1';
        final hostController = await EnhancedMultiplayerController.createGame(
          hostPlayerName: 'Host',
          maxPlayers: 4,
          networkAdapter: hostAdapter,
        );
        expect(hostController, isNotNull);
        expect(hostController!.isHost, isTrue);

        // Directly verify non-host guard: createGame always sets isHost true.
        // Use leaveGame on a join controller when join succeeds without host.
        mockAdapter.mockUserId = 'guest-user';
        mockAdapter.mockJoinSuccess = true;
        final guestController = await EnhancedMultiplayerController.joinGame(
          gameId: 'HOST1',
          playerName: 'Guest',
          networkAdapter: mockAdapter,
        );

        // Without Firebase game doc, join still succeeds with adapter; isHost
        // is false when getGame returns null.
        if (guestController != null && !guestController.isHost) {
          final ended = await guestController.endGameForEveryone();
          expect(ended, isFalse);
          expect(mockAdapter.endGameForEveryoneCalled, isFalse);
          guestController.dispose();
        }

        hostController.dispose();
      });

      test(
        'lifecycle stream emits cancelled when lobby status cancelled',
        () async {
          mockAdapter._mockUserId = 'test-user';
          mockAdapter._mockGameId = 'TEST123';

          controller = await EnhancedMultiplayerController.createGame(
            hostPlayerName: 'TestHost',
            maxPlayers: 4,
            networkAdapter: mockAdapter,
          );

          final events = <MultiplayerLifecycleEvent>[];
          final sub = controller!.lifecycleStream.listen(events.add);

          mockAdapter.emitLobbyUpdate({
            'status': 'cancelled',
            'endReason': 'host_ended',
          });
          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(events, contains(MultiplayerLifecycleEvent.gameCancelled));
          await sub.cancel();
        },
      );

      test('lifecycle stream emits deleted when lobby doc is null', () async {
        mockAdapter._mockUserId = 'test-user';
        mockAdapter._mockGameId = 'TEST123';

        controller = await EnhancedMultiplayerController.createGame(
          hostPlayerName: 'TestHost',
          maxPlayers: 4,
          networkAdapter: mockAdapter,
        );

        final events = <MultiplayerLifecycleEvent>[];
        final sub = controller!.lifecycleStream.listen(events.add);

        mockAdapter.emitLobbyUpdate(null);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(events, contains(MultiplayerLifecycleEvent.gameDeleted));
        await sub.cancel();
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
  bool endGameForEveryoneCalled = false;
  String? lastEndGameReason;
  int syncCalls = 0;
  GameState? lastSyncedGameState;
  bool isDisposed = false;
  final StreamController<Map<String, dynamic>?> _testLobbyController =
      StreamController<Map<String, dynamic>?>.broadcast();

  // Public setters for easier testing
  set mockUserId(String? value) => _mockUserId = value;
  set mockGameId(String? value) => _mockGameId = value;
  set mockJoinSuccess(bool value) => _mockJoinSuccess = value;

  void emitLobbyUpdate(Map<String, dynamic>? data) {
    if (!_testLobbyController.isClosed) {
      _testLobbyController.add(data);
    }
  }

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
  Stream<Map<String, dynamic>?> listenToGameLobby(String gameId) {
    return _testLobbyController.stream;
  }

  @override
  Future<bool> syncGameState(String gameId, GameState gameState) async {
    syncCalls++;
    lastSyncedGameState = gameState;
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
  Future<bool> endGameForEveryone(
    String gameId, {
    String endReason = 'host_ended',
  }) async {
    endGameForEveryoneCalled = true;
    lastEndGameReason = endReason;
    emitLobbyUpdate({'status': 'cancelled', 'endReason': endReason});
    return true;
  }

  @override
  void dispose() {
    if (isDisposed) {
      return;
    }
    isDisposed = true;
    if (!_testLobbyController.isClosed) {
      _testLobbyController.close();
    }
    super.dispose();
  }
}
