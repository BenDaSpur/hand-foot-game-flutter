import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/legal/privacy_policy_content.dart';
import 'package:hand_foot_game_flutter/screens/privacy_policy_screen.dart';
import 'package:hand_foot_game_flutter/theme/balatro_theme.dart';

void main() {
  testWidgets('privacy policy screen shows title, date, and sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BalatroTheme.testTheme,
        home: const PrivacyPolicyScreen(),
      ),
    );

    expect(find.text(PrivacyPolicyContent.title), findsWidgets);
    expect(
      find.text('Last updated: ${PrivacyPolicyContent.lastUpdated}'),
      findsOneWidget,
    );
    expect(find.text(PrivacyPolicyContent.website), findsOneWidget);
    expect(find.text(PrivacyPolicyContent.intro), findsOneWidget);

    for (final section in PrivacyPolicyContent.sections) {
      expect(find.text(section.title), findsOneWidget);
    }
  });

  testWidgets('privacy policy screen back button pops the route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BalatroTheme.testTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyPolicyScreen), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });
}
