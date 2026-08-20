/// Represents a decision made by a bot player.
///
/// This class encapsulates the action the bot wants to take and any
/// associated data needed to execute that action.
class BotDecision {
  /// The action to perform (e.g., 'discard', 'createMeld', 'addToMeld', 'goOut')
  final String action;

  /// Data associated with the action (e.g., card to discard, meld to create)
  final dynamic data;

  /// Whether to skip play-down requirement checks for this action
  final bool skipPlayDownCheck;

  /// Planner analytics (couldUnlock, keyCount, skipReason, chosenKind).
  final Map<String, dynamic>? analyticsContext;

  BotDecision({
    required this.action,
    this.data,
    this.skipPlayDownCheck = false,
    this.analyticsContext,
  });

  @override
  String toString() {
    return 'BotDecision(action: $action, data: $data, skipPlayDownCheck: $skipPlayDownCheck)';
  }
}
