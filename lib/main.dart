import 'package:flutter/material.dart';
import 'screens/game_screen.dart';
import 'theme/balatro_theme.dart';

void main() {
  runApp(const HandAndFootApp());
}

class HandAndFootApp extends StatelessWidget {
  const HandAndFootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hand & Foot Card Game',
      theme: BalatroTheme.darkTheme,
      home: const GameScreen(),
    );
  }
}
