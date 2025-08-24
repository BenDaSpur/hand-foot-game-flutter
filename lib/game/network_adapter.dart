import 'dart:async';
import '../models/game_state.dart';

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
    return _firebaseService.updateGameState(gameId, gameState);
  }

  @override
  Stream<GameState?> listenToGameState(String gameId) {
    return _firebaseService.listenToGameState(gameId);
  }

  @override
  Future<String?> createGame({
    required String hostPlayerName,
    required int maxPlayers,
  }) {
    return _firebaseService.createGame(
      hostPlayerName: hostPlayerName,
      maxPlayers: maxPlayers,
    );
  }

  @override
  Future<bool> joinGame({required String gameId, required String playerName}) {
    return _firebaseService.joinGame(gameId: gameId, playerName: playerName);
  }

  @override
  Future<bool> startGame(String gameId) {
    return _firebaseService.startGame(gameId);
  }

  @override
  Future<bool> leaveGame(String gameId) {
    return _firebaseService.leaveGame(gameId);
  }

  @override
  Stream<Map<String, dynamic>?> listenToGameLobby(String gameId) {
    return _firebaseService.listenToGameLobby(gameId);
  }

  @override
  Future<String?> getCurrentUserId() {
    return _firebaseService.getDeviceUserId();
  }

  @override
  Future<String> getCurrentUserName() {
    return _firebaseService.getDeviceUserName();
  }

  @override
  void dispose() {
    _connectionController.close();
  }

  // Private reference to existing service
  // This allows gradual migration without breaking existing code
  dynamic get _firebaseService {
    // Import here to avoid circular dependencies
    // We'll need to import '../services/firebase_service.dart'
    throw UnimplementedError('Firebase service reference needed');
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
