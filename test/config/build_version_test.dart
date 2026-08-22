import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/config/build_version.dart';

void main() {
  group('BuildVersion.next', () {
    test('starts calendar version at +1 from legacy semver', () {
      expect(
        BuildVersion.next(
          currentPubspecVersion: '1.0.2+4',
          now: DateTime.utc(2026, 8, 22),
        ),
        '2026.8.22+1',
      );
    });

    test('increments N for a second merge on the same UTC day', () {
      expect(
        BuildVersion.next(
          currentPubspecVersion: '2026.8.22+1',
          now: DateTime.utc(2026, 8, 22, 23, 59),
        ),
        '2026.8.22+2',
      );
    });

    test('resets N to 1 on a new UTC day', () {
      expect(
        BuildVersion.next(
          currentPubspecVersion: '2026.8.22+5',
          now: DateTime.utc(2026, 8, 23),
        ),
        '2026.8.23+1',
      );
    });

    test('does not pad month or day (valid Dart semver)', () {
      expect(
        BuildVersion.next(
          currentPubspecVersion: '1.0.0+1',
          now: DateTime.utc(2026, 1, 5),
        ),
        '2026.1.5+1',
      );
    });

    test('keeps two-digit months unquoted as integers', () {
      expect(
        BuildVersion.next(
          currentPubspecVersion: '2026.9.30+3',
          now: DateTime.utc(2026, 10, 1),
        ),
        '2026.10.1+1',
      );
    });

    test('increments double-digit same-day builds', () {
      expect(
        BuildVersion.next(
          currentPubspecVersion: '2026.8.22+9',
          now: DateTime.utc(2026, 8, 22),
        ),
        '2026.8.22+10',
      );
    });

    test('treats version without build number as a new day', () {
      expect(
        BuildVersion.next(
          currentPubspecVersion: '1.0.2',
          now: DateTime.utc(2026, 8, 22),
        ),
        '2026.8.22+1',
      );
    });

    test('treats malformed versions as a fresh calendar build', () {
      expect(
        BuildVersion.next(
          currentPubspecVersion: 'not-a-version',
          now: DateTime.utc(2026, 8, 22),
        ),
        '2026.8.22+1',
      );
    });

    test('uses the UTC calendar date', () {
      expect(
        BuildVersion.next(
          currentPubspecVersion: '1.0.2+4',
          now: DateTime.utc(2026, 8, 23, 2, 0),
        ),
        '2026.8.23+1',
      );
    });
  });

  group('BuildVersion.applyToPubspec', () {
    test('replaces only the version line', () {
      const pubspec = 'name: demo\nversion: 1.0.2+4\ndescription: test\n';
      expect(
        BuildVersion.applyToPubspec(
          pubspecContents: pubspec,
          version: '2026.8.22+1',
        ),
        'name: demo\nversion: 2026.8.22+1\ndescription: test\n',
      );
    });

    test('throws when pubspec has no version line', () {
      expect(
        () => BuildVersion.applyToPubspec(
          pubspecContents: 'name: demo\n',
          version: '2026.8.22+1',
        ),
        throwsFormatException,
      );
    });
  });

  group('BuildVersion.formatAppVersion', () {
    test('joins version and build number', () {
      expect(
        BuildVersion.formatAppVersion(version: '2026.8.22', buildNumber: '2'),
        '2026.8.22+2',
      );
    });

    test('omits plus when build number is empty', () {
      expect(
        BuildVersion.formatAppVersion(version: '2026.8.22', buildNumber: ''),
        '2026.8.22',
      );
    });
  });

  group('bump_build_version.dart CLI', () {
    test('writes the next calendar version into a pubspec file', () async {
      final temp = await Directory.systemTemp.createTemp('bump_build_version_');
      addTearDown(() => temp.delete(recursive: true));

      final pubspec = File('${temp.path}/pubspec.yaml');
      await pubspec.writeAsString('name: demo\nversion: 1.0.2+4\n');

      final result = await Process.run('dart', [
        'run',
        'scripts/bump_build_version.dart',
        pubspec.path,
        '2026-08-22',
      ]);

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout.toString().trim(), '2026.8.22+1');
      expect(
        await pubspec.readAsString(),
        'name: demo\nversion: 2026.8.22+1\n',
      );
    });

    test('rejects an invalid month', () async {
      final result = await Process.run('dart', [
        'run',
        'scripts/bump_build_version.dart',
        'pubspec.yaml',
        '2026-13-01',
      ]);

      expect(result.exitCode, isNot(0));
      expect(result.stderr.toString(), contains('Invalid calendar date'));
    });

    test('rejects an invalid day', () async {
      final result = await Process.run('dart', [
        'run',
        'scripts/bump_build_version.dart',
        'pubspec.yaml',
        '2026-02-30',
      ]);

      expect(result.exitCode, isNot(0));
      expect(result.stderr.toString(), contains('Invalid calendar date'));
    });
  });
}
