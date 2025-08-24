# Multiplayer Usage Examples

This document provides practical examples of how to use the new DRY multiplayer architecture.

## **Quick Start Examples**

### **Creating a Singleplayer Game**
```dart
import '../game/game_controller_factory.dart';
import '../models/player.dart';

// Create players
final humanPlayer = Player(
  id: 'human-1',
  name: 'Alice',
  type: PlayerType.human,
);

final botPlayer = Player(
  id: 'bot-1', 
  name: 'Bot Charlie',
  type: PlayerType.bot,
);

// Create game controller
final controller = GameControllerFactory.createSingleplayerGame(
  players: [humanPlayer, botPlayer],
  seed: 12345, // Optional for deterministic games
);

// Initialize and start game
controller.initializeGame();
```

### **Creating a Multiplayer Game (Host)**
```dart
import '../game/game_controller_factory.dart';

// Create multiplayer game
final controller = await GameControllerFactory.createMultiplayerGame(
  hostPlayerName: 'Alice',
  maxPlayers: 4,
);

if (controller != null) {
  print('Game created! ID: ${controller.gameId}');
  
  // Wait for players to join, then start
  await controller.startMultiplayerGame();
} else {
  print('Failed to create game');
}
```

### **Joining a Multiplayer Game**
```dart
// Join existing multiplayer game
final controller = await GameControllerFactory.joinMultiplayerGame(
  gameId: 'AB12',
  playerName: 'Bob',
);

if (controller != null) {
  print('Successfully joined game!');
} else {
  print('Failed to join game');
}
```

## **UI Integration Examples**

### **Using Same Interface for Both Game Types**
```dart
class GameScreen extends StatefulWidget {
  final GameInterface gameController; // Works for both single/multiplayer
  
  const GameScreen({Key? key, required this.gameController}) : super(key: key);
}

class _GameScreenState extends State<GameScreen> {
  late GameInterface _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = widget.gameController;
    
    // Listen to game state changes (works for both modes)
    if (_controller is EnhancedMultiplayerController) {
      final multiplayer = _controller as EnhancedMultiplayerController;
      multiplayer.gameStateStream.listen((state) {
        if (mounted) setState(() {});
      });
    }
  }
  
  void _drawFromDeck() {
    final success = _controller.drawFromDeck();
    if (success && mounted) setState(() {});
  }
  
  void _createMeld() {
    final selectedCards = /* get selected cards */;
    final success = _controller.createMeld(selectedCards);
    if (success && mounted) setState(() {});
  }
  
  @override
  Widget build(BuildContext context) {
    final gameState = _controller.gameState;
    
    return Scaffold(
      body: Column(
        children: [
          // Connection status for multiplayer
          if (_controller is EnhancedMultiplayerController)
            _buildConnectionStatus(),
            
          // Game UI (same for both modes)
          _buildGameUI(gameState),
        ],
      ),
    );
  }
  
  Widget _buildConnectionStatus() {
    final multiplayer = _controller as EnhancedMultiplayerController;
    
    return StreamBuilder<bool>(
      stream: multiplayer.connectionStream,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        return Container(
          padding: EdgeInsets.all(8),
          color: isOnline ? Colors.green : Colors.red,
          child: Text(
            isOnline ? 'Connected' : 'Offline',
            style: TextStyle(color: Colors.white),
          ),
        );
      },
    );
  }
}
```

### **Factory Pattern in Main Menu**
```dart
class MainMenuScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () => _startSingleplayerGame(context),
            child: Text('Singleplayer'),
          ),
          
          ElevatedButton(
            onPressed: () => _createMultiplayerGame(context),
            child: Text('Create Multiplayer Game'),
          ),
          
          ElevatedButton(
            onPressed: () => _joinMultiplayerGame(context),
            child: Text('Join Multiplayer Game'),
          ),
        ],
      ),
    );
  }
  
  void _startSingleplayerGame(BuildContext context) {
    final controller = GameControllerFactory.createSingleplayerGame(
      players: _createDefaultPlayers(),
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(gameController: controller),
      ),
    );
  }
  
  void _createMultiplayerGame(BuildContext context) async {
    final controller = await GameControllerFactory.createMultiplayerGame(
      hostPlayerName: 'Player',
      maxPlayers: 4,
    );
    
    if (controller != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameScreen(gameController: controller),
        ),
      );
    } else {
      _showError(context, 'Failed to create multiplayer game');
    }
  }
  
  void _joinMultiplayerGame(BuildContext context) async {
    final gameId = await _promptForGameId(context);
    if (gameId == null) return;
    
    final controller = await GameControllerFactory.joinMultiplayerGame(
      gameId: gameId,
      playerName: 'Player',
    );
    
    if (controller != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameScreen(gameController: controller),
        ),
      );
    } else {
      _showError(context, 'Failed to join game');
    }
  }
}
```

## **Testing Examples**

