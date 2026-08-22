/// Calendar build versions written to [pubspec.yaml] on merge to main.
///
/// Format: `YYYY.M.D+N` (UTC date, no leading zeros). `N` starts at 1
/// each UTC day and increments for additional merges on that date.
abstract final class BuildVersion {
  static final _versionLinePattern = RegExp(
    r'^version:\s*(.+)$',
    multiLine: true,
  );
  static final _pubspecVersionPattern = RegExp(
    r'^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$',
  );

  /// Next `YYYY.M.D+N` value from [currentPubspecVersion] and [now].
  static String next({
    required String currentPubspecVersion,
    required DateTime now,
  }) {
    final utc = now.toUtc();
    final year = utc.year;
    final month = utc.month;
    final day = utc.day;

    var buildNumber = 1;
    final parsed = tryParse(currentPubspecVersion);
    if (parsed != null &&
        parsed.year == year &&
        parsed.month == month &&
        parsed.day == day) {
      buildNumber = parsed.buildNumber + 1;
    }

    return '$year.$month.$day+$buildNumber';
  }

  /// Parsed calendar or semver pubspec version, or `null` if unusable.
  static ParsedBuildVersion? tryParse(String version) {
    final match = _pubspecVersionPattern.firstMatch(version.trim());
    if (match == null) {
      return null;
    }

    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) {
      return null;
    }

    final rawBuild = match.group(4);
    var buildNumber = 0;
    if (rawBuild != null) {
      buildNumber = int.tryParse(rawBuild) ?? 0;
    }

    return ParsedBuildVersion(
      year: year,
      month: month,
      day: day,
      buildNumber: buildNumber,
    );
  }

  /// Replaces the first `version:` line in [pubspecContents].
  static String applyToPubspec({
    required String pubspecContents,
    required String version,
  }) {
    final match = _versionLinePattern.firstMatch(pubspecContents);
    if (match == null) {
      throw const FormatException('pubspec.yaml has no version: line');
    }

    return pubspecContents.replaceFirst(match.group(0)!, 'version: $version');
  }

  /// App/analytics display string from package_info_plus fields.
  static String formatAppVersion({
    required String version,
    required String buildNumber,
  }) {
    if (buildNumber.isEmpty) {
      return version;
    }
    return '$version+$buildNumber';
  }
}

/// Components of a Flutter `version: x.y.z+build` string.
class ParsedBuildVersion {
  final int year;
  final int month;
  final int day;
  final int buildNumber;

  const ParsedBuildVersion({
    required this.year,
    required this.month,
    required this.day,
    required this.buildNumber,
  });
}
