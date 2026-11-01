import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the in-game turn coach strip has been dismissed.
class TurnCoachPreferences {
  static const String dismissedKey = 'turn_coach_dismissed';

  /// Whether the phase coach should still be shown on human turns.
  static Future<bool> shouldShowCoach() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(dismissedKey) ?? false);
  }

  /// Hide the coach after the player completes a first play-down cycle.
  static Future<void> dismissCoach() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(dismissedKey, true);
  }
}
