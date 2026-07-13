import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/deploy_version.dart';
import 'web_deploy_version_logic.dart';
import 'web_deploy_version_platform.dart';

/// Polls deployed [version.json] and notifies when a newer build is available.
class WebDeployVersionService {
  WebDeployVersionService({
    Future<String?> Function()? fetchVersionJson,
    Duration pollInterval = const Duration(minutes: 5),
  }) : _fetchVersionJson = fetchVersionJson ?? fetchDeployVersionJson,
       _pollInterval = pollInterval;

  final Future<String?> Function() _fetchVersionJson;
  final Duration _pollInterval;

  String? _sessionBuildNumber;
  Timer? _pollTimer;
  VoidCallback? _onUpdateAvailable;

  /// Starts polling on web; no-op on other platforms.
  void start({required VoidCallback onUpdateAvailable}) {
    if (!kIsWeb) {
      return;
    }

    _onUpdateAvailable = onUpdateAvailable;
    unawaited(_initializeSessionBuildNumber());
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(_checkForUpdate());
    });
  }

  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _onUpdateAvailable = null;
  }

  Future<void> _initializeSessionBuildNumber() async {
    final remoteJson = await _fetchVersionJson();
    final remoteBuildNumber = remoteJson == null
        ? null
        : parseBuildNumberFromVersionJson(remoteJson);

    _sessionBuildNumber = _firstNonEmpty([
      remoteBuildNumber,
      DeployVersion.buildNumber,
    ]);

    await _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final remoteJson = await _fetchVersionJson();
    if (remoteJson == null) {
      return;
    }

    final remoteBuildNumber = parseBuildNumberFromVersionJson(remoteJson);
    if (isRemoteBuildNewer(
      sessionBuildNumber: _sessionBuildNumber,
      remoteBuildNumber: remoteBuildNumber,
    )) {
      _onUpdateAvailable?.call();
    }
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}

void reloadForNewDeploy() {
  reloadDeployWebPage();
}
