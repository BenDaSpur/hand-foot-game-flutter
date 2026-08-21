import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/config/project_links.dart';
import 'package:hand_foot_game_flutter/legal/privacy_policy_content.dart';

void main() {
  test('privacy policy content covers required topics', () {
    final titles = PrivacyPolicyContent.sections.map((s) => s.title).toList();

    expect(PrivacyPolicyContent.title, 'Privacy Policy');
    expect(PrivacyPolicyContent.website, 'https://playhandfoot.com');
    expect(PrivacyPolicyContent.publicUrl, ProjectLinks.privacyPolicy);
    expect(titles, contains('Information you provide'));
    expect(titles, contains('Information collected automatically'));
    expect(
      titles,
      contains('Cookies, local storage, and similar technologies'),
    );
    expect(titles, contains('Third-party services'));
    expect(titles, contains('Your choices and rights'));
    expect(titles, contains('Advertising on native apps'));
    expect(titles, contains('Children'));
    expect(titles, contains('Contact'));

    final fullText = [
      PrivacyPolicyContent.intro,
      ...PrivacyPolicyContent.sections.map((s) => s.body),
    ].join('\n');
    expect(fullText, contains('Firebase'));
    expect(fullText, contains('Vercel'));
    expect(fullText, contains('GitHub'));
    expect(fullText, contains('AdMob'));
    expect(fullText, contains('do not sell'));
    expect(fullText, contains('Security Policy'));
    expect(fullText, contains(ProjectLinks.securityPolicy));
    expect(fullText, contains('Do not open a public GitHub issue'));
    expect(
      fullText.toLowerCase(),
      isNot(contains('open a github issue on the project')),
    );
  });

  test('static privacy.html mirrors in-app section titles', () {
    final html = File('web/privacy.html').readAsStringSync();

    expect(html, contains('<h1>Privacy Policy</h1>'));
    expect(html, contains('Last updated: ${PrivacyPolicyContent.lastUpdated}'));
    expect(html, contains(PrivacyPolicyContent.website));

    for (final section in PrivacyPolicyContent.sections) {
      expect(
        html,
        contains('<h2>${section.title}</h2>'),
        reason: 'privacy.html missing section "${section.title}"',
      );
    }

    expect(html, contains('Do not open a public GitHub issue'));
    expect(html, contains(ProjectLinks.securityPolicy));
    expect(
      html.toLowerCase(),
      isNot(contains('open a github issue on the project')),
    );
  });

  test('vercel.json sets no-cache headers for both privacy URL forms', () {
    final config =
        jsonDecode(File('vercel.json').readAsStringSync())
            as Map<String, dynamic>;
    final headers = (config['headers'] as List).cast<Map<String, dynamic>>();

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
    expect(cacheControl('/privacy.html'), expected);
    expect(cacheControl('/privacy'), expected);

    final rewrites = (config['rewrites'] as List).cast<Map<String, dynamic>>();
    expect(
      rewrites.any((rewrite) {
        return rewrite['source'] == '/privacy' &&
            rewrite['destination'] == '/privacy.html';
      }),
      isTrue,
    );
  });

  test('project links point at the public privacy policy URL', () {
    expect(ProjectLinks.privacyPolicy, 'https://playhandfoot.com/privacy.html');
    expect(ProjectLinks.securityPolicy, endsWith('/blob/main/SECURITY.md'));
    expect(
      ProjectLinks.iosAppStore,
      'https://apps.apple.com/us/app/hand-foot-card-game/id6802127614',
    );
  });
}
