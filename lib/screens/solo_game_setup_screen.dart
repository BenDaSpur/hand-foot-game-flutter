import 'package:flutter/material.dart';

import '../ai/bot_personality.dart';
import '../config/bot_configurations.dart';
import '../config/game_config.dart';
import '../config/solo_game_settings.dart';
import '../theme/balatro_theme.dart';
import 'game_screen.dart';

/// Pre-game configuration screen for solo play.
class SoloGameSetupScreen extends StatefulWidget {
  const SoloGameSetupScreen({super.key});

  @override
  State<SoloGameSetupScreen> createState() => _SoloGameSetupScreenState();
}

class _SoloGameSetupScreenState extends State<SoloGameSetupScreen> {
  late SoloGameSettings _settings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await SoloGameSettings.loadFromPreferences();
    if (mounted) {
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    }
  }

  void _setBotCount(int count) {
    setState(() {
      _settings = _settings.copyWith(botCount: count);
    });
  }

  void _setBotPersonality(int index, BotPersonality personality) {
    final personalities = List<BotPersonality>.from(
      _settings.normalizedPersonalities,
    );
    personalities[index] = personality;
    setState(() {
      _settings = _settings.copyWith(botPersonalities: personalities);
    });
  }

  void _randomizePersonalities() {
    setState(() {
      _settings = _settings.copyWith(
        botPersonalities: SoloGameSettings.randomPersonalities(
          _settings.botCount,
        ),
      );
    });
  }

  Future<void> _startGame() async {
    await _settings.saveToPreferences();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => GameScreen(settings: _settings)),
    );
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
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: BalatroTheme.neonPink,
                  ),
                )
              : Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildBotCountSelector(),
                            const SizedBox(height: 24),
                            _buildBotPersonalitiesSection(),
                            const SizedBox(height: 24),
                            _buildRuleToggle(
                              title:
                                  '+${GameConfig.goingOutBonus} pts to first player out',
                              subtitle:
                                  'Bonus for the player who goes out first each round',
                              value: _settings.enableGoingOutBonus,
                              onChanged: (value) {
                                setState(() {
                                  _settings = _settings.copyWith(
                                    enableGoingOutBonus: value,
                                  );
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildRuleToggle(
                              title: 'One more turn after going out',
                              subtitle:
                                  'Other players each get one final turn after someone goes out',
                              value: _settings.enableFinalTurnAfterGoingOut,
                              onChanged: (value) {
                                setState(() {
                                  _settings = _settings.copyWith(
                                    enableFinalTurnAfterGoingOut: value,
                                  );
                                });
                              },
                            ),
                            const SizedBox(height: 32),
                            _buildStartButton(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(
            'SOLO GAME SETUP',
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

  Widget _buildBotCountSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Number of Bots',
          style: TextStyle(
            color: BalatroTheme.neonPink,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You + ${_settings.botCount} bot${_settings.botCount == 1 ? '' : 's'} = ${_settings.botCount + 1} players',
          style: TextStyle(
            color: BalatroTheme.primaryText.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(SoloGameSettings.maxBotCount, (index) {
            final count = index + 1;
            final isSelected = _settings.botCount == count;
            return Expanded(
              child: GestureDetector(
                onTap: () => _setBotCount(count),
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
                    '$count',
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
          }),
        ),
      ],
    );
  }

  Widget _buildBotPersonalitiesSection() {
    final personalities = _settings.normalizedPersonalities;
    final previewNames = _settings.previewBotNames;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Bot Personalities',
                style: TextStyle(
                  color: BalatroTheme.neonPink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _randomizePersonalities,
              icon: const Icon(Icons.shuffle, color: BalatroTheme.neonBlue),
              label: const Text(
                'Randomize',
                style: TextStyle(color: BalatroTheme.neonBlue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(personalities.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildBotPersonalityRow(
              botNumber: index + 1,
              botName: previewNames[index],
              personality: personalities[index],
              onChanged: (value) {
                if (value != null) {
                  _setBotPersonality(index, value);
                }
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBotPersonalityRow({
    required int botNumber,
    required String botName,
    required BotPersonality personality,
    required ValueChanged<BotPersonality?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: BalatroTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BalatroTheme.neonPink.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bot $botNumber: $botName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<BotPersonality>(
            value: personality,
            dropdownColor: BalatroTheme.darkPurple,
            underline: const SizedBox.shrink(),
            style: const TextStyle(color: Colors.white),
            items: BotPersonality.values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(botPersonalityLabel(value)),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildRuleToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BalatroTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BalatroTheme.neonPink.withValues(alpha: 0.3)),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: BalatroTheme.primaryText.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
        value: value,
        activeThumbColor: BalatroTheme.neonPink,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildStartButton() {
    return ElevatedButton(
      onPressed: _startGame,
      style: ElevatedButton.styleFrom(
        backgroundColor: BalatroTheme.neonPink,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        'START GAME',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
