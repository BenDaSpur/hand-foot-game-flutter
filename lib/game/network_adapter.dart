import 'dart:async';
import '../models/game_state.dart';
import '../services/firebase_service.dart';

/// Abstract network adapter interface for different multiplayer backends
/// This enables DRY architecture by separating networking concerns
/// from game logic, allowing easy testing and different implementations
abstract class NetworkAdapter {
  /// Connection status stream
  Stream<bool> get connectionStream;

  /// Current connection state
  bool get isConnected;

  /// Game state synchronization
  Future<bool> syncGameState(String gameId, GameState gameState);
  Stream<GameState?> listenToGameState(String gameId);

  /// Game management
  Future<String?> createGame({
    required String hostPlayerName,
    required int maxPlayers,
  });

  Future<bool> joinGame({required String gameId, required String playerName});

  Future<bool> startGame(String gameId);
  Future<bool> leaveGame(String gameId);

  /// Lobby management
  Stream<Map<String, dynamic>?> listenToGameLobby(String gameId);

  /// User management
  Future<String?> getCurrentUserId();
  Future<String> getCurrentUserName();

  /// Security and validation
  bool validateGameAction(Map<String, dynamic> action, String userId);
  bool validatePlayerAuthorization(String gameId, String userId, String action);
  Map<String, dynamic> sanitizeInput(Map<String, dynamic> input);

  /// Connection health and optimization
  Future<bool> checkConnectionHealth();
  Stream<int> get pingStream; // Latency monitoring
  Future<void> optimizeBandwidth({bool lowBandwidthMode = false});

  /// Reconnection management
  Future<void> configureReconnection({
    Duration retryInterval = const Duration(seconds: 5),
    int maxRetries = 3,
    bool exponentialBackoff = true,
  });

  /// Player presence management
  Stream<Map<String, bool>> listenToPlayerPresence(String gameId);
  Future<void> updatePlayerPresence(String gameId, bool isActive);

  /// Cleanup
  void dispose();
}

/// Firebase implementation of NetworkAdapter
/// This keeps all Firebase-specific logic contained and replaceable
class FirebaseNetworkAdapter implements NetworkAdapter {
  late StreamController<bool> _connectionController;
  // ignore: prefer_final_fields
  bool _isConnected = true;

  FirebaseNetworkAdapter() {
    _connectionController = StreamController<bool>.broadcast();
    // Initialize connection monitoring here
  }

  @override
  Stream<bool> get connectionStream => _connectionController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<bool> syncGameState(String gameId, GameState gameState) {
    // Delegate to existing FirebaseService
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

  @override
  Future<bool> checkConnectionHealth() async {
    try {
      // Implement actual health check - simplified for now
      return _isConnected;
    } catch (e) {
      return false;
    }
  }

  @override
  Stream<int> get pingStream {
    // Mock ping stream - would implement actual ping monitoring
    return Stream.periodic(
      const Duration(seconds: 5),
      (i) => 50 + (i % 10) * 5,
    );
  }

  @override
  Future<void> optimizeBandwidth({bool lowBandwidthMode = false}) async {
    // Implement bandwidth optimization settings
    // Could adjust sync frequency, data compression, etc.
  }

  @override
  Future<void> configureReconnection({
    Duration retryInterval = const Duration(seconds: 5),
    int maxRetries = 3,
    bool exponentialBackoff = true,
  }) async {
    // Configure reconnection strategy - would store these settings
  }

  @override
  Stream<Map<String, bool>> listenToPlayerPresence(String gameId) {
    // Mock presence stream - would implement actual presence monitoring
    return Stream.periodic(
      const Duration(seconds: 10),
      (i) => {'player1': true, 'player2': i % 3 != 0},
    );
  }

  @override
  Future<void> updatePlayerPresence(String gameId, bool isActive) async {
    // Update player presence status
  }

  @override
  void dispose() {
    _connectionController.close();
  }
}

/// Mock network adapter for testing and development
class MockNetworkAdapter implements NetworkAdapter {
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<GameState?> _gameStateController =
      StreamController<GameState?>.broadcast();
  final StreamController<Map<String, dynamic>?> _lobbyController =
      StreamController<Map<String, dynamic>?>.broadcast();

