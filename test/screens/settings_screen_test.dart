import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/screens/settings_screen.dart';
import 'package:hand_foot_game_flutter/services/haptic_service.dart';
import 'package:hand_foot_game_flutter/theme/balatro_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HapticService().resetForTest(initialized: false);
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: BalatroTheme.testTheme, home: const SettingsScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('shows vibrations toggle enabled by default', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Vibrations'), findsOneWidget);
    expect(find.textContaining('Perfect Grab'), findsOneWidget);

    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.value, isTrue);
  });

  testWidgets('toggling vibrations off persists the preference', (
    tester,
  ) async {
    await pumpSettings(tester);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(HapticService().hapticsEnabled, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(HapticService.preferenceKey), isFalse);
  });

  testWidgets('loads a previously disabled preference', (tester) async {
    SharedPreferences.setMockInitialValues({
      HapticService.preferenceKey: false,
    });

    await pumpSettings(tester);

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('back button pops the route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BalatroTheme.testTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });
}
