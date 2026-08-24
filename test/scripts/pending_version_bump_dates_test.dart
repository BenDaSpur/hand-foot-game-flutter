import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pending_version_bump_dates.sh', () {
    test('prints only HEAD when history has no version-bump commit', () async {
      final repo = await _createRepo();
      addTearDown(() => repo.delete(recursive: true));

      await _commit(repo, message: 'first', dateIso: '2026-08-20T12:00:00Z');
      await _commit(repo, message: 'second', dateIso: '2026-08-22T15:30:00Z');

      final result = await _runScript(repo);
      expect(result.exitCode, 0, reason: result.stderr);
      expect(result.stdout.trim(), '2026-08-22');
    });

    test(
      'prints first-parent dates after the last bump, oldest first',
      () async {
        final repo = await _createRepo();
        addTearDown(() => repo.delete(recursive: true));

        await _commit(
          repo,
          message: 'chore: bump build version to 2026.8.21+1',
          dateIso: '2026-08-21T10:00:00Z',
        );
        await _commit(
          repo,
          message: 'merge A',
          dateIso: '2026-08-22T09:00:00Z',
        );
        await _commit(
          repo,
          message: 'merge B',
          dateIso: '2026-08-23T01:00:00Z',
        );

        final result = await _runScript(repo);
        expect(result.exitCode, 0, reason: result.stderr);
        expect(result.stdout.trim().split('\n'), ['2026-08-22', '2026-08-23']);
      },
    );

    test('ignores second-parent feature commits on a merge', () async {
      final repo = await _createRepo();
      addTearDown(() => repo.delete(recursive: true));

      await _commit(
        repo,
        message: 'chore: bump build version to 2026.8.21+1',
        dateIso: '2026-08-21T10:00:00Z',
      );
      await _commit(repo, message: 'mainline', dateIso: '2026-08-22T08:00:00Z');

      await Process.run('git', [
        'checkout',
        '-b',
        'feature',
      ], workingDirectory: repo.path);
      await _commit(
        repo,
        message: 'feature work',
        dateIso: '2026-08-22T09:00:00Z',
      );
      await Process.run('git', [
        'checkout',
        'main',
      ], workingDirectory: repo.path);
      final merge = await Process.run('git', [
        'merge',
        '--no-ff',
        '-m',
        'Merge feature',
        'feature',
      ], workingDirectory: repo.path);
      expect(merge.exitCode, 0, reason: merge.stderr);

      final result = await _runScript(repo);
      expect(result.exitCode, 0, reason: result.stderr);
      expect(result.stdout.trim().split('\n'), hasLength(2));
      expect(result.stdout, isNot(contains('feature work')));
    });

    test('prints nothing when HEAD is already a bump commit', () async {
      final repo = await _createRepo();
      addTearDown(() => repo.delete(recursive: true));

      await _commit(
        repo,
        message: 'chore: bump build version to 2026.8.22+1',
        dateIso: '2026-08-22T18:00:00Z',
      );

      final result = await _runScript(repo);
      expect(result.exitCode, 0, reason: result.stderr);
      expect(result.stdout.trim(), isEmpty);
    });
  });
}

Future<Directory> _createRepo() async {
  final repo = await Directory.systemTemp.createTemp('pending_version_dates_');
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

Future<void> _commit(
  Directory repo, {
  required String message,
  required String dateIso,
}) async {
  final file = File('${repo.path}/log.txt');
  await file.writeAsString('$message\n', mode: FileMode.append);
  await Process.run('git', ['add', 'log.txt'], workingDirectory: repo.path);
  final result = await Process.run(
    'git',
    ['commit', '-m', message],
    workingDirectory: repo.path,
    environment: <String, String>{
      ...Platform.environment,
      'GIT_AUTHOR_DATE': dateIso,
      'GIT_COMMITTER_DATE': dateIso,
    },
  );
  expect(result.exitCode, 0, reason: result.stderr);
}

Future<ProcessResult> _runScript(Directory repo) {
  return Process.run('bash', [
    '${Directory.current.path}/scripts/pending_version_bump_dates.sh',
  ], workingDirectory: repo.path);
}
