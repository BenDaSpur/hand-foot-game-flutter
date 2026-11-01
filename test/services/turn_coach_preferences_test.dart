import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/services/turn_coach_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('fresh prefs should show the turn coach', () async {
    expect(await TurnCoachPreferences.shouldShowCoach(), isTrue);
  });

  test('dismissCoach hides future coach strips', () async {
    await TurnCoachPreferences.dismissCoach();
    expect(await TurnCoachPreferences.shouldShowCoach(), isFalse);
  });
}
