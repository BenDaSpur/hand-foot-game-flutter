import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/player.dart';
import '../../models/card.dart';
import '../../game/game_controller.dart';
import '../../widgets/advanced_meld_selector.dart';
import '../../widgets/emergency_round_end_dialog.dart';
import '../../widgets/scoreboard_modal.dart';
import '../../theme/balatro_theme.dart';

/// Manages all dialogs and modals for the game screen.
///
/// This class handles the presentation of various dialogs including
/// error dialogs, game end dialogs, meld selectors, and info modals.
/// Extracted from GameScreen to improve code organization.
class DialogManager {
  final BuildContext context;
  final GameController gameController;
  final Function() onStateChanged;
  final Function() onNewGame;
  final Function() onReturnToMenu;

  DialogManager({
    required this.context,
    required this.gameController,
    required this.onStateChanged,
    required this.onNewGame,
    required this.onReturnToMenu,
  });

  /// Show error dialog with themed styling
  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BalatroTheme.glowColor, width: 2),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: BalatroTheme.heartsColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Error',
              style: GoogleFonts.arimo(
                color: BalatroTheme.heartsColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: BalatroTheme.heartsColor.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }

  /// Show critical error dialog with recovery options
  void showCriticalErrorDialog(String error, VoidCallback onRecover) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BalatroTheme.heartsColor, width: 2),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.warning,
              color: BalatroTheme.heartsColor,
              size: 32,
            ),
            const SizedBox(width: 12),
            Text(
              'CRITICAL ERROR',
              style: GoogleFonts.arimo(
                color: BalatroTheme.heartsColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: BalatroTheme.heartsColor.withValues(alpha: 0.8),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'A critical error occurred that may prevent the game from continuing normally.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BalatroTheme.deepPurple.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: BalatroTheme.heartsColor.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                error,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: onRecover,
            child: const Text(
              'Try Recovery',
              style: TextStyle(color: BalatroTheme.neonYellow),
            ),
          ),
          TextButton(
            onPressed: onNewGame,
            child: const Text(
              'New Game',
              style: TextStyle(color: BalatroTheme.neonGreen),
            ),
          ),
          TextButton(
            onPressed: onReturnToMenu,
            child: const Text(
              'Main Menu',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }

  /// Show new game confirmation dialog
  void showNewGameConfirmation(VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BalatroTheme.glowColor, width: 2),
        ),
        title: Row(
          children: [
            const Icon(Icons.refresh, color: BalatroTheme.neonYellow, size: 28),
            const SizedBox(width: 12),
            Text(
              'New Game',
              style: GoogleFonts.arimo(
                color: BalatroTheme.neonYellow,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: BalatroTheme.neonYellow.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to start a new game? Current progress will be lost.',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: const Text(
              'Start New Game',
              style: TextStyle(color: BalatroTheme.heartsColor),
            ),
          ),
        ],
      ),
    );
  }

  /// Show game end dialog when someone reaches winning score
  void showGameEndDialog(Player winner, List<Player> players) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BalatroTheme.glowColor, width: 2),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.emoji_events,
              color: BalatroTheme.neonYellow,
              size: 32,
            ),
            const SizedBox(width: 12),
            Text(
              'GAME WINNER!',
              style: TextStyle(
                color: BalatroTheme.neonYellow,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: BalatroTheme.neonYellow.withValues(alpha: 0.8),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${winner.name} wins with ${winner.score} points!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Final Scores:',
              style: const TextStyle(
                color: BalatroTheme.neonPink,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...players.map(
              (player) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${player.name}: ${player.score}',
                  style: TextStyle(
                    color: player == winner
                        ? BalatroTheme.neonGreen
                        : Colors.white70,
                    fontWeight: player == winner
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onNewGame();
            },
            child: const Text(
              'New Game',
              style: TextStyle(color: BalatroTheme.neonGreen),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              showScoreboard();
            },
            child: const Text(
              'Scoreboard',
              style: TextStyle(color: BalatroTheme.neonPink),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onReturnToMenu();
            },
            child: const Text(
              'Exit',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }

  /// Show detailed scoreboard with round-by-round breakdown
  void showScoreboard() {
    showDialog(
      context: context,
      builder: (context) =>
          ScoreboardModal(gameState: gameController.gameState),
    );
  }

  /// Show emergency round end dialog
  void showEmergencyRoundEndDialog() {
    EmergencyRoundEndDialog.show(
      context,
      onContinue: () {
        Navigator.of(context).pop();
        onStateChanged();
      },
    );
  }

  /// Show advanced meld selector modal
  void showAdvancedMeldSelector({
    required Function(List<List<int>>) onMeldsCreated,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdvancedMeldSelector(
        player: gameController.gameState.currentPlayer,
        playDownRequirement: gameController.gameState.playDownRequirement,
        onCancel: () {
          Navigator.of(context).pop();
        },
        onConfirm: (meldIndices) {
          Navigator.of(context).pop();
          onMeldsCreated(meldIndices);
        },
      ),
    );
  }

  /// Show wild card confirmation for meld creation
  void showWildCardConfirmation({
    required List<PlayingCard> selectedCards,
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
  }) {
    final wildCards = selectedCards.where((card) => card.isWild).toList();
    final naturalCards = selectedCards.where((card) => !card.isWild).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BalatroTheme.glowColor, width: 2),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.auto_fix_high,
              color: BalatroTheme.neonYellow,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Wild Card Meld',
              style: TextStyle(
                color: BalatroTheme.neonYellow,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: BalatroTheme.neonYellow.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Creating meld with ${wildCards.length} wild card(s) and ${naturalCards.length} natural card(s).',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BalatroTheme.deepPurple.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: BalatroTheme.glowColor.withValues(alpha: 0.3),
                ),
              ),
              child: const Text(
                'Wild cards (2s and Jokers) can substitute for natural cards, but wild cards cannot exceed natural cards in any meld.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onCancel();
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: BalatroTheme.heartsColor),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: const Text(
              'Create Meld',
              style: TextStyle(color: BalatroTheme.neonGreen),
            ),
          ),
        ],
      ),
    );
  }

  /// Show exported game dialog
  void showExportedGameDialog(String gameStateBase64) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BalatroTheme.glowColor, width: 2),
        ),
        title: Row(
          children: [
            const Icon(Icons.download, color: BalatroTheme.neonGreen, size: 28),
            const SizedBox(width: 12),
            Text(
              'Game Exported',
              style: TextStyle(
                color: BalatroTheme.neonGreen,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: BalatroTheme.neonGreen.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your game save has been copied to the clipboard. Share this text to transfer your game to another device:',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 12),
              const Text(
                'This compact save uses an optimized format for easy sharing. Mobile/desktop versions use gzip compression for maximum size reduction.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.maxFinite,
                height: 300,
                child: SingleChildScrollView(
                  child: SelectableText(
                    gameStateBase64,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }

  /// Show load game dialog
  void showLoadGameDialog(Function(String) onLoadJson) {
    final TextEditingController textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BalatroTheme.glowColor, width: 2),
        ),
        title: Row(
          children: [
            const Icon(Icons.upload, color: BalatroTheme.neonBlue, size: 28),
            const SizedBox(width: 12),
            Text(
              'Load Game Save',
              style: TextStyle(
                color: BalatroTheme.neonBlue,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: BalatroTheme.neonBlue.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste your game save (supports all formats: ultra-compact, base64, or JSON):',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: textController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Paste your game save here...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: BalatroTheme.glowColor,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: BalatroTheme.glowColor.withValues(alpha: 0.5),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: BalatroTheme.neonBlue,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: BalatroTheme.deepPurple.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: BalatroTheme.heartsColor),
            ),
          ),
          TextButton(
            onPressed: () async {
              final inputText = textController.text.trim();
              if (inputText.isNotEmpty) {
                Navigator.of(context).pop();
                onLoadJson(inputText);
              } else {
                showErrorDialog(
                  'Please paste a valid game save (Base64 or JSON).',
                );
              }
            },
            child: const Text(
              'Load Game',
              style: TextStyle(color: BalatroTheme.neonGreen),
            ),
          ),
        ],
      ),
    );
  }

  /// Show how to play dialog with bot personality information
  void showHowToPlayDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BalatroTheme.glowColor, width: 2),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.help_outline,
              color: BalatroTheme.neonPink,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'How to Play',
              style: TextStyle(
                color: BalatroTheme.neonPink,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: BalatroTheme.neonPink.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRulesSection(),
                const SizedBox(height: 20),
                _buildPersonalitiesSection(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Got it!',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Game Rules',
          style: TextStyle(
            color: BalatroTheme.neonYellow,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildRuleItem('🎯', 'Goal', 'Be first to reach 8,500 points!'),
        _buildRuleItem('📋', 'Melds', 'Groups of 3+ cards of same rank'),
        _buildRuleItem(
          '📚',
          'Books',
          '7+ card melds (500 pts clean, 300 pts dirty)',
        ),
        _buildRuleItem(
          '🃏',
          'Wild Cards',
          '2s and Jokers substitute for naturals',
        ),
        _buildRuleItem('🚫', 'Restrictions', 'Wilds ≤ naturals in any meld'),
        _buildRuleItem('🎲', 'Play Down', 'Round 1: 60 pts, +30 each round'),
        _buildRuleItem('🏁', 'Going Out', 'Need both clean AND dirty book'),
      ],
    );
  }

  Widget _buildPersonalitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bot Personalities',
          style: TextStyle(
            color: BalatroTheme.neonBlue,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildPersonalityDescription(
          Icons.security,
          'Conservative',
          'Plays cautiously, holds cards longer, avoids risky moves',
        ),
        _buildPersonalityDescription(
          Icons.flash_on,
          'Aggressive',
          'Quick play-downs, frequent unlocks, takes more risks',
        ),
        _buildPersonalityDescription(
          Icons.library_books,
          'Book Builder',
          'Focuses on completing books for maximum point bonuses',
        ),
        _buildPersonalityDescription(
          Icons.psychology,
          'Adaptive',
          'Changes strategy based on game state and opponent threats',
        ),
      ],
    );
  }

  Widget _buildRuleItem(String emoji, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  TextSpan(
                    text: description,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalityDescription(
    IconData icon,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: BalatroTheme.neonPink, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(
                      color: BalatroTheme.neonPink,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  TextSpan(
                    text: description,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