### **Unit Testing with Mock Adapter**
```dart
import 'package:flutter_test/flutter_test.dart';
import '../lib/game/enhanced_multiplayer_controller.dart';
import '../lib/game/network_adapter.dart';

void main() {
  group('Multiplayer Controller Tests', () {
    late MockNetworkAdapter mockAdapter;
    late EnhancedMultiplayerController controller;
    
    setUp(() async {
      mockAdapter = MockNetworkAdapter();
      
      controller = await EnhancedMultiplayerController.createGame(
        hostPlayerName: 'Test Host',
        maxPlayers: 2,
        networkAdapter: mockAdapter,
      );
    });
    
    testWidgets('should handle network disconnection gracefully', (tester) async {
      // Simulate network disconnection
      mockAdapter.simulateDisconnection();
      
      // Game should still allow local actions
      final success = controller.drawFromDeck();
      expect(success, isTrue);
      
      // Simulate reconnection
      mockAdapter.simulateReconnection();
      
      // Should sync state when reconnected
      await tester.pump(Duration(seconds: 1));
      expect(mockAdapter.isConnected, isTrue);
    });
    
    test('should delegate game logic to GameController', () {
      // Test that game rules are enforced
      final gameState = controller.gameState;
      expect(gameState.phase, equals(GamePhase.setup));
      
      controller.initializeGame();
      expect(gameState.phase, equals(GamePhase.playing));
    });
  });
}
```

### **Integration Testing**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../lib/game/game_controller_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  group('Multiplayer Integration Tests', () {
    testWidgets('should create and join multiplayer games', (tester) async {
      // Create game
      final hostController = await GameControllerFactory.createTestMultiplayerGame(
        hostPlayerName: 'Host',
        maxPlayers: 2,
      );
      
      expect(hostController, isNotNull);
      expect(hostController!.isHost, isTrue);
      
      // Join game
      final guestController = await GameControllerFactory.joinTestMultiplayerGame(
        gameId: hostController.gameId,
        playerName: 'Guest',
      );
      
      expect(guestController, isNotNull);
      expect(guestController!.isHost, isFalse);
      
      // Start game
      await hostController.startMultiplayerGame();
      
      // Both controllers should have synchronized state
      await tester.pump(Duration(seconds: 1));
      expect(hostController.gameState.phase, equals(GamePhase.playing));
      expect(guestController.gameState.phase, equals(GamePhase.playing));
    });
  });
}
```

## **Error Handling Examples**

### **Network Error Recovery**
```dart
class GameWithNetworkHandling extends StatefulWidget {
  final EnhancedMultiplayerController controller;
  
  const GameWithNetworkHandling({Key? key, required this.controller}) : super(key: key);
}

class _GameWithNetworkHandlingState extends State<GameWithNetworkHandling> {
  bool _isOnline = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    
    // Listen to connection changes
    widget.controller.connectionStream.listen((isConnected) {
      setState(() {
        _isOnline = isConnected;
        if (isConnected) {
          _errorMessage = null;
        } else {
          _errorMessage = 'Connection lost. Game continues offline.';
        }
      });
    });
  }
  
  void _performGameAction() async {
    try {
      final success = widget.controller.drawFromDeck();
      if (!success) {
        setState(() {
          _errorMessage = 'Unable to perform action. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Game error: ${e.toString()}';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Error message display
          if (_errorMessage != null)
            Container(
              padding: EdgeInsets.all(8),
              color: _isOnline ? Colors.orange : Colors.red,
              child: Text(_errorMessage!, style: TextStyle(color: Colors.white)),
            ),
            
          // Game content
          Expanded(child: _buildGameContent()),
          
          // Actions
          ElevatedButton(
            onPressed: _isOnline ? _performGameAction : null,
            child: Text('Draw Card'),
          ),
        ],
      ),
    );
  }
}
```

### **Graceful Degradation**
```dart
extension GameControllerExtensions on GameInterface {
  /// Safely perform action with error handling
  Future<bool> safeDrawFromDeck() async {
    try {
      return drawFromDeck();
    } catch (e) {
      print('Draw action failed: $e');
      return false;
    }
  }
  
  /// Check if multiplayer features are available
  bool get hasMultiplayerFeatures {
    return this is EnhancedMultiplayerController;
  }
  
  /// Get connection status if multiplayer
  bool get isConnectedIfMultiplayer {
    if (this is EnhancedMultiplayerController) {
      return (this as EnhancedMultiplayerController).isOnline;
    }
    return true; // Singleplayer is always "connected"
  }
}
```

## **Performance Optimization Examples**

### **Debounced State Updates**
```dart
class OptimizedGameScreen extends StatefulWidget {
  final GameInterface controller;
  
  const OptimizedGameScreen({Key? key, required this.controller}) : super(key: key);
}

class _OptimizedGameScreenState extends State<OptimizedGameScreen> {
  Timer? _updateTimer;
  GameState? _lastState;
  
  @override
  void initState() {
    super.initState();
    
    if (widget.controller is EnhancedMultiplayerController) {
      final multiplayer = widget.controller as EnhancedMultiplayerController;
      
      // Debounce rapid state updates
      multiplayer.gameStateStream.listen((newState) {
        _updateTimer?.cancel();
        _updateTimer = Timer(Duration(milliseconds: 100), () {
          if (mounted && newState != _lastState) {
            setState(() {
              _lastState = newState;
            });
          }
        });
      });
    }
  }
  
  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}
```

This architecture provides a solid foundation for multiplayer success while maintaining clean, testable, and maintainable code!