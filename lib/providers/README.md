# Riverpod Providers

This directory contains Riverpod providers for state management in the Hand & Foot game.

## Core Providers

### `game_providers.dart`

- `gameControllerProvider` - Singleplayer game controller StateNotifier
- `multiplayerControllerProvider` - Multiplayer game controller StateNotifier
- `gameInterfaceProvider` - Unified interface provider (singleplayer or multiplayer)
- `botAIProvider` - Bot AI instance provider
- `gameEventBusProvider` - Global event bus provider
- `gameEventListenerProvider` - Auto-disposing event listener service

### `computed_providers.dart`

Computed providers that derive state from the game controller:

- `currentGameStateProvider` - Current game state
- `currentPlayerProvider` - Current player
- `leaderboardProvider` - Players sorted by score
- `gameStatusProvider` - Game status summary map
- `isHumanTurnProvider` - Whether it's a human player's turn
- `isBotTurnProvider` - Whether it's a bot player's turn
- `isGameEndedProvider` - Whether the game has ended
- `isRoundEndedProvider` - Whether the round has ended
- `gameWinnerProvider` - Game winner (if any)
- `humanPlayerProvider` - Human player instance
- `botPlayersProvider` - List of bot players
- `playDownRequirementProvider` - Play-down requirement for current round

## Usage Example

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(currentGameStateProvider);
    final isHumanTurn = ref.watch(isHumanTurnProvider);
    final leaderboard = ref.watch(leaderboardProvider);

    // Widget automatically rebuilds when any watched provider changes
    return Text('Current player: ${gameState?.currentPlayer.name}');
  }
}
```

## Event-Driven Architecture

The providers work seamlessly with the event bus system. When game events are published, providers automatically update, triggering reactive UI rebuilds.
