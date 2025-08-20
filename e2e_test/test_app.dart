import 'package:flutter/material.dart';
import 'package:hand_foot_game_flutter/screens/game_screen.dart';
import 'package:hand_foot_game_flutter/theme/balatro_theme.dart';

/// Test-specific app with deterministic game state
class TestApp extends StatelessWidget {
  final int? seed;

  const TestApp({super.key, this.seed});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hand & Foot Test App',
      theme: BalatroTheme.darkTheme,
      home: GameScreen(testSeed: seed),
    );
  }
}
