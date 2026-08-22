import 'dart:io';

import 'package:hand_foot_game_flutter/config/build_version.dart';

/// Bumps `pubspec.yaml` to the next UTC calendar build version (`YYYY.M.D+N`).
///
/// Usage:
///   dart run scripts/bump_build_version.dart [pubspec_path] [YYYY-MM-DD]
void main(List<String> args) {
  final pubspecPath = args.isNotEmpty ? args[0] : 'pubspec.yaml';
  final now = args.length > 1 ? _parseUtcDate(args[1]) : DateTime.now().toUtc();

  final pubspecFile = File(pubspecPath);
  if (!pubspecFile.existsSync()) {
    stderr.writeln('Error: $pubspecPath does not exist');
    exit(1);
  }

  try {
    final contents = pubspecFile.readAsStringSync();
    final current = _currentVersion(contents);
    final next = BuildVersion.next(currentPubspecVersion: current, now: now);
    final updated = BuildVersion.applyToPubspec(
      pubspecContents: contents,
      version: next,
    );
    pubspecFile.writeAsStringSync(updated);
    stdout.writeln(next);
  } catch (e) {
    stderr.writeln('Error bumping build version: $e');
    exit(1);
  }
}

String _currentVersion(String pubspecContents) {
  final match = RegExp(
    r'^version:\s*(.+)$',
    multiLine: true,
  ).firstMatch(pubspecContents);
  if (match == null) {
    throw const FormatException('pubspec.yaml has no version: line');
  }
  return match.group(1)!.trim();
}

DateTime _parseUtcDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    throw FormatException('Expected YYYY-MM-DD, got "$value"');
  }
  return DateTime.utc(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}
