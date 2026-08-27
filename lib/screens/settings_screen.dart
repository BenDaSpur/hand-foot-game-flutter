import 'package:flutter/material.dart';

import '../services/haptic_service.dart';
import '../theme/balatro_theme.dart';

/// App-wide preferences, including mobile vibration feedback.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final HapticService _hapticService = HapticService();
  bool _isLoading = true;
  bool _hapticsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _hapticService.initialize();
    if (!mounted) {
      return;
    }
    setState(() {
      _hapticsEnabled = _hapticService.hapticsEnabled;
      _isLoading = false;
    });
  }

  Future<void> _setHapticsEnabled(bool enabled) async {
    setState(() {
      _hapticsEnabled = enabled;
    });
    await _hapticService.setHapticsEnabled(enabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BalatroTheme.deepPurple,
      appBar: AppBar(
        backgroundColor: BalatroTheme.darkPurple,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: BalatroTheme.neonBlue,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: BalatroTheme.glowColor),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
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
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
                      children: [
                        Text(
                          'FEEDBACK',
                          style: TextStyle(
                            color: BalatroTheme.neonPink,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildToggleCard(
                          key: const Key('haptics_toggle'),
                          icon: Icons.vibration,
                          title: 'Vibrations',
                          subtitle:
                              'Tiny taps when you select cards, play moves, '
                              'and play Perfect Grab. Works on phones and '
                              'tablets that support haptics.',
                          value: _hapticsEnabled,
                          onChanged: _setHapticsEnabled,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildToggleCard({
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Material(
      key: key,
      color: BalatroTheme.cardBackground,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: BalatroTheme.neonPink.withValues(alpha: 0.3),
          ),
        ),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(icon, color: BalatroTheme.neonGreen),
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
      ),
    );
  }
}
