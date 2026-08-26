import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kinds of haptic pulses used by gameplay and the settings preview.
enum HapticKind { selection, light, medium, heavy }

/// Singleton service for short mobile vibrations.
///
/// Mirrors [SoundService]: the preference is persisted locally and defaults to
/// on. Platform haptic calls are skipped when the user disables vibrations.
class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  bool _initialized = false;
  bool _hapticsEnabled = true;

  /// Preference key stored in SharedPreferences.
  static const String preferenceKey = 'haptics_enabled';

  /// When true, skip [HapticFeedback] so unit tests can assert without
  /// depending on a device vibration motor.
  @visibleForTesting
  bool suppressPlatformHaptics = false;

  /// Sequence of haptic kinds requested since the last [resetForTest].
  @visibleForTesting
  final List<HapticKind> debugPlayed = [];

  /// Initialize and load the persisted preference.
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _hapticsEnabled = prefs.getBool(preferenceKey) ?? true;
      _initialized = true;
    } catch (e) {
      debugPrint('HapticService initialization failed: $e');
      _initialized = true;
    }
  }

  /// Whether vibrations are currently enabled.
  bool get hapticsEnabled => _hapticsEnabled;

  /// Enable or disable vibrations and persist the choice.
  Future<void> setHapticsEnabled(bool enabled) async {
    _hapticsEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(preferenceKey, enabled);
    } catch (e) {
      debugPrint('Failed to save haptic preference: $e');
    }
    if (enabled) {
      lightImpact();
    }
  }

  /// Tiny click — card selection, action buttons, mini-game card deals.
  void selectionClick() {
    unawaited(_play(HapticKind.selection));
  }

  /// Soft bump — turn start, miss, invalid action.
  void lightImpact() {
    unawaited(_play(HapticKind.light));
  }

  /// Medium bump — play-down, foot pickup, discard-pile unlock.
  void mediumImpact() {
    unawaited(_play(HapticKind.medium));
  }

  /// Strong bump — book complete, going out, victory, mini-game success.
  void heavyImpact() {
    unawaited(_play(HapticKind.heavy));
  }

  Future<void> _play(HapticKind kind) async {
    if (!_initialized) {
      return;
    }
    if (!_hapticsEnabled) {
      return;
    }
    debugPlayed.add(kind);
    if (suppressPlatformHaptics) {
      return;
    }
    try {
      switch (kind) {
        case HapticKind.selection:
          await HapticFeedback.selectionClick();
          break;
        case HapticKind.light:
          await HapticFeedback.lightImpact();
          break;
        case HapticKind.medium:
          await HapticFeedback.mediumImpact();
          break;
        case HapticKind.heavy:
          await HapticFeedback.heavyImpact();
          break;
      }
    } catch (e) {
      debugPrint('HapticService failed to play $kind: $e');
    }
  }

  /// Reset in-memory state for tests. Does not clear SharedPreferences.
  @visibleForTesting
  void resetForTest({bool enabled = true, bool initialized = true}) {
    _initialized = initialized;
    _hapticsEnabled = enabled;
    suppressPlatformHaptics = true;
    debugPlayed.clear();
  }
}
