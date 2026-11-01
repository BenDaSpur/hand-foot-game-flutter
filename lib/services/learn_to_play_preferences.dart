import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the first-visit Learn to Play offer has been dismissed.
class LearnToPlayPreferences {
  static const String offerDismissedKey = 'learn_to_play_offer_dismissed';

  /// Whether the skippable first-visit offer should be shown.
  static Future<bool> shouldShowOffer() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(offerDismissedKey) ?? false);
  }

  /// Marks the first-visit offer as seen (skip or start/exit lesson).
  static Future<void> dismissOffer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(offerDismissedKey, true);
  }
}