  bool _isConnected = true;
  Map<String, dynamic>? _mockLobbyState;

  @override
  Stream<bool> get connectionStream => _connectionController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<bool> syncGameState(String gameId, GameState gameState) async {
    if (!_isConnected) return false;

    _gameStateController.add(gameState);
    return true;
  }

  @override
  Stream<GameState?> listenToGameState(String gameId) {
    return _gameStateController.stream;
  }

  @override
  Future<String?> createGame({
    required String hostPlayerName,
    required int maxPlayers,
  }) async {
    if (!_isConnected) return null;

    final gameId = 'MOCK${DateTime.now().millisecondsSinceEpoch % 10000}';
    _mockLobbyState = {
      'gameId': gameId,
      'hostPlayerName': hostPlayerName,
      'maxPlayers': maxPlayers,
      'players': [
        {'id': 'mock-host', 'name': hostPlayerName},
      ],
      'status': 'waiting',
    };
    _lobbyController.add(_mockLobbyState);
    return gameId;
  }

  @override
  Future<bool> joinGame({
    required String gameId,
    required String playerName,
  }) async {
    if (!_isConnected) return false;

    if (_mockLobbyState != null) {
      final players = List<Map<String, dynamic>>.from(
        _mockLobbyState!['players'],
      );
      players.add({'id': 'mock-${players.length}', 'name': playerName});
      _mockLobbyState!['players'] = players;
      _lobbyController.add(_mockLobbyState);
    }
    return true;
  }

  @override
  Future<bool> startGame(String gameId) async {
    if (!_isConnected) return false;

    if (_mockLobbyState != null) {
      _mockLobbyState!['status'] = 'playing';
      _lobbyController.add(_mockLobbyState);
    }
    return true;
  }

  @override
  Future<bool> leaveGame(String gameId) async {
    return true;
  }

  @override
  Stream<Map<String, dynamic>?> listenToGameLobby(String gameId) {
    return _lobbyController.stream;
  }

  @override
  Future<String?> getCurrentUserId() async {
    return 'mock-user-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<String> getCurrentUserName() async {
    return 'Mock User';
  }

  @override
  bool validateGameAction(Map<String, dynamic> action, String userId) {
    // Simple mock validation - always return true for testing
    return action.containsKey('type') && action.containsKey('playerId');
  }

  @override
  bool validatePlayerAuthorization(
    String gameId,
    String userId,
    String action,
  ) {
    // Mock authorization - always allow for testing
    return gameId.isNotEmpty && userId.isNotEmpty && action.isNotEmpty;
  }

  @override
  Map<String, dynamic> sanitizeInput(Map<String, dynamic> input) {
    // Mock sanitization - return as-is for testing (in real implementation would sanitize)
    return Map<String, dynamic>.from(input);
  }

  @override
  Future<bool> checkConnectionHealth() async {
    return _isConnected;
  }

  @override
  Stream<int> get pingStream {
    return Stream.periodic(const Duration(seconds: 2), (i) => 20 + (i % 5) * 2);
  }

  @override
  Future<void> optimizeBandwidth({bool lowBandwidthMode = false}) async {
    // Mock bandwidth optimization
  }

  @override
  Future<void> configureReconnection({
    Duration retryInterval = const Duration(seconds: 5),
    int maxRetries = 3,
    bool exponentialBackoff = true,
  }) async {
    // Mock reconnection configuration
  }

  @override
  Stream<Map<String, bool>> listenToPlayerPresence(String gameId) {
    return Stream.periodic(
      const Duration(seconds: 5),
      (i) => {'mock-host': true, 'mock-1': true},
    );
  }

  @override
  Future<void> updatePlayerPresence(String gameId, bool isActive) async {
    // Mock presence update
  }

  @override
  void dispose() {
    _connectionController.close();
    _gameStateController.close();
    _lobbyController.close();
  }

  // Test helpers
  void simulateDisconnection() {
    _isConnected = false;
    _connectionController.add(false);
  }

  void simulateReconnection() {
    _isConnected = true;
    _connectionController.add(true);
  }
}
