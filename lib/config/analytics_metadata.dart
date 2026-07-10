import 'package:package_info_plus/package_info_plus.dart';

/// Analytics version metadata loaded at runtime from package info.
class AnalyticsMetadata {
  static String? _appVersion;

  /// Loads [appVersion] from the platform package metadata.
  static Future<void> initialize() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
    } catch (_) {
      _appVersion = null;
    }
  }

  /// App version for cross-session analytics.
  static String get appVersion => _appVersion ?? 'unknown';

  AnalyticsMetadata._();
}
