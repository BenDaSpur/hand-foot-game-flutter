import 'dart:convert';

/// Parses the deploy build id from Flutter web [version.json].
String? parseBuildNumberFromVersionJson(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      return null;
    }

    final buildNumber = decoded['build_number'];
    if (buildNumber == null) {
      return null;
    }

    final value = buildNumber.toString().trim();
    if (value.isEmpty) {
      return null;
    }

    return value;
  } catch (_) {
    return null;
  }
}

/// Returns true when [remoteBuildNumber] represents a newer deploy.
bool isRemoteBuildNewer({
  required String? sessionBuildNumber,
  required String? remoteBuildNumber,
}) {
  if (sessionBuildNumber == null || sessionBuildNumber.isEmpty) {
    return false;
  }
  if (remoteBuildNumber == null || remoteBuildNumber.isEmpty) {
    return false;
  }

  return remoteBuildNumber != sessionBuildNumber;
}
