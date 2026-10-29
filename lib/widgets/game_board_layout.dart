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
  static const Key foldPlaySurfaceKey = ValueKey('game-board-fold-play');
  static const Key foldGapKey = ValueKey('game-board-fold-gap');

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

  /// Always-visible header row extras (e.g. multiplayer [TurnTimer]).
  final List<Widget> persistentHeaderExtras;
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
    this.persistentHeaderExtras = const [],
    this.currentUserId,
    this.botPersonalityManager,
    this.aboveMelds,
    this.useDesktopRecentActions = false,
    this.recentActionsExpanded = false,
    this.onRecentActionsToggle,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > UIConstants.smallScreenBreakpoint;
    final useWideBoard = GameResponsiveLayout.useWideBoardLayout(width);
    final windowFold = GameFoldGeometry.activeDivisionBounds(context);

    return SafeArea(
      child: windowFold != null
          ? _FoldAwareBoardHost(
              windowFold: windowFold,
              isWide: isWide,
              board: this,
            )
          : useWideBoard
          ? _buildWideBoard(context, isWide: isWide)
          : _buildNarrowBoard(context, isWide: isWide),
    );
  }

  /// Book pose: panes sized from physical fold left/width/right (no flex guess).
  Widget _buildBookFold(
    BuildContext context, {
    required Rect localFold,
    required double safeWidth,
    required bool isWide,
  }) {
    final leftWidth = localFold.left.clamp(0.0, safeWidth);
    final gapWidth = localFold.width.clamp(0.0, safeWidth - leftWidth);
    final rightWidth = (safeWidth - leftWidth - gapWidth).clamp(0.0, safeWidth);
    final leftWider = leftWidth >= rightWidth;
    final playSurface = KeyedSubtree(
      key: foldPlaySurfaceKey,
      child: _buildPlaySurface(context, isWide: isWide),
    );
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
        SizedBox(width: leftWidth, child: leftWider ? playSurface : dock),
        SizedBox(key: foldGapKey, width: gapWidth),
        SizedBox(width: rightWidth, child: leftWider ? dock : playSurface),
      ],
    );
  }

  /// Laptop pose: play surface ends at fold top; dock sits below the crease.
  Widget _buildLaptopFold(
    BuildContext context, {
    required Rect localFold,
    required double safeHeight,
    required bool isWide,
  }) {
    final topHeight = localFold.top.clamp(0.0, safeHeight);
    final gapHeight = localFold.height.clamp(0.0, safeHeight - topHeight);
    return Column(
      key: foldLaptopKey,
      children: [
        SizedBox(
          height: topHeight,
          child: KeyedSubtree(
            key: foldPlaySurfaceKey,
            child: _buildPlaySurface(context, isWide: isWide),
          ),
        ),
        SizedBox(key: foldGapKey, height: gapHeight),
        Flexible(
          child: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topCenter,
              child: _BottomDock(
                key: bottomDockKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [actionButtons, handDisplay],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Melds + scores + header without the hand dock (used by fold splits).
  Widget _buildPlaySurface(BuildContext context, {required bool isWide}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Laptop fold top panes can be short (esp. under an AppBar); collapse
        // chrome so the column fits without overflowing the crease.
        final tightHeight =
            constraints.hasBoundedHeight && constraints.maxHeight < 320;
        return Column(
          children: [
            GameCompactHeader(
              gameState: gameState,
              deckKey: deckKey,
              discardKey: discardKey,
              isExpanded: tightHeight ? false : headerExpanded,
              showExpandToggle: !tightHeight,
              onToggleExpand: onHeaderToggle,
              onRecentActionsTap: isWide
                  ? null
                  : () => showRecentActionsSheet(context, gameState),
              headerExtras: headerExtras,
              expandedExtras: expandedHeaderExtras,
              persistentHeaderExtras: persistentHeaderExtras,
            ),
            if (!tightHeight &&
                isWide &&
                useDesktopRecentActions &&
                gameState.recentActions.isNotEmpty)
              CollapsibleRecentActions(
                gameState: gameState,
                isExpanded: recentActionsExpanded,
                onToggle: onRecentActionsToggle ?? () {},
              ),
            if (!tightHeight)
              CompactPlayerScores(
                gameState: gameState,
                viewingPlayerMelds: viewingPlayerMelds,
                onPlayerTap: onPlayerTap,
                currentUserId: currentUserId,
                botPersonalityManager: botPersonalityManager,
              ),
            // Keep stuck-turn / last-call recovery visible on short fold panes.
            if (aboveMelds != null) aboveMelds!,
            Expanded(
              child: KeyedSubtree(key: meldAreaKey, child: meldsSection),
            ),
          ],
        );
      },
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
          persistentHeaderExtras: persistentHeaderExtras,
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
                persistentHeaderExtras: persistentHeaderExtras,
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

/// Converts window-space fold bounds using this widget's global origin so
/// AppBar / coach-banner chrome above the board does not misalign the crease.
class _FoldAwareBoardHost extends StatefulWidget {
  final Rect windowFold;
  final bool isWide;
  final GameBoardLayout board;

  const _FoldAwareBoardHost({
    required this.windowFold,
    required this.isWide,
    required this.board,
  });

  @override
  State<_FoldAwareBoardHost> createState() => _FoldAwareBoardHostState();
}

class _FoldAwareBoardHostState extends State<_FoldAwareBoardHost> {
  Offset? _origin;

  void _scheduleOriginMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        return;
      }
      final origin = box.localToGlobal(Offset.zero);
      if (_origin != origin) {
        setState(() {
          _origin = origin;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleOriginMeasure();
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final origin = _origin ?? Offset.zero;
        final localFold = GameFoldGeometry.toWidgetLocal(
          widget.windowFold,
          origin,
          size,
        );
        if (!_isUsableLocalFold(localFold, size)) {
          // Until the first measure (or if fold is outside the board), use
          // the normal wide/narrow layout for this width.
          final useWide = GameResponsiveLayout.useWideBoardLayout(
            MediaQuery.sizeOf(context).width,
          );
          return useWide
              ? widget.board._buildWideBoard(context, isWide: widget.isWide)
              : widget.board._buildNarrowBoard(context, isWide: widget.isWide);
        }
        if (GameFoldGeometry.isVerticalDivision(localFold)) {
          return widget.board._buildBookFold(
            context,
            localFold: localFold,
            safeWidth: size.width,
            isWide: widget.isWide,
          );
        }
        return widget.board._buildLaptopFold(
          context,
          localFold: localFold,
          safeHeight: size.height,
          isWide: widget.isWide,
        );
      },
    );
  }

  bool _isUsableLocalFold(Rect localFold, Size size) {
    if (!_originMeasured) {
      return false;
    }
    if (localFold.width < 1 && localFold.height < 1) {
      return false;
    }
    final board = Offset.zero & size;
    return localFold.overlaps(board);
  }

  bool get _originMeasured => _origin != null;
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
