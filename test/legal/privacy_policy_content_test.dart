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
    expect(titles, contains('Children'));
    expect(titles, contains('Contact'));

    final fullText = [
      PrivacyPolicyContent.intro,
      ...PrivacyPolicyContent.sections.map((s) => s.body),
    ].join('\n');
    expect(fullText, contains('Firebase'));
    expect(fullText, contains('Vercel'));
    expect(fullText, contains('GitHub'));
    expect(fullText, contains('do not sell'));
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
  });

  test('project links point at the public privacy policy URL', () {
    expect(ProjectLinks.privacyPolicy, 'https://playhandfoot.com/privacy.html');
  });
}
