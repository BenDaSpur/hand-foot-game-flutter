import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/services/web_deploy_version_logic.dart';
import 'package:hand_foot_game_flutter/services/web_deploy_version_service.dart';

void main() {
  group('parseBuildNumberFromVersionJson', () {
    test('reads build_number from version.json payload', () {
      const json =
          '{"app_name":"hand_foot_game_flutter","version":"1.0.0","build_number":"abc123","package_name":"hand_foot_game_flutter"}';

      expect(parseBuildNumberFromVersionJson(json), 'abc123');
    });

    test('returns null for invalid json', () {
      expect(parseBuildNumberFromVersionJson('not-json'), isNull);
      expect(parseBuildNumberFromVersionJson('{}'), isNull);
    });
  });

  group('isRemoteBuildNewer', () {
    test('detects changed deploy build ids', () {
      expect(
        isRemoteBuildNewer(
          sessionBuildNumber: 'abc123',
          remoteBuildNumber: 'def456',
        ),
        isTrue,
      );
    });

    test('ignores missing or matching build ids', () {
      expect(
        isRemoteBuildNewer(
          sessionBuildNumber: 'abc123',
          remoteBuildNumber: 'abc123',
        ),
        isFalse,
      );
      expect(
        isRemoteBuildNewer(sessionBuildNumber: null, remoteBuildNumber: 'abc'),
        isFalse,
      );
      expect(
        isRemoteBuildNewer(sessionBuildNumber: 'abc123', remoteBuildNumber: ''),
        isFalse,
      );
    });
  });

  group('WebDeployVersionService', () {
    test('start polling notifies when remote build changes', () async {
      var fetchCount = 0;
      var notified = false;
      final service = WebDeployVersionService(
        enablePolling: true,
        pollInterval: const Duration(milliseconds: 20),
        fetchVersionJson: () async {
          fetchCount++;
          if (fetchCount <= 2) {
            return '{"build_number":"build-a"}';
          }
          return '{"build_number":"build-b"}';
        },
      );

      service.start(onUpdateAvailable: () => notified = true);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(notified, isTrue);
      service.dispose();
    });

    test('start polling ignores matching remote build', () async {
      var notified = false;
      final service = WebDeployVersionService(
        enablePolling: true,
        pollInterval: const Duration(milliseconds: 20),
        fetchVersionJson: () async => '{"build_number":"build-a"}',
      );

      service.start(onUpdateAvailable: () => notified = true);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(notified, isFalse);
      service.dispose();
    });

    test('start polling ignores unavailable remote build data', () async {
      var fetchCount = 0;
      var notified = false;
      final service = WebDeployVersionService(
        enablePolling: true,
        pollInterval: const Duration(milliseconds: 20),
        fetchVersionJson: () async {
          fetchCount++;
          if (fetchCount <= 2) {
            return '{"build_number":"build-a"}';
          }
          return null;
        },
      );

      service.start(onUpdateAvailable: () => notified = true);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(notified, isFalse);
      service.dispose();
    });

    test('checkForUpdate notifies when remote build changes', () async {
      var remoteBuild = 'build-a';
      var notified = false;
      final service = WebDeployVersionService(
        enablePolling: true,
        fetchVersionJson: () async => '{"build_number":"$remoteBuild"}',
      );

      service.start(onUpdateAvailable: () => notified = true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(service.sessionBuildNumber, 'build-a');
      expect(notified, isFalse);

      remoteBuild = 'build-b';
      await service.checkForUpdateNow();

      expect(notified, isTrue);
      service.dispose();
    });

    test(
      'checkForUpdate ignores matching or unavailable remote build',
      () async {
        var remoteBuild = 'build-a';
        var returnNull = false;
        var notified = false;
        final service = WebDeployVersionService(
          enablePolling: true,
          fetchVersionJson: () async {
            if (returnNull) {
              return null;
            }
            return '{"build_number":"$remoteBuild"}';
          },
        );

        service.start(onUpdateAvailable: () => notified = true);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        await service.checkForUpdateNow();
        expect(notified, isFalse);

        returnNull = true;
        await service.checkForUpdateNow();
        expect(notified, isFalse);

        service.dispose();
      },
    );
  });
}
