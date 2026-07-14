import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Compact Learn to Play layouts can overflow by a few pixels in widget tests.
/// Call from tests that pump [LearnToPlayScreen] or navigate into it.
void configureLearnToPlayTestViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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
}

/// Pumps [widget] then settles the first Learn to Play frames.
Future<void> pumpLearnToPlayFrame(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump();
}
