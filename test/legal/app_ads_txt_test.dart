import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/config/project_links.dart';

const _expectedAuthorizationRecord =
    'google.com, pub-8788020871095245, DIRECT, f08c47fec0942fa0';

List<String> _activeAppAdsLines(String contents) {
  return contents
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toList();
}

void main() {
  test('web/app-ads.txt contains the AdMob publisher authorization line', () {
    final contents = File('web/app-ads.txt').readAsStringSync();
    final activeLines = _activeAppAdsLines(contents);

    expect(activeLines, contains(_expectedAuthorizationRecord));
    expect(ProjectLinks.appAdsTxt, 'https://playhandfoot.com/app-ads.txt');
  });

  test('vercel.json sets no-cache headers for app-ads.txt', () {
    final config =
        jsonDecode(File('vercel.json').readAsStringSync())
            as Map<String, dynamic>;
    final headers = (config['headers'] as List).cast<Map<String, dynamic>>();
    final endpoint = Uri.parse(ProjectLinks.appAdsTxt);

    String? cacheControl(String source) {
      for (final rule in headers) {
        if (rule['source'] != source) {
          continue;
        }
        final ruleHeaders = (rule['headers'] as List)
            .cast<Map<String, dynamic>>();
        for (final header in ruleHeaders) {
          if (header['key'] == 'Cache-Control') {
            return header['value'] as String?;
          }
        }
      }
      return null;
    }

    const expected = 'no-cache, no-store, must-revalidate';
    expect(cacheControl(endpoint.path), expected);

    final servedContents = File('web${endpoint.path}').readAsStringSync();
    expect(
      _activeAppAdsLines(servedContents),
      contains(_expectedAuthorizationRecord),
    );
  });
}
