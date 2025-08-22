import 'package:flutter/material.dart';
import '../theme/balatro_theme.dart';
import 'game_screen.dart';
import 'multiplayer_lobby_screen.dart';
import '../services/firebase_service.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  bool _isLoading = false;

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
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
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
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          color: BalatroTheme.neonPink,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                ),

                // Menu Options
                if (_isLoading)
                  const CircularProgressIndicator(color: BalatroTheme.neonBlue)
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                    ],
                  ),
              ],
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
  }) {
    return Container(
      width: 320,
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: BalatroTheme.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: BalatroTheme.neonPink.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          elevation: 8,
          shadowColor: BalatroTheme.neonPink.withValues(alpha: 0.3),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BalatroTheme.neonPink.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: BalatroTheme.neonPink, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
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

  void _startSoloGame() async {
    setState(() => _isLoading = true);

    // Log solo game start
    await FirebaseService.logGameEvent(
      'solo_game_started',
      parameters: {'game_type': 'solo'},
    );

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const GameScreen()),
      );
    }

    setState(() => _isLoading = false);
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

    setState(() => _isLoading = false);
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

    setState(() => _isLoading = false);
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
          style: TextStyle(
            color: BalatroTheme.neonBlue,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
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
