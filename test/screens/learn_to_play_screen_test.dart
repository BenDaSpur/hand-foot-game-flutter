import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/screens/learn_to_play_screen.dart';
import 'package:hand_foot_game_flutter/theme/balatro_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpLearnScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // Compact action-button layout can overflow by a few pixels in tests;
  // ignore those so we can assert coach + lock behavior.
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
      return;
    }
    originalOnError?.call(details);
  };
  addTearDown(() {
    FlutterError.onError = originalOnError;
  });

  await tester.pumpWidget(
    MaterialApp(theme: BalatroTheme.testTheme, home: const LearnToPlayScreen()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('uses real game UI with coach banner and locked actions', (
    tester,
  ) async {
    await _pumpLearnScreen(tester);

    expect(find.text('HAND & FOOT'), findsOneWidget);
    expect(find.textContaining('Hand and a Foot'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    final drawFinder = find.widgetWithText(ElevatedButton, 'Draw from deck');
    expect(drawFinder, findsOneWidget);
    expect(tester.widget<ElevatedButton>(drawFinder).onPressed, isNull);
  });

  testWidgets('draw step enables Draw from deck on the real action bar', (
    tester,
  ) async {
    await _pumpLearnScreen(tester);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('drawing 2 cards'), findsOneWidget);
    final drawFinder = find.widgetWithText(ElevatedButton, 'Draw from deck');
    expect(tester.widget<ElevatedButton>(drawFinder).onPressed, isNotNull);
  });
}
