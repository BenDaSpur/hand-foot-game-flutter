import 'package:flutter/material.dart';
import '../config/game_type_config.dart';
import '../config/game_type_ui_helpers.dart';
import '../theme/balatro_theme.dart';

/// Screen for selecting game type before starting a new game.
///
/// Displays all available game types with their configurations,
/// special rules, and difficulty levels in a visually appealing format.
class GameTypeSelectionScreen extends StatefulWidget {
  final Function(GameType) onGameTypeSelected;

  const GameTypeSelectionScreen({super.key, required this.onGameTypeSelected});

  @override
  State<GameTypeSelectionScreen> createState() =>
      _GameTypeSelectionScreenState();
}

class _GameTypeSelectionScreenState extends State<GameTypeSelectionScreen> {
  GameType? _selectedGameType;

  static const double _cardAspectRatio = 2.5;
  static const double _cardSpacing = 12.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BalatroTheme.deepPurple,
      appBar: AppBar(
        backgroundColor: BalatroTheme.darkPurple,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.casino, color: BalatroTheme.neonPink, size: 28),
            const SizedBox(width: 12),
            Text(
              'Choose Game Type',
              style: TextStyle(
                color: BalatroTheme.neonPink,
                fontSize: 24,
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: BalatroTheme.glowColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [BalatroTheme.darkPurple, BalatroTheme.deepPurple],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Select your preferred game variant with different rules and scoring',
                  style: TextStyle(
                    color: BalatroTheme.primaryText.withValues(alpha: 0.8),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Game type selection grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 1,
                          childAspectRatio: _cardAspectRatio,
                          mainAxisSpacing: _cardSpacing,
                        ),
                    itemCount: GameType.values.length,
                    itemBuilder: (context, index) {
                      final gameType = GameType.values[index];
                      final config = GameTypeConfig.forType(gameType);
                      final displayInfo = config.getDisplayInfo();
                      final isSelected = _selectedGameType == gameType;

                      return _buildGameTypeCard(
                        gameType: gameType,
                        config: config,
                        displayInfo: displayInfo,
                        isSelected: isSelected,
                      );
                    },
                  ),
                ),
              ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _selectedGameType == null
                            ? null
                            : () =>
                                  widget.onGameTypeSelected(_selectedGameType!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BalatroTheme.neonGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_arrow, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              _selectedGameType == null
                                  ? 'Select Game Type'
                                  : 'Start ${_selectedGameType!.displayName}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameTypeCard({
    required GameType gameType,
    required GameTypeConfig config,
    required Map<String, dynamic> displayInfo,
    required bool isSelected,
  }) {
    final difficultyColor = GameTypeUIHelpers.getDifficultyColor(
      config.difficultyLabel,
    );

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGameType = gameType;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? BalatroTheme.lightPurple.withValues(alpha: 0.8)
              : BalatroTheme.cardBackground.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? BalatroTheme.glowColor
                : BalatroTheme.cardBorder.withValues(alpha: 0.5),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: BalatroTheme.glowColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Game type icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: difficultyColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: difficultyColor, width: 2),
              ),
              child: Icon(
                GameTypeUIHelpers.getGameTypeIcon(gameType),
                color: difficultyColor,
                size: 30,
              ),
            ),

            const SizedBox(width: 16),

            // Game info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title and difficulty
                  Row(
                    children: [
                      Text(
                        config.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: difficultyColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: difficultyColor, width: 1),
                        ),
                        child: Text(
                          config.difficultyLabel,
                          style: TextStyle(
                            color: difficultyColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Description
                  Text(
                    config.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Quick stats
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _buildStatChip(
                        displayInfo['deckCount'] as String,
                        Icons.style,
                      ),
                      _buildStatChip(
                        displayInfo['handSize'] as String,
                        Icons.credit_card,
                      ),
                      _buildStatChip(
                        displayInfo['winCondition'] as String,
                        Icons.flag,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Selection indicator
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: BalatroTheme.neonGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: BalatroTheme.neonGreen.withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(Icons.check, color: Colors.black, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: BalatroTheme.deepPurple.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: BalatroTheme.glowColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: BalatroTheme.glowColor, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: BalatroTheme.glowColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
