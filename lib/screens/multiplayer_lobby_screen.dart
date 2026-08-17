import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../theme/balatro_theme.dart';
import '../services/firebase_service.dart';
import '../services/firebase_constants.dart';
import '../services/game_code.dart';
import '../services/multiplayer_resume_service.dart';
import '../game/enhanced_multiplayer_controller.dart';
import '../game/game_controller_factory.dart';
import '../models/game_state.dart';
import '../models/multiplayer_lifecycle.dart';
import 'multiplayer_exit_flow.dart';
import 'multiplayer_game_screen.dart';

enum LobbyMode { create, join }

class MultiplayerLobbyScreen extends StatefulWidget {
  final LobbyMode mode;
  final String? gameId; // For joining a specific game
  final EnhancedMultiplayerController? existingController;
  final String? playerName;

  const MultiplayerLobbyScreen({
    super.key,
    required this.mode,
    this.gameId,
    this.existingController,
    this.playerName,
  });

  /// Resume into an already-joined lobby after refresh/rejoin.
  factory MultiplayerLobbyScreen.resume({
    Key? key,
    required EnhancedMultiplayerController controller,
    required String playerName,
  }) {
    return MultiplayerLobbyScreen(
      key: key,
      mode: controller.isHost ? LobbyMode.create : LobbyMode.join,
      gameId: controller.gameId,
      existingController: controller,
      playerName: playerName,
    );
  }

  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen> {
  final TextEditingController _playerNameController = TextEditingController();
  final TextEditingController _gameIdController = TextEditingController();

  bool _isLoading = false;
  int _maxPlayers = 4;
  EnhancedMultiplayerController? _gameController;
  StreamSubscription<Map<String, dynamic>?>? _lobbySubscription;
  StreamSubscription<MultiplayerLifecycleEvent>? _lifecycleSubscription;
  bool _isExiting = false;
  bool _transferringToGame = false;

  List<Map<String, dynamic>> _currentPlayers = [];
  String? _currentGameId;
  String? _currentUserId;
  bool _isHost = false;

  @override
  void initState() {
    super.initState();
    if (widget.gameId != null) {
      _gameIdController.text = widget.gameId!;
    }
    if (widget.playerName != null) {
      _playerNameController.text = widget.playerName!;
    }
    _generateUserId();
    _resumeExistingControllerIfNeeded();
  }

  void _resumeExistingControllerIfNeeded() {
    final existing = widget.existingController;
    if (existing == null) {
      return;
    }

    _gameController = existing;
    _currentGameId = existing.gameId;
    _isHost = existing.isHost;
    _currentUserId = existing.userId;
    _startListeningToLobby();
    _listenForLifecycleEvents();
  }

  @override
  void dispose() {
    _playerNameController.dispose();
    _gameIdController.dispose();
    _lobbySubscription?.cancel();
    _lifecycleSubscription?.cancel();

    // Keep the controller alive when handing off to the game screen.
    // On leave/cancel/back, dispose here so network listeners stop.
    if (!_transferringToGame) {
      try {
        _gameController?.dispose();
      } catch (_) {
        // Ignore disposal races during navigation.
      }
    }

    super.dispose();
  }

  void _generateUserId() async {
    final userId = await FirebaseService.getMultiplayerUserId();
    if (!mounted || userId == null) {
      return;
    }
    // Do not overwrite identity restored by an already-joined controller.
    if (_currentUserId != null) {
      return;
    }
    setState(() {
      _currentUserId = userId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentGameId == null,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await _leaveLobbyAndExit();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1a0d2e), Color(0xFF16213e), Color(0xFF0f3460)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Content
                Expanded(
                  child: _currentGameId == null
                      ? _buildSetupForm()
                      : _buildLobbyContent(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              if (_currentGameId == null) {
                Navigator.of(context).pop();
                return;
              }
              await _leaveLobbyAndExit();
            },
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(
            widget.mode == LobbyMode.create ? 'CREATE GAME' : 'JOIN GAME',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: BalatroTheme.neonBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Player Name Input
          _buildInputField(
            controller: _playerNameController,
            label: 'Your Name',
            hint: 'Enter your player name',
            icon: Icons.person,
          ),

          const SizedBox(height: 20),

          if (widget.mode == LobbyMode.create) ...[
            // Max Players Selector
            _buildMaxPlayersSelector(),
            const SizedBox(height: 40),
          ] else ...[
            // Game ID Input
            _buildInputField(
              controller: _gameIdController,
              label: 'Game ID',
              hint: 'Enter game ID to join',
              icon: Icons.games,
              inputFormatters: [
                // Auto-convert short join codes to uppercase
                _GameIdFormatter(),
              ],
            ),
            const SizedBox(height: 40),
          ],

          // Action Button
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: BalatroTheme.neonPink,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          inputFormatters: inputFormatters,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            prefixIcon: Icon(icon, color: BalatroTheme.neonPink),
            filled: true,
            fillColor: BalatroTheme.cardBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: BalatroTheme.neonPink.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: BalatroTheme.neonPink.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: BalatroTheme.neonPink, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMaxPlayersSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Maximum Players',
          style: TextStyle(
            color: BalatroTheme.neonPink,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [2, 3, 4, 5, 6].map((players) {
            final isSelected = _maxPlayers == players;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _maxPlayers = players),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? BalatroTheme.neonPink.withValues(alpha: 0.3)
                        : BalatroTheme.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? BalatroTheme.neonPink
                          : BalatroTheme.neonPink.withValues(alpha: 0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    '$players',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? BalatroTheme.neonPink : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleAction,
        style: ElevatedButton.styleFrom(
          backgroundColor: BalatroTheme.neonBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                widget.mode == LobbyMode.create ? 'CREATE GAME' : 'JOIN GAME',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildLobbyContent() {
    return Column(
      children: [
        // Game ID Display
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BalatroTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: BalatroTheme.neonBlue.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.games, color: BalatroTheme.neonBlue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Game ID',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _currentGameId ?? '',
                      style: TextStyle(
                        color: BalatroTheme.neonBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _copyGameId,
                icon: const Icon(Icons.copy, color: Colors.white),
                tooltip: 'Copy Game ID',
              ),
            ],
          ),
        ),

        // Players List
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Players (${_currentPlayers.length}/$_maxPlayers)',
                  style: TextStyle(
                    color: BalatroTheme.neonPink,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: _currentPlayers.length,
                    itemBuilder: (context, index) {
                      final player = _currentPlayers[index];
                      final isCurrentUser = player['id'] == _currentUserId;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCurrentUser
                              ? BalatroTheme.neonPink.withValues(alpha: 0.2)
                              : BalatroTheme.cardBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCurrentUser
                                ? BalatroTheme.neonPink
                                : BalatroTheme.neonPink.withValues(alpha: 0.3),
                            width: isCurrentUser ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: isCurrentUser
                                  ? BalatroTheme.neonPink
                                  : Colors.white,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              player['name'] ?? 'Unknown',
                              style: TextStyle(
                                color: isCurrentUser
                                    ? BalatroTheme.neonPink
                                    : Colors.white,
                                fontSize: 16,
                                fontWeight: isCurrentUser
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            if (isCurrentUser) ...[
                              const SizedBox(width: 8),
                              Text(
                                '(You)',
                                style: TextStyle(
                                  color: BalatroTheme.neonPink.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // Host actions
        if (_isHost)
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _currentPlayers.length >= 2 ? _startGame : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BalatroTheme.neonBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'START GAME',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _confirmEndGameForEveryone,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'END GAME FOR EVERYONE',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _handleAction() async {
    if (_playerNameController.text.trim().isEmpty) {
      _showErrorDialog('Please enter your name');
      return;
    }

    if (widget.mode == LobbyMode.join &&
        _gameIdController.text.trim().isEmpty) {
      _showErrorDialog('Please enter a game ID');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.mode == LobbyMode.create) {
        await _createGame();
      } else {
        await _joinGame();
      }
    } catch (e) {
      final message = e.toString();
      final displayMessage = message.startsWith('Exception: ')
          ? message.substring('Exception: '.length)
          : message;
      _showErrorDialog(displayMessage);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _createGame() async {
    final controller = await GameControllerFactory.createMultiplayerGame(
      hostPlayerName: _playerNameController.text.trim(),
      maxPlayers: _maxPlayers,
    );

    if (controller != null) {
      _gameController = controller;
      _currentGameId = _gameController!.gameId;
      _isHost = true;
      _startListeningToLobby();
      _listenForLifecycleEvents();
    } else {
      throw Exception(
        FirebaseService.lastOperationError ?? 'Failed to create game',
      );
    }
  }

  Future<void> _joinGame() async {
    final gameId = _gameIdController.text.trim();
    // Normalize short game IDs to uppercase for consistency
    final normalizedGameId = GameCode.normalize(gameId);

    final controller = await GameControllerFactory.joinMultiplayerGame(
      gameId: normalizedGameId,
      playerName: _playerNameController.text.trim(),
    );

    if (controller != null) {
      _gameController = controller;
      _currentGameId = _gameController!.gameId;
      _isHost = controller.isHost;
      _startListeningToLobby();
      _listenForLifecycleEvents();
    } else {
      throw Exception(
        FirebaseService.lastOperationError ?? 'Failed to join game',
      );
    }
  }

  void _startListeningToLobby() {
    if (_currentGameId == null) {
      return;
    }

    _lobbySubscription?.cancel();
    _lobbySubscription = FirebaseService.listenToGameLobby(_currentGameId!)
        .listen(
          (gameData) {
            if (!mounted || _isExiting) {
              return;
            }

            if (gameData == null) {
              _handleRemoteGameEnded('This game was ended by the host.');
              return;
            }

            setState(() {
              _currentPlayers = List<Map<String, dynamic>>.from(
                gameData['players'] ?? [],
              );
              // Sync maxPlayers from Firestore data
              _maxPlayers = gameData['maxPlayers'] ?? _maxPlayers;
            });

            final status = gameData['status'] as String?;
            if (status == FirebaseConstants.gameStatusCancelled) {
              _handleRemoteGameEnded('The host ended this game.');
              return;
            }

            // Check if game has started
            if (status == FirebaseConstants.gameStatusPlaying) {
              _navigateToGame();
            }
          },
          onError: (error) {
            if (mounted) {
              _showErrorDialog('Connection lost. Please try again.');
            }
          },
        );
  }

  void _listenForLifecycleEvents() {
    _lifecycleSubscription?.cancel();
    final controller = _gameController;
    if (controller == null) {
      return;
    }

    _lifecycleSubscription = controller.lifecycleStream.listen((event) {
      if (!mounted || _isExiting) {
        return;
      }
      _handleRemoteGameEnded(
        MultiplayerExitFlow.messageForLifecycleEvent(event),
      );
    });
  }

  void _startGame() async {
    if (_gameController != null && _isHost) {
      final success = await _gameController!.startMultiplayerGame();
      if (!success) {
        _showErrorDialog('Failed to start game. Please try again.');
      }
    }
  }

  void _confirmEndGameForEveryone() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.3), width: 1),
        ),
        title: const Text(
          'End Game for Everyone?',
          style: TextStyle(
            color: Colors.red,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'This will cancel the lobby for all players. They will be returned to the main menu.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _endGameForEveryoneAndExit();
            },
            child: const Text(
              'End Game',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _endGameForEveryoneAndExit() async {
    if (_isExiting) {
      return;
    }
    _isExiting = true;

    var success = false;
    try {
      success = await _gameController?.endGameForEveryone() ?? false;
    } catch (e) {
      debugPrint('Warning: Failed to end multiplayer game: $e');
      success = false;
    }

    if (!success) {
      _isExiting = false;
      if (mounted) {
        _showErrorDialog('Failed to end the game. Please try again.');
      }
      return;
    }

    await MultiplayerResumeService.clearActiveGame();
    if (!mounted) {
      return;
    }
    MultiplayerExitFlow.goToMainMenu(context);
  }

  Future<void> _leaveLobbyAndExit() async {
    if (_isExiting) {
      return;
    }
    _isExiting = true;

    try {
      await _gameController?.leaveGame();
    } catch (e) {
      debugPrint('Warning: Failed to leave multiplayer lobby: $e');
    }

    await MultiplayerResumeService.clearActiveGame();
    if (!mounted) {
      return;
    }
    MultiplayerExitFlow.goToMainMenu(context);
  }

  Future<void> _handleRemoteGameEnded(String message) async {
    await MultiplayerExitFlow.handleRemoteGameEnded(
      context: context,
      alreadyExiting: _isExiting,
      markExiting: () => _isExiting = true,
      message: message,
      dialogBackground: BalatroTheme.cardBackground,
      dialogBorder: BorderSide(
        color: BalatroTheme.neonPink.withValues(alpha: 0.3),
        width: 1,
      ),
    );
  }

  void _navigateToGame({int retryCount = 0}) {
    const maxRetries = 10; // Prevent infinite loops

    if (_gameController != null) {
      // Ensure game state has proper player count before navigating
      final gameState = _gameController!.gameState;
      if (gameState.players.isNotEmpty && gameState.phase != GamePhase.setup) {
        _transferringToGame = true;
        _lifecycleSubscription?.cancel();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                MultiplayerGameScreen(gameController: _gameController!),
          ),
        );
      } else if (retryCount < maxRetries) {
        // Game state not ready yet, wait for next update
        // This can happen if the game status changes before game state is fully synced
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _gameController != null) {
            _navigateToGame(retryCount: retryCount + 1);
          }
        });
      } else {
        // Exceeded max retries - show error and stay in lobby
        _showErrorDialog(
          'Game Sync Error: Failed to sync game state. Please try refreshing or rejoining the game.',
        );
      }
    }
  }

  void _copyGameId() {
    if (_currentGameId != null) {
      Clipboard.setData(ClipboardData(text: _currentGameId!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Game ID copied to clipboard',
            style: TextStyle(color: BalatroTheme.primaryText),
          ),
          backgroundColor: BalatroTheme.neonBlue,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.3), width: 1),
        ),
        title: const Text(
          'Error',
          style: TextStyle(
            color: Colors.red,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: TextStyle(color: BalatroTheme.neonBlue)),
          ),
        ],
      ),
    );
  }
}

/// Custom TextInputFormatter for Game ID fields
/// Automatically converts short game codes to uppercase for consistency
class _GameIdFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Only apply uppercase conversion within join-code length. Uses the
    // longest accepted code, not the length this build generates, so a
    // 6-character code from a future build is still typable today.
    if (newValue.text.length <= GameCode.maxLength) {
      final upperCaseText = newValue.text.toUpperCase();
      return newValue.copyWith(
        text: upperCaseText,
        selection: TextSelection.collapsed(offset: upperCaseText.length),
      );
    }

    // For longer IDs, leave as-is (might be full Firebase document IDs)
    return newValue;
  }
}
