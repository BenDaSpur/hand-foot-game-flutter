import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/game_config.dart';
import '../config/project_links.dart';
import '../config/solo_game_settings.dart';
import '../theme/balatro_theme.dart';
import '../utils/debug_logger.dart';
import 'game_screen.dart';
import 'learn_to_play_screen.dart';
import 'multiplayer_lobby_screen.dart';
import 'privacy_policy_screen.dart';
import 'solo_game_setup_screen.dart';
import 'multiplayer_game_screen.dart';
import '../ads/ads_banner.dart';
import '../ads/ads_service.dart';
import '../services/firebase_service.dart';
import '../services/game_save_service.dart';
import '../services/multiplayer_resume_service.dart';
import '../models/player.dart';

/// Layout and styling constants for main menu buttons.
abstract final class _MenuButtonLayout {
  static const double width = 320;
  static const double height = 80;
  static const double horizontalMargin = 20;
  static const double borderRadius = 12;
  static const double iconContainerRadius = 8;
  static const double primaryBorderWidth = 2;
  static const double secondaryBorderWidth = 1;
  static const double primaryShadowBlur = 12;
  static const double secondaryShadowBlur = 8;
  static const Offset shadowOffset = Offset(0, 4);
  static const double contentPadding = 16;
  static const double iconContainerPadding = 8;
  static const double iconSpacing = 16;
  static const double labelDescriptionGap = 2;
  static const double mainIconSize = 24;
  static const double arrowIconSize = 16;
  static const double settingsIconSize = 22;
  static const double labelFontSize = 18;
  static const double descriptionFontSize = 12;
  static const double dividerWidth = 1;
  static const double dividerHeight = 48;
  static const double settingsButtonMinSize = 48;
  static const double settingsButtonHorizontalPadding = 12;

