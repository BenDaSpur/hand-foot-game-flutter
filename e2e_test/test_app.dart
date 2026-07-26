import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hand_foot_game_flutter/screens/game_screen.dart';
import 'package:hand_foot_game_flutter/theme/balatro_theme.dart';

/// Test-specific app with deterministic game state.
class TestApp extends StatelessWidget {
  final int? seed;

  const TestApp({super.key, this.seed});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Hand & Foot Test App',
        theme: BalatroTheme.testTheme, // Use test-safe theme
        home: GameScreen(testSeed: seed),
      ),
    );
  }
}
