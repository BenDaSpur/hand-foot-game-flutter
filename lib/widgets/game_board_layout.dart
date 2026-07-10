import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../ai/bot_personality.dart';
import '../constants/ui_constants.dart';
import '../utils/game_responsive_layout.dart';
import 'game_compact_header.dart';
import 'compact_player_scores.dart';
import 'collapsible_recent_actions.dart';

/// Mobile-first game board shell shared by solo and multiplayer screens.
///
/// Layout zones: compact header → player chips → melds (expanded) → bottom dock
/// (actions + hand pinned for thumb reach).
class GameBoardLayout extends StatelessWidget {
  final GameState gameState;
  final Player? viewingPlayerMelds;
  final Function(Player) onPlayerTap;
  final Widget meldsSection;
  final Widget actionButtons;
  final Widget handDisplay;
  final GlobalKey deckKey;
  final GlobalKey discardKey;
  final GlobalKey? meldAreaKey;
  final bool headerExpanded;
  final VoidCallback onHeaderToggle;
  final List<Widget> headerExtras;
  final String? currentUserId;
  final BotPersonalityManager? botPersonalityManager;
  final Widget? aboveMelds;
  final bool useDesktopRecentActions;
  final bool recentActionsExpanded;
  final VoidCallback? onRecentActionsToggle;

  const GameBoardLayout({
    super.key,
    required this.gameState,
    required this.viewingPlayerMelds,
    required this.onPlayerTap,
    required this.meldsSection,
    required this.actionButtons,
    required this.handDisplay,
    required this.deckKey,
    required this.discardKey,
    this.meldAreaKey,
    required this.headerExpanded,
    required this.onHeaderToggle,
    this.headerExtras = const [],
    this.currentUserId,
    this.botPersonalityManager,
    this.aboveMelds,
    this.useDesktopRecentActions = false,
    this.recentActionsExpanded = false,
    this.onRecentActionsToggle,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width > UIConstants.smallScreenBreakpoint;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              GameCompactHeader(
                gameState: gameState,
                deckKey: deckKey,
                discardKey: discardKey,
                isExpanded: headerExpanded,
                onToggleExpand: onHeaderToggle,
                onRecentActionsTap: isWide
                    ? null
                    : () => showRecentActionsSheet(context, gameState),
                headerExtras: headerExtras,
              ),

              if (isWide &&
                  useDesktopRecentActions &&
                  gameState.recentActions.isNotEmpty)
                CollapsibleRecentActions(
                  gameState: gameState,
                  isExpanded: recentActionsExpanded,
                  onToggle: onRecentActionsToggle ?? () {},
                ),

              CompactPlayerScores(
                gameState: gameState,
                viewingPlayerMelds: viewingPlayerMelds,
                onPlayerTap: onPlayerTap,
                currentUserId: currentUserId,
                botPersonalityManager: botPersonalityManager,
              ),

              if (aboveMelds != null) aboveMelds!,

              Expanded(
                child: KeyedSubtree(key: meldAreaKey, child: meldsSection),
              ),

              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [actionButtons, handDisplay],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Provides [GameCardSizes] to descendants via [InheritedWidget].
class GameCardSizesScope extends InheritedWidget {
  final GameCardSizes sizes;

  const GameCardSizesScope({
    super.key,
    required this.sizes,
    required super.child,
  });

  static GameCardSizes of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<GameCardSizesScope>();
    return scope?.sizes ?? GameCardSizes.tabletPlus;
  }

  @override
  bool updateShouldNotify(GameCardSizesScope oldWidget) {
    return sizes.handWidth != oldWidget.sizes.handWidth;
  }
}
