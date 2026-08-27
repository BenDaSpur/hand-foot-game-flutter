import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ads/ads_service.dart';
import 'screens/main_menu_screen.dart';
import 'services/firebase_service.dart';
import 'services/analytics_config_service.dart';
import 'services/haptic_service.dart';
import 'services/web_deploy_version_service.dart';
import 'theme/balatro_theme.dart';
import 'widgets/web_app_update_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prevent mobile browser long-press menus (Find in Page, text selection)
  // from interrupting card taps during gameplay.
  if (kIsWeb) {
    try {
      await BrowserContextMenu.disableContextMenu();
    } catch (e) {
      debugPrint('Failed to disable browser context menu: $e');
    }
  }

  // Skip font preloading during integration tests to avoid binding conflicts
  if (!kIsWeb) {
    // Only preload fonts in native apps, skip in web/test environments
    try {
      await GoogleFonts.pendingFonts([
        GoogleFonts.arimo(),
        GoogleFonts.arimo(fontWeight: FontWeight.bold),
        GoogleFonts.arimo(fontWeight: FontWeight.w600),
        GoogleFonts.arimo(fontWeight: FontWeight.w300),
      ]);
    } catch (e) {
      // Font preloading failed - continue with system fonts as fallback
      debugPrint('Font preloading failed: $e');
    }
  }

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

    // Clean up expired waiting lobbies and finished/cancelled games
    FirebaseService.cleanupExpiredGames();
    FirebaseService.cleanupCompletedGames();
  } catch (e) {
    // Continue without Firebase - this is normal for local development
    // Only log in debug mode to avoid production noise
    if (kDebugMode) {
      print('Firebase initialization failed, continuing without analytics');
    }
  }

  // Consent + ads init must not block first frame. No-op on web/desktop.
  unawaited(AdsService.instance.initialize());
  unawaited(HapticService().initialize());

  runApp(const ProviderScope(child: HandAndFootApp()));
}

class HandAndFootApp extends StatefulWidget {
  const HandAndFootApp({super.key});

  @override
  State<HandAndFootApp> createState() => _HandAndFootAppState();
}

class _HandAndFootAppState extends State<HandAndFootApp> {
  final WebDeployVersionService _deployVersionService =
      WebDeployVersionService();
  bool _updateAvailable = false;

  @override
  void initState() {
    super.initState();
    _deployVersionService.start(
      onUpdateAvailable: () {
        if (!mounted || _updateAvailable) {
          return;
        }
        setState(() {
          _updateAvailable = true;
        });
      },
    );
  }

  @override
  void dispose() {
    _deployVersionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hand & Foot Card Game',
      debugShowCheckedModeBanner: false,
      theme: BalatroTheme.darkTheme,
      builder: (context, child) {
        if (!_updateAvailable || child == null) {
          return child ?? const SizedBox.shrink();
        }

        return Stack(children: [child, const WebAppUpdateBanner()]);
      },
      home: const MainMenuScreen(),
    );
  }
}
