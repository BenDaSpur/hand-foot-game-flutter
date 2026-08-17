import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../ai/bot_personality.dart';
import '../constants/ui_constants.dart';
import '../theme/balatro_theme.dart';
import '../utils/game_responsive_layout.dart';
import 'game_compact_header.dart';
import 'compact_player_scores.dart';
import 'collapsible_recent_actions.dart';

/// Mobile-first game board shell shared by solo and multiplayer screens.
///
/// Uses a two-pane rail layout when width ≥ tablet landscape breakpoint
/// (iPad landscape / macOS).
class GameBoardLayout extends StatelessWidget {
  static const Key wideBoardKey = ValueKey('game-board-wide');
  static const Key narrowBoardKey = ValueKey('game-board-narrow');
  static const Key wideRailKey = ValueKey('game-board-wide-rail');

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
  final List<Widget> expandedHeaderExtras;
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
    this.expandedHeaderExtras = const [],
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
    final useWideBoard = GameResponsiveLayout.useWideBoardLayout(width);

    return SafeArea(
      child: useWideBoard
          ? _buildWideBoard(context, isWide: isWide)
          : _buildNarrowBoard(context, isWide: isWide),
    );
  }

  Widget _buildNarrowBoard(BuildContext context, {required bool isWide}) {
    return Column(
      key: narrowBoardKey,
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
          expandedExtras: expandedHeaderExtras,
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
        _BottomDock(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [actionButtons, handDisplay],
          ),
        ),
      ],
    );
  }

  Widget _buildWideBoard(BuildContext context, {required bool isWide}) {
    return Row(
      key: wideBoardKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: wideRailKey,
          width: GameResponsiveLayout.wideBoardRailWidth,
          child: Column(
            children: [
              GameCompactHeader(
                gameState: gameState,
                deckKey: deckKey,
                discardKey: discardKey,
                isExpanded: true,
                onToggleExpand: onHeaderToggle,
                onRecentActionsTap: null,
                headerExtras: headerExtras,
                expandedExtras: expandedHeaderExtras,
              ),
              CompactPlayerScores(
                gameState: gameState,
                viewingPlayerMelds: viewingPlayerMelds,
                onPlayerTap: onPlayerTap,
                currentUserId: currentUserId,
                botPersonalityManager: botPersonalityManager,
                vertical: true,
              ),
              const Spacer(),
              actionButtons,
            ],
          ),
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: BalatroTheme.glowColor.withValues(alpha: 0.2),
        ),
        Expanded(
          child: Column(
            children: [
              if (isWide &&
                  useDesktopRecentActions &&
                  gameState.recentActions.isNotEmpty)
                CollapsibleRecentActions(
                  gameState: gameState,
                  isExpanded: recentActionsExpanded,
                  onToggle: onRecentActionsToggle ?? () {},
                ),
              if (aboveMelds != null) aboveMelds!,
              Expanded(
                child: KeyedSubtree(key: meldAreaKey, child: meldsSection),
              ),
              _BottomDock(child: handDisplay),
            ],
          ),
        ),
      ],
    );
  }
}

class _BottomDock extends StatelessWidget {
  final Widget child;

  const _BottomDock({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            BalatroTheme.darkPurple.withValues(alpha: 0.88),
            BalatroTheme.deepPurple.withValues(alpha: 0.98),
          ],
        ),
        border: Border(
          top: BorderSide(
            color: BalatroTheme.glowColor.withValues(alpha: 0.18),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: child,
    );
  }
}
