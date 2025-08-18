import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/game_screen.dart';
import 'theme/balatro_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
