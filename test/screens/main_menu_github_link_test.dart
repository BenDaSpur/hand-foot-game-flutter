import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/screens/main_menu_screen.dart';
import 'package:hand_foot_game_flutter/theme/balatro_theme.dart';

void main() {
  testWidgets('main menu shows View on GitHub link', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: BalatroTheme.darkTheme, home: const MainMenuScreen()),
    );
    await tester.pump();

    expect(find.text('View on GitHub'), findsOneWidget);
    expect(find.text('How to Play'), findsOneWidget);

    // Tap should not crash even if the platform cannot open a browser in tests.
    await tester.tap(find.text('View on GitHub'));
    await tester.pump();
  });
}
