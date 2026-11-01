import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/services/learn_to_play_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('fresh prefs should show the Learn to Play offer', () async {
    expect(await LearnToPlayPreferences.shouldShowOffer(), isTrue);
  });

  test('dismissOffer hides future offers', () async {
    await LearnToPlayPreferences.dismissOffer();
    expect(await LearnToPlayPreferences.shouldShowOffer(), isFalse);
  });
}
