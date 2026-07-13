import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/services/web_deploy_version_logic.dart';

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
}
