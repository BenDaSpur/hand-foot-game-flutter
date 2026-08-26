import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/screens/main_menu_screen.dart';
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

  testWidgets('main menu Settings opens the settings screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: BalatroTheme.testTheme, home: const MainMenuScreen()),
    );
    await tester.pump();

    expect(find.text('Settings'), findsOneWidget);

    await tester.ensureVisible(find.text('Settings'));
    await tester.pump();
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Vibrations'), findsOneWidget);
  });
}
