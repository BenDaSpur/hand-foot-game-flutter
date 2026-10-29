@Tags(['widget'])
library;

import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/utils/game_fold_geometry.dart';

void main() {
  group('GameFoldGeometry', () {
    testWidgets('returns null when no display features', (tester) async {
      late Rect? bounds;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(951, 669)),
          child: Builder(
            builder: (context) {
              bounds = GameFoldGeometry.activeDivisionBounds(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(bounds, isNull);
    });

    testWidgets('reads half-opened fold from MediaQuery', (tester) async {
      late Rect? bounds;
      const fold = Rect.fromLTWH(455, 0, 40, 669);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(951, 669),
            displayFeatures: [
              DisplayFeature(
                bounds: fold,
                type: DisplayFeatureType.fold,
                state: DisplayFeatureState.postureHalfOpened,
              ),
            ],
          ),
          child: Builder(
            builder: (context) {
              bounds = GameFoldGeometry.activeDivisionBounds(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(bounds, fold);
      expect(GameFoldGeometry.isVerticalDivision(fold), isTrue);
    });

    testWidgets('ignores flat posture folds', (tester) async {
      late Rect? bounds;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(951, 669),
            displayFeatures: [
              DisplayFeature(
                bounds: Rect.fromLTWH(455, 0, 40, 669),
                type: DisplayFeatureType.fold,
                state: DisplayFeatureState.postureFlat,
              ),
            ],
          ),
          child: Builder(
            builder: (context) {
              bounds = GameFoldGeometry.activeDivisionBounds(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(bounds, isNull);
    });

    test('classifies horizontal laptop crease', () {
      const crease = Rect.fromLTWH(0, 300, 951, 40);
      expect(GameFoldGeometry.isVerticalDivision(crease), isFalse);
    });

    test('avoidInsets prefers the larger pane', () {
      const viewport = Size(951, 669);
      const verticalFold = Rect.fromLTWH(455, 0, 40, 669);
      final insets = GameFoldGeometry.avoidInsets(viewport, verticalFold);
      expect(insets.left + insets.right, 40);
    });

    test('toSafeAreaLocal subtracts padding into local coordinates', () {
      const fold = Rect.fromLTWH(455, 50, 40, 569);
      final local = GameFoldGeometry.toSafeAreaLocal(
        fold,
        const EdgeInsets.only(top: 50),
        const Size(951, 619),
      );
      expect(local.top, 0);
      expect(local.left, 455);
      expect(local.width, 40);
      expect(local.height, 569);
    });

    test('toWidgetLocal uses board origin including app-bar offset', () {
      const fold = Rect.fromLTWH(0, 300, 951, 40);
      // Board starts 56pt below the window top (toolbar).
      final local = GameFoldGeometry.toWidgetLocal(
        fold,
        const Offset(0, 56),
        const Size(951, 613),
      );
      expect(local.top, closeTo(244, 0.5));
      expect(local.height, 40);
      expect(local.left, 0);
      expect(local.width, 951);
    });
  });
}
