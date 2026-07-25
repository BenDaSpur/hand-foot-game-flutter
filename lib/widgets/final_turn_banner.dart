import 'package:flutter/material.dart';
import '../constants/ui_constants.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../theme/balatro_theme.dart';

/// Prominent banner shown while other players take one final turn after a go-out.
///
/// On phone-width screens the banner collapses to a single compact strip so it
/// does not push the melds and hand off screen; tapping it reveals the full
/// guidance.
class FinalTurnBanner extends StatefulWidget {
  final GameState gameState;

  /// Local human player id (solo) or multiplayer user id. When null, uses
  /// the first [PlayerType.human] in [GameState.players].
  final String? localPlayerId;

  const FinalTurnBanner({
    super.key,
    required this.gameState,
    this.localPlayerId,
  });

  @override
  State<FinalTurnBanner> createState() => _FinalTurnBannerState();
}

class _FinalTurnBannerState extends State<FinalTurnBanner> {
  static const _detailedPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 10,
  );
  static const _compactPadding = EdgeInsets.fromLTRB(10, 6, 6, 6);
  static const _detailedIconSize = 26.0;
  static const _compactIconSize = 18.0;
  static const _chevronSize = 20.0;
  static const _detailedIconGap = 10.0;
  static const _compactVerticalMargin = 3.0;
  static const _cornerRadius = 12.0;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final gameState = widget.gameState;
    if (!gameState.finalTurnPhaseActive) {
      return const SizedBox.shrink();
    }

    final isCompact =
        MediaQuery.sizeOf(context).width <= UIConstants.smallScreenBreakpoint;
    final showDetails = !isCompact || _expanded;

    final wentOut = gameState.playerWhoWentOut;
    final localPlayer = _resolveLocalPlayer();
    final isLocalFinalTurn =
        localPlayer != null && gameState.isPlayerAwaitingFinalTurn(localPlayer);
    final remaining = gameState.playersAwaitingFinalTurn.length;
    final urgencyColor = isLocalFinalTurn
        ? BalatroTheme.neonOrange
        : BalatroTheme.neonYellow;

    final content = Padding(
      padding: showDetails ? _detailedPadding : _compactPadding,
      child: Row(
        crossAxisAlignment: showDetails
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Icon(
            isLocalFinalTurn ? Icons.timer : Icons.hourglass_bottom,
            color: urgencyColor,
            size: showDetails ? _detailedIconSize : _compactIconSize,
          ),
          SizedBox(
            width: showDetails ? _detailedIconGap : UIConstants.mediumSpacing,
          ),
          Expanded(
            child: showDetails
                ? _buildDetails(
                    urgencyColor: urgencyColor,
                    isLocalFinalTurn: isLocalFinalTurn,
                    wentOutName: wentOut?.name,
                    remaining: remaining,
                  )
                : _buildSummary(
                    urgencyColor: urgencyColor,
                    isLocalFinalTurn: isLocalFinalTurn,
                    wentOutName: wentOut?.name,
                    remaining: remaining,
                  ),
          ),
          if (isCompact) ...[
            const SizedBox(width: UIConstants.smallSpacing),
            Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              color: urgencyColor,
              size: _chevronSize,
            ),
          ],
        ],
      ),
    );

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: UIConstants.defaultMargin,
        vertical: isCompact ? _compactVerticalMargin : UIConstants.smallSpacing,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            urgencyColor.withValues(alpha: 0.28),
            BalatroTheme.neonPink.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(_cornerRadius),
        border: Border.all(color: urgencyColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: urgencyColor.withValues(alpha: 0.35),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: isCompact
          ? Semantics(
              button: true,
              label: _expanded
                  ? 'Hide final turn details'
                  : 'Show final turn details',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: BorderRadius.circular(_cornerRadius),
                  child: content,
                ),
              ),
            )
          : content,
    );
  }

  Widget _buildDetails({
    required Color urgencyColor,
    required bool isLocalFinalTurn,
    required String? wentOutName,
    required int remaining,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _headline(isLocalFinalTurn),
          style: TextStyle(
            color: urgencyColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _body(wentOutName, isLocalFinalTurn, remaining),
          style: const TextStyle(
            color: BalatroTheme.primaryText,
            fontSize: 12,
            height: 1.35,
          ),
        ),
        if (isLocalFinalTurn) ...[
          const SizedBox(height: 6),
          Text(
            'Meld every card you can — leftover hand & foot cards '
            'become penalty points when the round ends.',
            style: TextStyle(
              color: urgencyColor.withValues(alpha: 0.95),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummary({
    required Color urgencyColor,
    required bool isLocalFinalTurn,
    required String? wentOutName,
    required int remaining,
  }) {
    return Row(
      children: [
        Flexible(
          child: Text(
            _compactHeadline(isLocalFinalTurn),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: urgencyColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _summary(wentOutName, isLocalFinalTurn, remaining),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: BalatroTheme.primaryText,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Player? _resolveLocalPlayer() {
    final localPlayerId = widget.localPlayerId;
    if (localPlayerId != null) {
      for (final player in widget.gameState.players) {
        if (player.id == localPlayerId) {
          return player;
        }
      }
      return null;
    }

    for (final player in widget.gameState.players) {
      if (player.type == PlayerType.human) {
        return player;
      }
    }
    return null;
  }

  String _headline(bool isLocalFinalTurn) {
    if (isLocalFinalTurn) {
      return 'YOUR FINAL TURN';
    }
    return 'FINAL TURNS IN PROGRESS';
  }

  String _compactHeadline(bool isLocalFinalTurn) {
    if (isLocalFinalTurn) {
      return 'YOUR FINAL TURN';
    }
    return 'FINAL TURNS';
  }

  String _body(String? wentOutName, bool isLocalFinalTurn, int remaining) {
    final who = wentOutName ?? 'Someone';
    if (isLocalFinalTurn) {
      return '$who went out. This is your last turn before scoring — '
          'play down as much as you can.';
    }

    final turnWord = remaining == 1 ? 'turn' : 'turns';
    return '$who went out. Each other player gets one more $turnWord '
        '($remaining remaining).';
  }

  String _summary(String? wentOutName, bool isLocalFinalTurn, int remaining) {
    final who = wentOutName ?? 'Someone';
    if (isLocalFinalTurn) {
      return '$who went out — meld all you can';
    }
    return '$who went out — $remaining left';
  }
}
