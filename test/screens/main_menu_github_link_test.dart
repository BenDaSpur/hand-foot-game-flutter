import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/config/project_links.dart';
import 'package:hand_foot_game_flutter/screens/main_menu_screen.dart';
import 'package:hand_foot_game_flutter/theme/balatro_theme.dart';

void main() {
  testWidgets('main menu View on GitHub launches expected repository URL', (
    WidgetTester tester,
  ) async {
    Uri? launchedUri;
    var launchCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: BalatroTheme.darkTheme,
        home: MainMenuScreen(
          urlLauncher: (uri) async {
            launchCalls++;
            launchedUri = uri;
            return true;
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('View on GitHub'), findsOneWidget);
    expect(find.text('How to Play'), findsOneWidget);

    await tester.tap(find.text('View on GitHub'));
    await tester.pump();

    expect(launchCalls, 1);
    expect(launchedUri, Uri.parse(ProjectLinks.githubRepository));
  });

  testWidgets('main menu View on GitHub tap does not crash when launch fails', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BalatroTheme.darkTheme,
        home: MainMenuScreen(urlLauncher: (_) async => false),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('View on GitHub'));
    await tester.pump();

    expect(
      find.text('Could not open GitHub. Try again later.'),
      findsOneWidget,
    );
  });
}
