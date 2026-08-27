@Tags(['haptics'])
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/services/haptic_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HapticService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = HapticService();
    service.resetForTest();
  });

  group('HapticService', () {
    test('defaults to enabled', () {
      expect(service.hapticsEnabled, isTrue);
    });

    test('loads persisted disabled preference', () async {
      SharedPreferences.setMockInitialValues({
        HapticService.preferenceKey: false,
      });
      service.resetForTest(initialized: false);

      await service.initialize();

      expect(service.hapticsEnabled, isFalse);
    });

    test('initialize is idempotent', () async {
      SharedPreferences.setMockInitialValues({
        HapticService.preferenceKey: false,
      });
      service.resetForTest(enabled: true, initialized: false);

      await service.initialize();
      expect(service.hapticsEnabled, isFalse);

      SharedPreferences.setMockInitialValues({
        HapticService.preferenceKey: true,
      });
      await service.initialize();
      expect(service.hapticsEnabled, isFalse);
    });

    test('does not play before initialize', () {
      service.resetForTest(initialized: false);

      service.selectionClick();
      service.lightImpact();
      service.mediumImpact();
      service.heavyImpact();

      expect(service.debugPlayed, isEmpty);
    });

    test('records selection, light, medium, and heavy when enabled', () {
      service.selectionClick();
      service.lightImpact();
      service.mediumImpact();
      service.heavyImpact();

      expect(service.debugPlayed, [
        HapticKind.selection,
        HapticKind.light,
        HapticKind.medium,
        HapticKind.heavy,
      ]);
    });

    test('does not play when vibrations are disabled', () async {
      await service.setHapticsEnabled(false);
      service.debugPlayed.clear();

      service.selectionClick();
      service.lightImpact();
      service.mediumImpact();
      service.heavyImpact();

      expect(service.hapticsEnabled, isFalse);
      expect(service.debugPlayed, isEmpty);
    });

    test('persists the preference', () async {
      await service.setHapticsEnabled(false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(HapticService.preferenceKey), isFalse);

      await service.setHapticsEnabled(true);
      expect(prefs.getBool(HapticService.preferenceKey), isTrue);
    });

    test('plays a confirmation pulse when re-enabled', () async {
      await service.setHapticsEnabled(false);
      service.debugPlayed.clear();

      await service.setHapticsEnabled(true);

      expect(service.debugPlayed, [HapticKind.light]);
    });

    test('swallows platform-channel failures from HapticFeedback', () async {
      service.suppressPlatformHaptics = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            throw PlatformException(
              code: 'unavailable',
              message: 'no haptic motor',
            );
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      service.selectionClick();
      await Future<void>.delayed(Duration.zero);

      expect(service.debugPlayed, [HapticKind.selection]);
    });

    test(
      'setHapticsEnabled waits for initialize and keeps the new value',
      () async {
        SharedPreferences.setMockInitialValues({
          HapticService.preferenceKey: true,
        });
        service.resetForTest(initialized: false, enabled: true);

        final init = service.initialize();
        final set = service.setHapticsEnabled(false);
        await Future.wait<void>([init, set]);

        expect(service.hapticsEnabled, isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(HapticService.preferenceKey), isFalse);
      },
    );

    test('overlapping setHapticsEnabled writes apply in order', () async {
      final first = service.setHapticsEnabled(false);
      final second = service.setHapticsEnabled(true);
      await Future.wait<void>([first, second]);

      expect(service.hapticsEnabled, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(HapticService.preferenceKey), isTrue);
    });
  });
}
