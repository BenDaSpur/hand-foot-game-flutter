import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../utils/debug_logger.dart';

/// Points the iOS ads plugin at the foreground scene window before a load.
///
/// `google_mobile_ads` reads `UIApplication.delegate.window` when an
/// interstitial is loaded and presents from that controller later. The
/// scene-based embed leaves that window nil, so the plugin falls back to
/// `keyWindow`, which on Duo can be a single pane. Binding the Flutter
/// scene window first makes the load use the full-bleed view controller.
abstract final class AdsSceneWindow {
  static const MethodChannel _channel = MethodChannel(
    'com.handfoot/ads_window',
  );

  static Future<void> bind() async {
    if (!Platform.isIOS) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('bindSceneWindow');
    } catch (e) {
      DebugLogger.debug('Ads scene window bind failed: $e');
    }
  }
}