  static const double primaryBackgroundAlpha = 0.2;
  static const double primaryBorderAlpha = 0.6;
  static const double secondaryBorderAlpha = 0.3;
  static const double primaryShadowAlpha = 0.5;
  static const double primaryIconBackgroundAlpha = 0.3;
  static const double secondaryIconBackgroundAlpha = 0.2;
  static const double descriptionTextAlpha = 0.7;
  static const double dividerAlpha = 0.3;
}

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key, this.urlLauncher, bool? isWeb})
    : isWeb = isWeb ?? kIsWeb;

  /// Optional launcher override for tests. Defaults to [launchUrl].
  final Future<bool> Function(Uri uri)? urlLauncher;

  /// Whether web-only links (iOS App Store, PWA install) are shown.
  /// Defaults to [kIsWeb]; override in tests.
  final bool isWeb;

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  bool _isLoading = false;
  bool _hasSavedSinglePlayerGame = false;
  bool _multiplayerAvailable = false;
  Map<String, dynamic>? _rejoinableGame;

  bool _didAttemptAutoResume = false;

  @override
  void initState() {
    super.initState();
    _checkForSavedSinglePlayerGame();
    _multiplayerAvailable = FirebaseService.isMultiplayerAvailable;
    _attemptAutoResumeOrOfferRejoin();
  }

  /// Jackbox-style: auto-resume when bookmark + Auth UID still match a live game.
  /// Falls back to showing the REJOIN GAME button if auto-nav fails.
  void _attemptAutoResumeOrOfferRejoin() async {
    if (_didAttemptAutoResume) {
      return;
    }
    _didAttemptAutoResume = true;

    if (!_multiplayerAvailable) {
      return;
    }

    try {
      final autoResume = await MultiplayerResumeService.attemptAutoResume();
      if (autoResume != null && mounted) {
        _navigateToResumedGame(autoResume);
        return;
      }

      final rejoinOpportunity =
          await MultiplayerResumeService.checkForRejoinOpportunity();
      if (rejoinOpportunity != null && mounted) {
        setState(() {
          _rejoinableGame = rejoinOpportunity;
        });
      }
    } catch (e) {
      debugPrint('Error checking for rejoinable games: $e');
    }
  }

  void _navigateToResumedGame(MultiplayerResumeResult result) {
    if (result.isWaiting) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MultiplayerLobbyScreen.resume(
            controller: result.controller,
            playerName: result.playerName,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) =>
            MultiplayerGameScreen(gameController: result.controller),
      ),
    );
  }

  /// Check if there's a saved single player game against bots
  void _checkForSavedSinglePlayerGame() async {
    try {
      final savedGameData = await GameSaveService.loadGame();
      if (savedGameData != null) {
        final players = savedGameData['players'] as List?;
        if (players != null) {
          // Check if this is a single player game (1 human + bots)
          int humanPlayerCount = 0;
          int botPlayerCount = 0;

          for (final playerData in players) {
            final playerType = playerData['type'] as String?;
            if (playerType == PlayerType.human.name) {
              humanPlayerCount++;
            } else if (playerType == PlayerType.bot.name) {
              botPlayerCount++;
            }
          }

          // This is a single player game if there's exactly 1 human and the rest are bots
          if (humanPlayerCount == 1 && botPlayerCount > 0) {
            setState(() {
              _hasSavedSinglePlayerGame = true;
            });
          }
        }
      }
    } catch (e) {
      // If loading fails, just don't show the continue button
    }
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
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Game Title
                        Container(
                          margin: const EdgeInsets.only(bottom: 60),
                          child: Column(
                            children: [
                              Text(
                                'HAND & FOOT',
                                style: Theme.of(context).textTheme.displayLarge
                                    ?.copyWith(
                                      color: BalatroTheme.neonBlue,
                                      shadows: [
                                        Shadow(
                                          color: BalatroTheme.neonBlue
                                              .withValues(alpha: 0.5),
                                          blurRadius: 20,
                                        ),
                                      ],
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'CARD GAME',
                                style: Theme.of(context).textTheme.displaySmall
                                    ?.copyWith(
                                      color: BalatroTheme.neonPink,
                                      letterSpacing: 4,
                                    ),
                              ),
                            ],
                          ),
                        ),

                        // Menu Options
                        if (_isLoading)
                          const CircularProgressIndicator(
                            color: BalatroTheme.neonBlue,
                          )
                        else
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Continue button (only shown if saved single player game exists)
                              if (_hasSavedSinglePlayerGame) ...[
                                _buildMenuButton(
                                  icon: Icons.play_arrow,
                                  label: 'CONTINUE',
                                  description: 'Resume your saved game',
                                  onPressed: _continueSavedGame,
                                  isPrimary: true,
                                ),
                                const SizedBox(height: 20),
                              ],
                              if (_rejoinableGame != null &&
                                  _multiplayerAvailable) ...[
                                _buildMenuButton(
                                  icon: Icons.wifi,
                                  label: 'REJOIN GAME',
                                  description:
                                      'Reconnect to ${_rejoinableGame!['gameId']}',
                                  onPressed: _rejoinMultiplayerGame,
                                  isPrimary: true,
                                ),
                                const SizedBox(height: 20),
                              ],
                              _buildMenuButton(
                                icon: Icons.person,
                                label: 'PLAY SOLO',
                                description: 'Play against AI opponents',
                                onPressed: _startSoloGame,
                                onSettingsPressed: _openSoloGameSettings,
                              ),
                              const SizedBox(height: 20),
                              _buildMenuButton(
                                icon: Icons.school,
                                label: 'LEARN TO PLAY',
                                description:
                                    'Guided lesson for rules and controls',
                                onPressed: _startLearnToPlay,
                              ),
                              const SizedBox(height: 20),
                              _buildMenuButton(
                                icon: Icons.group_add,
                                label: 'CREATE GAME',
                                description: _multiplayerAvailable
                                    ? 'Host a multiplayer game'
                                    : 'Multiplayer requires Firebase configuration',
                                onPressed: _multiplayerAvailable
                                    ? _createMultiplayerGame
                                    : _showMultiplayerUnavailable,
                              ),
                              const SizedBox(height: 20),
                              _buildMenuButton(
                                icon: Icons.group,
                                label: 'JOIN GAME',
                                description: _multiplayerAvailable
                                    ? 'Join an existing game'
                                    : 'Multiplayer requires Firebase configuration',
                                onPressed: _multiplayerAvailable
                                    ? _joinMultiplayerGame
                                    : _showMultiplayerUnavailable,
                              ),
                              const SizedBox(height: 40),
                              _buildInfoButton(),
                              const SizedBox(height: 16),
                              _buildGitHubButton(),
                              if (widget.isWeb) ...[
                                const SizedBox(height: 16),
                                _buildIosAppStoreButton(),
                                const SizedBox(height: 16),
                                _buildInstallButton(),
                              ],
                              const SizedBox(height: 16),
                              _buildPrivacyButton(),
                              ListenableBuilder(
                                listenable: AdsService.instance,
                                builder: (context, _) {
                                  if (!AdsService
                                      .instance
                                      .shouldShowPrivacyOptions) {
                                    return const SizedBox.shrink();
                                  }
                                  return Column(
                                    children: [
                                      const SizedBox(height: 8),
                                      _buildPrivacyOptionsButton(),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const AdsBanner(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onPressed,
    VoidCallback? onSettingsPressed,
    bool isPrimary = false,
  }) {
    final accentColor = isPrimary
        ? BalatroTheme.neonBlue
        : BalatroTheme.neonPink;

    return Container(
      width: _MenuButtonLayout.width,
      height: _MenuButtonLayout.height,
      margin: const EdgeInsets.symmetric(
        horizontal: _MenuButtonLayout.horizontalMargin,
      ),
      decoration: BoxDecoration(
        color: isPrimary
            ? BalatroTheme.neonBlue.withValues(
                alpha: _MenuButtonLayout.primaryBackgroundAlpha,
              )
            : BalatroTheme.cardBackground,
        borderRadius: BorderRadius.circular(_MenuButtonLayout.borderRadius),
        border: Border.all(
          color: isPrimary
              ? BalatroTheme.neonBlue.withValues(
                  alpha: _MenuButtonLayout.primaryBorderAlpha,
                )
              : BalatroTheme.neonPink.withValues(
                  alpha: _MenuButtonLayout.secondaryBorderAlpha,
                ),
          width: isPrimary
              ? _MenuButtonLayout.primaryBorderWidth
              : _MenuButtonLayout.secondaryBorderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: isPrimary
                ? BalatroTheme.neonBlue.withValues(
                    alpha: _MenuButtonLayout.primaryShadowAlpha,
                  )
                : BalatroTheme.neonPink.withValues(
                    alpha: _MenuButtonLayout.secondaryBorderAlpha,
                  ),
            blurRadius: isPrimary
                ? _MenuButtonLayout.primaryShadowBlur
                : _MenuButtonLayout.secondaryShadowBlur,
            offset: _MenuButtonLayout.shadowOffset,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(
                  _MenuButtonLayout.borderRadius,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(
                    _MenuButtonLayout.contentPadding,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(
                          _MenuButtonLayout.iconContainerPadding,
                        ),
                        decoration: BoxDecoration(
                          color: isPrimary
                              ? BalatroTheme.neonBlue.withValues(
                                  alpha: _MenuButtonLayout
                                      .primaryIconBackgroundAlpha,
                                )
                              : BalatroTheme.neonPink.withValues(
                                  alpha: _MenuButtonLayout
                                      .secondaryIconBackgroundAlpha,
                                ),
                          borderRadius: BorderRadius.circular(
                            _MenuButtonLayout.iconContainerRadius,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: accentColor,
                          size: _MenuButtonLayout.mainIconSize,
                        ),
                      ),
                      const SizedBox(width: _MenuButtonLayout.iconSpacing),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: _MenuButtonLayout.labelFontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(
                              height: _MenuButtonLayout.labelDescriptionGap,
                            ),
                            Flexible(
                              child: Text(
                                description,
                                style: TextStyle(
                                  color: Colors.white.withValues(
                                    alpha:
                                        _MenuButtonLayout.descriptionTextAlpha,
                                  ),
                                  fontSize:
                                      _MenuButtonLayout.descriptionFontSize,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onSettingsPressed == null)
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: BalatroTheme.neonBlue,
                          size: _MenuButtonLayout.arrowIconSize,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (onSettingsPressed != null) ...[
              Container(
                width: _MenuButtonLayout.dividerWidth,
                height: _MenuButtonLayout.dividerHeight,
                color: accentColor.withValues(
                  alpha: _MenuButtonLayout.dividerAlpha,
                ),
              ),
              Tooltip(
                message: 'Game settings',
                child: IconButton(
                  onPressed: onSettingsPressed,
                  icon: Icon(
                    Icons.settings,
                    color: accentColor,
                    size: _MenuButtonLayout.settingsIconSize,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal:
                        _MenuButtonLayout.settingsButtonHorizontalPadding,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: _MenuButtonLayout.settingsButtonMinSize,
                    minHeight: _MenuButtonLayout.settingsButtonMinSize,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoButton() {
    return TextButton(
      onPressed: _showGameInfo,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, color: BalatroTheme.glowColor, size: 16),
          SizedBox(width: 8),
          Text(
            'How to Play',
            style: TextStyle(
              color: BalatroTheme.glowColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGitHubButton() {
    return TextButton(
      onPressed: _openGitHubRepository,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.code,
            color: BalatroTheme.neonPink.withValues(alpha: 0.7),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'View on GitHub',
            style: TextStyle(
              color: BalatroTheme.neonPink.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyButton() {
    return TextButton(
      onPressed: _openPrivacyPolicy,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.privacy_tip_outlined,
            color: Colors.white.withValues(alpha: 0.55),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'Privacy Policy',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyOptionsButton() {
    return TextButton(
      onPressed: () {
        AdsService.instance.showPrivacyOptions();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.tune,
            color: Colors.white.withValues(alpha: 0.55),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'Privacy options',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _openPrivacyPolicy() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
    );
  }

  Future<void> _openGitHubRepository() async {
    await _openExternalLink(
      Uri.parse(ProjectLinks.githubRepository),
      errorMessage: 'Could not open GitHub. Try again later.',
    );
  }

  Future<void> _openIosAppStore() async {
    await _openExternalLink(
      Uri.parse(ProjectLinks.iosAppStore),
      errorMessage: 'Could not open the App Store. Try again later.',
    );
  }

  Future<void> _openExternalLink(
    Uri uri, {
    required String errorMessage,
  }) async {
    try {
      final launcher = widget.urlLauncher;
      final launched = launcher != null
          ? await launcher(uri)
          : await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        DebugLogger.warning('Could not open URL: $uri');
        _showLinkLaunchError(errorMessage);
      }
    } catch (e) {
      DebugLogger.warning('Failed to open URL $uri: $e');
      _showLinkLaunchError(errorMessage);
    }
  }

  void _showLinkLaunchError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: BalatroTheme.snackBarContentOnBright),
        ),
        backgroundColor: BalatroTheme.neonPink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildIosAppStoreButton() {
    return TextButton(
      onPressed: _openIosAppStore,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.phone_iphone,
            color: BalatroTheme.neonOrange.withValues(alpha: 0.85),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'Get on iOS',
            style: TextStyle(
              color: BalatroTheme.neonOrange.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallButton() {
    return TextButton(
      onPressed: _showInstallInstructions,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.download_rounded,
            color: BalatroTheme.neonGreen.withValues(alpha: 0.7),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'Install App',
            style: TextStyle(
              color: BalatroTheme.neonGreen.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showInstallInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: BalatroTheme.neonGreen.withValues(alpha: 0.3),
          ),
        ),
        title: const Row(
          children: [
            Icon(Icons.download_rounded, color: BalatroTheme.neonGreen),
            SizedBox(width: 12),
            Text('Install App', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Install this game on your device for offline play!\n',
                style: TextStyle(color: Colors.white70),
              ),
              _buildInstallSection(
                '🍎 iPhone / iPad (Safari only)',
                [
                  '1. Open this page in Safari',
                  '2. Tap the Share button (📤)',
                  '3. Scroll down and tap "Add to Home Screen"',
                  '4. Tap "Add"',
                ],
                note:
                    '⚠️ iOS only allows PWA installs from Safari.\nFirefox/Chrome cannot install apps on iOS.',
              ),
              const SizedBox(height: 16),
              _buildInstallSection('🤖 Android (Chrome)', [
                '1. Tap the menu (⋮) in Chrome',
                '2. Tap "Add to Home screen" or "Install app"',
                '3. Tap "Install"',
              ]),
              const SizedBox(height: 16),
              _buildInstallSection('💻 Desktop (Chrome/Edge)', [
                '1. Look for the install icon (⊕) in the address bar',
                '2. Click "Install"',
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it!',
              style: TextStyle(color: BalatroTheme.neonGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallSection(
    String title,
    List<String> steps, {
    String? note,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ...steps.map(
          (step) => Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text(
              step,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Text(
              note,
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  void _continueSavedGame() async {
    setState(() => _isLoading = true);

    try {
      final savedGameData = await GameSaveService.loadGame();
      if (savedGameData != null) {
        final gameController = GameSaveService.restoreGameController(
          savedGameData,
        );
        if (gameController != null) {
          // Log continue game event - completely optional, never crash singleplayer
          try {
            await FirebaseService.logGameEvent(
              'solo_game_continued',
              parameters: {'game_type': 'solo_continue'},
            );
          } catch (e) {
            // Silently ignore Firebase errors in singleplayer mode
            // Game must work completely offline
          }

          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) =>
                    GameScreen(gameController: gameController),
              ),
            );
          }
        } else {
          // Failed to restore game, show error and refresh menu state
          if (mounted) {
            _showErrorDialog(
              'Failed to load saved game. The save file may be corrupted.',
            );
            setState(() {
              _hasSavedSinglePlayerGame = false;
            });
          }
        }
      } else {
        // No saved game found, refresh menu state
        if (mounted) {
          setState(() {
            _hasSavedSinglePlayerGame = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error loading saved game: ${e.toString()}');
        setState(() {
          _hasSavedSinglePlayerGame = false;
        });
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Rejoin an active multiplayer game after crash/disconnect
  void _rejoinMultiplayerGame() async {
    if (_rejoinableGame == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final gameId = _rejoinableGame!['gameId'] as String;
      final playerName = _rejoinableGame!['playerName'] as String;

      final result = await MultiplayerResumeService.rejoinGameWithStatus(
        gameId: gameId,
        playerName: playerName,
      );

      if (result != null && mounted) {
        setState(() {
          _rejoinableGame = null;
        });
        _navigateToResumedGame(result);
      } else {
        // Failed to rejoin - clear stale data and show error
        await MultiplayerResumeService.clearActiveGame();
        setState(() {
          _rejoinableGame = null;
        });

        if (mounted) {
          _showErrorDialog(
            'Unable to rejoin game. The game may have ended or you may have been disconnected.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to rejoin game: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startSoloGame() async {
    setState(() => _isLoading = true);

    try {
      final settings = await SoloGameSettings.loadFromPreferences();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => GameScreen(
              settings: settings,
              launchOptions: const SoloGameLaunchOptions(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to start game: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startLearnToPlay() {
    _openLearnToPlay();
  }

  void _openLearnToPlay() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const LearnToPlayScreen()));
  }

  void _openSoloGameSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SoloGameSetupScreen()),
    );
  }

  void _createMultiplayerGame() async {
    setState(() => _isLoading = true);

    try {
      // Navigate to lobby screen in create mode
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                const MultiplayerLobbyScreen(mode: LobbyMode.create),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to create game. Please try again.');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _joinMultiplayerGame() async {
    setState(() => _isLoading = true);

    try {
      // Navigate to lobby screen in join mode
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                const MultiplayerLobbyScreen(mode: LobbyMode.join),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to join game. Please try again.');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showGameInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: BalatroTheme.neonPink.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        title: Text(
          'Hand & Foot Rules',
          style: Theme.of(
            context,
          ).textTheme.headlineLarge?.copyWith(color: BalatroTheme.neonBlue),
        ),
        content: SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRuleSection(
                  'OBJECTIVE',
                  'Be the first to get rid of all cards in your hand and foot pile by creating melds.',
                ),
                _buildRuleSection(
                  'SETUP',
                  'Each player gets ${GameConfig.handSize} cards in hand and '
                      '${GameConfig.footSize} in the foot pile. Draw '
                      '${GameConfig.requiredDrawCount} cards each turn. The deal '
                      'mini-game is the only time you might pick up a different '
                      'number of cards.',
                ),
                _buildRuleSection(
                  'MELDS',
                  'Create groups of 3+ cards of the same rank. Wild cards (2s and Jokers) can substitute, but cannot exceed natural cards.',
                ),
                _buildRuleSection(
                  'GOING OUT',
                  'To win a round, you need both a clean book (7+ cards, no wilds) and a dirty book (7+ cards with wilds), then discard your last card.',
                ),
                _buildRuleSection(
                  'SCORING',
                  'Cards in melds add points. Cards in hand/foot subtract points. Books give bonus points.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Got it!',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleSection(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: BalatroTheme.neonPink,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  void _showMultiplayerUnavailable() {
    _showErrorDialog(
      'Multiplayer requires Firebase configuration. Solo play works offline.',
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.3), width: 1),
        ),
        title: const Text(
          'Error',
          style: TextStyle(
            color: Colors.red,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: TextStyle(color: BalatroTheme.neonBlue)),
          ),
        ],
      ),
    );
  }
}
