import 'package:material_ui/material_ui.dart';

import '../models/game_state.dart';
import '../models/player.dart';
import '../ai/bot_personality.dart';
import '../constants/ui_constants.dart';
import '../theme/balatro_theme.dart';
import '../utils/game_fold_geometry.dart';
import '../utils/game_responsive_layout.dart';
import 'game_compact_header.dart';
import 'compact_player_scores.dart';
import 'collapsible_recent_actions.dart';

/// Mobile-first game board shell shared by solo and multiplayer screens.
///
/// Uses a two-pane rail layout when width ≥ tablet landscape breakpoint
/// (iPad landscape / macOS / iPhone Duo inner landscape). When a fold crease
/// is active (partially open), keeps the interactive dock clear of the fold.
class GameBoardLayout extends StatelessWidget {
  static const Key wideBoardKey = ValueKey('game-board-wide');
  static const Key narrowBoardKey = ValueKey('game-board-narrow');
  static const Key wideRailKey = ValueKey('game-board-wide-rail');
  static const Key foldBookKey = ValueKey('game-board-fold-book');
  static const Key foldLaptopKey = ValueKey('game-board-fold-laptop');
  static const Key bottomDockKey = ValueKey('game-board-bottom-dock');

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
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final isWide = width > UIConstants.smallScreenBreakpoint;
    final useWideBoard = GameResponsiveLayout.useWideBoardLayout(width);
    final foldBounds = GameFoldGeometry.activeDivisionBounds(context);

    return SafeArea(
      child: foldBounds != null
          ? _buildFoldAwareBoard(
              context,
              foldBounds: foldBounds,
              isWide: isWide,
            )
          : useWideBoard
          ? _buildWideBoard(context, isWide: isWide)
          : _buildNarrowBoard(context, isWide: isWide),
    );
  }

  Widget _buildFoldAwareBoard(
    BuildContext context, {
    required Rect foldBounds,
    required bool isWide,
  }) {
    if (GameFoldGeometry.isVerticalDivision(foldBounds)) {
      // Book pose: melds/scores on the larger pane, hand+actions on the other.
      final leftWider =
          foldBounds.left >=
          (MediaQuery.sizeOf(context).width - foldBounds.right);
      final playSurface = _buildPlaySurface(context, isWide: isWide);
      final dock = _BottomDock(
        key: bottomDockKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [actionButtons, handDisplay],
        ),
      );
      return Row(
        key: foldBookKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: leftWider ? 6 : 4,
            child: leftWider ? playSurface : dock,
          ),
          SizedBox(width: foldBounds.width.clamp(24.0, 56.0)),
          Expanded(
            flex: leftWider ? 4 : 6,
            child: leftWider ? dock : playSurface,
          ),
        ],
      );
    }

    // Laptop pose: play surface above the crease, dock below.
    return Column(
      key: foldLaptopKey,
      children: [
        Expanded(child: _buildPlaySurface(context, isWide: isWide)),
        SizedBox(height: foldBounds.height.clamp(24.0, 56.0)),
        _BottomDock(
          key: bottomDockKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [actionButtons, handDisplay],
          ),
        ),
      ],
    );
  }

  /// Melds + scores + header without the hand dock (used by fold splits).
  Widget _buildPlaySurface(BuildContext context, {required bool isWide}) {
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
      ],
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
          key: bottomDockKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [actionButtons, handDisplay],
          ),
        ),
      ],
    );
  }

  Widget _buildWideBoard(BuildContext context, {required bool isWide}) {
    final width = MediaQuery.sizeOf(context).width;
    return Row(
      key: wideBoardKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: wideRailKey,
          width: GameResponsiveLayout.wideBoardRailWidthFor(width),
          child: Column(
            children: [
              GameCompactHeader(
                gameState: gameState,
                deckKey: deckKey,
                discardKey: discardKey,
                isExpanded: true,
                showExpandToggle: false,
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
              _BottomDock(key: bottomDockKey, child: handDisplay),
            ],
          ),
        ),
      ],
    );
  }
}

class _BottomDock extends StatelessWidget {
  final Widget child;

  const _BottomDock({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isUltraShort = GameResponsiveLayout.isUltraShortHeight(
      MediaQuery.sizeOf(context).height,
    );
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
            blurRadius: isUltraShort ? 6 : 12,
            offset: Offset(0, isUltraShort ? -1 : -3),
          ),
        ],
      ),
      child: child,
    );
  }
}
