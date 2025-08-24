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
    // Validate required fields
    if (!action.containsKey('type') || !action.containsKey('playerId')) {
      return false;
    }

    // Ensure player authorization
    if (action['playerId'] != userId) {
      return false;
    }

    // Validate action type
    final validActions = {
      'drawFromDeck',
      'drawFromDiscard',
      'createMeld',
      'addToMeld',
      'discardCard',
      'unlockDiscard',
      'startGame',
      'leaveGame',
    };

    if (!validActions.contains(action['type'])) {
      return false;
    }

    // Additional validation based on action type
    switch (action['type']) {
      case 'createMeld':
      case 'addToMeld':
        return action.containsKey('cards') && action['cards'] is List;
      case 'discardCard':
        return action.containsKey('card') && action['card'] is Map;
      default:
        return true;
    }
  }

  @override
  bool validatePlayerAuthorization(
    String gameId,
    String userId,
    String action,
  ) {
    // Basic authorization - could be enhanced with role-based checks
    if (gameId.isEmpty || userId.isEmpty || action.isEmpty) {
      return false;
    }

    // Host-only actions
    final hostOnlyActions = {'startGame', 'deleteGame'};
    if (hostOnlyActions.contains(action)) {
      // Would need to check if user is host - simplified for now
      return true;
    }

    return true;
  }

  @override
  Map<String, dynamic> sanitizeInput(Map<String, dynamic> input) {
    final sanitized = <String, dynamic>{};

    for (final entry in input.entries) {
      final key = entry.key;
      final value = entry.value;

      // Remove potentially dangerous keys
      if (key.startsWith('_') || key.toLowerCase().contains('admin')) {
        continue;
      }

      // Sanitize string values
      if (value is String) {
        // Remove dangerous HTML elements and their content first
        String cleanValue = value
            .trim()
            .replaceAll(
              RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false),
              '',
            ) // Remove script tags and content
            .replaceAll(
              RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false),
              '',
            ) // Remove style tags and content
            .replaceAll(RegExp(r'<[^>]*>'), '') // Remove remaining HTML tags
            .replaceAll('<', '')
            .replaceAll('>', '')
            .replaceAll('"', '')
            .replaceAll("'", '')
            .replaceAll('&', '')
            .replaceAll('(', '')
            .replaceAll(')', '');
        sanitized[key] = cleanValue;
      } else if (value is Map<String, dynamic>) {
        sanitized[key] = sanitizeInput(value);
      } else if (value is List) {
        sanitized[key] = value
            .map(
              (item) => item is Map<String, dynamic>
                  ? sanitizeInput(item)
                  : item is String
                  ? item
                        .trim()
                        .replaceAll(
                          RegExp(
                            r'<script[^>]*>.*?</script>',
                            caseSensitive: false,
                          ),
                          '',
                        ) // Remove script tags and content
                        .replaceAll(
                          RegExp(
                            r'<style[^>]*>.*?</style>',
                            caseSensitive: false,
                          ),
                          '',
                        ) // Remove style tags and content
                        .replaceAll(
                          RegExp(r'<[^>]*>'),
                          '',
                        ) // Remove remaining HTML tags
                        .replaceAll('<', '')
                        .replaceAll('>', '')
                        .replaceAll('"', '')
                        .replaceAll("'", '')
                        .replaceAll('&', '')
                        .replaceAll('(', '')
                        .replaceAll(')', '')
                  : item,
            )
            .toList();
      } else {
        sanitized[key] = value;
      }
    }

    return sanitized;
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
