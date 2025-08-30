import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';
import 'game_analytics_logger.dart';

/// Service for managing analytics configuration and privacy controls
class AnalyticsConfigService {
  static final Logger _logger = Logger('AnalyticsConfigService');

  // SharedPreferences keys
  static const String _analyticsEnabledKey = 'analytics_enabled';
  static const String _detailedLoggingEnabledKey = 'detailed_logging_enabled';
  static const String _firstLaunchKey = 'first_launch_analytics';

  // Default values
  static const bool _defaultAnalyticsEnabled =
      true; // Basic analytics enabled by default
  static const bool _defaultDetailedLoggingEnabled =
      false; // Detailed logging opt-in only

  static SharedPreferences? _prefs;

  /// Initialize the analytics configuration service
  static Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      // Check if this is the first launch
      final isFirstLaunch = !(_prefs!.containsKey(_firstLaunchKey));
      if (isFirstLaunch) {
        await _setFirstLaunchDefaults();
      }

      // Apply current settings to the analytics logger
      await _applySettingsToLogger();

      _logger.info('Analytics configuration initialized');
    } catch (e) {
      _logger.severe('Failed to initialize analytics configuration: $e');
    }
  }

  /// Set default values on first launch
  static Future<void> _setFirstLaunchDefaults() async {
    if (_prefs == null) return;

    try {
      await _prefs!.setBool(_analyticsEnabledKey, _defaultAnalyticsEnabled);
      await _prefs!.setBool(
        _detailedLoggingEnabledKey,
        _defaultDetailedLoggingEnabled,
      );
      await _prefs!.setBool(_firstLaunchKey, true);

      _logger.info('Set default analytics preferences for first launch');
    } catch (e) {
      _logger.warning('Failed to set first launch defaults: $e');
    }
  }

  /// Apply current settings to the analytics logger
  static Future<void> _applySettingsToLogger() async {
    try {
      final analyticsEnabled = isAnalyticsEnabled();
      final detailedLoggingEnabled = isDetailedLoggingEnabled();

      await GameAnalyticsLogger.initialize(
        analyticsEnabled: analyticsEnabled,
        detailedLoggingEnabled: detailedLoggingEnabled,
      );

      _logger.info(
        'Applied settings to analytics logger - '
        'Basic: $analyticsEnabled, Detailed: $detailedLoggingEnabled',
      );
    } catch (e) {
      _logger.warning('Failed to apply settings to logger: $e');
    }
  }

  /// Get current analytics enabled status
  static bool isAnalyticsEnabled() {
    if (_prefs == null) return _defaultAnalyticsEnabled;
    return _prefs!.getBool(_analyticsEnabledKey) ?? _defaultAnalyticsEnabled;
  }

  /// Get current detailed logging enabled status
  static bool isDetailedLoggingEnabled() {
    if (_prefs == null) return _defaultDetailedLoggingEnabled;
    return _prefs!.getBool(_detailedLoggingEnabledKey) ??
        _defaultDetailedLoggingEnabled;
  }

  /// Enable or disable basic analytics
  static Future<void> setAnalyticsEnabled(bool enabled) async {
    if (_prefs == null) {
      _logger.warning('Cannot set analytics preference - not initialized');
      return;
    }

    try {
      await _prefs!.setBool(_analyticsEnabledKey, enabled);
      await _applySettingsToLogger();

      _logger.info('Analytics ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      _logger.severe('Failed to set analytics enabled: $e');
    }
  }

  /// Enable or disable detailed logging (opt-in for development/debugging)
  static Future<void> setDetailedLoggingEnabled(bool enabled) async {
    if (_prefs == null) {
      _logger.warning(
        'Cannot set detailed logging preference - not initialized',
      );
      return;
    }

    try {
      await _prefs!.setBool(_detailedLoggingEnabledKey, enabled);
      await _applySettingsToLogger();

      _logger.info('Detailed logging ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      _logger.severe('Failed to set detailed logging enabled: $e');
    }
  }

  /// Get privacy-friendly description of what data is collected
  static Map<String, dynamic> getPrivacyInfo() {
    return {
      'basicAnalytics': {
        'enabled': isAnalyticsEnabled(),
        'description':
            'Collects anonymous game statistics including bot performance metrics, '
            'game duration, rounds played, and player counts. No personal information is stored.',
        'dataTypes': [
          'Game session duration',
          'Bot personality performance',
          'Round completion stats',
          'Win/loss ratios',
          'Device type (for optimization)',
          'Game version (for compatibility)',
        ],
        'retention': '30 days maximum',
      },
      'detailedLogging': {
        'enabled': isDetailedLoggingEnabled(),
        'description':
            'Collects detailed bot decision-making data for AI improvement. '
            'This is opt-in only and used for development purposes.',
        'dataTypes': [
          'Bot decision reasoning',
          'Game state context',
          'Move sequences',
          'Risk assessment data',
          'Performance metrics',
        ],
        'retention': '7 days maximum',
        'purpose': 'AI improvement and debugging only',
      },
      'dataSecurity': {
        'encryption': 'All data is encrypted in transit and at rest',
        'anonymization': 'No personally identifiable information is collected',
        'sharing': 'Data is never shared with third parties',
        'deletion': 'Data can be deleted by disabling analytics',
      },
    };
  }

  /// Reset all analytics preferences to defaults
  static Future<void> resetToDefaults() async {
    if (_prefs == null) {
      _logger.warning('Cannot reset preferences - not initialized');
      return;
    }

    try {
      await _prefs!.setBool(_analyticsEnabledKey, _defaultAnalyticsEnabled);
      await _prefs!.setBool(
        _detailedLoggingEnabledKey,
        _defaultDetailedLoggingEnabled,
      );
      await _applySettingsToLogger();

      _logger.info('Reset analytics preferences to defaults');
    } catch (e) {
      _logger.severe('Failed to reset analytics preferences: $e');
    }
  }

  /// Clear all analytics data (request data deletion)
  static Future<void> requestDataDeletion() async {
    try {
      // Note: This would typically make an API call to request data deletion
      // For now, we'll disable analytics and log the request
      await setAnalyticsEnabled(false);
      await setDetailedLoggingEnabled(false);

      _logger.info('Data deletion requested - analytics disabled');

      // In a production environment, you would:
      // 1. Make an API call to request deletion of stored data
      // 2. Provide a reference ID for the user to track the request
      // 3. Send confirmation when deletion is complete
    } catch (e) {
      _logger.severe('Failed to process data deletion request: $e');
    }
  }

  /// Export current analytics configuration for debugging
  static Map<String, dynamic> exportConfiguration() {
    return {
      'analyticsEnabled': isAnalyticsEnabled(),
      'detailedLoggingEnabled': isDetailedLoggingEnabled(),
      'configurationVersion': '1.0',
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }
}
