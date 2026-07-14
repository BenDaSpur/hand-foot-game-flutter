import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the first-visit Learn to Play offer has been dismissed.
class LearnToPlayPreferences {
  static const String offerDismissedKey = 'learn_to_play_offer_dismissed';

  /// Returns true when the first-visit offer should be shown.
  static Future<bool> shouldShowOffer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(offerDismissedKey) ?? false);
    } catch (_) {
      return false;
    }
  }

  /// Marks the first-visit offer as seen (skip or mid-lesson exit).
  static Future<void> dismissOffer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(offerDismissedKey, true);
    } catch (_) {
      // Preference write failures should not block navigation.
    }
  }

  /// Test helper to clear the dismiss flag.
  static Future<void> resetOfferForTests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(offerDismissedKey);
  }
}
