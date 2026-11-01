import 'dart:io';

import 'package:flutter/services.dart';

import '../utils/debug_logger.dart';
import 'foundation_models_service.dart';
import 'foundation_models_service_stub.dart';

FoundationModelsService createFoundationModelsService() {
  if (Platform.isIOS) {
    return IosFoundationModelsService();
  }
  return StubFoundationModelsService();
}

/// MethodChannel client for the iOS Foundation Models bridge.
class IosFoundationModelsService implements FoundationModelsService {
  static const MethodChannel _channel = MethodChannel(
    'com.spurlockapp.handfootgame/foundation_models',
  );

  @override
  Future<FoundationModelsAvailability> checkAvailability() async {
    try {
      final result = await _channel.invokeMethod<dynamic>('isAvailable');
      if (result is Map) {
        final available = result['available'] == true;
        final reason =
            result['reason']?.toString() ??
            (available ? 'available' : 'unavailable');
        return FoundationModelsAvailability(
          available: available,
          reason: reason,
        );
      }
      if (result == true) {
        return const FoundationModelsAvailability(
          available: true,
          reason: 'available',
        );
      }
      return const FoundationModelsAvailability(
        available: false,
        reason: 'Foundation Models unavailable on this device.',
      );
    } catch (e) {
      DebugLogger.warning('Foundation Models availability check failed: $e');
      return FoundationModelsAvailability(
        available: false,
        reason: 'Availability check failed: $e',
      );
    }
  }

  @override
  Future<Map<String, dynamic>?> planTurn(Map<String, dynamic> prompt) async {
    try {
      final result = await _channel
          .invokeMethod<dynamic>('planTurn', prompt)
          .timeout(const Duration(seconds: 4));
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e) {
      DebugLogger.warning('Foundation Models planTurn failed: $e');
      return null;
    }
  }
}
