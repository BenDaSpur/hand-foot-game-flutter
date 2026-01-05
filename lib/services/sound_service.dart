import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton service for playing game sound effects.
///
/// Uses a simple beep-based approach for web compatibility.
/// Sound effects provide audio feedback for game actions.
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  bool _initialized = false;
  bool _soundEnabled = true;
  double _volume = 0.5;

  // Preference keys
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _volumeKey = 'sound_volume';

  /// Initialize the sound service and load preferences
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
      _volume = prefs.getDouble(_volumeKey) ?? 0.5;
      _initialized = true;
      debugPrint(
        'SoundService initialized: enabled=$_soundEnabled, volume=$_volume',
      );
    } catch (e) {
      debugPrint('SoundService initialization failed: $e');
      _initialized =
          true; // Mark as initialized even on failure to prevent retry loops
    }
  }

  /// Whether sound effects are enabled
  bool get soundEnabled => _soundEnabled;

  /// Current volume level (0.0 to 1.0)
  double get volume => _volume;

  /// Enable or disable sound effects
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundEnabledKey, enabled);
    } catch (e) {
      debugPrint('Failed to save sound preference: $e');
    }
  }

  /// Set volume level (0.0 to 1.0)
  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_volumeKey, _volume);
    } catch (e) {
      debugPrint('Failed to save volume preference: $e');
    }
  }

  /// Play card draw sound - quick shuffle sound
  void playCardDraw() {
    if (!_soundEnabled) return;
    _logSound('card_draw');
  }

  /// Play card discard sound - soft thud
  void playCardDiscard() {
    if (!_soundEnabled) return;
    _logSound('card_discard');
  }

  /// Play meld creation sound - positive chime
  void playMeldCreated() {
    if (!_soundEnabled) return;
    _logSound('meld_created');
  }

  /// Play book completion sound - celebratory fanfare
  void playBookCompleted() {
    if (!_soundEnabled) return;
    _logSound('book_completed');
  }

  /// Play turn notification sound - gentle alert
  void playYourTurn() {
    if (!_soundEnabled) return;
    _logSound('your_turn');
  }

  /// Play error/invalid action sound - negative tone
  void playError() {
    if (!_soundEnabled) return;
    _logSound('error');
  }

  /// Play game win/victory sound - triumphant fanfare
  void playVictory() {
    if (!_soundEnabled) return;
    _logSound('victory');
  }

  /// Play game over sound - somber tone
  void playGameOver() {
    if (!_soundEnabled) return;
    _logSound('game_over');
  }

  /// Play round complete sound - achievement tone
  void playRoundComplete() {
    if (!_soundEnabled) return;
    _logSound('round_complete');
  }

  /// Play foot pickup sound - whoosh sound
  void playFootPickup() {
    if (!_soundEnabled) return;
    _logSound('foot_pickup');
  }

  /// Play unlock discard sound
  void playUnlockDiscard() {
    if (!_soundEnabled) return;
    _logSound('unlock_discard');
  }

  // Log sound for debugging (sounds will be added later)
  void _logSound(String soundName) {
    if (kDebugMode) {
      debugPrint('🔊 Sound: $soundName (volume: $_volume)');
    }
  }

  /// Dispose of audio resources
  void dispose() {
    // No resources to dispose currently
  }
}
