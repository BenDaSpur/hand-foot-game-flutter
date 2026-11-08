import 'package:material_ui/material_ui.dart';

import '../models/game_state.dart';
import '../models/player.dart';
import '../ai/bot_personality.dart';
import '../constants/ui_constants.dart';
import '../theme/balatro_theme.dart';
import '../utils/game_fold_geometry.dart';
import '../utils/game_responsive_layout.dart';
import 'game_action_rail_scope.dart';
import 'game_compact_header.dart';
import 'compact_player_scores.dart';
import 'collapsible_recent_actions.dart';

/// Mobile-first game board shell shared by solo and multiplayer screens.
///
/// Uses a two-pane rail layout when width ≥ tablet landscape breakpoint
/// (iPad landscape / macOS / iPhone Duo inner landscape). On Duo inner
/// landscape that rail stays inside the safe area, beside the Control Center
/// strip. The Duo cover and book pose put turn actions in the strip itself,
/// under the status icons, so the table is not squeezed by a second column.
/// When a fold crease is active, the table stays on the left page and the
/// hand plus actions stay on the right; a horizontal crease keeps the dock
/// in the lower half.
class GameBoardLayout extends StatelessWidget {
  static const Key wideBoardKey = ValueKey('game-board-wide');
  static const Key narrowBoardKey = ValueKey('game-board-narrow');
  static const Key wideRailKey = ValueKey('game-board-wide-rail');
  static const Key coverBoardKey = ValueKey('game-board-cover');
  static const Key trailingActionRailKey = ValueKey(
    'game-board-trailing-action-rail',
  );
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
  final VoidCallback? onDeckTap;
  final VoidCallback? onDiscardTap;

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
    this.onDeckTap,
    this.onDiscardTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width > UIConstants.smallScreenBreakpoint;
    final useWideBoard = GameResponsiveLayout.useWideBoardLayout(size.width);
    final windowFold = GameFoldGeometry.activeDivisionBounds(context);
    final padding = MediaQuery.paddingOf(context);
    final trailingIsLeft = Directionality.of(context) == TextDirection.rtl;
    final trailingInset = trailingIsLeft ? padding.left : padding.right;
    // Cover and book poses draw into the trailing status strip. Leaving
    // SafeArea on that side, then adding another 84pt rail, parks Draw beside
    // the clock and leaves the strip empty.
    final absorbTrailingStrip = _placeActionsInStatusStrip(
      size: size,
      windowFold: windowFold,
    );
    final slimRailWidth = _slimRailWidthFor(
      trailingInset,
      absorbStrip: absorbTrailingStrip,
    );
    final board = windowFold != null
        ? _FoldAwareBoardHost(
            windowFold: windowFold,
            isWide: isWide,
            board: this,
            slimRailWidth: slimRailWidth,
            trailingReserve: absorbTrailingStrip ? trailingInset : 0,
            trailingIsLeft: trailingIsLeft,
          )
        : useWideBoard
        ? _buildWideBoard(context, isWide: isWide)
        : absorbTrailingStrip
        ? _buildCoverBoard(
            context,
            isWide: isWide,
            slimRailWidth: slimRailWidth,
          )
        : _buildNarrowBoard(context, isWide: isWide);

