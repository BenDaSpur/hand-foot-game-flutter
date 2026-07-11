import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/game/enhanced_multiplayer_controller.dart';
import 'enhanced_multiplayer_controller_test.dart'; // For TestMockNetworkAdapter

void main() {
  group('Multiplayer Game State Synchronization Tests', () {
    late TestMockNetworkAdapter mockAdapter;
    late EnhancedMultiplayerController? controller;

    setUp(() {
      mockAdapter = TestMockNetworkAdapter();
    });

    tearDown(() {
      controller?.dispose();
    });

    test(
      'FIX: Everyone had same cards - should sync unique player cards',
      () async {
        mockAdapter.mockUserId = 'player1';
        mockAdapter.mockGameId = 'TEST123';

        controller = await EnhancedMultiplayerController.createGame(
          hostPlayerName: 'Player1',
          maxPlayers: 3,
          networkAdapter: mockAdapter,
        );

        // BEFORE THE FIX: Local controller only had 1 player (the host)
        expect(controller!.gameState.players.length, 1);
        expect(controller!.gameState.players[0].id, 'player1');

        // Simulate Firebase creating proper server game state with all players
        final player1 = Player(
          id: 'player1',
          name: 'Player1',
          type: PlayerType.human,
        );
        final player2 = Player(
          id: 'player2',
          name: 'Player2',
          type: PlayerType.human,
        );
        final player3 = Player(
          id: 'player3',
          name: 'Player3',
          type: PlayerType.human,
        );

        // Give each player UNIQUE cards (simulating proper dealing by Firebase)
        player1.hand.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        ]);
        player2.hand.addAll([
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.jack),
        ]);
        player3.hand.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
          const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
        ]);

        final serverGameState = GameState(
          players: [player1, player2, player3],
          deck: Deck(),
          phase: GamePhase.playing,
        );

        // THE CRITICAL FIX: initializeFromServerState now replaces entire game state
        await controller!.initializeFromServerState(serverGameState);

        // VERIFY: Now has all 3 players instead of just 1
        expect(controller!.gameState.players.length, 3);
        expect(controller!.gameState.players[0].id, 'player1');
        expect(controller!.gameState.players[1].id, 'player2');
        expect(controller!.gameState.players[2].id, 'player3');

        // VERIFY: Each player has different, unique cards
        final p1Hand = controller!.gameState.players[0].hand;
        final p2Hand = controller!.gameState.players[1].hand;
        final p3Hand = controller!.gameState.players[2].hand;

        expect(p1Hand[0].rank, CardRank.ace); // Player1: Ace♥
        expect(p2Hand[0].rank, CardRank.queen); // Player2: Queen♣
        expect(p3Hand[0].rank, CardRank.ten); // Player3: Ten♥

        // CRITICAL: Verify they don't all have the same cards
        expect(p1Hand, isNot(equals(p2Hand)));
        expect(p1Hand, isNot(equals(p3Hand)));
        expect(p2Hand, isNot(equals(p3Hand)));
      },
    );

    test(
      'FIX: Nobody could take actions - should enforce turn-based validation',
      () async {
        mockAdapter.mockUserId = 'player2';
        mockAdapter.mockGameId = 'TEST123';

        controller = await EnhancedMultiplayerController.createGame(
          hostPlayerName: 'Player2',
          maxPlayers: 2,
          networkAdapter: mockAdapter,
        );

        final player1 = Player(
          id: 'player1',
          name: 'Player1',
          type: PlayerType.human,
        );
        final player2 = Player(
          id: 'player2',
          name: 'Player2',
          type: PlayerType.human,
        );

        player1.hand.add(
          const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
        );
        player2.hand.add(
          const PlayingCard(suit: Suit.spades, rank: CardRank.five),
        );

        // Setup game state where it's player1's turn (NOT player2 who owns controller)
        final gameState = GameState(
          players: [player1, player2],
          deck: Deck.createHandAndFootDeck(2, seed: 12345),
          currentPlayerIndex: 0, // Player1's turn
          turnPhase: TurnPhase.draw,
          phase: GamePhase.playing,
        );

        await controller!.initializeFromServerState(gameState);

        // BEFORE THE FIX: Actions would be allowed without turn validation
        // AFTER THE FIX: Should strictly enforce turn-based validation

        expect(
          controller!.isMyTurn,
          false,
          reason: 'Should detect it is NOT player2 turn',
        );
        expect(
          controller!.canPerformAction('drawFromDeck'),
          false,
          reason: 'Should not allow actions when not your turn',
        );
        expect(
          controller!.getAvailableActions(),
          isEmpty,
          reason: 'Should have no available actions when not your turn',
        );
        expect(
          controller!.drawFromDeck(),
          false,
          reason: 'Should reject draw action when not your turn',
        );

        // Now change to player2's turn
        gameState.currentPlayerIndex = 1;
        await controller!.initializeFromServerState(gameState);

        // NOW actions should be allowed
        expect(
          controller!.isMyTurn,
          true,
          reason: 'Should detect it IS player2 turn',
        );
        expect(
          controller!.canPerformAction('drawFromDeck'),
          true,
          reason: 'Should allow actions when it is your turn',
        );
        expect(
          controller!.getAvailableActions(),
          isNotEmpty,
          reason: 'Should have available actions when it is your turn',
        );
        expect(
          controller!.drawFromDeck(),
          true,
          reason: 'Should allow draw action when it is your turn',
        );
      },
    );

    test('should sync all moves to Firebase for other players', () async {
      mockAdapter.mockUserId = 'current-player';
      mockAdapter.mockGameId = 'TEST123';

      controller = await EnhancedMultiplayerController.createGame(
        hostPlayerName: 'CurrentPlayer',
        maxPlayers: 2,
        networkAdapter: mockAdapter,
      );

      final currentPlayer = Player(
        id: 'current-player',
        name: 'CurrentPlayer',
        type: PlayerType.human,
      );
      final otherPlayer = Player(
        id: 'other-player',
        name: 'OtherPlayer',
        type: PlayerType.human,
      );

      currentPlayer.hand.add(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.six),
      );

      final gameState = GameState(
        players: [currentPlayer, otherPlayer],
        deck: Deck.createHandAndFootDeck(2, seed: 54321),
        currentPlayerIndex: 0, // Current player's turn
        turnPhase: TurnPhase.meld, // Ready to discard
        phase: GamePhase.playing,
      );
      gameState.hasDrawnFromDeck = true; // Already drew
      gameState.hasMelded = true; // Already melded

      await controller!.initializeFromServerState(gameState);
      mockAdapter.syncCalls = 0; // Reset sync counter

      // VERIFY: Discard action syncs to Firebase
      final discardSuccess = controller!.discardCard(currentPlayer.hand.first);
      expect(discardSuccess, true);
      expect(
        mockAdapter.syncCalls,
        1,
        reason: 'Discard should trigger Firebase sync',
      );

      // VERIFY: Turn advanced automatically after discard
      expect(controller!.gameState.currentPlayerIndex, 1);
      expect(
        controller!.isMyTurn,
        false,
        reason: 'Should no longer be current player turn after discard',
      );
    });

    test(
      'should handle complete multiplayer game state from Firebase',
      () async {
        mockAdapter.mockUserId = 'player-b';
        mockAdapter.mockGameId = 'FULL-GAME';

        controller = await EnhancedMultiplayerController.createGame(
          hostPlayerName: 'PlayerB',
          maxPlayers: 2,
          networkAdapter: mockAdapter,
        );

        // Create comprehensive server game state like Firebase would generate
        final playerA = Player(
          id: 'player-a',
          name: 'PlayerA',
          type: PlayerType.human,
        );
        final playerB = Player(
          id: 'player-b',
          name: 'PlayerB',
          type: PlayerType.human,
        );

        // Give players comprehensive game state
        playerA.hand.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
        ]);
        playerA.foot.addAll([
          const PlayingCard(suit: Suit.clubs, rank: CardRank.jack),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ten),
        ]);
        playerA.hasPlayedDown = true;
        playerA.hasPickedUpFoot = true;

        playerB.hand.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.eight),
        ]);

        final serverGameState = GameState(
          players: [playerA, playerB],
          deck: Deck.createHandAndFootDeck(2, seed: 77777),
          currentPlayerIndex: 1, // PlayerB's turn
          turnPhase: TurnPhase.meld,
          phase: GamePhase.playing,
          round: 3,
          discardPile: [
            const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
          ],
        );
        serverGameState.hasDrawnFromDeck = true;

        await controller!.initializeFromServerState(serverGameState);

        // VERIFY: All aspects of game state are properly synchronized
        expect(controller!.gameState.players.length, 2);
        expect(controller!.gameState.currentPlayerIndex, 1);
        expect(controller!.gameState.turnPhase, TurnPhase.meld);
        expect(controller!.gameState.phase, GamePhase.playing);
        expect(controller!.gameState.round, 3);
        expect(controller!.gameState.hasDrawnFromDeck, true);
        expect(controller!.gameState.discardPile.length, 1);

        // VERIFY: Player-specific state is preserved
        expect(controller!.gameState.players[0].hasPlayedDown, true);
        expect(controller!.gameState.players[0].hasPickedUpFoot, true);
        expect(controller!.gameState.players[1].hasPlayedDown, false);

        // VERIFY: Turn detection works
        expect(
          controller!.isMyTurn,
          true,
          reason: 'Should detect it is PlayerB turn',
        );
        expect(controller!.getCurrentUserPlayer()!.name, 'PlayerB');
      },
    );

    test('FIX: deck syncs on incremental game state updates', () async {
      mockAdapter.mockUserId = 'player1';
      mockAdapter.mockGameId = 'DECK-SYNC';

      controller = await EnhancedMultiplayerController.createGame(
        hostPlayerName: 'Player1',
        maxPlayers: 2,
        networkAdapter: mockAdapter,
      );

      final initialDeck = Deck.createHandAndFootDeck(2, seed: 12345);
      final initialState = GameState(
        players: [
          Player(id: 'player1', name: 'Player1', type: PlayerType.human),
          Player(id: 'player2', name: 'Player2', type: PlayerType.human),
        ],
        deck: initialDeck,
        phase: GamePhase.playing,
        turnPhase: TurnPhase.draw,
      );

      await controller!.initializeFromServerState(initialState);
      final initialDeckSize = controller!.gameState.deck.size;
      expect(initialDeckSize, greaterThan(0));

      final updatedDeck = Deck.createHandAndFootDeck(2, seed: 12345);
      updatedDeck.drawCard();
      updatedDeck.drawCard();

      final updatedState = GameState(
        players: initialState.players,
        deck: updatedDeck,
        phase: GamePhase.playing,
        turnPhase: TurnPhase.meld,
        currentPlayerIndex: 1,
      );
      updatedState.hasDrawnFromDeck = true;

      mockAdapter.simulateGameStateUpdate(updatedState);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller!.gameState.deck.size, initialDeckSize - 2);
      expect(controller!.gameState.turnPhase, TurnPhase.meld);
      expect(controller!.gameState.currentPlayerIndex, 1);
    });
  });
}
