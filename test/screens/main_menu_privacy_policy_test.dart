import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/screens/main_menu_screen.dart';
import 'package:hand_foot_game_flutter/screens/privacy_policy_screen.dart';
import 'package:hand_foot_game_flutter/theme/balatro_theme.dart';

void main() {
  testWidgets('main menu Privacy Policy opens the in-app policy screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: BalatroTheme.testTheme, home: const MainMenuScreen()),
    );
    await tester.pump();

    expect(find.text('Privacy Policy'), findsOneWidget);

    await tester.ensureVisible(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();

    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    expect(find.textContaining('Last updated:'), findsOneWidget);
  });
}
