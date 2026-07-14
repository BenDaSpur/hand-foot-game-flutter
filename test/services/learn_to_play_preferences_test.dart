import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/services/learn_to_play_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('shouldShowOffer is true by default', () async {
    expect(await LearnToPlayPreferences.shouldShowOffer(), isTrue);
  });

  test('dismissOffer makes shouldShowOffer false', () async {
    await LearnToPlayPreferences.dismissOffer();
    expect(await LearnToPlayPreferences.shouldShowOffer(), isFalse);
  });

  test('resetOfferForTests restores offer', () async {
    await LearnToPlayPreferences.dismissOffer();
    await LearnToPlayPreferences.resetOfferForTests();
    expect(await LearnToPlayPreferences.shouldShowOffer(), isTrue);
  });
}
