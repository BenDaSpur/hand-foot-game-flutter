import 'package:material_ui/material_ui.dart';

/// Marks the slim trailing action column used on the Duo cover and in book pose.
///
/// Absent, or with [slim] false, the action buttons keep their full text.
class GameActionRailScope extends InheritedWidget {
  final bool slim;

  const GameActionRailScope({
    super.key,
    required this.slim,
    required super.child,
  });

  static bool slimOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<GameActionRailScope>();
    return scope?.slim ?? false;
  }

  @override
  bool updateShouldNotify(GameActionRailScope oldWidget) {
    return slim != oldWidget.slim;
  }
}