    return SafeArea(
      left: !(absorbTrailingStrip && trailingIsLeft),
      right: !(absorbTrailingStrip && !trailingIsLeft),
      child: Builder(
        builder: (context) {
          if (!absorbTrailingStrip) {
            return board;
          }
          // SafeArea leaves the unconsumed side in MediaQuery. Drop it so the
          // table does not inset itself a second time beside the action rail.
          return MediaQuery.removePadding(
            context: context,
            removeLeft: trailingIsLeft,
            removeRight: !trailingIsLeft,
            child: board,
          );
        },
      ),
    );
  }

  /// Cover and vertical book folds own the trailing status strip.
  static bool _placeActionsInStatusStrip({
    required Size size,
    required Rect? windowFold,
  }) {
    if (windowFold != null) {
      return GameFoldGeometry.isVerticalDivision(windowFold);
    }
    return GameResponsiveLayout.isDuoCover(size);
  }

  /// Rail fills the status strip when that inset is wider than the minimum.
  static double _slimRailWidthFor(
    double trailingInset, {
    required bool absorbStrip,
  }) {
    final minimum = GameResponsiveLayout.trailingActionRailWidth;
    if (!absorbStrip || !trailingInset.isFinite || trailingInset <= minimum) {
      return minimum;
    }
    return trailingInset;
  }

  /// Cover: phone column for the table and hand, turn actions in the status strip.
  Widget _buildCoverBoard(
    BuildContext context, {
    required bool isWide,
    required double slimRailWidth,
  }) {
    return Row(
      key: coverBoardKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _buildPlayColumn(
            context,
            isWide: isWide,
            bottom: _BottomDock(key: bottomDockKey, child: handDisplay),
          ),
        ),
        _slimActionRail(width: slimRailWidth),
      ],
    );
  }

  Widget _slimActionRail({required double width}) {
    return _TrailingActionRail(
      key: trailingActionRailKey,
      width: width,
      child: GameActionRailScope(slim: true, child: actionButtons),
    );
  }

  /// Book pose: panes sized from physical fold left/width/right (no flex guess).
  Widget _buildBookFold(
    BuildContext context, {
    required Rect localFold,
    required double safeWidth,
    required bool isWide,
    required double slimRailWidth,
  }) {
    final leftWidth = localFold.left.clamp(0.0, safeWidth);
    final gapWidth = localFold.width.clamp(0.0, safeWidth - leftWidth);
    final rightWidth = (safeWidth - leftWidth - gapWidth).clamp(0.0, safeWidth);
    final playSurface = KeyedSubtree(
      key: foldPlaySurfaceKey,
      child: _buildPlaySurface(context, isWide: isWide),
    );
    // Right page is the outer edge. The hand sits at the bottom of that page;
    // turn actions occupy the status strip on its trailing edge.
    final dock = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [_BottomDock(key: bottomDockKey, child: handDisplay)],
          ),
        ),
        _slimActionRail(width: slimRailWidth.clamp(0.0, rightWidth).toDouble()),
      ],
    );
    return Row(
      key: foldBookKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: leftWidth, child: playSurface),
        SizedBox(key: foldGapKey, width: gapWidth),
        SizedBox(width: rightWidth, child: dock),
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
              onDeckTap: onDeckTap,
              onDiscardTap: onDiscardTap,
              localPlayerId: currentUserId,
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
    return _buildPlayColumn(
      context,
      isWide: isWide,
      columnKey: narrowBoardKey,
      bottom: _BottomDock(
        key: bottomDockKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [actionButtons, handDisplay],
        ),
      ),
    );
  }

  /// Header, scores, and melds with [bottom] pinned under the table.
  Widget _buildPlayColumn(
    BuildContext context, {
    required bool isWide,
    Key? columnKey,
    required Widget bottom,
  }) {
    return Column(
      key: columnKey,
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
          onDeckTap: onDeckTap,
          onDiscardTap: onDiscardTap,
          localPlayerId: currentUserId,
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
        bottom,
      ],
    );
  }

  Widget _buildWideBoard(BuildContext context, {required bool isWide}) {
    final size = MediaQuery.sizeOf(context);
    final railOnTrailing = GameResponsiveLayout.useTrailingWideRail(size);
    final rail = SizedBox(
      key: wideRailKey,
      width: GameResponsiveLayout.wideBoardRailWidthFor(size.width),
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
            onDeckTap: onDeckTap,
            onDiscardTap: onDiscardTap,
            localPlayerId: currentUserId,
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
    );
    final divider = VerticalDivider(
      width: 1,
      thickness: 1,
      color: BalatroTheme.glowColor.withValues(alpha: 0.2),
    );
    final play = Expanded(
      child: Column(
        // Stretch so the hand dock fills the pane. Centered alignment
        // shrinks the dock to the fan and leaves it floating in the pane.
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
    );
    return Row(
      key: wideBoardKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!railOnTrailing) ...[rail, divider],
        play,
        if (railOnTrailing) ...[divider, rail],
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
  final double slimRailWidth;

  /// Trailing inset the host must keep clear when it falls back to a layout
  /// that does not draw into the status strip.
  final double trailingReserve;
  final bool trailingIsLeft;

  const _FoldAwareBoardHost({
    required this.windowFold,
    required this.isWide,
    required this.board,
    required this.slimRailWidth,
    required this.trailingReserve,
    required this.trailingIsLeft,
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
          // the normal wide/narrow layout for this width. That layout stays
          // beside the status strip, so put the trailing inset back.
          final useWide = GameResponsiveLayout.useWideBoardLayout(
            MediaQuery.sizeOf(context).width,
          );
          final fallback = useWide
              ? widget.board._buildWideBoard(context, isWide: widget.isWide)
              : widget.board._buildNarrowBoard(context, isWide: widget.isWide);
          final reserve = widget.trailingReserve;
          if (reserve <= 0) {
            return fallback;
          }
          return Padding(
            padding: EdgeInsets.only(
              left: widget.trailingIsLeft ? reserve : 0,
              right: widget.trailingIsLeft ? 0 : reserve,
            ),
            child: fallback,
          );
        }
        if (GameFoldGeometry.isVerticalDivision(localFold)) {
          return widget.board._buildBookFold(
            context,
            localFold: localFold,
            safeWidth: size.width,
            isWide: widget.isWide,
            slimRailWidth: widget.slimRailWidth,
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

/// Trailing turn-action column. On the Duo cover and in book pose this is the
/// status / Control Center strip, with the buttons at the bottom of it.
class _TrailingActionRail extends StatelessWidget {
  final Widget child;
  final double width;

  const _TrailingActionRail({
    super.key,
    required this.child,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BalatroTheme.deepPurple.withValues(alpha: 0.96),
        border: Border(
          left: BorderSide(
            color: BalatroTheme.glowColor.withValues(alpha: 0.28),
          ),
        ),
      ),
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 8, 0),
          child: Align(alignment: Alignment.bottomCenter, child: child),
        ),
      ),
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
