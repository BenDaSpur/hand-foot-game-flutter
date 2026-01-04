import '../models/player.dart';
import 'game_controller.dart';
import 'enhanced_multiplayer_controller.dart';
import 'network_adapter.dart';

/// Factory for creating game controllers with proper DRY architecture
/// This centralizes controller creation logic and uses direct controller types
class GameControllerFactory {
  /// Create a singleplayer game controller
  static GameController createSingleplayerGame({
    required List<Player> players,
    int? seed,
    dynamic eventBus, // Optional event bus for event-driven architecture
  }) {
    return GameController(players: players, seed: seed, eventBus: eventBus);
  }

  /// Create a multiplayer game controller with Firebase backend
  static Future<EnhancedMultiplayerController?> createMultiplayerGame({
    required String hostPlayerName,
    required int maxPlayers,
  }) async {
    final networkAdapter = FirebaseNetworkAdapter();

    return await EnhancedMultiplayerController.createGame(
      hostPlayerName: hostPlayerName,
      maxPlayers: maxPlayers,
      networkAdapter: networkAdapter,
    );
  }

  /// Join a multiplayer game with Firebase backend
  static Future<EnhancedMultiplayerController?> joinMultiplayerGame({
    required String gameId,
    required String playerName,
  }) async {
    final networkAdapter = FirebaseNetworkAdapter();

    return await EnhancedMultiplayerController.joinGame(
      gameId: gameId,
      playerName: playerName,
      networkAdapter: networkAdapter,
    );
  }

  /// Create a test multiplayer game controller with mock backend
  static Future<EnhancedMultiplayerController?> createTestMultiplayerGame({
    required String hostPlayerName,
    required int maxPlayers,
  }) async {
    final networkAdapter = MockNetworkAdapter();

    return await EnhancedMultiplayerController.createGame(
      hostPlayerName: hostPlayerName,
      maxPlayers: maxPlayers,
      networkAdapter: networkAdapter,
    );
  }

  /// Join a test multiplayer game with mock backend
  static Future<EnhancedMultiplayerController?> joinTestMultiplayerGame({
    required String gameId,
    required String playerName,
  }) async {
    final networkAdapter = MockNetworkAdapter();

    return await EnhancedMultiplayerController.joinGame(
      gameId: gameId,
      playerName: playerName,
      networkAdapter: networkAdapter,
    );
  }
}
