import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('find_reserved_version.py', () {
    test('exits 1 when no other ref has the version', () async {
      final repo = await _createRepo();
      addTearDown(() => repo.delete(recursive: true));

      await _commitPubspec(repo, version: '2026.8.22+1', message: 'current');
      await Process.run('git', [
        'checkout',
        '-b',
        'other',
      ], workingDirectory: repo.path);
      await _commitPubspec(repo, version: '1.0.2+4', message: 'other');

      final result = await _runScript(repo, ['2026.8.22+1', 'main', 'other']);
      expect(result.exitCode, 1, reason: result.stderr);
      expect(result.stdout.trim(), isEmpty);
    });

    test('prints the other ref that already has the version', () async {
      final repo = await _createRepo();
      addTearDown(() => repo.delete(recursive: true));

      await _commitPubspec(repo, version: '1.0.2+4', message: 'current');
      await Process.run('git', [
        'checkout',
        '-b',
        'stamped',
      ], workingDirectory: repo.path);
      await _commitPubspec(repo, version: '2026.8.22+1', message: 'stamped');

      final result = await _runScript(repo, ['2026.8.22+1', 'main', 'stamped']);
      expect(result.exitCode, 0, reason: result.stderr);
      expect(result.stdout.trim(), 'stamped');
    });

    test('ignores the current ref matching the version', () async {
      final repo = await _createRepo();
      addTearDown(() => repo.delete(recursive: true));

      await _commitPubspec(repo, version: '2026.8.22+1', message: 'current');

      final result = await _runScript(repo, ['2026.8.22+1', 'main', 'main']);
      expect(result.exitCode, 1, reason: result.stderr);
    });
  });
}

Future<Directory> _createRepo() async {
  final repo = await Directory.systemTemp.createTemp('find_reserved_version_');
  final init = await Process.run('git', [
    'init',
    '-b',
    'main',
  ], workingDirectory: repo.path);
  expect(init.exitCode, 0, reason: init.stderr);
  await Process.run('git', [
    'config',
    'user.name',
    'Test',
  ], workingDirectory: repo.path);
  await Process.run('git', [
    'config',
    'user.email',
    'test@example.com',
  ], workingDirectory: repo.path);
  return repo;
}

Future<void> _commitPubspec(
  Directory repo, {
  required String version,
  required String message,
}) async {
  await File('${repo.path}/pubspec.yaml').writeAsString('version: $version\n');
  await Process.run('git', [
    'add',
    'pubspec.yaml',
  ], workingDirectory: repo.path);
  final result = await Process.run('git', [
    'commit',
    '-m',
    message,
  ], workingDirectory: repo.path);
  expect(result.exitCode, 0, reason: result.stderr);
}

Future<ProcessResult> _runScript(Directory repo, List<String> args) {
  return Process.run('python3', [
    '${Directory.current.path}/scripts/find_reserved_version.py',
    ...args,
  ], workingDirectory: repo.path);
}
