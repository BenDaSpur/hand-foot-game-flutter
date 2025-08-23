import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Service for generating stable, privacy-friendly device identifiers
/// This provides a more secure alternative to anonymous authentication
class DeviceService {
  static final Logger _logger = Logger('DeviceService');
  static const String _deviceIdKey = 'device_id';
  static const String _deviceNameKey = 'device_name';

  static String? _cachedDeviceId;
  static String? _cachedDeviceName;

  /// Get a stable device identifier that persists across app sessions
  /// This combines device info with a locally stored UUID for privacy
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if we already have a stored device ID
      String? storedId = prefs.getString(_deviceIdKey);

      if (storedId != null && storedId.isNotEmpty) {
        _cachedDeviceId = storedId;
        _logger.info('Using stored device ID: ${storedId.substring(0, 8)}...');
        return storedId;
      }

      // Generate a new device-specific ID
      final deviceId = await _generateDeviceId();

      // Store it for future use
      await prefs.setString(_deviceIdKey, deviceId);
      _cachedDeviceId = deviceId;

      _logger.info('Generated new device ID: ${deviceId.substring(0, 8)}...');
      return deviceId;
    } catch (e) {
      _logger.severe('Failed to get device ID: $e');
      // Fallback to a simple UUID
      const uuid = Uuid();
      return uuid.v4();
    }
  }

  /// Get a human-readable device name for display purposes
  static Future<String> getDeviceName() async {
    if (_cachedDeviceName != null) {
      return _cachedDeviceName!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if we have a stored device name
      String? storedName = prefs.getString(_deviceNameKey);
      if (storedName != null && storedName.isNotEmpty) {
        _cachedDeviceName = storedName;
        return storedName;
      }

      // Generate device name based on platform
      final deviceName = await _generateDeviceName();

      // Store it
      await prefs.setString(_deviceNameKey, deviceName);
      _cachedDeviceName = deviceName;

      return deviceName;
    } catch (e) {
      _logger.warning('Failed to get device name: $e');
      return _getFallbackDeviceName();
    }
  }

  /// Generate a unique device ID combining device info and UUID
  static Future<String> _generateDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceIdentifier = '';

    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceIdentifier =
            '${webInfo.browserName}_${webInfo.platform}_${webInfo.userAgent.hashCode}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceIdentifier = '${androidInfo.model}_${androidInfo.fingerprint}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceIdentifier = '${iosInfo.model}_${iosInfo.identifierForVendor}';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        deviceIdentifier = '${macInfo.model}_${macInfo.systemGUID}';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        deviceIdentifier =
            '${windowsInfo.computerName}_${windowsInfo.deviceId}';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        deviceIdentifier = '${linuxInfo.name}_${linuxInfo.machineId}';
      }
    } catch (e) {
      _logger.warning('Failed to get detailed device info: $e');
    }

    // Combine device identifier with a UUID for uniqueness
    // Use crypto-quality UUID instead of hashCode to prevent collisions
    const uuid = Uuid();
    final uniquePart = uuid.v4().split('-').first; // Use first part of UUID

    // Create a more collision-resistant identifier by combining multiple elements
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final deviceHash = deviceIdentifier.length > 8
        ? deviceIdentifier.substring(
            0,
            8,
          ) // Use actual chars instead of hashCode
        : deviceIdentifier.padRight(8, '0');

    return 'device_${deviceHash}_${uniquePart}_${timestamp.substring(timestamp.length - 6)}';
  }

  /// Generate a human-readable device name
  static Future<String> _generateDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        return '${webInfo.browserName} on ${webInfo.platform}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.name} (${iosInfo.model})';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        return '${macInfo.computerName} (${macInfo.model})';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        return windowsInfo.computerName;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        return '${linuxInfo.name} (${linuxInfo.prettyName})';
      }
    } catch (e) {
      _logger.warning('Failed to get device name: $e');
    }

    return _getFallbackDeviceName();
  }

  /// Get a fallback device name when device info is not available
  static String _getFallbackDeviceName() {
    if (kIsWeb) {
      return 'Web Browser';
    } else if (Platform.isAndroid) {
      return 'Android Device';
    } else if (Platform.isIOS) {
      return 'iOS Device';
    } else if (Platform.isMacOS) {
      return 'Mac';
    } else if (Platform.isWindows) {
      return 'Windows PC';
    } else if (Platform.isLinux) {
      return 'Linux PC';
    } else {
      return 'Unknown Device';
    }
  }

  /// Clear stored device information (for testing or reset purposes)
  static Future<void> clearDeviceInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deviceIdKey);
      await prefs.remove(_deviceNameKey);

      _cachedDeviceId = null;
      _cachedDeviceName = null;

      _logger.info('Device information cleared');
    } catch (e) {
      _logger.warning('Failed to clear device info: $e');
    }
  }

  /// Check if this is the first time the app is running on this device
  static Future<bool> isFirstRun() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !prefs.containsKey(_deviceIdKey);
    } catch (e) {
      _logger.warning('Failed to check first run: $e');
      return true;
    }
  }

  /// Get device information for debugging
  static Future<Map<String, String>> getDebugInfo() async {
    return {
      'deviceId': await getDeviceId(),
      'deviceName': await getDeviceName(),
      'isFirstRun': (await isFirstRun()).toString(),
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
    };
  }
}
