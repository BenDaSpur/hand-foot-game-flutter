import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/config/project_links.dart';
import 'package:hand_foot_game_flutter/screens/main_menu_screen.dart';
import 'package:hand_foot_game_flutter/theme/balatro_theme.dart';

void main() {
  testWidgets('main menu hides iOS App Store link when not on web', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BalatroTheme.darkTheme,
        home: const MainMenuScreen(isWeb: false),
      ),
    );
    await tester.pump();

    expect(find.text('Get on iOS'), findsNothing);
    expect(find.text('Install App'), findsNothing);
  });

  testWidgets('main menu Get on iOS launches App Store URL on web', (
    WidgetTester tester,
  ) async {
    Uri? launchedUri;
    var launchCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: BalatroTheme.darkTheme,
        home: MainMenuScreen(
          isWeb: true,
          urlLauncher: (uri) async {
            launchCalls++;
            launchedUri = uri;
            return true;
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Get on iOS'), findsOneWidget);
    expect(find.text('Install App'), findsOneWidget);

    await tester.ensureVisible(find.text('Get on iOS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get on iOS'));
    await tester.pump();

    expect(launchCalls, 1);
    expect(launchedUri, Uri.parse(ProjectLinks.iosAppStore));
  });

  testWidgets('main menu Get on iOS tap does not crash when launch fails', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BalatroTheme.darkTheme,
        home: MainMenuScreen(isWeb: true, urlLauncher: (_) async => false),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Get on iOS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get on iOS'));
    await tester.pump();

    expect(
      find.text('Could not open the App Store. Try again later.'),
      findsOneWidget,
    );
  });
}
