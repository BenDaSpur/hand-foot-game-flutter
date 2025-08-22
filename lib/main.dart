import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'screens/game_screen.dart';
import 'services/firebase_service.dart';
import 'theme/balatro_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only initialize Firebase in non-test environments
  if (!kDebugMode || kIsWeb) {
    try {
      await FirebaseService.initialize();
    } catch (e) {
      print('Firebase initialization failed: $e');
      // Continue without Firebase in test environments
    }
  }

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
