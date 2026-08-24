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

const _expectedAdsTxtUrl = 'https://playhandfoot.com/ads.txt';
const _expectedAdSenseClient = 'ca-pub-8788020871095245';
const _expectedAdSenseScriptSrc =
    'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=$_expectedAdSenseClient';

String? _cacheControlFor(List<Map<String, dynamic>> headers, String source) {
  for (final rule in headers) {
    if (rule['source'] != source) {
      continue;
    }
    final ruleHeaders = (rule['headers'] as List).cast<Map<String, dynamic>>();
    for (final header in ruleHeaders) {
      if (header['key'] == 'Cache-Control') {
        return header['value'] as String?;
      }
    }
  }
  return null;
}

void main() {
  test('web/app-ads.txt contains the AdMob publisher authorization line', () {
    final contents = File('web/app-ads.txt').readAsStringSync();
    final activeLines = _activeAppAdsLines(contents);

    expect(activeLines, contains(_expectedAuthorizationRecord));
    expect(ProjectLinks.appAdsTxt, 'https://playhandfoot.com/app-ads.txt');
  });

  test('web/ads.txt contains the AdSense publisher authorization line', () {
    final contents = File('web/ads.txt').readAsStringSync();
    final activeLines = _activeAppAdsLines(contents);

    expect(activeLines, contains(_expectedAuthorizationRecord));
    expect(ProjectLinks.adsTxt, _expectedAdsTxtUrl);
  });

  test('web/index.html loads the AdSense script for the site publisher', () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, contains(_expectedAdSenseScriptSrc));
    expect(html, contains('crossorigin="anonymous"'));
    final escapedSrc = RegExp.escape(_expectedAdSenseScriptSrc);
    expect(
      RegExp(
        '<script[^>]*\\basync\\b[^>]*src="$escapedSrc"|'
        '<script[^>]*src="$escapedSrc"[^>]*\\basync\\b',
      ).hasMatch(html),
      isTrue,
    );
  });

  test('vercel.json sets no-cache headers for ads authorization files', () {
    final config =
        jsonDecode(File('vercel.json').readAsStringSync())
            as Map<String, dynamic>;
    final headers = (config['headers'] as List).cast<Map<String, dynamic>>();

    const expected = 'no-cache, no-store, must-revalidate';
    for (final endpoint in [
      Uri.parse(ProjectLinks.appAdsTxt),
      Uri.parse(ProjectLinks.adsTxt),
    ]) {
      expect(
        _cacheControlFor(headers, endpoint.path),
        expected,
        reason: '${endpoint.path} must not be cached',
      );

      final servedContents = File('web${endpoint.path}').readAsStringSync();
      expect(
        _activeAppAdsLines(servedContents),
        contains(_expectedAuthorizationRecord),
      );
    }
  });
}
