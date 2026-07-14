import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/screens/learn_to_play_screen.dart';
import 'package:hand_foot_game_flutter/theme/balatro_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows coach text and locks non-draw actions on welcome', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BalatroTheme.testTheme,
        home: const LearnToPlayScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Hand and a Foot'), findsOneWidget);

    final drawButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Draw from deck'),
    );
    final playButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Play Cards'),
    );
    expect(drawButton.onPressed, isNull);
    expect(playButton.onPressed, isNull);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('draw step enables only Draw from deck', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BalatroTheme.testTheme,
        home: const LearnToPlayScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.textContaining('drawing 2 cards'), findsOneWidget);

    final drawButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Draw from deck'),
    );
    final playButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Play Cards'),
    );
    expect(drawButton.onPressed, isNotNull);
    expect(playButton.onPressed, isNull);
  });
}
