import 'package:material_ui/material_ui.dart';

import '../constants/ui_constants.dart';
import '../game/game_action_feedback.dart';
import '../models/player.dart';
import '../theme/balatro_theme.dart';

/// Banner shown when a human cannot discard or go out after melding down
/// without both books. Offers undo (when available) and skip-turn recovery.
///
/// On phone-width screens the banner collapses to a single compact strip so it
/// does not push the melds and hand off screen; tapping reveals full guidance.
class StuckGoOutRecoveryBanner extends StatefulWidget {
  final Player humanPlayer;
  final VoidCallback? onUndo;
  final VoidCallback onSkipTurn;

  const StuckGoOutRecoveryBanner({
    super.key,
    required this.humanPlayer,
    this.onUndo,
    required this.onSkipTurn,
  });

  @override
  State<StuckGoOutRecoveryBanner> createState() =>
      _StuckGoOutRecoveryBannerState();
}

class _StuckGoOutRecoveryBannerState extends State<StuckGoOutRecoveryBanner> {
  static const _urgencyColor = BalatroTheme.neonPink;
  static const _cornerRadius = 12.0;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isCompact =
        MediaQuery.sizeOf(context).width <= UIConstants.smallScreenBreakpoint;
    final showDetails = !isCompact || _expanded;
    final message = GameActionFeedback.stuckWithoutBooksMessage(
      widget.humanPlayer,
    );

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: showDetails ? 10 : 6,
      ),
      child: showDetails
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: _urgencyColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'CAN’T GO OUT',
                        style: TextStyle(
                          color: _urgencyColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    if (isCompact)
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: _urgencyColor,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    color: BalatroTheme.primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.onUndo != null)
                      ElevatedButton(
                        onPressed: widget.onUndo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BalatroTheme.neonOrange,
                        ),
                        child: const Text('Undo Meld'),
                      ),
                    ElevatedButton(
                      onPressed: widget.onSkipTurn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _urgencyColor,
                      ),
                      child: const Text('Skip Turn (Emergency Recovery)'),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: _urgencyColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'CAN’T GO OUT — tap for details',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _urgencyColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: _urgencyColor,
                  size: 20,
                ),
              ],
            ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _urgencyColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(_cornerRadius),
        border: Border.all(color: _urgencyColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _urgencyColor.withValues(alpha: 0.25),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: isCompact
          ? Semantics(
              button: true,
              label: _expanded
                  ? 'Hide stuck recovery details'
                  : 'Show stuck recovery details',
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
}
