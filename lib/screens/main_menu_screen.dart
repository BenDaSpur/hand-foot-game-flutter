import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../theme/balatro_theme.dart';
import 'game_screen.dart';
import 'multiplayer_lobby_screen.dart';
import 'multiplayer_game_screen.dart';
import '../services/firebase_service.dart';
import '../services/game_save_service.dart';
import '../services/multiplayer_resume_service.dart';
import '../models/player.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  bool _isLoading = false;
  bool _hasSavedSinglePlayerGame = false;
  Map<String, dynamic>? _rejoinableGame;

  @override
  void initState() {
    super.initState();
    _checkForSavedSinglePlayerGame();
    _checkForRejoinableMultiplayerGame();
  }

  /// Check for rejoinable multiplayer games
  void _checkForRejoinableMultiplayerGame() async {
    try {
      final rejoinOpportunity =
          await MultiplayerResumeService.checkForRejoinOpportunity();
      if (rejoinOpportunity != null && mounted) {
        setState(() {
          _rejoinableGame = rejoinOpportunity;
        });
      }
    } catch (e) {
      debugPrint('Error checking for rejoinable games: $e');
    }
  }

  /// Check if there's a saved single player game against bots
  void _checkForSavedSinglePlayerGame() async {
    try {
      final savedGameData = await GameSaveService.loadGame();
      if (savedGameData != null) {
        final players = savedGameData['players'] as List?;
        if (players != null) {
          // Check if this is a single player game (1 human + bots)
          int humanPlayerCount = 0;
          int botPlayerCount = 0;

          for (final playerData in players) {
            final playerType = playerData['type'] as String?;
            if (playerType == PlayerType.human.name) {
              humanPlayerCount++;
            } else if (playerType == PlayerType.bot.name) {
              botPlayerCount++;
            }
          }

          // This is a single player game if there's exactly 1 human and the rest are bots
          if (humanPlayerCount == 1 && botPlayerCount > 0) {
            setState(() {
              _hasSavedSinglePlayerGame = true;
            });
          }
        }
      }
    } catch (e) {
      // If loading fails, just don't show the continue button
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a0d2e), Color(0xFF16213e), Color(0xFF0f3460)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Game Title
                  Container(
                    margin: const EdgeInsets.only(bottom: 60),
                    child: Column(
                      children: [
                        Text(
                          'HAND & FOOT',
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(
                                color: BalatroTheme.neonBlue,
                                shadows: [
                                  Shadow(
                                    color: BalatroTheme.neonBlue.withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'CARD GAME',
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                color: BalatroTheme.neonPink,
                                letterSpacing: 4,
                              ),
                        ),
                      ],
                    ),
                  ),

                  // Menu Options
                  if (_isLoading)
                    const CircularProgressIndicator(
                      color: BalatroTheme.neonBlue,
                    )
                  else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Continue button (only shown if saved single player game exists)
                        if (_hasSavedSinglePlayerGame) ...[
                          _buildMenuButton(
                            icon: Icons.play_arrow,
                            label: 'CONTINUE',
                            description: 'Resume your saved game',
                            onPressed: _continueSavedGame,
                            isPrimary: true,
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (_rejoinableGame != null) ...[
                          _buildMenuButton(
                            icon: Icons.wifi,
                            label: 'REJOIN GAME',
                            description:
                                'Reconnect to ${_rejoinableGame!['gameId']}',
                            onPressed: _rejoinMultiplayerGame,
                            isPrimary: true,
                          ),
                          const SizedBox(height: 20),
                        ],
                        _buildMenuButton(
                          icon: Icons.person,
                          label: 'PLAY SOLO',
                          description: 'Play against AI opponents',
                          onPressed: _startSoloGame,
                        ),
                        const SizedBox(height: 20),
                        _buildMenuButton(
                          icon: Icons.group_add,
                          label: 'CREATE GAME',
                          description: 'Host a multiplayer game',
                          onPressed: _createMultiplayerGame,
                        ),
                        const SizedBox(height: 20),
                        _buildMenuButton(
                          icon: Icons.group,
                          label: 'JOIN GAME',
                          description: 'Join an existing game',
                          onPressed: _joinMultiplayerGame,
                        ),
                        const SizedBox(height: 40),
                        _buildInfoButton(),
                        if (kIsWeb) ...[
                          const SizedBox(height: 16),
                          _buildInstallButton(),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return Container(
      width: 320,
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary
              ? BalatroTheme.neonBlue.withValues(alpha: 0.2)
              : BalatroTheme.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isPrimary
                  ? BalatroTheme.neonBlue.withValues(alpha: 0.6)
                  : BalatroTheme.neonPink.withValues(alpha: 0.3),
              width: isPrimary ? 2 : 1,
            ),
          ),
          elevation: isPrimary ? 12 : 8,
          shadowColor: isPrimary
              ? BalatroTheme.neonBlue.withValues(alpha: 0.5)
              : BalatroTheme.neonPink.withValues(alpha: 0.3),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isPrimary
                      ? BalatroTheme.neonBlue.withValues(alpha: 0.3)
                      : BalatroTheme.neonPink.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isPrimary
                      ? BalatroTheme.neonBlue
                      : BalatroTheme.neonPink,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Flexible(
                      child: Text(
                        description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: BalatroTheme.neonBlue,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoButton() {
    return TextButton(
      onPressed: _showGameInfo,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline,
            color: BalatroTheme.neonBlue.withValues(alpha: 0.7),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'How to Play',
            style: TextStyle(
              color: BalatroTheme.neonBlue.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallButton() {
    return TextButton(
      onPressed: _showInstallInstructions,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.download_rounded,
            color: BalatroTheme.neonGreen.withValues(alpha: 0.7),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'Install App',
            style: TextStyle(
              color: BalatroTheme.neonGreen.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showInstallInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: BalatroTheme.neonGreen.withValues(alpha: 0.3),
          ),
        ),
        title: const Row(
          children: [
            Icon(Icons.download_rounded, color: BalatroTheme.neonGreen),
            SizedBox(width: 12),
            Text('Install App', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Install this game on your device for offline play!\n',
                style: TextStyle(color: Colors.white70),
              ),
              _buildInstallSection(
                '🍎 iPhone / iPad (Safari only)',
                [
                  '1. Open this page in Safari',
                  '2. Tap the Share button (📤)',
                  '3. Scroll down and tap "Add to Home Screen"',
                  '4. Tap "Add"',
                ],
                note:
                    '⚠️ iOS only allows PWA installs from Safari.\nFirefox/Chrome cannot install apps on iOS.',
              ),
              const SizedBox(height: 16),
              _buildInstallSection('🤖 Android (Chrome)', [
                '1. Tap the menu (⋮) in Chrome',
                '2. Tap "Add to Home screen" or "Install app"',
                '3. Tap "Install"',
              ]),
              const SizedBox(height: 16),
              _buildInstallSection('💻 Desktop (Chrome/Edge)', [
                '1. Look for the install icon (⊕) in the address bar',
                '2. Click "Install"',
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it!',
              style: TextStyle(color: BalatroTheme.neonGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallSection(
    String title,
    List<String> steps, {
    String? note,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ...steps.map(
          (step) => Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text(
              step,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Text(
              note,
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  void _continueSavedGame() async {
    setState(() => _isLoading = true);

    try {
      final savedGameData = await GameSaveService.loadGame();
      if (savedGameData != null) {
        final gameController = GameSaveService.restoreGameController(
          savedGameData,
        );
        if (gameController != null) {
          // Log continue game event - completely optional, never crash singleplayer
          try {
            await FirebaseService.logGameEvent(
              'solo_game_continued',
              parameters: {'game_type': 'solo_continue'},
            );
          } catch (e) {
            // Silently ignore Firebase errors in singleplayer mode
            // Game must work completely offline
          }

          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) =>
                    GameScreen(gameController: gameController),
              ),
            );
          }
        } else {
          // Failed to restore game, show error and refresh menu state
          if (mounted) {
            _showErrorDialog(
              'Failed to load saved game. The save file may be corrupted.',
            );
            setState(() {
              _hasSavedSinglePlayerGame = false;
            });
          }
        }
      } else {
        // No saved game found, refresh menu state
        if (mounted) {
          setState(() {
            _hasSavedSinglePlayerGame = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error loading saved game: ${e.toString()}');
        setState(() {
          _hasSavedSinglePlayerGame = false;
        });
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Rejoin an active multiplayer game after crash/disconnect
  void _rejoinMultiplayerGame() async {
    if (_rejoinableGame == null) return;

    setState(() => _isLoading = true);

    try {
      final gameId = _rejoinableGame!['gameId'] as String;
      final playerName = _rejoinableGame!['playerName'] as String;

      // Attempt to rejoin the game
      final controller = await MultiplayerResumeService.rejoinGame(
        gameId: gameId,
        playerName: playerName,
      );

      if (controller != null && mounted) {
        // Navigate directly to the game screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                MultiplayerGameScreen(gameController: controller),
          ),
        );

        // Clear the rejoin state since we successfully rejoined
        setState(() {
          _rejoinableGame = null;
        });
      } else {
        // Failed to rejoin - clear stale data and show error
        await MultiplayerResumeService.clearActiveGame();
        setState(() {
          _rejoinableGame = null;
        });

        if (mounted) {
          _showErrorDialog(
            'Unable to rejoin game. The game may have ended or you may have been disconnected.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to rejoin game: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startSoloGame() async {
    setState(() => _isLoading = true);

    // Log solo game start - completely optional, never crash singleplayer
    try {
      await FirebaseService.logGameEvent(
        'solo_game_started',
        parameters: {'game_type': 'solo'},
      );
    } catch (e) {
      // Silently ignore Firebase errors in singleplayer mode
      // Game must work completely offline
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const GameScreen()),
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _createMultiplayerGame() async {
    setState(() => _isLoading = true);

    try {
      // Navigate to lobby screen in create mode
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                const MultiplayerLobbyScreen(mode: LobbyMode.create),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to create game. Please try again.');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _joinMultiplayerGame() async {
    setState(() => _isLoading = true);

    try {
      // Navigate to lobby screen in join mode
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                const MultiplayerLobbyScreen(mode: LobbyMode.join),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to join game. Please try again.');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showGameInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: BalatroTheme.neonPink.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        title: Text(
          'Hand & Foot Rules',
          style: Theme.of(
            context,
          ).textTheme.headlineLarge?.copyWith(color: BalatroTheme.neonBlue),
        ),
        content: SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRuleSection(
                  'OBJECTIVE',
                  'Be the first to get rid of all cards in your hand and foot pile by creating melds.',
                ),
                _buildRuleSection(
                  'SETUP',
                  'Each player gets 13 cards in hand and 13 in foot pile. Draw 2 cards each turn.',
                ),
                _buildRuleSection(
                  'MELDS',
                  'Create groups of 3+ cards of the same rank. Wild cards (2s and Jokers) can substitute, but cannot exceed natural cards.',
                ),
                _buildRuleSection(
                  'GOING OUT',
                  'To win a round, you need both a clean book (7+ cards, no wilds) and a dirty book (7+ cards with wilds), then discard your last card.',
                ),
                _buildRuleSection(
                  'SCORING',
                  'Cards in melds add points. Cards in hand/foot subtract points. Books give bonus points.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Got it!',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleSection(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: BalatroTheme.neonPink,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
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
