import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/screens/learn_to_play_screen.dart';
import 'package:hand_foot_game_flutter/screens/main_menu_screen.dart';
import 'package:hand_foot_game_flutter/services/learn_to_play_preferences.dart';
import 'package:hand_foot_game_flutter/theme/balatro_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('main menu shows LEARN TO PLAY button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BalatroTheme.testTheme,
        home: const MainMenuScreen(enableLearnToPlayOffer: false),
      ),
    );
    await tester.pump();

    expect(find.text('LEARN TO PLAY'), findsOneWidget);
    expect(find.text('How to Play'), findsOneWidget);
  });

  testWidgets('first-visit offer Skip dismisses future offers', (tester) async {
    expect(await LearnToPlayPreferences.shouldShowOffer(), isTrue);

    await tester.pumpWidget(
      MaterialApp(theme: BalatroTheme.testTheme, home: const MainMenuScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Learn to Play?'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(await LearnToPlayPreferences.shouldShowOffer(), isFalse);
    expect(find.text('LEARN TO PLAY'), findsOneWidget);
  });

  testWidgets('LEARN TO PLAY opens lesson screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BalatroTheme.testTheme,
        home: const MainMenuScreen(enableLearnToPlayOffer: false),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('LEARN TO PLAY'));
    await tester.pumpAndSettle();

    expect(find.byType(LearnToPlayScreen), findsOneWidget);
    expect(find.textContaining('Hand and a Foot'), findsOneWidget);
  });
}
