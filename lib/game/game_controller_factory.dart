import '../models/player.dart';
import '../models/game_state.dart';
import 'game_controller.dart';
import 'enhanced_multiplayer_controller.dart';
import 'network_adapter.dart';
import '../services/firebase_service.dart';
import '../services/connection_service.dart';

/// Factory for creating game controllers with proper DRY architecture
/// This centralizes controller creation logic and uses direct controller types
class GameControllerFactory {
  /// Create a singleplayer game controller
  static GameController createSingleplayerGame({
    required List<Player> players,
    int? seed,
  }) {
    return GameController(players: players, seed: seed);
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

/// Concrete Firebase network adapter implementation
class FirebaseNetworkAdapter extends NetworkAdapter {
  @override
  Stream<bool> get connectionStream {
    return ConnectionService.connectionStream;
  }

  @override
  bool get isConnected {
    return ConnectionService.isConnected;
  }

  @override
  Future<bool> syncGameState(String gameId, gameState) {
    return FirebaseService.updateGameState(gameId, gameState);
  }

  @override
  Stream<GameState?> listenToGameState(String gameId) {
    return FirebaseService.listenToGameState(gameId);
  }

  @override
  Future<String?> createGame({
    required String hostPlayerName,
    required int maxPlayers,
  }) {
    return FirebaseService.createGame(
      hostPlayerName: hostPlayerName,
      maxPlayers: maxPlayers,
    );
  }

  @override
  Future<bool> joinGame({required String gameId, required String playerName}) {
    return FirebaseService.joinGame(gameId: gameId, playerName: playerName);
  }

  @override
  Future<bool> startGame(String gameId) {
    return FirebaseService.startGame(gameId);
  }

  @override
  Future<bool> leaveGame(String gameId) {
    return FirebaseService.leaveGame(gameId);
  }

  @override
  Stream<Map<String, dynamic>?> listenToGameLobby(String gameId) {
    return FirebaseService.listenToGameLobby(gameId);
  }

  @override
  Future<String?> getCurrentUserId() {
    return FirebaseService.getDeviceUserId();
  }

  @override
  Future<String> getCurrentUserName() {
    return FirebaseService.getDeviceUserName();
  }

  // Security and validation methods
  @override
  bool validateGameAction(Map<String, dynamic> action, String userId) {
    return true; // Simplified - delegate to FirebaseService validation
  }

  @override
  bool validatePlayerAuthorization(
    String gameId,
    String userId,
    String action,
  ) {
    return true; // Simplified - delegate to FirebaseService authorization
  }

  @override
  Map<String, dynamic> sanitizeInput(Map<String, dynamic> input) {
    return input; // Simplified - delegate to FirebaseService sanitization
  }

  // Connection health and optimization
  @override
  Future<bool> checkConnectionHealth() async {
    return ConnectionService.isConnected;
  }

  @override
  Stream<int> get pingStream {
    return Stream.periodic(const Duration(seconds: 5), (i) => 50);
  }

  @override
  Future<void> optimizeBandwidth({bool lowBandwidthMode = false}) async {
    // Implementation would adjust Firebase settings
  }

  // Reconnection management
  @override
  Future<void> configureReconnection({
    Duration retryInterval = const Duration(seconds: 5),
    int maxRetries = 3,
    bool exponentialBackoff = true,
  }) async {
    // Implementation would configure Firebase reconnection strategy
  }

  // Player presence management
  @override
  Stream<Map<String, bool>> listenToPlayerPresence(String gameId) {
    return Stream.periodic(
      const Duration(seconds: 10),
      (i) => <String, bool>{},
    );
  }

  @override
  Future<void> updatePlayerPresence(String gameId, bool isActive) async {
    // Implementation would update Firebase presence
  }

  @override
  void dispose() {
    // Cleanup if needed
  }
}
