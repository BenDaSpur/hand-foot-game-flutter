import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/screens/learn_to_play_screen.dart';
import 'package:hand_foot_game_flutter/screens/main_menu_screen.dart';
import 'package:hand_foot_game_flutter/theme/balatro_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/learn_to_play_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('main menu shows LEARN TO PLAY button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: BalatroTheme.testTheme, home: const MainMenuScreen()),
    );
    await tester.pump();

    expect(find.text('LEARN TO PLAY'), findsOneWidget);
    expect(find.text('How to Play'), findsOneWidget);
    expect(find.text('Learn to Play?'), findsNothing);
  });

  testWidgets('LEARN TO PLAY opens lesson screen', (tester) async {
    configureLearnToPlayTestViewport(tester);

    await tester.pumpWidget(
      MaterialApp(theme: BalatroTheme.testTheme, home: const MainMenuScreen()),
    );
    await tester.pump();

    await tester.tap(find.text('LEARN TO PLAY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    expect(find.byType(LearnToPlayScreen), findsOneWidget);
    expect(find.textContaining('Hand and a Foot'), findsOneWidget);
  });
}
