import 'package:flutter/material.dart';
import '../theme/balatro_theme.dart';
import '../models/game_state.dart';
import '../screens/main_menu_screen.dart';
import 'game_session_info_menu.dart';

class GameAppBar extends StatelessWidget implements PreferredSizeWidget {
  final GameState gameState;
  final bool isMultiplayer;
  final Stream<bool>? connectionStream;
  final bool? isOnline;
  final VoidCallback? onNewGame;
  final VoidCallback? onCopySeed;
  final VoidCallback? onExportGame;
  final VoidCallback? onLoadGame;
  final VoidCallback? onHowToPlay;
  final VoidCallback? onLeaveGame;
  final GameSessionInfo? sessionInfo;
  final List<Widget> additionalActions;

  const GameAppBar({
    super.key,
    required this.gameState,
    required this.isMultiplayer,
    this.connectionStream,
    this.isOnline,
    this.onNewGame,
    this.onCopySeed,
    this.onExportGame,
    this.onLoadGame,
    this.onHowToPlay,
    this.onLeaveGame,
    this.sessionInfo,
    this.additionalActions = const [],
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [BalatroTheme.neonPink, BalatroTheme.glowColor],
        ).createShader(bounds),
        child: const Text(
          'HAND & FOOT',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        ...additionalActions,
        // Round indicator
        Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BalatroTheme.glowDecoration(
            glowColor: BalatroTheme.neonGreen,
            backgroundColor: BalatroTheme.darkPurple,
          ),
          child: Text(
            'ROUND ${gameState.round}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: BalatroTheme.neonGreen,
            ),
          ),
        ),

        // Connection status for multiplayer
        if (isMultiplayer && connectionStream != null) ...[
          StreamBuilder<bool>(
            stream: connectionStream,
            initialData: isOnline ?? true,
            builder: (context, snapshot) {
              final isConnected = snapshot.data ?? true;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BalatroTheme.glowDecoration(
                  glowColor: isConnected ? BalatroTheme.neonGreen : Colors.red,
                  backgroundColor: BalatroTheme.darkPurple,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConnected ? Icons.wifi : Icons.wifi_off,
                      color: isConnected ? BalatroTheme.neonGreen : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isConnected ? 'ONLINE' : 'OFFLINE',
                      style: TextStyle(
                        color: isConnected
                            ? BalatroTheme.neonGreen
                            : Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],

        // Menu
        PopupMenuButton<String>(
          onSelected: (String value) {
            switch (value) {
              case 'new_game':
                onNewGame?.call();
                break;
              case 'copy_seed':
                onCopySeed?.call();
                break;
              case 'export_game':
                onExportGame?.call();
                break;
              case 'load_game':
                onLoadGame?.call();
                break;
              case 'how_to_play':
                onHowToPlay?.call();
                break;
              case 'leave_game':
                onLeaveGame?.call();
                break;
              case GameSessionInfoMenu.copyValue:
                if (sessionInfo != null) {
                  GameSessionInfoMenu.copyToClipboard(context, sessionInfo!);
                }
                break;
              case 'main_menu':
                _returnToMainMenu(context);
                break;
            }
          },
          itemBuilder: (BuildContext context) => [
            if (!isMultiplayer) ...[
              const PopupMenuItem<String>(
                value: 'new_game',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.red),
                    SizedBox(width: 8),
                    Text('New Game'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'copy_seed',
                child: Row(
                  children: [
                    Icon(Icons.copy, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Copy Seed'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'export_game',
                child: Row(
                  children: [
                    Icon(Icons.download, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Export Game'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'load_game',
                child: Row(
                  children: [
                    Icon(Icons.upload, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Load Game'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'how_to_play',
                child: Row(
                  children: [
                    Icon(Icons.help_outline, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('How to Play'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
            ] else ...[
              const PopupMenuItem<String>(
                value: 'leave_game',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Leave Game'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
            ],
            const PopupMenuItem<String>(
              value: 'main_menu',
              child: Row(
                children: [
                  Icon(Icons.home, color: BalatroTheme.neonBlue),
                  SizedBox(width: 8),
                  Text('Main Menu'),
                ],
              ),
            ),
            if (sessionInfo != null)
              ...GameSessionInfoMenu.buildItems(sessionInfo!),
          ],
        ),
      ],
    );
  }

  void _returnToMainMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BalatroTheme.neonPink, width: 1),
        ),
        title: const Text(
          'Return to Main Menu',
          style: TextStyle(
            color: BalatroTheme.neonPink,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to return to the main menu? Your current game progress will be lost.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const MainMenuScreen()),
                (route) => false,
              );
            },
            child: const Text(
              'Return to Menu',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }
}
