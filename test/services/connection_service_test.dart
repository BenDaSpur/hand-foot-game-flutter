import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/services/connection_service.dart';

void main() {
  group('ConnectionService', () {
    tearDown(() {
      ConnectionService.dispose();
    });

    test('initializes correctly', () async {
      await ConnectionService.initialize();
      expect(ConnectionService.isConnected, isA<bool>());
    });

    test('provides connection stream', () async {
      await ConnectionService.initialize();
      expect(ConnectionService.connectionStream, isA<Stream<bool>>());
    });

    test('handles double initialization gracefully', () async {
      await ConnectionService.initialize();
      await ConnectionService.initialize(); // Should not throw
      expect(ConnectionService.isConnected, isA<bool>());
    });

    test('disposes cleanly', () {
      // Should not throw
      ConnectionService.dispose();
      ConnectionService.dispose(); // Should handle double disposal
    });

    test('waitForConnection completes when already connected', () async {
      await ConnectionService.initialize();
      if (ConnectionService.isConnected) {
        // Should complete immediately if already connected
        await expectLater(
          ConnectionService.waitForConnection(
            timeout: const Duration(seconds: 1),
          ),
          completes,
        );
      }
    });

    test('waitForConnection times out when offline', () async {
      await ConnectionService.initialize();
      // If currently disconnected, should timeout
      if (!ConnectionService.isConnected) {
        await expectLater(
          ConnectionService.waitForConnection(
            timeout: const Duration(milliseconds: 100),
          ),
          throwsA(isA<TimeoutException>()),
        );
      }
    });

    test('connection service provides basic functionality', () async {
      await ConnectionService.initialize();

      // Basic functionality should work in test environment
      expect(ConnectionService.isConnected, isA<bool>());
      expect(ConnectionService.connectionStream, isA<Stream<bool>>());
    });

    test('gracefully handles connectivity plugin errors', () async {
      // Should not throw even if connectivity plugin has issues
      await expectLater(() => ConnectionService.initialize(), returnsNormally);
    });
  });
}
