import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'screens/main_menu_screen.dart';
import 'services/firebase_service.dart';
import 'services/analytics_config_service.dart';
import 'theme/balatro_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Try to initialize Firebase and analytics, but continue gracefully if they fail
  try {
    await FirebaseService.initialize();
    await AnalyticsConfigService.initialize();

    // Log app startup event for analytics
    await FirebaseService.logGameEvent(
      'app_startup',
      parameters: {
        'platform': kIsWeb ? 'web' : 'mobile',
        'debug_mode': kDebugMode,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    // Clean up expired games on app startup
    FirebaseService.cleanupExpiredGames();
  } catch (e) {
    // Continue without Firebase - this is normal for local development
    // Only log in debug mode to avoid production noise
    if (kDebugMode) {
      print('Firebase initialization failed, continuing without analytics');
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
      home: const MainMenuScreen(),
    );
  }
}
